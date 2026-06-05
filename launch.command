#!/bin/bash
# Double-click to open HelloWord in its own app window (macOS).
DIR="$(cd "$(dirname "$0")" && pwd)"
DOC="$DIR/index.html"
PROFILE="$HOME/Library/Application Support/HelloWord"
mkdir -p "$PROFILE"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || CHROME="/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
[ -x "$CHROME" ] || CHROME="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
if [ -x "$CHROME" ]; then
  "$CHROME" --app="file://$DOC" --user-data-dir="$PROFILE" \
            --no-first-run --no-default-browser-check --window-size=1100,820 &
else
  open "file://$DOC"
fi
