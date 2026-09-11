# M1-23 — external refresh validation map

Issue: https://github.com/redrossa/neomd/issues/23. **Final triage ACCEPTED for implementation readiness**, exact source base `acc932318bda21a9cafde3e2ea53d612d1bcbe5a`. Runtime Astra/high verified. This is not an implementation/native behavior pass. Triage only researched source/docs and staged inert artifacts. Worker evidence is **UNRUN / not supplied**.

Authority: [adopted M1-DAG-001](milestone-1-dependency-plan.md), canonical issue, current user-approved build/non-interaction-only policy. No reviewer, builds/tests by triage, UI/E2E/manual scripted interactions, watcher experiments, real/synthetic events, app/window hosting, AX actions or host substitutes. Future native recipes below are deferred, not permission to execute them now.

## Complete story and criterion map

As a reviewer watching an agent's output, I want externally saved changes to appear so that I do not have to reopen the file.

| Criterion (verbatim) | Source gap at triage | Required worker evidence and final native boundary |
| --- | --- | --- |
| C1: Refresh an open document after an external write settles, including when the writer replaces the file atomically. | `ReadOnlyMarkdownNSDocument.read` replaces text only; explicit `DocumentOpeningCoordinator.open` renders and installs once, same-URL path returns cached state. | Settled read and injected event/revision models; owned-file URL reread after atomic replacement; source trace from public presenter and polling to installed viewer. Actual native notification/rehosting remains deferred. |
| C2: Coalesce rapid writes so that intermediate updates do not repeatedly interrupt reading. | No refresh observation/scheduler exists. | Logical-clock coalescing, bounded one-job/latest-pending model, same-content suppression and stale-result tests. Native interruption/focus/selection observations remain deferred. |
| C3: Preserve reading position relative to the current content where possible; use a nearby valid position if that content disappears. | `DocumentReadingAnchor.block` carries render-local integer; `install` destroys old view state. Metadata insertion shifts body IDs. | Pure copied content-locator/fraction remap and per-viewer cancellation/commit tests; existing anchor geometry regressions. Actual lazy materialization and viewport restoration remain deferred. |
| C4: A temporarily unavailable or unreadable file keeps its last successful rendering with a quiet status message; recover when it becomes readable again. | Last-good opening stage exists but no refresh status/retry. Existing link notice announces and expires. | Inject missing/access/coordination/decode failures; verify last-good data/position, quiet deduped status, retry and identical-content recovery. Native status/AX and OS access recovery remain deferred. |
| C5: Refreshing never writes to the file or prompts to save it. | Native mutation APIs reject; existing low-level descriptor is read-only. | Owned-file byte/mtime invariants around refresh reader calls, failure and preparation; source trace of no save/write prompt path. Native no-prompt/close behavior remains deferred. |

Do not check a full original criterion solely because a pure model test passes. Record reduced implementation acceptance separately; all five full native outcomes are unverified at triage.

## Fixture packet

[README and future human recipe](fixtures/m1-23-refresh/README-fixture.md). Four ordinary UTF-8 snapshot files plus empty snapshot and JSON logical scenarios:

- `v1.md`: initial content, two same-heading sections with repeated text, distinctive neighboring paragraphs, nested quote/task/code, local fragment.
- `v2-metadata-insert.md`: leading metadata and inserted body material shift render IDs; the watched unique passage remains verbatim. Exact textual matching must beat old integer IDs.
- `v3-target-deleted.md`: watched passage disappears; its immediate preceding/following content survives for nearby fallback.
- `v4-recovered.md`: distinct recovery snapshot; deliberately valid Markdown, not an unsupported-encoding oracle.
- `empty.md`: zero bytes; a genuinely settled empty save is successful empty content.
- `cases.json`: inert logical timelines, identities and semantic position oracles. No runtime watcher or real clock required to test these decisions.

Use owned disposable copies only. Never externally overwrite checked-in originals to exercise refresh. Last-good preservation and mtime expectations compare snapshots **after** each intentional test writer action, since external saves legitimately change bytes/mtime. Tests must distinguish writer changes from reader changes. Hashing fixtures is artifact validation, not app validation.

## Inspected existing non-interaction allowlist

Bodies and helpers were inspected at the source base. No blanket `NeoMDTests` or `NativeNavigationTests` selection is authorized. Selector form: `-only-testing:NeoMDTests/<suite>/<method>`; exact current spellings below omit parentheses, following repository Xcode selector convention. Worker must confirm nonzero executed counts, not accept a silently unmatched selector. Reinspect if another story changes their bodies.

