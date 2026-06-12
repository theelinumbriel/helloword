#!/usr/bin/env bash
# Usage: bash tests/hw-test.sh '<js snippet that sets document.title to PASS or FAIL:...>'
# Loads the real index.html (which exposes window.HW) and runs the snippet on load.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
# Trailing X's so BSD/GNU mktemp both randomize, then add the .html suffix Chrome needs.
TMP="$(mktemp "${TMPDIR:-/tmp}/hwtest.XXXXXXXX")"
mv "$TMP" "$TMP.html"; TMP="$TMP.html"
trap 'rm -f "$TMP"' EXIT
cp "$ROOT/index.html" "$TMP"
# Append test bootstrap. Runs after the app's own load handlers so our title wins.
cat >> "$TMP" <<'EOF'
<script>
function eq(a,b,m){ if(JSON.stringify(a)!==JSON.stringify(b)) throw new Error((m||"")+" got "+JSON.stringify(a)+" want "+JSON.stringify(b)); }
window.addEventListener("load",function(){ setTimeout(function(){ try{ __RUN__(); document.title="PASS"; }catch(e){ document.title="FAIL: "+(e&&e.message||e); } },50); });
</script>
EOF
# Inject the snippet as the body of __RUN__
SNIPPET="$1"
python3 - "$TMP" "$SNIPPET" <<'PY'
import sys
path, snippet = sys.argv[1], sys.argv[2]
html = open(path).read()
html = html.replace("__RUN__()", "(function(){ %s })()" % snippet, 1)
open(path,"w").write(html)
PY
"$CHROME" --headless --disable-gpu --dump-dom --virtual-time-budget=1000 "file://$TMP" 2>/dev/null \
  | grep -o '<title>[^<]*</title>' | head -1 | sed 's/<[^>]*>//g'
