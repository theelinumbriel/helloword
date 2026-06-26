#!/usr/bin/env bash
# Tests serve.py's /__open endpoint. Starts a throwaway server on a test port.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT=8765
PY="$(command -v python3 || command -v python)"
SRV=""
cleanup(){ [ -n "$SRV" ] && kill "$SRV" 2>/dev/null; }
trap cleanup EXIT
fail(){ echo "FAIL: $1"; exit 1; }

# Start server. serve.py chdirs to its own dir, so no `cd` wrapper is needed; running
# python directly (not in a subshell) makes $! the python PID so cleanup actually kills it.
PORT="$PORT" HELLOWORD_NOOPEN=1 "$PY" "$ROOT/serve.py" >/dev/null 2>&1 &
SRV=$!
for i in $(seq 1 25); do curl -fs "http://localhost:$PORT/index.html" >/dev/null 2>&1 && break; sleep 0.2; done

TMP="$(mktemp /tmp/hwopen.XXXXXX).md"
printf '# Hello\n\nbody text\n' > "$TMP"

# 1) reads an allowed file verbatim
GOT="$(curl -fs "http://localhost:$PORT/__open?path=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$TMP")")"
[ "$GOT" = "$(cat "$TMP")" ] || fail "content mismatch: [$GOT]"

# 2) rejects an unsupported extension (403)
CODE="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/__open?path=%2Fetc%2Fhosts")"
[ "$CODE" = "403" ] || fail "expected 403 for /etc/hosts, got $CODE"

# 3) 404 for a missing .md
CODE="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/__open?path=%2Ftmp%2Fdoes-not-exist-xyz.md")"
[ "$CODE" = "404" ] || fail "expected 404 for missing file, got $CODE"

# 4) static serving still works. Capture the body and glob-match instead of `curl | grep -q`,
# which under `set -o pipefail` fails: grep -q closes the pipe early and curl gets SIGPIPE.
BODY="$(curl -fs "http://localhost:$PORT/index.html")"
[[ "$BODY" == *helloword* ]] || fail "static index.html broke"

rm -f "$TMP"
echo "PASS"
