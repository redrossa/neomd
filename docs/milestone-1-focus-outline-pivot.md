# M1-P5 — Remove oversized document focus outlines

Status: **IMPLEMENTED and closed** as [#48 — M1-P5](https://github.com/redrossa/neomd/issues/48), merged in [PR #49](https://github.com/redrossa/neomd/pull/49) at `71cdd6acef777526f16f4020bc54fb273060b9a0`. [Worker evidence](m1-p5-focus-validation.md) records a passing Debug build and 28 scoped non-interaction units; visual/native behavior remains DEFERRED/UNRUN, not passed. The [milestone order](https://github.com/redrossa/neomd/milestone/1) now authorizes only [M1-P6 / #50](milestone-1-command-click-pivot.md), with #14 deferred and #15–24 paused even after #50. The approved story and source-investigation history below are retained, not authorization to resume other work.

## Business outcome and order

Keep the reading surface visually quiet without blue focus borders around paragraphs or the document viewport. The user reports outlines around link-bearing blocks, sometimes the content after Tab, and occasionally apparently the entire window.

Approved next story after completed #43, before any remaining M1 stories. #14 is entirely deferred by the user; #15–24 remain paused. Completing this pivot does not automatically resume them. No new milestone is proposed.

## M1-P5 — Quiet document keyboard focus

As a reader, I want document focus changes not to draw oversized blue outlines around blocks or the reading area, so that keyboard use does not distract from the document.

Labels: `bug`, `user-story`, `accessibility`.

- [ ] Link-bearing blocks do not acquire an enclosing blue border/glow when focused.
- [ ] Tab and existing reader keyboard navigation do not produce an enclosing focus border/glow around the document viewport or window content. Investigate the reported window-wide outline rather than assuming it has the same cause as the block overlay.
- [ ] Preserve existing focus targets, traversal, keyboard scrolling, link selection/activation and accessibility semantics; do not remove keyboard focusability to hide the effect.
- [ ] Preserve text-selection highlighting, normal link styling/underlines/cursors, ordinary native control focus indicators and intentional file-drag target feedback. Do not disable system-wide accessibility or focus settings.
- [ ] Reading and focus changes remain read-only, with no source bytes or modification-time changes.

## Evidence and scope boundaries

Source inspection at `8704fb2` confirms a custom accent-colour rounded-rectangle focus overlay in `NeoMD/Views/MarkdownBlockView.swift`, conditional on `.links(block.id)`. `NeoMD/Views/DocumentReaderView.swift` makes the document ScrollView focusable; default framework focus effects are a possible separate cause of the viewport outline, not a reproduced diagnosis. Horizontally overflowing code is also focusable.

The image Retry button and file-drop target have distinct intentional overlays; they are not automatically part of this removal. No parser, renderer architecture, window ownership, navigation-policy, global AppKit override, or selection rewrite is proposed. This would supersede the earlier link-block enclosing visual-focus requirement only; it does not authorize removing keyboard access or accessibility announcements. No new replacement indicator design is silently required.

## Dependencies and unresolved decisions

Depends on the current native reader and merged #43 baseline. The user approved the acceptance scope above, including retaining ordinary control rings and file-drag feedback. Published GitHub issue #48 is the implementation contract. Investigate exact local suppression APIs and window-wide cause during triage; escalate if preserving keyboard behavior requires a broader design change.

## Validation

Current user override: app build and relevant non-interaction unit tests only. No UI/E2E or manual scripted app flows. Record visual, Tab, window-wide, light/dark, selection, and assistive-technology behavior as deferred/unverified rather than passed. Triage supplies reproducible final-testing fixtures/documentation; no reviewer stage. All remaining stories stay paused pending renewed user direction.
