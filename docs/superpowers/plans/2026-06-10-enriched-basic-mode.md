# Enriched / Basic Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make rich formatting (color, font, size, alignment, etc.) survive a save by embedding an invisible fidelity payload in the `.md`, with a Basic/Enriched mode toggle, while the file stays clean Markdown for every other tool.

**Architecture:** Pure functions inside `index.html` handle checksum, base64, serialize, and parse. They are exposed on `window.HW` so a headless-Chrome harness can unit-test them without a build step. Save composes `clean markdown [+ trailing HTML comment payload]`; Open detects/validates/strips the payload and falls back to clean Markdown on any mismatch. A status-bar control switches mode.

**Tech Stack:** Vanilla JS in a single `index.html`. Tests: headless Google Chrome via a bash harness that loads `index.html` and asserts on `window.HW`. macOS `sips`/`qlmanage` not needed here.

**Spec:** `docs/superpowers/specs/2026-06-10-enriched-basic-mode-design.md`

---

## File Structure

- **Modify `index.html`** — all production code lives here:
  - Pure helpers (checksum, base64 unicode-safe, `composeFileText`, `parseFileText`) added inside the existing IIFE, then assigned to `window.HW` for testing.
  - `docMode` state, status-bar toggle UI + menu + CSS, switch handler with one-time Basic warning.
  - `saveMarkdown` uses `composeFileText`; `loadText` uses `parseFileText`; autosave (`sync`/`restore`) carries `mode`.
- **Create `tests/hw-test.sh`** — the test runner: injects a JS snippet into a temp copy of `index.html`, runs headless Chrome, prints the resulting `document.title` (the snippet sets it to `PASS` or `FAIL: ...`).
- **Create `tests/enriched-cases.md`** — short human-readable log of what each test covers (kept in sync as tasks land).

All `window.HW` test hooks are harmless in production (they only expose pure functions; no behavior change).

---

## Conventions used by every test

The harness sets `document.title` to `PASS` or `FAIL: <reason>`. Snippets use a tiny inline assert:

```js
function eq(a,b,m){ if(JSON.stringify(a)!==JSON.stringify(b)) throw new Error((m||"")+" got "+JSON.stringify(a)+" want "+JSON.stringify(b)); }
```

Run command is always: `bash tests/hw-test.sh '<snippet>'` and Expected output is the literal line `PASS`.

---

## Task 0: Test harness

**Files:**
- Create: `tests/hw-test.sh`

- [ ] **Step 1: Write the harness script**

Create `tests/hw-test.sh`:

```bash
#!/usr/bin/env bash
# Usage: bash tests/hw-test.sh '<js snippet that sets document.title to PASS or FAIL:...>'
# Loads the real index.html (which exposes window.HW) and runs the snippet on load.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
TMP="$(mktemp /tmp/hwtest.XXXXXX.html)"
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
```

- [ ] **Step 2: Make it executable and verify it can read window (HW not present yet)**

Run: `chmod +x tests/hw-test.sh && bash tests/hw-test.sh 'eq(1,1)'`
Expected: `PASS`

- [ ] **Step 3: Verify a failing assert reports FAIL**

Run: `bash tests/hw-test.sh 'eq(1,2,"nums")'`
Expected: a line starting with `FAIL: nums`

- [ ] **Step 4: Commit**

```bash
git add tests/hw-test.sh
git commit -m "test: add headless-chrome test harness for index.html"
```

---

## Task 1: Pure helpers — checksum + unicode-safe base64, exposed on window.HW

**Files:**
- Modify: `index.html` (inside the IIFE, near the other helpers; add `window.HW` assignment before the closing `})();`)

- [ ] **Step 1: Write the failing tests**

Run: `bash tests/hw-test.sh 'eq(typeof HW.checksum,"function","checksum exists"); eq(typeof HW.b64encode,"function"); eq(typeof HW.b64decode,"function"); var s="café 🌮 漢字"; eq(HW.b64decode(HW.b64encode(s)), s, "b64 unicode roundtrip"); eq(HW.checksum("abc")===HW.checksum("abc"), true, "stable"); eq(HW.checksum("abc")!==HW.checksum("abd"), true, "differs");'`
Expected: `FAIL: checksum exists ...` (HW undefined / not a function)

