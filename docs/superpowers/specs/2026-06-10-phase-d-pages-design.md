# helloword — Phase D: pages + pageless mode

**Date:** 2026-06-10
**Scope:** `index.html` only.
**Decision (from user):** Page Layout uses **block-level pagination** (robust), plus a **Pageless** toggle. Not true line-level reflow.

## Core idea
The editor stays a single `contenteditable` (so the caret/selection/undo all keep working). Pagination is purely visual:
- A layer of absolutely-positioned white "sheet" rectangles (8.5x11in, gaps between) sits BEHIND the editor.
- The editor is transparent and overlaid exactly on the sheets.
- Non-editable "page-break spacer" elements are inserted BETWEEN top-level blocks so no block lands in the gap between sheets.

Because spacers are inserted only BETWEEN content blocks (never inside text nodes), re-pagination never disturbs the caret position within a block.

## Geometry
- Page = 8.5in x 11in. Margins = 1in each side. Printable content height per page `H = 9in`; content width = 6.5in.
- Inter-sheet gap `GAP = 0.35in`.
- Sheet `k` (0-based) spans vertical `k*(11in + GAP)` to `+11in`.
- The editor in Page mode: `background:transparent; box-shadow:none; padding:1in` (its 1in top/side padding aligns content with sheet 0's content area). Sheets are drawn behind via a `.page-bg` layer inside the stage.

## Pagination algorithm (`repaginate()`), debounced ~250ms on input; also on mode switch, zoom, resize
1. Remove all existing `.hw-pagebreak` spacers.
2. Save selection (anchor node + offset, focus node + offset).
3. Let `H_px` = 9in in px at current zoom (use a hidden 1in ruler element or `9 * 96 * zoomFactor`; the page CSS uses 96dpi, so 1in = 96px; zoom is a CSS transform on the editor, so measure in untransformed px = 96). Use `H_px = 9*96 = 864`.
4. Walk top-level block children of the editor (Element nodes only; skip spacers). Track `used` (px used on the current page).
   - measure `h = block.offsetHeight` (+ its vertical margins via getComputedStyle marginTop/marginBottom).
   - if `used + h <= H_px` (or `used === 0`): place it; `used += h`.
   - else (block overflows and `used > 0`): insert a `<div class="hw-pagebreak" contenteditable="false"></div>` before the block with height = `(H_px - used) + (2*96 + GAP_px)` i.e. fill the rest of the current page + bottom margin + gap + next top margin; then `used = h` (block starts the new page). GAP_px = 0.35*96.
   - if a single block `h > H_px` (taller than a page): place it without a spacer (accepted limitation: it will span the gap); set `used = (h % (H_px + 2*96 + GAP_px))` approximately — simplest: `used = h` and continue (subsequent blocks paginate after it). Document this approximation.
5. Restore selection.
6. Compute page count `P = ceil(totalContentHeight / H_px)` (or count spacers + 1). Render `P` background sheets in `.page-bg`. Update the status bar `Page 1 of P`.

## Modes
- `viewMode` in {`'page'`,`'pageless'`}, default `'page'`, persisted in settings (`SETTINGS` object alongside `stampDate`/`googleFonts`).
- **Pageless:** remove spacers + `.page-bg`; editor gets back its white background + box-shadow + continuous `min-height`. (Essentially today's look.)
- **Page:** transparent editor over background sheets + run `repaginate()`.
- Toggle UI: a "Views" group on the **View** ribbon tab with two buttons — `Print Layout` (page) and `Pageless`. Also reflect current mode (active button highlighted).

## Print
- Existing `@media print` already hides chrome. In Page mode, also hide `.hw-pagebreak` spacers and `.page-bg` for printing, and rely on the browser's own page breaking (`@page{margin:1in}`), so print output is clean regardless of on-screen pagination. Add `.hw-pagebreak{break-after:page}` is NOT needed; just hide spacers in print.

## Interactions / edge cases
- Spacers are `contenteditable="false"`, `user-select:none`, and excluded from `htmlToMd` (intercept `.hw-pagebreak` in `blockChildren` -> emit nothing) and from word/char counts.
- Enriched save: spacers would be saved in innerHTML; strip them before composing the payload OR re-paginate on load. Simplest: `repaginate()` regenerates them, so strip `.hw-pagebreak` before `htmlToMd`/`composeCurrentFileText` and before storing the Enriched `html` payload, then re-run `repaginate()` on load. (Keep the saved HTML clean of layout spacers.)
- Selection save/restore must handle the case where the anchor was inside a removed spacer (it never is, since spacers are non-editable and skipped).
- Re-paginate must not recurse: it edits only `.hw-pagebreak` nodes; the `input` listener is debounced and `repaginate` itself must not trigger `input` (DOM spacer insertion on a contenteditable can fire `input`; guard with a `repaginating` flag to ignore input events while repaginating).

## Verification
- Pure helper `paginatePlan(heights, H, extra)` -> array of page-break indices, unit-tested via `tests/hw-test.sh` (deterministic, no DOM).
- Screenshots: a long multi-heading/paragraph doc in Page mode shows stacked sheets with gaps and blocks starting cleanly on new pages; Pageless shows a continuous sheet; toggling works; Page N of M updates.
- Caret stability: type at the end of a long doc and confirm the caret doesn't jump when a new page is created (manual/scripted check).
