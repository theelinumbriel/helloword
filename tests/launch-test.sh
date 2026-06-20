#!/usr/bin/env bash
# Tests launch.command's URL building via the HELLOWORD_DRYRUN hook (no server/browser launched).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "FAIL: $1"; exit 1; }

# no file arg -> plain index URL
GOT="$(HELLOWORD_DRYRUN=1 "$ROOT/launch.command")"
[ "$GOT" = "http://localhost:8137/index.html" ] || fail "no-arg url: [$GOT]"

# file arg -> ?open= with the url-encoded absolute path (spaces -> %20, slashes -> %2F)
GOT="$(HELLOWORD_DRYRUN=1 "$ROOT/launch.command" "/tmp/My Notes.md")"
[ "$GOT" = "http://localhost:8137/index.html?open=%2Ftmp%2FMy%20Notes.md" ] || fail "file url: [$GOT]"

echo "PASS"