- [ ] **Step 2: Implement the helpers**

In `index.html`, inside the IIFE (e.g. just after `function escapeHtml(...)`), add:

```js
/* ===== ENRICHED MODE: pure helpers ===== */
function hwChecksum(str){             // djb2, returned as unsigned hex
  let h=5381; for(let i=0;i<str.length;i++){ h=((h<<5)+h+str.charCodeAt(i))|0; }
  return (h>>>0).toString(16);
}
function hwB64Encode(str){            // unicode-safe
  return btoa(unescape(encodeURIComponent(str)));
}
function hwB64Decode(b64){
  return decodeURIComponent(escape(atob(b64)));
}
```

Then immediately before the IIFE's closing `})();` (the last line is `})();`), add the test surface:

```js
window.HW = {
  checksum: hwChecksum,
  b64encode: hwB64Encode,
  b64decode: hwB64Decode
};
```

- [ ] **Step 3: Run the test to verify it passes**

Run: `bash tests/hw-test.sh 'eq(typeof HW.checksum,"function","checksum exists"); eq(typeof HW.b64encode,"function"); eq(typeof HW.b64decode,"function"); var s="café 🌮 漢字"; eq(HW.b64decode(HW.b64encode(s)), s, "b64 unicode roundtrip"); eq(HW.checksum("abc")===HW.checksum("abc"), true, "stable"); eq(HW.checksum("abc")!==HW.checksum("abd"), true, "differs");'`
Expected: `PASS`

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: add enriched-mode checksum + unicode base64 helpers (window.HW)"
```

---

## Task 2: composeFileText — the serializer

**Files:**
- Modify: `index.html` (add `composeFileText`; extend `window.HW`)

- [ ] **Step 1: Write the failing tests**

Run:
```
bash tests/hw-test.sh 'var clean="# Title\n\nbody"; var b=HW.composeFileText(clean,"<h1>Title</h1>","Doc","basic"); eq(b, clean, "basic is clean only"); var e=HW.composeFileText(clean,"<h1>Title</h1>","Doc","enriched"); eq(/<!--\s*helloword:v1\s+[A-Za-z0-9+/=]+\s*-->\s*$/.test(e), true, "enriched has trailing comment"); eq(e.indexOf(clean)===0, true, "enriched starts with clean md");'
```
Expected: `FAIL: ... HW.composeFileText is not a function`

- [ ] **Step 2: Implement composeFileText**

In `index.html`, after the helpers from Task 1, add:

```js
const HW_MARK_PREFIX = "<!-- helloword:v1 ";
const HW_MARK_SUFFIX = " -->";
function composeFileText(cleanMd, html, name, mode){
  if(mode!=="enriched") return cleanMd;
  const payload = JSON.stringify({ v:1, html: html, srcChecksum: hwChecksum(cleanMd), name: name||"" });
  return cleanMd + "\n\n" + HW_MARK_PREFIX + hwB64Encode(payload) + HW_MARK_SUFFIX + "\n";
}
```

Extend the `window.HW` object to include `composeFileText`:

```js
window.HW = {
  checksum: hwChecksum,
  b64encode: hwB64Encode,
  b64decode: hwB64Decode,
  composeFileText: composeFileText
};
```

- [ ] **Step 3: Run the test to verify it passes**

Run:
```
bash tests/hw-test.sh 'var clean="# Title\n\nbody"; var b=HW.composeFileText(clean,"<h1>Title</h1>","Doc","basic"); eq(b, clean, "basic is clean only"); var e=HW.composeFileText(clean,"<h1>Title</h1>","Doc","enriched"); eq(/<!--\s*helloword:v1\s+[A-Za-z0-9+/=]+\s*-->\s*$/.test(e), true, "enriched has trailing comment"); eq(e.indexOf(clean)===0, true, "enriched starts with clean md");'
```
Expected: `PASS`

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: add composeFileText serializer for enriched/basic save"
```

