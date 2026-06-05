#!/bin/bash
# Double-click to open helloword in its own chromeless app window (macOS).
# Serves over http://localhost to avoid file:// permission denials.
DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8137
PROFILE="$HOME/Library/Application Support/helloword"
mkdir -p "$PROFILE"
URL="http://localhost:$PORT/index.html"

if ! curl -s -o /dev/null "$URL"; then
  PY="$(command -v python3 || command -v python)"
  if [ -n "$PY" ]; then
    ( cd "$DIR" && nohup "$PY" -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 & )
    for i in $(seq 1 25); do curl -s -o /dev/null "$URL" && break; sleep 0.2; done
  fi
fi

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || CHROME="/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
[ -x "$CHROME" ] || CHROME="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"

if curl -s -o /dev/null "$URL" && [ -x "$CHROME" ]; then
  "$CHROME" --app="$URL" --user-data-dir="$PROFILE" \
            --no-first-run --no-default-browser-check --window-size=1100,820 &
else
  open "$URL" 2>/dev/null || open "file://$DIR/index.html"
fi
