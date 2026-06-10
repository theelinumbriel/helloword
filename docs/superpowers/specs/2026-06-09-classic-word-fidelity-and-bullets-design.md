# helloword — Classic Word fidelity + Word bullet system

**Date:** 2026-06-09
**Scope:** Single-file app `index.html` plus `icon.svg` / `icon-256.png`. No new dependencies, no build step.

## Goal

Make helloword look visually like **classic Microsoft Word (Office 2016/2019)** — the solid blue ribbon/status-bar era — and make its **bullet/numbering system behave and look exactly like Word**, including the Bullets ▾ and Numbering ▾ library dropdowns. No unrelated features.

Target look chosen by user: **Classic (A)**, not Modern 365.

## 1. Logo

Replace the current title-bar tile and icons with a faithful Word-app-icon-style mark.

- Color: Word blue `#2b579a`.
- Glyph: lowercase **hw**, Segoe UI (Word's UI font), semibold (600), slight negative letter-spacing.
- White text on the blue tile, rounded corners.
- Apply to:
  - `.wlogo` in the title bar (small rounded tile, ~24×20).
  - `icon.svg` (rounded blue square, white lowercase `hw`).
  - `icon-256.png` regenerated from the SVG.

## 2. Bullet rendering (Word-exact)

Native `<ul>`/`<ol>` are kept (the editor depends on `execCommand` and the Markdown converter). Tune CSS only:

- **Marker color:** black (`#000`), not gray. Marker slightly bolder/larger via `::marker { font-size }`.
- **Glyph ladder (bullets):** L1 `disc` (•), L2 `circle` (o), L3 `square` (▪), then repeat — already correct; keep.
- **Number ladder:** L1 `decimal` (1.), L2 `lower-alpha` (a.), L3 `lower-roman` (i.), then repeat.
- **Indents:** Word-style hanging indent — first level text at ~0.5″, marker hanging ~0.25″ left; each nested level adds ~0.25–0.5″. Replace the current loose `0.4in`/`0.3in` with tighter Word-like values.
- **Item spacing:** tight (Word's default near-0 between list items), replacing the looser `2pt`.
- Task lists keep their existing `ul.task` no-marker behavior.

## 3. Bullets ▾ + Numbering ▾ library dropdowns

Restructure the Paragraph group's Bullets and Numbering buttons into **split buttons**:

- **Main part:** toggles the list (`insertUnorderedList` / `insertOrderedList`) — current behavior.
- **▾ part:** opens a Word-style picker panel anchored under the button.

**Bullet Library panel:** a grid of glyph tiles — `None`, `•`, `o`, `▪`, `❖`, `➢`, `✓`. (Optionally a "Recently used" row.)

**Numbering Library panel:** tiles for `None`, `1. 2. 3.`, `1) 2) 3)`, `I. II. III.`, `A. B. C.`, `a) b) c)`, `a. b. c.`, `i. ii. iii.`

**Apply behavior:**
- Find the list (`<ul>`/`<ol>`) containing the caret. If none, create one first (`insertUnorderedList`/`insertOrderedList`).
- For bullets: set `listStyleType` to `disc`/`circle`/`square` (keywords) or a CSS string value (e.g. `'"➢  "'`) for custom glyphs (Chromium supports string `list-style-type`). `None` → `none`.
- For numbering: use keywords (`decimal`, `upper-roman`, `upper-alpha`, `lower-alpha`, `lower-roman`) and `@counter-style` rules for paren-suffixed variants (`1)`, `a)`).
- Panel closes on selection or outside click (reuse the existing file-menu close pattern).

**Persistence/export:** inline `list-style-type` persists via the existing autosave (stores `innerHTML`). Markdown export is unchanged — `listToMd` still emits `-` / `1.`; bullet glyph styling is presentation-only and intentionally not serialized to Markdown.

## Non-goals

- No Multilevel List gallery (third Word button) — out of agreed scope.
- No Modern 365 restyle.
- No change to Markdown read/write semantics.

## Verification

- Open `index.html`, confirm: logo tile matches; bullets render black •/o/▪ with tight Word indents at three nesting levels; numbers render 1./a./i.; Bullets ▾ and Numbering ▾ open panels and apply the chosen glyph to the current list; Save still produces clean `.md` (`-` bullets, `1.` numbers) including nested items.
