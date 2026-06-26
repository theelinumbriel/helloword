#!/bin/bash
# Double-click to open helloword in its own chromeless app window (macOS).
DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8137
PROFILE="$HOME/Library/Application Support/helloword"
mkdir -p "$PROFILE"
BASEURL="http://localhost:$PORT/index.html"

PY="$(command -v python3 || command -v python)"

# Optional first arg = a file to open (used by Finder "Open With HelloWord" via the .app).
# Resolve to an absolute path and append it as a url-encoded ?open= param so the page can
# fetch its contents from the server (see serve.py /__open).
URL="$BASEURL"
if [ -n "${1:-}" ]; then
  case "$1" in
    /*) ABS="$1" ;;
    *)  ABS="$(cd "$(dirname "$1")" 2>/dev/null && pwd)/$(basename "$1")" ;;
  esac
  if [ -n "$PY" ]; then
    ENC="$("$PY" -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$ABS")"
    URL="$BASEURL?open=$ENC"
  fi
fi

# Test hook: print the URL we would open and exit, without starting the server/browser.
if [ "${HELLOWORD_DRYRUN:-}" = "1" ]; then
  echo "$URL"
  exit 0
fi

# True only if OUR helloword app is what's served on the port (not just any HTTP 200/404
# from some other local service that happens to use 8137).
is_helloword(){ curl -fs "$BASEURL" 2>/dev/null | grep -q "helloword"; }

if ! is_helloword; then
  if [ -n "$PY" ]; then
    ( cd "$DIR" && PORT="$PORT" HELLOWORD_NOOPEN=1 nohup "$PY" serve.py >/dev/null 2>&1 & )
    for i in $(seq 1 25); do is_helloword && break; sleep 0.2; done
  fi
fi

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || CHROME="/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
[ -x "$CHROME" ] || CHROME="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"

if is_helloword && [ -x "$CHROME" ]; then
  nohup "$CHROME" --app="$URL" --user-data-dir="$PROFILE" \
        --no-first-run --no-default-browser-check --window-size=1100,820 \
        >/dev/null 2>&1 &
  disown 2>/dev/null
elif is_helloword; then
  open "$URL"
else
  # our server isn't on the port (busy/unavailable) — fall back to the local file
  open "file://$DIR/index.html"
fi
exit 0
