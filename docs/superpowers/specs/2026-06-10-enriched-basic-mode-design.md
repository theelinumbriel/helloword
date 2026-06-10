# helloword — Enriched / Basic mode (Phase B foundation)

**Date:** 2026-06-10
**Scope:** Single-file app `index.html`. Save/open layer + a mode toggle. No new dependencies.
**Why first:** This is the foundation for later rich features (color, fonts, alignment, equations, footnotes, citations). Once rich formatting can round-trip through a saved file, those features land already persistent instead of needing rework.

## Problem

The file format is Markdown, so formatting Markdown cannot express (font color, highlight, font family, font size, alignment, line spacing, sub/superscript, later: equations/footnotes/citations) is silently dropped on Save. The user wants this formatting preserved and recoverable on reopen, while the `.md` stays a normal, clean Markdown file.

## Decision

Two save modes, defaulting to Enriched.

- **Enriched (default):** write clean Markdown, then append ONE invisible HTML comment carrying full fidelity:
  ```
  # Heading
  Clean markdown body...

  <!-- helloword:v1 <base64 JSON payload> -->
  ```
  Markdown renderers (GitHub, Obsidian, VS Code preview) ignore HTML comments, so the file looks and renders as clean Markdown everywhere. helloword reads the comment to restore exact formatting.
- **Basic:** write pure clean Markdown, no comment. Lossy by design.

Rejected alternatives: a separate sidecar `.hw.json` file (requires writing two files via the File System Access API and fidelity is lost if the sidecar is separated from the `.md`); inline HTML throughout the Markdown (round-trips but the `.md` is no longer clean, which is the opposite of the goal).

## Payload format

`<!-- helloword:v1 <base64> -->` where base64 encodes UTF-8 JSON:

```json
{
  "v": 1,
  "html": "<editor.innerHTML at save time>",
  "srcChecksum": "<checksum of the clean markdown body>",
  "name": "<doc title>"
}
```

- base64 is used so newlines and any `-->` inside the HTML cannot terminate the comment early.
- `srcChecksum` is a cheap hash (e.g. FNV-1a / djb2 over the clean markdown body string) used to detect external edits.
- `v` allows the format to evolve; readers ignore unknown future fields.
- Encoding handles full Unicode: encode the JSON string as UTF-8 bytes before base64 (e.g. `btoa(unescape(encodeURIComponent(json)))`, decode with the inverse).

## Save (serializer)

1. Compute clean markdown with the existing `htmlToMd(editor)`.
2. If mode is Basic: write the clean markdown.
3. If mode is Enriched: compute `srcChecksum` of the clean markdown, build the JSON, base64-encode it, append `\n\n<!-- helloword:v1 <base64> -->\n` after the clean markdown.

Both the File System Access write path and the download fallback use this combined output.

## Open (deserializer) — safety-critical

1. Read file text.
2. Detect a trailing comment with a strict regex anchored at end of file: `/\n*<!--\s*helloword:v1\s+([A-Za-z0-9+/=]+)\s*-->\s*$/`.
3. Strip the matched comment to get the clean markdown body.
4. If a comment was found:
   - base64-decode and JSON-parse the payload (guard with try/catch; on any parse error, treat as no comment).
   - Compute the checksum of the clean markdown body actually present in the file.
   - **Match:** set `editor.innerHTML = payload.html`, mode = Enriched.
   - **Mismatch** (file was edited in another app): discard the payload, render the clean markdown via `mdToHtml`, mode = Basic, show a non-blocking notice: "External edits detected, opened as Basic."
5. If no comment: render clean markdown via `mdToHtml`, mode = Basic.

This guarantees we never silently resurrect stale content over a user's external edits.

## Mode toggle (UI)

- A status-bar control: `Mode: Enriched` with a small caret; clicking opens a small 2-item menu (Enriched / Basic) and selecting one sets the mode. Placed in the status bar near the existing view controls (Word puts view toggles there).
- Switching to Basic shows a one-time confirm with this exact text (no em dashes):
  > Basic saves plain Markdown so colors/sizes/alignment won't be stored in the file.
- Switching mode does NOT alter the in-editor content; it only changes what the next Save writes. Rich formatting stays visible in the session regardless of mode.
- Mode persists per document: stored in the autosave record and written into the Enriched payload.

## Autosave

The localStorage record gains a `mode` field alongside the existing `name` and `html`. No migration needed: a missing `mode` defaults to Enriched.

## Edge cases

- The hidden comment must be the last content in the file. `htmlToMd` trims trailing whitespace, so append the comment after that trim.
- Detection is anchored at end-of-file and requires the exact `helloword:v1` token, so ordinary body text starting with `<!--` will not be misread as a payload.
- Embedded images already live in `editor.innerHTML` as data URIs, so Enriched preserves them automatically. How Basic represents local images is deferred to Phase C.
- Very large payloads (many embedded images) inflate file size; acceptable for v1, revisit with optional compression (CompressionStream gzip) later.

## Out of scope (Phase B)

Color pickers, styles gallery, equations, footnotes, citations, TOC, pages, find/replace. Phase B only makes fidelity round-trip; those features are later phases that rely on it.

## Verification

Headless-Chrome round-trip tests against the real `index.html`:
1. Build a doc with font color, centered paragraph, and a custom font size. Serialize Enriched, re-parse the output, confirm restored HTML equals the original.
2. Serialize Basic, confirm output is the clean markdown with no comment.
3. Take an Enriched output, mutate the markdown body text, re-open: confirm it falls back to Basic and renders the edited text (no stale restore).
4. Confirm a plain `.md` with no comment opens as Basic.
5. Confirm Unicode content (accents, emoji, CJK) round-trips through the base64 payload.
