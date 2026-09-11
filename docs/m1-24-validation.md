# M1-24 history — validation map

Triage **ACCEPTED for implementation readiness only** at `acc932318bda21a9cafde3e2ea53d612d1bcbe5a`. [Canonical issue #24](https://github.com/redrossa/neomd/issues/24), full five criteria and paginated comments read (zero comments at research). Runtime openai-codex/gpt-6-astra/high verified. [Inert packet](fixtures/m1-24-history/README-fixture.md). No builds/tests/prototypes/interactions run by triage. Native and business acceptance remain user-owned.

## Complete contract and criterion evidence

As a returning reader, I want recent files and my reading position restored so that I can resume quickly.

| Criterion, unchanged | Exact-base implementation evidence and worker scope | Allowed evidence / outstanding native evidence |
| --- | --- | --- |
| C1 Recently opened files are available through the native recent-file menu, with a command to clear that history. | `NativeReaderMenus.menuNeedsUpdate` uses native recent URLs/full paths and Clear Menu; controller records only committed opens. Keep list, add private-position clear behind existing controller action. | Pure store clear/epoch/state tests; actual native menu/order/clear and real user history behavior DEFERRED/UNRUN. |
| C2 Reopening a file restores its last reading position when possible, including after relaunching NeoMD. | Only transient resize anchors exist; new host on install loses state. Add bounded durable locator records, successful-install one-shot restoration and quit flush; preserve same-reader no-op and explicit fragments. | Owned-store instance reconstruction, capture/resolve and injected session lifecycle tests; real reopen/relaunch/quit/lazy scroll DEFERRED/UNRUN. |
| C3 Remember positions independently for files with identical names in different folders. | Prepared URL and native path labels exist; no private history key. Normalize entire file URL without lowercasing or basename lookup. | Alpha/beta URL-key persistence round-trip with different locators; actual two-reader/menu location behavior DEFERRED/UNRUN. |
| C4 If a file has changed, restore a nearby valid position; if it has moved or disappeared, explain the problem without replacing another open document. | Stage-before-commit and path/recovery failure text exist. Per-render integer IDs are not durable; fresh real reopen content must not come from cached native text. | Semantic/rendered remap vectors, fresh owned read with injected cached-payload alternative, failure/cancel retention; native missing-menu/open/error and actual fallback placement DEFERRED/UNRUN. |
| C5 Store reading history separately from the Markdown files so that their contents and modification times remain unchanged. | ReadOnlyMarkdownNSDocument rejects writes; RegularMarkdownRead opens read-only. Store only in private app storage, injected/owned in tests. | Compare owned source bytes/mtime around real store/read/resolve operations; native interacted source immutability and no-save-prompt behavior DEFERRED/UNRUN. |

All issue checkboxes remain unchecked at triage. Do not check a full criterion merely because its model portion passes.

## Concrete implementation boundary

Versioned v1 private Application Support JSON, max 100 URL records and 1 MiB, stable digests plus bounded neighbor/progress/fraction values, no source excerpts or bookmarks. URL normalization preserves distinct locations. Save latest original capture serial, not close/flush order. Clear increments an epoch and prevents stale resurrection without moving existing readers. Load/write failures retain readable content. Explicit fragment (including empty top or missing destination) wins over history; fresh replacement/reopen without fragment may restore. Same displayed URL without fragment stays where that reader is. No auto-reopen-all-windows, folder grants, source writes or observer work.

Final #23 DESIGN/HANDOFF were read: #23 owns shared copied locator/remapper, capture/apply/busy/session wiring first; #24 stores a bounded portable projection, independent service first. Use a common presentation-bound request and optional live-only context, not parallel scroll engines. Automatic refresh remaps must preserve history capture provenance. #19 owns tables/bridge/traversal/frame production and currently Xcode. Generic nonempty rendered-leaf text supports its flat cell model without persisting cell IDs. Coordinator leases exact overlapping methods and reconciles actual merged APIs; no sibling hard prerequisite or unmerged source dependency. #16/#17 holds do not block #24. #14/#36/#38 stay deferred without repair/extended waiver.

## Inspected existing non-interaction selector allowlist

Source bodies inspected, not run. Add `-only-testing:` to each selector passed to Xcode:

- `NeoMDTests/DocumentReaderLayoutTests` — all six methods: pure column/anchor/fraction geometry and cancellation state; no host construction.
- `NeoMDTests/DocumentOpeningTests/sectionRequestsAreWindowScopedAndConsumedOnce` — in-memory rendered inputs and independent sessions.
- `NeoMDTests/NativeNavigationTests/capturedDestinationCancelFailureAndClosedWindowPreservePresentation` — model sessions/cancel reservation; no windows.
- `NeoMDTests/NativeNavigationTests/failedAndCanceledPreparationNeverPublish` — injected failure and suspended completion.
- `NeoMDTests/NativeNavigationTests/suspendedOlderPreparationCannotWinOrClearNewerFragment` — model generations/sections.
- `NeoMDTests/MarkdownMetadataTests/bodySemanticsAndArenaAreUnaffectedByMetadata` — pure rendered-text/arena shift check, including its pure normalization helper.

That is eleven existing test methods before any additions. Do not run whole `DocumentOpeningTests` or `NativeNavigationTests` on the strength of these selections. Reinspect selected bodies/dependencies after integration so a newly added production history dependency cannot touch the user's data. Production history injection must be lazy/inert in hosted unit context.

## Planned new tests — not executable or already present

Worker authors meaningful tests; inspect actual bodies before adding selectors. Proposed suite names below are not claims that they exist.

**ReadingHistoryStoreTests (owned temporary storage or in-memory only):**

- `roundTripRestoresDistinctSameBasenameURLsAcrossStoreInstances`: two folders, different positions, recreate store, retrieve both; no app launch/production defaults.
- `normalizedURLsRetainCaseUnicodeAndLocation`: dot components collapse, encoded spaces/Unicode round-trip, different directories/case are not lowercased; no network URL, query or fragment key.
- `boundedRecordsEvictByAcceptedCaptureOrder`: 101 entries, max100; encoded size cap and stable ties; bounded oversized-load rejection before decode.
- `clearRejectsOlderEpochWritesAndIdleFlush`: pending saves/apply reject after clear; no idle reader resurrection; a distinct new reading capture can persist.
- `lateCompletionCannotRegressDiskRevision`: injected suspended old writer, accepted new revision; deterministic serialization/flush.
- `invalidHistoryNeverBlocksReadableInput`: corrupt JSON/version/digest/nonfinite fraction/invalid URL, independently valid siblings where possible, read/write failures; no source fallback writes.
- `storeAndResolutionLeaveOwnedSourceBytesAndModificationTimeUnchanged`: set up source before baseline, then actual read/capture/store/reconstruct/resolve; verify bytes/mtime and no sibling sidecars/xattrs introduced.

**ReadingHistorySessionTests (copied inputs/injected callbacks only):**

- `laterSuccessfulCaptureWinsRegardlessOfWindowCloseOrder`: original serials retained on replacement/close/termination; idle geometry and automatic refresh remap not new capture actions.
- `initialGeometryCannotOverwritePendingRestore`: zero geometry/top placeholder and bounded acquisition failure never overwrite saved context.
- `explicitAndEmptyFragmentsOutrankHistory`: valid, empty and missing fragment requests; missing keeps explicit feedback, no hidden fallback.
- `newUserIntentAndClosedPresentationCancelApply`: session/presentation/navigation/epoch mismatch at simulated suspension; no late cross-window publication.
- `failedPreparationKeepsOtherReaderAndHistory`: fresh read error, canceled request, moved/absent owned target; no commit/new recent/history entry.
- `busyHistoryApplyDefersAndReleasesLatestRefresh`: retained latest injected refresh result resumes after apply/cancel, explicit section still wins, no history task hijacks session.task.
- `reopenUsesFreshPreparedContentNotCachedNativePayload`: injected cached text A vs fresh owned file B on a real new/replacement preparation; same-presented no-fragment no-op remains intact.

**Portable locator adapter/shared mapper regression cases** (reuse #23's actual merged `DocumentContentLocatorTests` ownership under the lease; do not create a competing mapper):

Consume `mapping-cases.json`, plus rendered alpha with exact `changed-prefix.txt` concatenation; cover metadata ID shift, context-disambiguated duplicates, deleted target neighbors, complete rewrite/progress, empty/top/bottom, long code fraction, Unicode and line-ending normalization. Add finite fraction validation, unknown/empty content, nested leaves, serial-preserving refresh remap and same-row table-cell frame tie once #19 is merged. Optional richer live-only #23 context may remain absent after persistence projection; no old IDs/enum kinds become stored identity.

These establish data/model/read behavior only, not real native recents, scroll or relaunch. No native host/event/AX substitutes or observer experiments.

## Later worker gates and exact evidence

No Xcode invocation until coordinator grants the resource (#19 currently holds it). Run from the isolated worker worktree, with unique external DerivedData/log/result paths. Use diagnostics before build per tooling instructions. Required Debug build:

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-24-DerivedData build
```

For units, use that project/scheme/destination, a fresh external result bundle and only the selectors listed above plus inspected actual new tests; pass each as its own `-only-testing:<selector>` argument followed by `test`. Never substitute `-only-testing:NeoMDTests`. Source/test bodies can change on rebase; reinspect and rerun allowed gates on the exact resulting head. Do not change signing, deployment, security settings or user configuration to make local tests pass.

Worker evidence — recorded by the implementing worker (fallback runtime
`anthropic/claude-opus-5`, high, verified before repository work):

- **Integrated main base:** `5c1940c515533d093b53ab2124a7c06fb84f2994` (canonical `main` after #23 / PR #57).
  Stage 1 was written on `1d06906579e9f320f6d15bc4bc4c75d053563ee5` and rebased onto `5c1940c`;
  the only rebase conflict was the `docs/milestone-1-e2e-fixtures.md` append, resolved by keeping
  #23's entry verbatim and appending the M1-24 entry after it.
- **Shared interfaces reconciled with #23:** #24 adds **no second remapper**.
  `ReadingHistoryLocator` is now purely the durable Codable projection of the merged
  `DocumentContentLocator` (`init(_:)` / `restored` / `isWellFormed`), so capture and remap are
  the merged `DocumentContentLocator.capture(anchor:in:)` / `resolve(in:)` against
  `DocumentContentIndex`. `ReadingPositionRequest.Reason` gained `.reopenHistory` alongside
  `.refresh`; `DocumentReadSession` gained `requestReadingPosition(_:presentation:reason:)` and a
  `positionObserver` hook invoked from the existing `recordReadingPosition`. #23's
  `commitRefresh`/`refreshTicket`/`takeReadingPosition` and the reader's `consumeReadingPosition`
  and `updateReadingAnchor` are reused unchanged; `DocumentReaderView.swift` was **not modified**.
  #19's table/bridge/traversal seams were not touched: table cells are ordinary leaves in
  `DocumentContentIndex`, and no cell address is ever persisted.
- **Fixture/catalog verification:** all 11 staged artifacts SHA-256 verified against
  `/tmp/neomd-24-triage`; the 8 repository destinations are byte-identical. The catalog base hash
  had already moved from triage's `8c444788…` to `26bc6c42…` (#19) and then to #23's revision; the
  `## M1-24 / #24 …` heading was verified absent and only that entry was appended. **One staged
  oracle diverges from merged behavior** — see the reconciliation note below. No fixture byte was
  changed.
- **Debug build:** `xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-24-DerivedData build` → exit 0,
  `** BUILD SUCCEEDED **`, log `/tmp/neomd-24-build-1.log`. No warnings from story code; the only
  warnings are the pre-existing, untouched `ReadOnlyMarkdownLegacyGuards.m` deprecations.
- **Units:** one selector-scoped run, `/tmp/neomd-24-test-cmd.sh`, log `/tmp/neomd-24-test-1.log`,
  bundle `/tmp/neomd-24-results.xcresult`. Result **Passed: 66 tests, 66 passed, 0 failed,
  0 skipped, 0 expected failures**, 11 suites, exit 0. Never `-only-testing:NeoMDTests`.
  - New: `ReadingHistoryLocatorTests` 6, `ReadingHistoryStoreTests` 13, `ReadingHistorySessionTests` 5.
  - Allowlisted existing: `DocumentReaderLayoutTests` 6, `DocumentOpeningTests` 1 method,
    `NativeNavigationTests` 3 methods, `MarkdownMetadataTests` 1 method.
  - #23 integration regression (this story edits the shared `DocumentReadSession`):
    `DocumentContentLocatorTests` 11, `DocumentRefreshStateTests` 4,
    `DocumentRefreshControllerTests` 8, `DocumentRefreshCommitTests` 8.
  - Swift Testing method selectors carry the trailing `()`; every selector matched a non-zero
    number of cases, confirmed per suite from the result bundle.
- **Owned storage:** every store test uses `FileManager.default.temporaryDirectory/NeoMD-History-<UUID>`
  or an in-memory substitute. `ReadingHistoryStore`'s default dependency is
  `ReadingHistoryInertStorage`, and `ReadingHistoryService.production()` returns inert storage when
  `XCTestConfigurationFilePath` is set or `XCTestCase` exists, which
  `productionServiceUsesInertStorageInAHostedTestProcess` executes. No production application
  support path, user defaults key or recent-document list was read, written or cleared.
- **Source immutability:** `historyOperationsLeaveOwnedSourceBytesAndModificationTimeUnchanged`
  compares exact bytes and modification date around a real read/capture/store/reconstruct/resolve
  cycle on an owned file, and asserts no sidecar lands beside the document. This is an owned-file
  model check, not interacted native proof.
- **Remaining limitations:** the reader-side application of a restored position
  (`consumeReadingPosition`) has no executed test of its own — `DocumentReaderView` needs a host —
  so its correctness rests on source plus the session/locator model tests. Quit-time flushing now
  uses `.terminateLater` with a reply after `drainReadingHistory()`; the reply path is unexercised
  by units.
- **Native interaction status: DEFERRED/UNVERIFIED**, unchanged by these model results. Native Open
  Recent contents and Clear Menu, real reopening, relaunching, quitting, scrolling, lazy layout,
  appearance, accessibility and interacted source byte/mtime behavior are **not** established here.

### Staged-oracle reconciliation — `deleted-target-neighbor-tie`

`docs/fixtures/m1-24-history/mapping-cases.json` expects a deleted target to fall back to the **end
of the preceding** surviving neighbour (ordinal 1, fraction 1.0). The merged #23
`DocumentContentLocator.match` deliberately prefers the **start of the following** surviving
neighbour first (ordinal 2, fraction 0.0), on the documented ground that the content which moved up
into the deleted passage is what the reader reads next. Both satisfy C4's "restore a nearby valid
position". #24 is required not to fork a second remapper, so the merged behavior stands and
`stagedMappingVectorsRemapThroughDurableProjection` asserts it under an explicitly named constant
with this rationale. The fixture bytes were **not** edited. The remaining nine staged vectors —
metadata shift, duplicate disambiguation by context, next-neighbour-only survival, complete-rewrite
progress, empty output, both edges, Unicode/indented code and line-ending normalization — pass
against their stated expectations. **This divergence is reported for coordinator reconciliation; it
is not a silently adjusted oracle.**

No reviewer. Coordinator integrates worker evidence, preserves failures/deferrals and user-owned final acceptance. Fixture human recipes are future-only and require renewed authorization; no UI/E2E/manual scripted interactions, native NSWindow/hosting/event/AX probes, clipboard writes, real menus/pickers, user history clearing, appearance toggling or application-launch substitutes are authorized now.