Entire focused suites inspected and allowed:

- `-only-testing:NeoMDTests/DocumentReaderLayoutTests` — six pure geometry/anchor/resize-state methods, no host or event.
- `-only-testing:NeoMDTests/MarkdownTextDecoderTests` — eight in-memory decoding/error-description methods; explicitly preserve the permissive non-UTF8 fallback regression. Do not invent unsupported-encoding failure bytes.

Selected methods:

- `-only-testing:NeoMDTests/DocumentOpeningTests/sectionRequestsAreWindowScopedAndConsumedOnce` — in-memory sessions and rendered strings.
- `-only-testing:NeoMDTests/NativeNavigationTests/capturedDestinationCancelFailureAndClosedWindowPreservePresentation` — pure sessions/coordinator model; calls session.close, not window hosting.
- `-only-testing:NeoMDTests/NativeNavigationTests/failedAndCanceledPreparationNeverPublish` — injected async preparation/continuation, no app events.
- `-only-testing:NeoMDTests/NativeNavigationTests/suspendedOlderPreparationCannotWinOrClearNewerFragment` — ordering/fragment model.
- `-only-testing:NeoMDTests/NativeNavigationTests/canonicalReservationsProtectSharedCandidatesAndOtherViewers` — only owned temp files/symlink plus reservation model.
- `-only-testing:NeoMDTests/NativeNavigationTests/safeReadRejectsDirectoriesMissingFilesAndFIFOsWithoutBlocking` — owned temp regular/missing/directory/FIFO inputs, no host/watcher.
- `-only-testing:NeoMDTests/MarkdownMetadataTests/bodySemanticsAndArenaAreUnaffectedByMetadata` — pure parser/metadata shift regression, proves old IDs cannot represent content identity.

No selection of native write-selector/NSDocument-close action tests is needed for this initial allowlist; keep C5 new tests at the owned-file refresh-read boundary. Excluded: NativeNavigationTests suite-wide, all NeoMDUITests, broad NeoMDTests, DocumentNavigationBridgeTests, native text/selection/hosting/event/clipboard/AX test suites, appearance-test-host and any real watcher registration/notification test used as an interaction substitute. Historical selectors elsewhere are not current permission.

## Planned new non-interaction tests (not implemented, names proposed)

The worker authors executable coverage separately; triage has authored none. New suite names are proposals, not existing selectors or executed evidence.

### DocumentRefreshStateTests — injected logical time, reader and completion results

1. `rapidInvalidationsPublishOnlyLatestSettledRevision`: logical events at 0/100/200ms, no publication before the last quiet boundary; advancing time does not repeatedly reinstall intermediate content. Poll-only detection works without presenter notification.
2. `sameBytesAndAttributeOnlyChangesDoNotReinstall`: new signature or duplicate callbacks with identical decoded text publish zero redundant presentations; success can still clear refresh failure.
3. `newerWriteDuringReadOrRenderRejectsOldCompletion`: explicitly suspended injected read/render, new revision arrives, old completion is ignored; one active preparation and one latest pending revision, bounded work under burst.
4. `unstableSnapshotReschedulesWithoutBlanking`: differing before/after/path stamps never commit; stable zero-byte snapshot does commit empty content.
5. `unavailableThenReadableRecoversWithoutNewEvent`: inject ENOENT, EACCES and a coordination error followed by success using retry ticks; last-good snapshot and locator unchanged while unavailable; clear status for changed **and unchanged** recovered content. Inject decoder failure directly if testing that branch, do not change permissive decoding policy.
6. `closeDetachAndTerminationInvalidateWork`: disposing one of two subscribers does not stop the other's source; last detach cancels work; late callbacks cannot recreate session/controller.
7. `viewerNavigationAndFragmentWinThenLatestRefreshResumes`: pending picker/open, canceled/failed open, same-document section request, new-document commit and stale refresh all exercise exact session/presentation/request binding. A declined viewer is not falsely marked current; other viewers refresh independently.
8. `twoViewersKeepIndependentLocatorsAndStatuses`: same source revision, distinct copied positions; closed/replaced viewer rejects late result; unrelated open/link notice remains untouched.
9. `firstAttachmentAndNewSubscriberCatchUp`: read-to-observation race and already-observed native identity deliver latest data without re-opening/raising existing viewers.
10. `presentationCaptureAndApplyRejectStaleUserIntent`: old view disappearance cannot overwrite newer capture; apply is consumed once; user scroll/navigation cancels pending automatic restore. Pure state test only, not scroll event synthesis.

### DocumentContentLocatorTests — existing renderer plus pure matching