---

## Task 3: parseFileText — the deserializer (safety-critical)

**Files:**
- Modify: `index.html` (add `parseFileText`; extend `window.HW`)

- [ ] **Step 1: Write the failing tests**

Run (round-trip, tamper, plain, garbage):
```
bash tests/hw-test.sh 'var clean="# Title\n\nbody text"; var html="<h1 style=\"color:red\">Title</h1><p>body text</p>"; var file=HW.composeFileText(clean,html,"Doc","enriched"); var r=HW.parseFileText(file); eq(r.mode,"enriched","roundtrip mode"); eq(r.stale,false,"roundtrip not stale"); eq(r.html,html,"roundtrip html"); eq(r.cleanMd,clean,"roundtrip clean"); var tampered=file.replace("body text","body text EDITED"); var t=HW.parseFileText(tampered); eq(t.mode,"basic","tampered=basic"); eq(t.stale,true,"tampered=stale"); eq(t.html,null,"tampered html null"); eq(t.cleanMd.indexOf("EDITED")>-1,true,"tampered keeps edit"); var p=HW.parseFileText("# Just markdown\n\nhi"); eq(p.mode,"basic","plain basic"); eq(p.html,null,"plain html null"); eq(p.stale,false,"plain not stale"); var g=HW.parseFileText("# x\n\n<!-- helloword:v1 not_valid_base64!! -->"); eq(g.mode,"basic","garbage basic"); eq(g.html,null,"garbage html null");'
```
Expected: `FAIL: ... HW.parseFileText is not a function`

- [ ] **Step 2: Implement parseFileText**

In `index.html`, after `composeFileText`, add:

```js
const HW_PAYLOAD_RE = /\n*<!--\s*helloword:v1\s+([A-Za-z0-9+/=]+)\s*-->\s*$/;
function parseFileText(text){
  const m = text.match(HW_PAYLOAD_RE);
  if(!m){ return { cleanMd: text.replace(/\s+$/,""), html:null, mode:"basic", stale:false }; }
  const cleanMd = text.slice(0, m.index).replace(/\s+$/,"");
  let payload=null;
  try { payload = JSON.parse(hwB64Decode(m[1])); } catch(_){ payload=null; }
  if(!payload || typeof payload.html!=="string"){
    return { cleanMd: cleanMd, html:null, mode:"basic", stale:false };
  }
  if(payload.srcChecksum !== hwChecksum(cleanMd)){
    return { cleanMd: cleanMd, html:null, mode:"basic", stale:true };  // edited elsewhere
  }
  return { cleanMd: cleanMd, html: payload.html, mode:"enriched", stale:false };
}
```

Extend `window.HW` to include `parseFileText`:

```js
window.HW = {
  checksum: hwChecksum,
  b64encode: hwB64Encode,
  b64decode: hwB64Decode,
  composeFileText: composeFileText,
  parseFileText: parseFileText
};
```

- [ ] **Step 3: Run the test to verify it passes**

Run the same long command from Step 1.
Expected: `PASS`

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: add parseFileText deserializer with stale-payload fallback"
```

---

## Task 4: Mode state + status-bar toggle UI

**Files:**
- Modify: `index.html` (status-bar HTML, CSS for the menu, `docMode` state, `setMode`, click handlers; extend `window.HW` with `getMode`/`setMode`)

- [ ] **Step 1: Write the failing tests**

Run:
```
bash tests/hw-test.sh 'eq(HW.getMode(),"enriched","default enriched"); HW.setMode("basic",true); eq(HW.getMode(),"basic","set basic"); eq(document.getElementById("modeToggle").textContent.indexOf("Basic")>-1,true,"label shows Basic"); HW.setMode("enriched",true); eq(document.getElementById("modeToggle").textContent.indexOf("Enriched")>-1,true,"label shows Enriched");'
```
Expected: `FAIL: ... getMode is not a function` (or `modeToggle` is null)

- [ ] **Step 2: Add the status-bar control HTML**

In `index.html`, in the `.status-bar`, add a mode control right after the `saveStat` span (`<span class="si" id="saveStat">Autosaved</span>`):

```html
    <span class="si mode-toggle" id="modeToggle" title="Document fidelity mode">Mode: Enriched ▾</span>
