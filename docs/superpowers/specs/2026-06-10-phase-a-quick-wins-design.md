# helloword — Phase A: quick wins

**Date:** 2026-06-10
**Scope:** `index.html` only. Six mostly-independent improvements. Builds on Phase B (Enriched mode), so formatting added here (colors, styles) round-trips automatically when saved in Enriched mode.

## Decisions (from user)
- Filename date stamp: OFF by default; a toggle in the File menu turns it on.
- Format Painter: removed (dead button).

## Features

### A1 — Date-in-filename toggle
- New state `stampDate` (boolean), default `false`, persisted in localStorage settings.
- `stampedName()` currently always prefixes `YYYYMMDD HHMMSS ±HHMM`. Change so it only prefixes when `stampDate` is true; otherwise returns `cleanTitle(name).md`.
- File menu gains a toggle row: `Add date & time to filename` with a check mark when on. Clicking flips `stampDate` and persists it.

### A2 — Remove dead UI
- Remove the Format Painter button (`data-cmd="format-painter"`) and its no-op `case 'format-painter': break;`.
- Remove the three non-functional status-bar buttons: Read Mode (📖), Print Layout (📄), Web Layout (🌐). (Keep the zoom controls.)

### A3 — Print CSS
- Add an `@media print` block: hide `.title-bar, .ribbon-tabs, .ribbon, .ruler, .status-bar`, popups, and menus; show only `.page` at full width with no shadow/margins; `.stage` becomes static (no scroll, no gray background). Result: printing outputs just the document.

### A4 — Color pickers (highlight + font color)
- Highlight and Font Color become split buttons: main button applies the last-used color; the ▾ opens a palette popup (reuse the existing `.listlib`-style popup pattern from the bullet library).
- Palette: a grid of standard swatches (Word's standard colors + a row of theme grays), plus a "More colors…" row that opens a native `<input type="color">`.
- State: `lastHighlight` (default `#ffff00`) and `lastFontColor` (default `#c00000`). Applying uses `document.execCommand('hiliteColor'|'foreColor', false, color)`.
- The little color bar under each button reflects the last-used color.

### A5 — Styles / headings gallery
- Add a Styles group to the Home ribbon (after Paragraph) with clickable cards: Normal, No Spacing, Title, Heading 1, Heading 2, Heading 3, Heading 4, Quote.
- Each card applies via the existing `applyStyle()` / `formatBlock`: Normal→`p`, Title→`h1` (styled larger), Heading 1–4→`h1`–`h4`, Quote→`blockquote`, No Spacing→`p` with zero margins (a class).
- Cards show a small visual preview of the style (font/size/color), matching Word's Styles gallery look.

### A6 — Find & Replace
- A dialog overlay (hidden by default). `Ctrl/Cmd+F` opens it in Find mode; `Ctrl/Cmd+H` opens it with Replace shown. `Esc` closes.
- Fields: Find, Replace; buttons: Find Next, Find Previous, Replace, Replace All; a live "n of m" match count; optional Match case checkbox.
- Implementation: search `editor` text. Use the browser `window.find()` for navigation where available, plus a manual fallback that walks text nodes, wraps matches in a temporary `<mark class="hw-find">` highlight, and steps through them. Replace All operates on the matches. After replace, re-run search and `sync()`.
- Highlights are transient (not serialized): strip all `mark.hw-find` wrappers before save/markdown conversion, or use a non-persisted highlight (e.g. CSS ::selection-like styling via a wrapper removed on close).

## Testing / verification
- Pure logic where possible exposed on `window.HW` and tested with `tests/hw-test.sh`:
  - A1: `stampedName` honoring the flag (on → has prefix, off → no prefix).
  - A6: the search/replace core (match count, replaceAll on a string) as pure functions.
- DOM/visual features (A2 removal, A3 print, A4 palette, A5 gallery, A6 dialog) verified with headless-Chrome screenshots and by simulating clicks in the harness.

## Out of scope
Real pagination/page breaks (Phase D), images/tables/equations/footnotes/citations/TOC (Phase C).