- Metadata and unrelated content insertion remap the unique watched paragraph and preserve fraction 0.65 despite shifted integer IDs.
- Two repeated paragraphs under duplicate headings choose the matching neighbor/section context rather than the first text/slug; renumbered duplicate heading and footnote/image occurrence metadata are not trusted as identity.
- Surviving content moved elsewhere follows its content; changed paragraph with bounded common excerpt and surviving neighbors remains near its old passage.
- Deleted target chooses a surviving immediate neighbor; if all identity evidence vanishes, normalized reading-order fallback is deterministic and valid. Empty output resolves to top.
- Top/bottom edges, oversized/negative/nonfinite fractions, stale/missing indices, Unicode and literal code whitespace are handled without invalid indexing or NaN geometry.
- Nested quote/list leaves use new lazyRootIDs; metadata literal/formatted plain text, image-only alt/source and hidden zero-height anchors follow the documented locator boundary.
- Copies contain no old renderer/view references; multiple independent session captures do not cross-contaminate.

### RegularMarkdownSnapshotTests — owned filesystem access, never watchers

- Read v1, atomically replace an **owned temporary** destination with v2, call the snapshot reader again directly. It sees new URL bytes/inode, not an old open descriptor. Repeat, including same-size content and preserved external mtime where feasible; explicit identity/ctime model vectors cover stamp decisions independently of filesystem precision.
- Instrument/inject stamp changes around read to deterministically exercise replacement or in-place write during read; do not race a real watcher as a substitute for native tests.
- Missing file, nonregular file and executable-bit inert file stay failures; restore a regular readable file and call read again. Permission mapping primarily uses injected EACCES; an owned chmod test must not assume denial when host credentials allow reading.
- Record exact bytes and nanosecond mtime before and after every reader/preparation call, including failure; no source sidecars appear. Test fixture setup/replacement/cleanup writes only owned paths and is explicitly separated from the read-under-test.

Tests must not instantiate windows/hosting controllers, register actual observers and wait for host events, mutate clipboard/theme, drive NSApplication, launch files, invoke AX or trigger a native picker. Model injection is allowed as model evidence, never advertised as native integration proof.

## Worker gate recipe (future; triage did not execute)