```

And add the menu near the file menu (`<div class="filemenu hidden" id="fileMenu">...</div>`), after it:

```html
  <!-- MODE MENU -->
  <div class="filemenu hidden" id="modeMenu" style="left:auto">
    <button data-mode="enriched"><span class="ic">✦</span> Enriched <span style="opacity:.5;margin-left:auto">rich formatting saved</span></button>
    <button data-mode="basic"><span class="ic">≡</span> Basic <span style="opacity:.5;margin-left:auto">plain Markdown</span></button>
  </div>
```

- [ ] **Step 3: Add CSS for the mode toggle**

In the `<style>` block, after the `.status-bar .si:hover` rule, add:

```css
  .status-bar .mode-toggle{cursor:pointer}
  #modeMenu{top:auto;bottom:26px;min-width:230px}
```

- [ ] **Step 4: Implement state + setMode + handlers**

In the IIFE, near the top where elements are grabbed, add:

```js
  const modeToggle=document.getElementById('modeToggle');
  const modeMenu=document.getElementById('modeMenu');
  let docMode='enriched';
```

Add the functions (near `closeFileMenu`):

```js
  function renderMode(){ modeToggle.textContent='Mode: '+(docMode==='enriched'?'Enriched':'Basic')+' ▾'; }
  function setMode(mode, silent){
    if(mode!=='enriched'&&mode!=='basic') return;
    if(mode==='basic' && docMode!=='basic' && !silent){
      if(!confirm("Basic saves plain Markdown so colors/sizes/alignment won't be stored in the file.")) return;
    }
    docMode=mode; renderMode(); sync();
  }
```

Wire the toggle + menu (near the other menu handlers):

```js
  modeToggle.addEventListener('click',e=>{ e.stopPropagation(); closeFileMenu(); modeMenu.classList.toggle('hidden'); });
  modeMenu.addEventListener('click',e=>{ const b=e.target.closest('button'); if(!b)return; modeMenu.classList.add('hidden'); setMode(b.dataset.mode); });
  document.addEventListener('click',e=>{ if(!e.target.closest('#modeMenu')&&!e.target.closest('#modeToggle')) modeMenu.classList.add('hidden'); });
```

Call `renderMode()` once during init (add to the final init line area, e.g. right before `editor.focus();` in the bottom `restore();ensureBlock();...` line):

```js
  renderMode();
```

Extend `window.HW`:

```js
  window.HW = {
    checksum: hwChecksum, b64encode: hwB64Encode, b64decode: hwB64Decode,
    composeFileText: composeFileText, parseFileText: parseFileText,
    getMode: ()=>docMode, setMode: setMode
  };
```

- [ ] **Step 5: Run the test to verify it passes**

Run the command from Step 1.
Expected: `PASS`

- [ ] **Step 6: Visual check the toggle renders in the status bar**

Run: `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --force-device-scale-factor=2 --window-size=1000,820 --screenshot=/tmp/mode.png "file://$(pwd)/index.html" 2>/dev/null`
Then open `/tmp/mode.png` and confirm the status bar shows `Mode: Enriched ▾`. Delete `/tmp/mode.png` after.

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat: add Basic/Enriched mode toggle in the status bar"
```

---

## Task 5: Integrate serializer into Save

**Files:**
- Modify: `index.html` (`saveMarkdown` function around `const md=htmlToMd(editor);`)

- [ ] **Step 1: Write the failing test (string composition path)**

This test exercises the exact composition Save will write, via a new `composeCurrentFileText()` wrapper that Save will call.

Run:
```
bash tests/hw-test.sh 'document.getElementById("editor").innerHTML="<h1>Hi</h1><p style=\"text-align:center\">mid</p>"; HW.setMode("enriched",true); var out=HW.composeCurrentFileText(); eq(/helloword:v1/.test(out),true,"enriched save has payload"); HW.setMode("basic",true); var out2=HW.composeCurrentFileText(); eq(/helloword:v1/.test(out2),false,"basic save no payload");'
```
Expected: `FAIL: ... composeCurrentFileText is not a function`

