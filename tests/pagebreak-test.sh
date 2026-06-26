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

# Code blocks: a tall <pre> splits into fragments, none taller than one page.
R="$(bash "$H" '
  var ed=document.getElementById("editor");
  var code=""; for(var i=1;i<=120;i++) code+="line "+i+" of code\n";
  ed.innerHTML="<pre><code>"+code+"</code></pre>"; window.HW.repaginate();
  var CONTENT=9*96, pres=[].slice.call(ed.querySelectorAll("pre"));
  if(pres.length<2) throw new Error("pre did not split");
  if(pres.filter(function(p){return p.offsetHeight>CONTENT;}).length) throw new Error("a pre fragment is taller than a page");
')"
[ "$R" = "PASS" ] || fail "code-block split geometry -> $R"

# Code blocks: saving stitches the fragments back into ONE fenced block with all lines.
R="$(bash "$H" '
  var ed=document.getElementById("editor");
  var code=""; for(var i=1;i<=120;i++) code+="codeline"+i+"\n";
  ed.innerHTML="<pre><code>"+code+"</code></pre>"; window.HW.repaginate();
  var txt=window.HW.composeCurrentFileText();
  var fences=txt.split("\n").filter(function(l){return /^\s*```/.test(l);}).length;
  var clines=(txt.match(/codeline\d+/g)||[]).length;
  if(fences!==2) throw new Error("saved "+fences+" fence lines, want 2");
  if(clines!==120) throw new Error("saved "+clines+" code lines, want 120");
')"
[ "$R" = "PASS" ] || fail "code-block merge-on-save -> $R"

# Paragraphs: a paragraph taller than a page splits at a word boundary, fragments fit, and the
# full text (in order) survives a save round-trip.
R="$(bash "$H" '
  var ed=document.getElementById("editor");
  var words=[]; for(var i=1;i<=1500;i++) words.push("w"+i);
  ed.innerHTML="<p>"+words.join(" ")+"</p>"; window.HW.repaginate();
  var CONTENT=9*96, ps=[].slice.call(ed.querySelectorAll("p"));
  if(ps.length<2) throw new Error("paragraph did not split");
  if(ps.filter(function(p){return p.offsetHeight>CONTENT;}).length) throw new Error("a paragraph fragment is taller than a page");
  var body=window.HW.composeCurrentFileText().split("<!-- helloword")[0];
  var got=(body.match(/w\d+/g)||[]);
  if(got.length!==1500) throw new Error("saved "+got.length+" words, want 1500");
  for(var k=1;k<=1500;k++){ if(got[k-1]!=="w"+k) throw new Error("word order broke at "+k); }
')"
[ "$R" = "PASS" ] || fail "paragraph split + round-trip -> $R"

echo "PASS"