Coordinator grants the single Xcode resource lease. Use an isolated story worktree and unique external DerivedData/log/xcresult paths. Run proactive diagnostics before builds. Build command from worker repository root:

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$STORY_DERIVED_DATA" build
```

For tests, use the same project/scheme/destination/DerivedData, a fresh `-resultBundlePath`, and the explicit allowlisted selectors above plus new suites only after their actual non-interaction bodies are inspected. Do not substitute a broad test target. Run `git diff --check`, inspect actual story scope, and record exact head, command, exit, executed/pass/fail/skip counts and paths. Rebase/merge integration changes through coordinator, rerun gates on actual resulting head. No protection bypass, no silent skip/zero test result or known-failure waiver.

## Deferred final-milestone native recipe and defect context

All real external observation, atomic-save delivery, quiet status appearance/VoiceOver, scroll-position restoration, multiple-window independence, keyboard/selection/focus, image reflow and save-prompt behavior remain **DEFERRED/UNRUN**, not passed. See packet README for a reproducible user-owned future procedure. No human/native testing is authorized by this document alone.

#14 is entirely deferred/open. Preserve #36's baseline native selection/reflow hang and #38's larger-size cue scrolling failures and original tests; no evidence proves equivalence, fixes, safety under refresh, or an extended waiver. A known applicable failure discovered during permitted work blocks the affected work pending coordinator/user resolution. Do not proactively repair or investigate with forbidden host/UI experiments. #17's initial-open encoding-policy hold is independent; this story preserves decoder/error causes. #24 owns private bounded persisted reopen history, not the refresh observer; #22 public size behavior is not added.

## Evidence filled by worker

Implemented on `story/23-external-refresh`. Triage base `acc932318bda21a9cafde3e2ea53d612d1bcbe5a`; **integration base `1d06906579e9f320f6d15bc4bc4c75d053563ee5`** (canonical `main` after #19 merged). The branch was rebased onto that commit — a clean rebase, no conflict, the only shared path being the `docs/milestone-1-e2e-fixtures.md` append. Runtime: user-approved fallback `anthropic/claude-opus-5`, high.

- Debug build: `xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-23-DerivedData build` → exit 0, `** BUILD SUCCEEDED **` (`/tmp/neomd-23-build-final.log`). No warnings from story code.
- Units: one command, explicit `-only-testing:` selectors only, never the whole `NeoMDTests` target (`/tmp/neomd-23-test-cmd.sh`, log `/tmp/neomd-23-test-final.log`, bundle `/tmp/neomd-23-results-final.xcresult`). Result **Passed**: **87 test cases, 87 passed, 0 failed, 0 skipped, 0 expected failures** across 15 suites. Swift Testing method selectors were written with the trailing `()`; per-suite counts were read back from the result bundle to prove no selector matched zero cases.
  - New: `DocumentRefreshStateTests` 4, `DocumentRefreshControllerTests` 8, `DocumentRefreshCommitTests` 8, `DocumentContentLocatorTests` 11, `RegularMarkdownSnapshotTests` 2.
  - Allowlisted existing: `DocumentReaderLayoutTests` 6, `MarkdownTextDecoderTests` 8, `NativeNavigationTests` 5 selected methods, `DocumentOpeningTests/sectionRequestsAreWindowScopedAndConsumedOnce()` 1, `MarkdownMetadataTests/bodySemanticsAndArenaAreUnaffectedByMetadata()` 1.
  - Coordinator-authorized integration regression beyond this map's original exclusion list: `DocumentNavigationBridgeTests` 2, and the merged #19 suites `MarkdownTableAddressTests` 6, `MarkdownTableLayoutTests` 10, `MarkdownTableRenderingTests` 7, `MarkdownCellDisplayProjectionTests` 8.
- Static checks: **SourceKit-LSP is not usable as evidence in this worktree.** It reported "clean" for every changed file, and also for a deliberate probe containing `let broken: Int = "not an int"` plus a call to a nonexistent member, so it is not type-checking sources outside the primary checkout. The probe was deleted and never committed. `xcodebuild` is therefore the only type-check evidence here, and it did find two real errors on the first run (a `Darwin.stat` name collision with the `stat` struct) plus a Swift-6 captured-`var self` warning, all fixed. `git diff --check` exits 0.
- Fixture hash verification / catalog reconciliation: all 11 MANIFEST artifacts SHA-256-verified against `/tmp/neomd-23-triage` (`MANIFEST.json` = `289a6718…269a`); the eight unique repository destinations are byte-identical to the staged versions and the catalog carries exactly the appended ENTRY-PATCH entry, after #19's own insertion. No oracle was changed; no correction was needed.
- Actual API surface for #24/#22 integration: `DocumentRefreshController.attach/detach/invalidate/acknowledge/tick/bind/rebind`, `DocumentRefreshSource`, `DocumentRefreshPayload/Failure/Outcome`, `DocumentRefreshState`, `RegularMarkdownRead.Stamp/Snapshot/stamp(at:)/snapshot(at:afterRead:)`, `DocumentContentIndex(_:)`, `DocumentContentLocator.capture(anchor:in:)` / `resolve(in:)`, `PreparedReadingDocument.index` and `init(_ payload:)`, `DocumentReadSession.recordReadingPosition(_:presentation:)` / `capturedPosition(for:)` / `refreshTicket(binding:revision:)` / `commitRefresh(_:ticket:restoration:)` / `takeReadingPosition(for:)` / `reportRefreshFailure(_:)` / `clearRefreshStatus()` / `binding` / `isUserBusy`, `ReadOnlyMarkdownNSDocument.bindingID` / `observeExternalChanges(for:deliver:)` / `stopObservingExternalChanges(for:)`, and the reader-side `DocumentReaderView.consumeReadingPosition/syncReadingActivity` capture and apply hooks.
- Merged-#19 seams actually touched: none of the table address/frame/reveal API, `isOwned`, `Marker.Kind`, `hasActionFocus`, `DocumentReaderFocusTarget.leafID` or `DocumentReaderTraversal.candidates` were modified. `DocumentNavigationBridge.swift` is **unchanged**: a refresh replaces the whole hosting controller, so each presentation gets a fresh bridge and stale apply is revoked by the presentation UUID and restoration serial instead. Table cells are ordinary leaves in `leafIDs`, so the locator index covers them, and a table container frame resolves through `firstLeafIDs` to its first cell; no table horizontal offset is reset by vertical restoration.
- Native C1–C5, real external-save/atomic-replace observation, coalesced interruption, on-screen position/focus/selection, quiet status appearance and VoiceOver, and interacted no-save/bytes/mtime outcomes: **DEFERRED/UNVERIFIED, not passed.** No UI/E2E/manual/event/host/clipboard test was run. Model and owned-file tests are not native proof. #14/#36/#38 deferrals unchanged; no waiver extended.
