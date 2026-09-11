# M1-P6 — Command-click local Markdown into an additional reader

Status: **APPROVED and published** as [#50 — M1-P6](https://github.com/redrossa/neomd/issues/50). The user explicitly approved restoring Command-click-new-window while ordinary clicks reuse the current reader. Source-only triage at canonical `main` `71cdd6acef777526f16f4020bc54fb273060b9a0` is **ACCEPTED for implementation**, not a behavior pass. No implementation/build/interaction was performed by triage.

## Business outcome

Keep the source document available while following a local Markdown reference, without changing the familiar ordinary-click replacement flow. A destination already open elsewhere still gets a distinct additional reader; existing readers retain their state.

## Approved order and publication

1. M1-01–M1-13 and priority M1-P1–M1-P4 (#40–43): completed.
2. [M1-P5 / #48](https://github.com/redrossa/neomd/issues/48): completed in [PR #49](https://github.com/redrossa/neomd/pull/49), merged at the triage base above.
3. **[M1-P6 / #50](https://github.com/redrossa/neomd/issues/50): next and the only authorized story.**
4. M1-14 / #14: entirely deferred. M1-15–M1-24 / #15–24: paused, including after #50. Do not automatically resume them.

The [canonical milestone order](https://github.com/redrossa/neomd/milestone/1) controls sequencing. No new milestone is proposed. Labels: `enhancement`, `user-story` (published). Milestone business acceptance remains user-owned.

## M1-P6 — Open local Markdown links in a new window with Command-click

As a reader following a local Markdown link, I want Command-click to open it in a new reading window while ordinary clicks reuse the current window, so that I can keep the source document open.

The following is the published issue's acceptance wording, reproduced without checking unverified criteria:

- [ ] Command-click on a supported local Markdown link opens the destination in an additional reading window, leaving the source window and its reading state unchanged, including when the destination is already open.
- [ ] Ordinary clicks continue to replace the source reading window. Preserve local path and fragment resolution for both dispositions; a fragment on a Command-click target belongs to the new reader, not an existing reader.
- [ ] Failed, missing or inaccessible destinations preserve existing readers and provide actionable feedback without leaving an empty additional window. Reading/navigation does not modify source bytes or modification times.
- [ ] Preserve Command-N, File > Open / Command-O, drops, ordinary internal anchors, external links and safe non-Markdown file handling. Only the Command-click disposition for local Markdown links changes.

## Dependencies and precise supersession

- Depends on merged [#43 / PR #47](https://github.com/redrossa/neomd/pull/47): app-owned NSDocument/NSWindowController ownership, staged acquisition/render/commit, per-window sessions/fragments, conservative file handling and read-only guards.
- Depends on merged [#48 / PR #49](https://github.com/redrossa/neomd/pull/49): retain contained focus-decoration behavior, link selection, keyboard/accessibility semantics and ordinary control effects.
- Supersedes **only** #43's restriction that Command-N alone explicitly creates another reader and its ordinary-Command-click implementation advice. All other #43 policies remain in force: native Markdown-only reading, same-window ordinary opening/drop, single-file Command-N picker, one-file-at-a-time batch feedback, zero-reader creation only after success, no app-managed folder grants or new permissions, existing unsandboxed access/read-only policy.
- Existing destinations may share the native document identity, but must not share the new reader's session or fragment request. A path-bearing self-link is a local Markdown link and receives the requested disposition; a pure `#fragment` remains internal navigation in the source reader.

## Smallest implementation scope

Carry explicit pointer activation intent from the existing native text bridge to the reader's common URL routing, capture source and destination sessions synchronously before asynchronous classification/acquisition, and use a separate not-yet-visible session for additional-reader intent. Reuse the existing staged native opening transaction; never display then close a spare window or focus an already-open reader instead.

Preserve native text selection/link detection, context-menu Open/Copy behavior, accessibility presses, keyboard Return/Space activation, external forwarding and unlinked image-only rendering. Include the whitespace-only linked-label fallback in the native activation boundary if needed. See [source trace, allowed unit selectors and final-check oracles](m1-p6-command-click-validation.md) and the [inert fixtures](fixtures/m1-p6-command-click/README-fixture.md).

No renderer rewrite, new navigation/history/tab feature, modifier preference, context-menu feature, permissions/sandbox change, source writes, settings/team/deployment change, or unrelated refactor. No update to the user's modified project file is needed.

## Decisions and validation limits

No unresolved product decision blocks this scope. Exact public-API wiring and cancellation/cleanup implementation remain engineering work, not proof supplied by the proposal. If implementation requires broader behavior or cannot preserve native interaction semantics within this boundary, stop and report rather than weakening criteria.

Current user override: **no reviewer stage; Debug build and selected non-interaction units only.** No UI/E2E, prototypes, real/synthetic event dispatch, manual scripted interactions, app opening or AX press tests. Actual Command-click, source scroll/selection preservation, independent physical windows and fragment landing, menus/drops, failure UI, light/dark, keyboard/VoiceOver and interaction bytes/mtime are **DEFERRED/UNRUN**, not passed. Preserve #36/#38 and all historical failures/evidence. Triage supplies fixtures/docs; worker installs them and records actual exact-head evidence/corrections. Issue closure does not establish user-owned combined milestone acceptance.
