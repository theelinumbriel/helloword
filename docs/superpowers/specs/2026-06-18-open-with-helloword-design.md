# Open With HelloWord — design

**Date:** 2026-06-18
**Status:** Approved (design)

## Goal

Let a user select a Markdown file in Finder and choose **Open With → HelloWord**, which
launches the HelloWord app window with that file already loaded for editing.

Scope is **read-only open**: the file is loaded and displayed; Save uses the existing
picker/download flow (no silent write-back to the original file). No new disk-write
capability is added to the local server.

## Background / current state

- `HelloWord.app` is a thin launcher bundle living inside the repo
  (`/Users/eldw/Desktop/md_editor/HelloWord.app`). Its executable
  (`Contents/MacOS/helloword`) is a **bash script** that starts `serve.py` on port 8137
  and opens a chromeless Chrome/Edge/Brave window at `http://localhost:8137/index.html`.
  Its `BUNDLE` resolves to the repo dir (the bundle's parent), so it serves the repo's
  `index.html` / `serve.py`.
- `launch.command` (repo root) is a near-duplicate of that bash launcher for non-`.app`
  use (double-click).
- `serve.py` is a read-only static file server (`SimpleHTTPRequestHandler`) with no-cache
  headers, bound to `127.0.0.1`.
- `index.html` already opens `.md`/`.markdown`/`.txt` files via the File System Access API
  (`openFile()` → `loadText(text, fileName)`), and `loadText` renders raw Markdown and sets
  the doc name from the filename. `saveMarkdown()` writes via `showSaveFilePicker` (or falls
  back to download).

### The macOS catch

A bash-script `.app` does **not** receive "Open With" files: macOS delivers the chosen file
via an `odoc` Apple Event, which a bash script cannot handle (no event loop). The file is
**not** passed as `argv`. To receive it without a compiler, the bundle must be an
**AppleScript applet** (handles `on open`). `osacompile` is available (macOS 26.3.1).

## Approaches considered

**Receiving the file:**
- **AppleScript applet (chosen)** — no compiler, natively handles the open-documents event,
  `osacompile` is present.
- Compiled Swift/ObjC stub — most native, but needs Xcode/clang and a build step (against the
  project's no-build ethos).
- Automator/Platypus — external tooling.

**Delivering the file to the web app:**
- **localhost read endpoint (chosen)** — the launcher passes the path via URL; the page
  fetches the content from the server. Works because the page can't read arbitrary local
  paths itself.
- URL param + File System Access — can't bind a path to a file handle; rejected.
- Launcher copies the file into a served temp location — extra copies, no benefit over the
  read endpoint; rejected.

## Design

### 1. `HelloWord.app` → AppleScript applet

Rebuild the bundle with `osacompile` from a small script:

```applescript
on run
    launchHelloWord(missing value)
end run

on open theFiles
    repeat with f in theFiles
        launchHelloWord(POSIX path of f)
    end repeat
end open

on launchHelloWord(posixPath)
    -- bundle path -> repo dir (the bundle's parent). `dirname` of a path with a
    -- trailing slash drops the last component, so dirname ".../HelloWord.app/" is
    -- the repo dir.
    set repoDir to do shell script "dirname " & quoted form of (POSIX path of (path to me))
    set launcher to repoDir & "/launch.command"
    if posixPath is missing value then
        do shell script quoted form of launcher
    else
        do shell script quoted form of launcher & " " & quoted form of posixPath
    end if
end launchHelloWord
```

Then re-apply the bundle's customizations on top of the osacompile output:

- `CFBundleName` / `CFBundleDisplayName` = `helloword`
- `CFBundleIdentifier` = `com.helloword.app`
- icon (`helloword.icns`) + `CFBundleIconFile`
- `NSHighResolutionCapable` = true, `LSMinimumSystemVersion` = 10.13
- **`CFBundleDocumentTypes`** declaring the openable types:

```xml
<key>CFBundleDocumentTypes</key>
<array>
  <dict>
    <key>CFBundleTypeName</key><string>Text / Markdown Document</string>
    <key>CFBundleTypeRole</key><string>Editor</string>
    <key>LSHandlerRank</key><string>Alternate</string>
    <key>CFBundleTypeExtensions</key>
    <array><string>md</string><string>markdown</string><string>txt</string></array>
    <key>LSItemContentTypes</key>
    <array>
      <string>net.daringfireball.markdown</string>
      <string>public.plain-text</string>
    </array>
  </dict>
</array>
```

Register so Finder picks it up (one-time setup step; re-runs harmlessly):
`/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f /Users/eldw/Desktop/md_editor/HelloWord.app`

Multiple files selected → one window per file (acceptable). Accept the limitation.

### 2. `launch.command` — single launcher, optional file arg

- Becomes the single source of launch logic (the applet calls it; double-click still works).
- Accepts an optional `$1` = absolute file path.
- Builds the URL: base `http://localhost:8137/index.html`, and if a file arg is present,
  append `?open=<url-encoded absolute path>` (URL-encode via `python3`).
- Everything else (start server if `is_helloword` is false, pick browser, `--app` window)
  is unchanged.
- The duplicate bash in `HelloWord.app/Contents/MacOS/helloword` is removed (that file
  becomes the compiled applet executable).

### 3. `serve.py` — add one read-only endpoint

Override `do_GET`: if the path is `/__open`, handle it; otherwise defer to the static
handler (`super().do_GET()`).

`GET /__open?path=<abs path>`:
- URL-decode `path`.
- Reject (HTTP 403) if the extension is not one of `.md`, `.markdown`, `.txt`.
- Reject (HTTP 404) if the file does not exist / is not a regular file.
- On success: read as UTF-8 and return `200` with `Content-Type: text/plain; charset=utf-8`
  and the file contents as the body.
- No write endpoint. Server stays read-only and `127.0.0.1`-bound.

### 4. `index.html` — load on `?open=`

- On init (after the existing `restore()`), read `?open=` from `location.search` via
  `URLSearchParams`.
- If present: `fetch('/__open?path=' + encodeURIComponent(path))`. On `200`, take the text
  and the basename of the path, and call the existing `loadText(text, basename)` — the same
  routine normal "Open" uses (renders Markdown, sets `docName`). On non-OK, leave the
  autosaved doc as-is and show a brief status message.
- **Save is unchanged.** Because `docName` is set from the opened file's basename,
  `saveMarkdown()`'s `suggestedName` is already pre-filled correctly.
- Loading the opened file takes precedence over the autosaved draft for display, but the
  autosave/localStorage behavior itself is untouched.

## Testing

**Automated (curl / shell):**
- Start `serve.py`; `GET /__open?path=<tmp>.md` returns the file's exact contents.
- `GET /__open` for a `.exe`/`.png` path → 403.
- `GET /__open` for a missing path → 404.
- `launch.command "/tmp/x.md"` with `HELLOWORD_NOOPEN=1` and a stubbed browser → assert the
  constructed URL contains `?open=` with the correctly encoded path.

**Existing harness (`tests/hw-test.sh`):**
- Confirm `loadText(text, name)` still renders Markdown and sets `docName` (regression).

**Manual end-to-end:**
- Rebuild the app, `lsregister`, right-click a real `.md` in Finder → Open With HelloWord →
  confirm the window opens with the file loaded → Cmd+S → picker appears pre-filled with the
  right name.

## Security note

`/__open` is read-only and `127.0.0.1`-bound, restricted to `.md`/`.markdown`/`.txt` that
exist. A local process/page that can reach `localhost:8137` could read such files whose path
it knows — a minor read-only disclosure acceptable for a personal, offline, single-user tool.
No write capability is added.

## Out of scope (YAGNI)

- Writing back to the original file from the server (explicitly deferred; Save uses the
  picker).
- Making HelloWord the *default* Markdown handler (`LSHandlerRank: Alternate` only — it just
  appears in "Open With").
- Opening many files into a single tabbed window.
