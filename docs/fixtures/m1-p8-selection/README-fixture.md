# M1-P8 / #64 inert selection packet

Base: `1738b1d2e9e7f74411f0d63e4aab401c1522109b`. This packet is triage-authored, not a native test result. See [validation](../../m1-p8-validation.md).

- `cross-blocks.md`: original, offline Markdown with metadata key/value parts, adjacent prose, literal spaces/tab in code, same-row table cells, safe explicit internal/self-file links, decomposed accent and a composed emoji. Opening must not automatically follow links. Copy includes rendered words without style delimiters; keep code indentation and TAB/LF table/metadata joining.
- `pointer-cases.json`: declarative geometry and event-state expectations. Coordinates are a synthetic, common window space for pure value tests, not actual AppKit measurements. Rectangles are `[x,y,width,height]`; bounds/visibleRect/clip rects in geometry cases are already converted into this common space. Worker writes the pure helper/tests, not a native test host. `range`/offset values use UTF-16.
- Existing `../m1-16-selection/table-order.md`, `projection-cases.json`, `refresh-before.md`, `refresh-after.md` and `../m1-22-reading-size/` remain unchanged and supplement extraction/refresh/reflow coverage.

## Future user-owned native observation matrix — DEFERRED/UNRUN

This is a pending checklist, not authorization for an agent to execute scripted/manual interactions.

1. Select from the middle of Alpha into Delta, reverse the direction, and extend through code, metadata and same-row/next-row table cells. Confirm the pointer's actual target, continuous owner range and one active selection appearance, including wrapped lines.
2. Shift-click forward/backward from a stored anchor. Double-/triple-click then drag in either direction retains the initial word/paragraph. Select All and explicit Copy include offscreen logical fragments with the existing plain-text oracle. Inspect clipboard only during user-authorized final testing; no worker clipboard mutation.
3. Link mouse-up without drag opens once; link-origin drag never opens. Command-click self-file creates an independent additional reader; Control/right-click retains #11 destinations/menu. Ordinary controls/find field retain their own shortcuts.
4. Find `lantern`; extend selection across its match; dismiss/reopen/step find. Selection and match never erase each other's state/decorations. Move focus across native leaves: no inactive-gray islands in the active reader, no enclosing glow. In an actually inactive window, all slices must follow one consistent inactive policy rather than mixing states.
5. Change reading size/width; return to original size; perform an external refresh on a disposable copy. Endpoints re-derive, source remains immutable, and no stale rectangles/ranges survive. A queued size command waits for a gesture to finish.
6. For lazy coverage, use the existing M1-16 long-document recipe, then drag through an edge while the origin scrolls away. Newly mounted leaves join the owner range; horizontal code/table reveal stays local. Cancel/close/window loss ends busy state and cannot activate a pending link. Second reader stays untouched.
7. Inspect adaptive light/dark colors, high-contrast legibility, native/AX selection and unchanged source bytes/mtime under the user's final validation authority. Model/API tests cannot establish any of these outcomes.

Triage and worker native result slots: **DEFERRED/UNRUN**. Preserve known #36/#38 failures and #14 deferral; do not declare milestone acceptance.
