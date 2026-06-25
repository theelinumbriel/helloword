#!/usr/bin/env bash
# Tests that blocks taller than one page split across the page break instead of spilling
# past the sheet, and that saving stitches the fragments back into one block.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
H="$ROOT/tests/hw-test.sh"
fail(){ echo "FAIL: $1"; exit 1; }

# Tables: a tall table splits into fragments, none taller than one page (9in content area).
R="$(bash "$H" '
  var ed=document.getElementById("editor");
  var h="<table><thead><tr><th>A</th><th>B</th></tr></thead><tbody>";
  for(var r=1;r<=60;r++) h+="<tr><td>row "+r+"</td><td>val "+r+"</td></tr>";
  h+="</tbody></table>"; ed.innerHTML=h; window.HW.repaginate();
  var CONTENT=9*96, tables=[].slice.call(ed.querySelectorAll("table"));
  if(tables.length<2) throw new Error("table did not split");
  if(tables.filter(function(t){return t.offsetHeight>CONTENT;}).length) throw new Error("a fragment is taller than a page");
')"
[ "$R" = "PASS" ] || fail "table split geometry -> $R"

# Tables: saving stitches the fragments back into ONE table with all rows (no duplicate header).
R="$(bash "$H" '
  var ed=document.getElementById("editor");
  var h="<table><thead><tr><th>A</th><th>B</th></tr></thead><tbody>";
  for(var r=1;r<=60;r++) h+="<tr><td>r"+r+"a</td><td>r"+r+"b</td></tr>";
  h+="</tbody></table>"; ed.innerHTML=h; window.HW.repaginate();
  var txt=window.HW.composeCurrentFileText();
  var sep=txt.split("\n").filter(function(l){return /^\s*\|[\s|:-]*\|\s*$/.test(l)&&l.indexOf("---")>=0;}).length;
  var rows=(txt.match(/r\d+a/g)||[]).length;
  if(sep!==1) throw new Error("saved as "+sep+" tables, want 1");
  if(rows!==60) throw new Error("saved "+rows+" rows, want 60");
')"
[ "$R" = "PASS" ] || fail "table merge-on-save -> $R"

echo "PASS"