- [ ] **Step 2: Add composeCurrentFileText and use it in saveMarkdown**

In `index.html`, add near `composeFileText`:

```js
  function composeCurrentFileText(){
    const md = htmlToMd(editor);
    const name = (docName.textContent.trim()||'Document1');
    return composeFileText(md, editor.innerHTML, name, docMode);
  }
```

In `saveMarkdown`, replace the line `const md=htmlToMd(editor);` with:

```js
    const md=composeCurrentFileText();
```

(The rest of `saveMarkdown` already writes `md` to the file/handle/download — no other change.)

Extend `window.HW` with `composeCurrentFileText: composeCurrentFileText`.

- [ ] **Step 3: Run the test to verify it passes**

Run the command from Step 1.
Expected: `PASS`

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: Save writes enriched payload when in Enriched mode"
```

---

## Task 6: Integrate deserializer into Open

**Files:**
- Modify: `index.html` (`loadText` function)

- [ ] **Step 1: Write the failing tests**

This drives `loadText` directly (exposed via HW) and checks editor content + mode + stale notice.

Run:
```
bash tests/hw-test.sh 'var clean="# Doc\n\nhello"; var html="<h1>Doc</h1><p style=\"color:rgb(192,0,0)\">hello</p>"; var file=HW.composeFileText(clean,html,"Doc","enriched"); HW.loadText(file,"Doc.md"); eq(document.getElementById("editor").innerHTML,html,"enriched restores html"); eq(HW.getMode(),"enriched","mode enriched after open"); var plain="# Plain\n\njust text"; HW.loadText(plain,"Plain.md"); eq(HW.getMode(),"basic","plain opens basic"); eq(document.getElementById("editor").innerHTML.indexOf("Plain")>-1,true,"plain renders heading");'
```
Expected: `FAIL` (loadText not on HW, or behavior wrong)

- [ ] **Step 2: Rewrite loadText to use parseFileText**

In `index.html`, replace the existing `loadText` body:

```js
  function loadText(text,fileName){
    const parsed = parseFileText(text);
    if(parsed.html!==null){ editor.innerHTML = parsed.html; }
    else { editor.innerHTML = mdToHtml(parsed.cleanMd); }
    setMode(parsed.mode, true);
    docName.textContent=fileName.replace(/\.(md|markdown|txt)$/i,'')||'Document1';
    document.title=docName.textContent+' - helloword';
    if(parsed.stale){ saveStat.textContent='External edits detected, opened as Basic'; }
    editor.focus();ensureBlock();sync();
  }
```

Expose it: add `loadText: loadText` to `window.HW`.

- [ ] **Step 3: Run the test to verify it passes**

Run the command from Step 1.
Expected: `PASS`

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: Open restores enriched payload, falls back to Basic on external edits"
```

---

## Task 7: Autosave carries mode + full round-trip verification

**Files:**
- Modify: `index.html` (`sync` and `restore`)

- [ ] **Step 1: Write the failing test**

Run:
```
bash tests/hw-test.sh 'HW.setMode("basic",true); var raw=localStorage.getItem("wordlike.doc.v2"); eq(raw&&JSON.parse(raw).mode,"basic","autosave stores mode");'
```
Expected: `FAIL` (mode not present in the autosave record). Note: `setMode` calls `sync()` which writes localStorage after a 400ms debounce, so the snippet must wait. Adjust the snippet to assert after a delay:

Run instead:
```
bash tests/hw-test.sh 'HW.setMode("basic",true); var done=false; setTimeout(function(){var raw=localStorage.getItem("wordlike.doc.v2"); if(!(raw&&JSON.parse(raw).mode==="basic")) document.title="FAIL: mode not saved"; else document.title="PASS";},700); throw {message:"__async__"};'
```
Expected: `FAIL: mode not saved` (before implementing).

