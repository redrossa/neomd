# M1-P7 — Source-relative Command-click window placement

Status: **APPROVED and published** as [#52 — M1-P7](https://github.com/redrossa/neomd/issues/52), in [milestone 1](https://github.com/redrossa/neomd/milestone/1). The user explicitly requested additional windows slightly down/right from the source window's top-left with screen-edge handling, then reported that it does not work. The earlier assistant's completion claim was incorrect: at canonical `main` `918cfa40f9fdb7323400021b3a06b11f1ff8cf69`, `DocumentWindowController.init` still unconditionally calls `window.center()`.

Source-only triage is **ACCEPTED for implementation**, not completed implementation or native behavior verification. No app code, executable tests, builds, prototypes or interactions were performed by triage.

## Business outcome

Make an additional reader feel spatially connected to the document that opened it, while keeping its native title bar and controls accessible on the source display. Preserve #50's independent reader and fragment behavior.

## Approved order and publication

1. M1-01–M1-13 and priority M1-P1–M1-P5 (#40–43, #48): completed.
2. [M1-P6 / #50](https://github.com/redrossa/neomd/issues/50): completed in [PR #51](https://github.com/redrossa/neomd/pull/51), merged as `918cfa40f9fdb7323400021b3a06b11f1ff8cf69`.
3. **[M1-P7 / #52](https://github.com/redrossa/neomd/issues/52): next and the only authorized story.**
4. M1-14 / #14: entirely deferred. M1-15–M1-24 / #15–24: paused, including after #52. Do not resume them automatically.

The canonical milestone order is authoritative. Published labels: `bug`, `enhancement`, `user-story`. No new milestone or additional story is proposed. Milestone business acceptance remains user-owned.

## M1-P7 — Cascade Command-click windows from their source within screen edges

As a reader opening a local Markdown link with Command-click, I want the additional window to cascade slightly down and right from the source window's top-left corner, so that it feels native and keeps the source easy to find.

The published acceptance wording is reproduced without checking unverified criteria:

- [ ] A successful Command-click local Markdown open initially positions the additional reader slightly down and right from the source reader's top-left corner, rather than centering it. Capture the originating reader before asynchronous opening; do not substitute whichever window later becomes active.
- [ ] Place the new reader on the source screen and constrain its frame to that screen's usable visible area, accounting for menu bar/Dock, screen edges, nonzero/negative display coordinates, and windows too large for the available area. Keep the title bar and controls accessible; if the desired offset cannot fit, adjust placement rather than leaving the window offscreen.
- [ ] Do not move or resize existing readers. Preserve #50 routing, source reading state, independent destination fragments, and failure behavior (no empty additional window). Ordinary opens still reuse their current reader; other opening routes retain their existing behavior.

## Dependencies and boundaries

Depends on completed #50 and #43. This corrects missing placement, not #50's routing. Ordinary clicks reuse the source; Command-click local Markdown gets an independent reader, including already-open/self-path destinations. Pure anchors, external and safe non-Markdown handling, File > Open / Command-O, Command-N, drops, cancellation and no-window-before-success policies remain unchanged. Command-N retains its existing default sizing/centering path; this is not a general cascade policy for all opens.

No new tabs/preferences/persistence, renderer rewrite, permission changes, settings changes or source writes. Preserve the unrelated local `project.pbxproj` modifications; no project-file change is expected.

## Engineering plan and unresolved decisions

Snapshot source frame and screen identity/usable geometry synchronously from the source session's registered controller; carry copied placement values through the existing request and late successful commit. Never look up the later active window or retain a live source window as placement authority. Use the actual new window frame, including title bar, with its existing default content size unless it needs shrinking to fit. Clamp in global AppKit coordinates to a currently available screen's `visibleFrame`.

A **24-point** right/down shift is a small native-style engineering choice, not a separately user-approved exact pixel specification or a claim of matching AppKit's private cascade algorithm. Source-screen removal, missing source geometry and screen-list edge cases use documented deterministic fallback; source closure after capture retains the captured placement and #50's independent destination lifetime. No missing product decision blocks this bounded scope. See [source trace, precise policy and allowable tests](m1-p7-window-cascade-validation.md).

## Validation limits

Current override: **no reviewer stage; later Debug build and relevant non-interaction units only.** No UI/E2E, real or synthetic events, window-host probes, manual scripted interactions, AX actions, pickers or app interactions. Physical display placement, title-bar/control accessibility, source scroll/selection, fragment landing, failure UI and interaction read-only checks remain **DEFERRED/UNRUN**, not passed. [Fixture packet and final user-owned recipe](fixtures/m1-p7-window-cascade/README-fixture.md) supplies future oracles, not present authorization. Preserve all historical catalog content and #36/#38 deferrals. Issue closure does not establish combined milestone acceptance.
