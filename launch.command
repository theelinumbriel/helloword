#!/bin/bash
# Double-click to open helloword in its own chromeless app window (macOS).
DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8137
PROFILE="$HOME/Library/Application Support/helloword"
mkdir -p "$PROFILE"
URL="http://localhost:$PORT/index.html"

# True only if OUR helloword app is what's served on the port (not just any HTTP 200/404
# from some other local service that happens to use 8137).
is_helloword(){ curl -fs "$URL" 2>/dev/null | grep -q "helloword"; }

if ! is_helloword; then
  PY="$(command -v python3 || command -v python)"
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