NOTE for the implementer: the harness sets `PASS` after the snippet returns; for async assertions the snippet sets `document.title` itself inside the `setTimeout` and throws a sentinel so the harness does not overwrite it. The reported title will be whatever the timeout set, observed because `--virtual-time-budget=1000` waits. If the sentinel approach is fragile, instead assert synchronously by calling the localStorage write directly (see Step 2 alternative).

- [ ] **Step 2: Persist mode in sync, restore it in restore**

In `index.html`, in `sync`, change the `localStorage.setItem` payload to include `mode`:

```js
      try{localStorage.setItem(STORAGE,JSON.stringify({name:docName.textContent.trim()||'Document1',html:editor.innerHTML,mode:docMode}));saveStat.textContent='Autosaved ✓';}
```

In `restore`, after restoring name/html, restore mode:

```js
      if(d.mode==='basic'||d.mode==='enriched'){ docMode=d.mode; }
```

(Place this inside the existing `if(raw){...}` block, then `renderMode()` is already called at init.)

To make the test deterministic, also expose a synchronous flush for tests by adding `flushAutosave` that writes immediately:

```js
  function flushAutosave(){ localStorage.setItem(STORAGE,JSON.stringify({name:docName.textContent.trim()||'Document1',html:editor.innerHTML,mode:docMode})); }
```

Add `flushAutosave: flushAutosave` to `window.HW`.

- [ ] **Step 3: Run a deterministic test**

Run:
```
bash tests/hw-test.sh 'HW.setMode("basic",true); HW.flushAutosave(); eq(JSON.parse(localStorage.getItem("wordlike.doc.v2")).mode,"basic","autosave mode basic"); HW.setMode("enriched",true); HW.flushAutosave(); eq(JSON.parse(localStorage.getItem("wordlike.doc.v2")).mode,"enriched","autosave mode enriched");'
```
Expected: `PASS`

- [ ] **Step 4: Full end-to-end round-trip test**

Run:
```
bash tests/hw-test.sh 'var ed=document.getElementById("editor"); ed.innerHTML="<h1 style=\"color:rgb(192,0,0)\">Colored</h1><p style=\"text-align:center;font-size:18pt\">Centered big</p>"; HW.setMode("enriched",true); var file=HW.composeCurrentFileText(); HW.loadText(file,"RT.md"); eq(ed.innerHTML,"<h1 style=\"color:rgb(192,0,0)\">Colored</h1><p style=\"text-align:center;font-size:18pt\">Centered big</p>","full fidelity roundtrip"); eq(HW.getMode(),"enriched","still enriched");'
```
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add index.html tests/
git commit -m "feat: autosave persists mode; add full enriched round-trip test"
```

---

## Self-Review (completed during authoring)

- **Spec coverage:** payload format (Tasks 1–2), save serializer (Tasks 2, 5), open deserializer with checksum + stale fallback (Tasks 3, 6), status-bar toggle + exact Basic warning text (Task 4), autosave mode field (Task 7), Unicode round-trip (Task 1), versioned tag `v1` (Task 2). All spec sections map to a task.
- **Placeholder scan:** every code step contains complete code; every test step contains the exact command and expected `PASS`. The one async wrinkle (Task 7 Step 1) is called out and resolved with `flushAutosave` for a deterministic test.
- **Type/name consistency:** `composeFileText`, `parseFileText`, `composeCurrentFileText`, `loadText`, `setMode`, `getMode`, `flushAutosave`, `docMode`, `hwChecksum`, `hwB64Encode`, `hwB64Decode`, `HW_PAYLOAD_RE`, `HW_MARK_PREFIX/SUFFIX` are used consistently across tasks. The `window.HW` object is extended (not redefined inconsistently) — the implementer should keep one `window.HW = {...}` assignment and add keys to it as tasks land (the plan shows the growing object each time; keep the latest superset).

**Implementer note:** maintain a single `window.HW = { ... }` assignment placed just before the IIFE's closing `})();`. Each task adds keys; use the most complete version (Task 7's superset: checksum, b64encode, b64decode, composeFileText, parseFileText, composeCurrentFileText, loadText, getMode, setMode, flushAutosave).
