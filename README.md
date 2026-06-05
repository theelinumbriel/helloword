# HelloWord — a Markdown word processor

> *Hello, World → Hello, Word.* 👋

Microsoft Word, basically — but every document saves as clean **Markdown** (`.md`).
It's a single HTML file. No install, no build step, no internet connection required.

A faithful Microsoft Word look — blue title bar, ribbon tabs (Home / Insert /
View…), grouped toolbars, ruler, and a blue status bar with a zoom slider —
wrapped around an editor whose only file format is Markdown.

## Features

- 📝 **WYSIWYG editing** — a real Word-style page, not a raw text box
- 🎀 **Ribbon toolbar** — headings, **bold**, *italic*, underline, ~~strikethrough~~, inline `code`
- 📋 Bulleted, numbered, and ☑ task lists (with nesting)
- 🔗 Links, 🖼 images, ― horizontal rules, ▦ tables, ❝ quotes, code blocks
- 💾 **Save to `.md`** (`Ctrl`/`Cmd`+`S`) — exports clean, portable Markdown
- 📂 **Open any `.md` file** — it's rendered back into the editor
- 🔢 Live word + character count
- 💿 **Autosaves** your work in the browser, so you never lose a draft
- ⌨️ Familiar shortcuts: `Cmd/Ctrl` + `B` / `I` / `U` / `K` / `S`
- ✈️ **100% offline & private** — nothing ever leaves your computer

## Run it locally

### Option 1 — just open it (easiest)

Download or clone this repo, then **double-click `index.html`**. That's it.
It opens in your browser and works completely offline.

```bash
git clone https://github.com/<your-username>/md_editor.git
cd md_editor
open index.html       # macOS
# xdg-open index.html # Linux
# start index.html    # Windows
```

### Option 2 — serve it on localhost

Some browsers are slightly happier serving files over `http://` than `file://`.
If you have Python installed:

```bash
python3 serve.py
```

Then open <http://localhost:8000> in your browser. Stop it with `Ctrl`+`C`.

(Any static server works too, e.g. `npx serve`.)

## How saving works

When you click **💾 Save .md**, the editor converts what's on the page into
Markdown and downloads a `.md` file named after your document title (editable in
the top bar). Open that file in any Markdown app — GitHub, Obsidian, VS Code,
Notion — and it just works.

Your in-progress document is also autosaved in your browser's local storage, so
closing the tab won't lose anything. Use **🗎 New** to start fresh.

## Browser support

Works in any modern browser (Chrome, Edge, Firefox, Safari). Everything runs
client-side in plain HTML/CSS/JavaScript — there is no server, no tracking, and
no dependencies.

## License

[MIT](LICENSE) — do whatever you like with it.
