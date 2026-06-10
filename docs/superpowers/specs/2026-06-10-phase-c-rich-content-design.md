# helloword — Phase C: rich content

**Date:** 2026-06-10
**Scope:** `index.html` (plus, for equations, an inlined KaTeX bundle). Builds on Phase B Enriched mode so rich content round-trips.

## Decisions (from user)
- Equations: inline KaTeX (full LaTeX), bundled into the single file (fonts inlined as base64 so it stays offline).
- Images: embedded as base64 data URIs (portable, offline).

## Features

### C1 — Embedded image insert
- Insert > Pictures opens a file picker (`<input type="file" accept="image/*">`); the chosen image is read as a data URI and inserted as `<img src="data:...">`.
- Inserted images get `max-width:100%` and a simple resize affordance: clicking an image selects it and shows small size presets (25/50/75/100%) plus a width field; setting width applies an inline `width`.
- Markdown export already handles `<img>` as `![alt](src)`, so embedded images export as data-URI markdown (large but valid). Keep the existing `image` URL flow available too (e.g. via a secondary "by URL" option).

### C2 — Table row/column management
- When the caret is inside a table, a small floating table toolbar appears near it with: Insert Row Above, Insert Row Below, Insert Column Left, Insert Column Right, Delete Row, Delete Column, Delete Table.
- Operations manipulate the DOM `<table>` directly (insert/delete `<tr>`/`<td>`), preserving header row.
- Existing table insert (2x2) stays. Markdown export of tables already works.

### C3 — Table of Contents
- Insert > Table of Contents inserts a `<nav class="hw-toc" contenteditable="false">` listing all headings (h1–h6) with indentation by level and in-document anchor links (each heading gets/【keeps an `id`).
- An "Update" affordance on the TOC regenerates it from current headings.
- Markdown export: render the TOC as a nested bulleted list of links; or as a placeholder line. Keep it simple: export as a nested list of `- [Heading](#anchor)`.

### C4 — Footnotes
- Insert > Footnote inserts a superscript reference `<sup class="hw-fnref" data-fn="N"><a href="#fn-N">[N]</a></sup>` at the caret and a numbered entry in a footnotes section (`<section class="hw-footnotes">`) at the document end, with an editable text area for the note.
- References auto-number in document order; renumber on insert/delete.
- Markdown export: standard footnote syntax — `[^N]` at the reference and `[^N]: text` collected at the end. Extend `htmlToMd` (and `mdToHtml` for round-trip) to handle these.

### C5 — Citations + bibliography (lightweight)
- A simple source manager held in the document (Enriched payload / a hidden data block): Insert > Citation opens a small form (Author, Title, Year). Sources are stored; inserting a citation drops an inline `(Author, Year)` marker linked to the source.
- Insert > Bibliography inserts a `<section class="hw-bibliography">` listing all sources (Author, Title, Year), regenerable.
- This is a deliberately lightweight version (not full CSL/APA styles). Markdown export: inline citations as plain text `(Author, Year)`; bibliography as a list.

### C6 — Equations (inline KaTeX)
- Bundle KaTeX into `index.html`: inline `katex.min.js`, `katex.min.css`, and the required woff2 fonts as base64 `@font-face` data URIs so math renders fully offline.
- Insert > Equation prompts for LaTeX (or opens a small input); render with `katex.renderToString(latex, {throwOnError:false})` into a `<span class="hw-eq" contenteditable="false" data-tex="...">…</span>`. Support inline `$...$` and display `$$...$$`.
- Editing: clicking an equation re-opens the input pre-filled with its `data-tex`.
- Markdown export: `$tex$` (inline) / `$$tex$$` (display). Extend `htmlToMd` to emit from `data-tex`, and `mdToHtml` to render `$...$` back via KaTeX on open.
- Size budget: inline KaTeX + core fonts is in the hundreds of KB, accepted by the user. Only bundle the font subsets KaTeX actually needs (KaTeX_Main, KaTeX_Math, KaTeX_Size1–4, KaTeX_AMS, etc., regular+bold+italic as required).

## Cross-cutting
- All new block types that are `contenteditable="false"` (TOC, footnotes section, equations, bibliography) must be skipped/handled cleanly by `htmlToMd` so saving stays correct, and re-hydrated by `mdToHtml`/the Enriched payload on open.
- Enriched mode preserves everything via the HTML payload; Basic mode relies on the Markdown serialization defined per-feature above.

## Verification
- Pure logic on `window.HW` where possible (e.g. footnote renumbering, TOC building from a heading list, table op helpers) tested via `tests/hw-test.sh`.
- DOM/visual features verified with headless-Chrome screenshots and simulated interactions.
- Round-trip tests: insert each feature, save Enriched, reload → identical; save Basic → sane Markdown.

## Build order (increasing complexity)
C1 images → C2 tables → C3 TOC → C4 footnotes → C5 citations → C6 equations.
