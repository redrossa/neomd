# M1-17 — file recovery validation map

**Final triage ACCEPTED for narrow implementation readiness**, source base `c672c090b6c47a7c8247781af9cb4c3ec6b5dd54`. Runtime `openai-codex/gpt-6-astra`, high, verified. [Issue #17](https://github.com/redrossa/neomd/issues/17), [encoding approval](https://github.com/redrossa/neomd/issues/17#issuecomment-5642959135) resolves [old hold](https://github.com/redrossa/neomd/issues/17#issuecomment-5629507743). [M1-DAG-001](milestone-1-dependency-plan.md) controls scheduling and validation. Triage performed source/documentation and inert byte inspection only; **no builds, tests, prototypes or interactions**.

## Full criterion map and exact-base evidence

ALREADY_SATISFIED below means implementation exists at the source/model boundary, not full native criterion acceptance. All original native criteria remain **DEFERRED/UNRUN**, not passed. No checkbox should be marked solely from this assessment.

| Canonical criterion (verbatim) | Disposition / evidence | Required focused worker evidence |
| --- | --- | --- |
| C1 Empty files open successfully with a subtle empty-document message distinct from the no-file state. | **ALREADY_SATISFIED** implementation: `NeoMD/Documents/MarkdownTextDecoder.swift:39-54`; `NeoMD/Rendering/MarkdownBlockRenderer.swift:119-126`; `NeoMD/Views/DocumentReaderView.swift:163-182`; `NeoMD/Documents/DocumentWindowController.swift:38-57`. Startup picker/windowless no-file state: `NeoMD/NeoMDApp.swift:83-93`, `DocumentWindowLifecycle.swift:25-33`. | New empty/BOM-only/whitespace fixture decode/render regressions and existing pure window lifecycle units. Actual message subtlety/title/no-file distinction deferred. |
| C2 UTF-8 documents, including emoji and common line-ending variants, render correctly. | **ALREADY_SATISFIED** implementation: `MarkdownTextDecoder.swift:39-71,88-92`; `CMarkDocument.swift:24-52`; `MarkdownTextDecoderTests.swift:12-37`. | New mixed-endings fixture: preserve scalar sequences, ZWJ/flags/skin tones/keycaps, final no-newline text, three code lines and merged #19 table cell text. Glyph shaping/appearance deferred. |
| C3 Deleted, unreadable, or unsupported-encoding files produce a concise native error with a path and an actionable explanation. | **GAP**, with approved permissive-encoding interpretation. Probe states are discarded at `DocumentOpeningCoordinator.swift:107-117`; caught causes discarded in coordinator `:164-178`, picker `MarkdownDocumentController.swift:51-68`, app `NeoMDApp.swift:95-119`, link `DocumentLinkActivation.swift:92-96`. Coordinator `:181-189` uses a transient notice for a prepared reader, and `:263-265` is generic text. Native completion `MarkdownDocumentController.swift:86-97` passes raw error. | Preserve attempted path and specific cause; pure failure classification/recovery formatting; captured-reader native presentation intent; no duplicated completion/presentation, stale source or cancellation alerts. Native dialog presentation remains deferred. No invalid-UTF8 rejection invented. |
| C4 A failed open does not replace an already readable document. | **ALREADY_SATISFIED** implementation: coordinator `:83-159` stage before commit/installation/recents, `:99-105,257-261` release failed unused candidates; controller `:100-109` display:false; session `:83-109` stages without replacing prepared. | Add typed-failure matrix retaining prepared identity/text/URL/render/index/capture/binding and independent other-session state. Cancellation/staleness/released reservations remain protected. begin() legitimately increments generation and clears pending section. Actual existing-reader retention deferred. |
| C5 Repeated opening and closing leaves file bytes and modification times unchanged. | **ALREADY_SATISFIED** implementation: `ReadOnlyMarkdownNSDocument.swift:16-19,98-165,198-258`; coordinator close `:42-54`. Read descriptors are read-only and closed; native writes/autosave/versioning reject; #24 history is separate. | New five-cycle owned-file direct read/decode/render/session lifecycle test, exact bytes and nanosecond mtime unchanged, no sidecars. Actual NSDocument/window close/no-save-prompt interactions deferred. |

### Existing #23/#24 foundations to preserve

`DocumentOpeningCoordinator.swift:218-242` and `DocumentReadSession.swift:183-192` preserve last rendering/position while setting a separate quiet refresh status. `DocumentRefreshController.swift:159-218,226-245` retains latest on failure, retries and deduplicates status; identical-content recovery clears failure without reinstall. `ReadOnlyMarkdownNSDocument.swift:47-61,74-86` uses coordinated `.withoutChanges`, follows moves and prevents default deletion closing. Do not replace quiet background retries with native alert storms. Explicit attempts have native errors; same-displayed-URL no-read fast path remains intact.

Best-effort malformed Markdown is an existing related foundation, not a sixth published criterion: renderer `:117-126`, `CMarkDocument.swift:24-57` and `MarkdownBlockRendererTests.swift:150-172`. Add bounded fixture regression, not broad arbitrary-size crash/performance claims or #18 work.

## Artifact and oracle ownership

[Fixture README](fixtures/m1-17-recovery/README-fixture.md) and [cases.json](fixtures/m1-17-recovery/cases.json) are triage-owned inert oracles. Verified byte shapes/hashes are not app results. Keep all predecessor fixture bytes unchanged, including CRLF/CR/BOM/invalid bytes via `.gitattributes`. Binary/invalid/truncated inputs are permissive compatibility fixtures, not unsupported-encoding error examples. Inject the defensive decoder error for message/state coverage.

Corrections made before final acceptance: removed predecessor's native NSDocument close/save cycle instructions; corrected 5,000 asterisks to thematic break, updated stale source references, removed universal all-byte success guarantee, distinguished Cocoa corrupt from proven encoding failure, and avoided pre-begin generation/section invariants. Workers report actual discrepancies for coordinator/triage reconciliation rather than silently rewriting oracles or policy.

## Inspected existing non-interaction allowlist

The following test bodies and invoked test helpers were read at this exact base; none ran during triage. Test selectors below include the trailing `()` used by actual merged Swift Testing method selections. Every selector must match nonzero cases in worker results. Reinspect changed bodies after integration; old allowance is not authorization for newly added native behavior.

Entire focused suites allowed:

- `-only-testing:NeoMDTests/MarkdownTextDecoderTests` — eight in-memory decode/error-text units; keep permissive fallback.
- `-only-testing:NeoMDTests/RegularMarkdownSnapshotTests` — two owned temporary-file snapshot/replacement units; no watchers or host.
- `-only-testing:NeoMDTests/DocumentRefreshControllerTests` — eight injected in-memory/logical-clock units; `automaticPolling=false`, no presenter or real events.
- `-only-testing:NeoMDTests/DocumentRefreshCommitTests` — eight pure session/capture/status/ticket units; no file access/host.

Selected methods only:

- `-only-testing:NeoMDTests/MarkdownBlockRendererTests/rendersNothingForEmptySource()`
- `-only-testing:NeoMDTests/MarkdownBlockRendererTests/malformedUnsupportedEscapedAndCodeWrappersStayLiteral()`
- `-only-testing:NeoMDTests/DocumentOpeningTests/firstDocumentHidesTheInstructionAndLastCloseStaysWindowless()`
- `-only-testing:NeoMDTests/DocumentOpeningTests/unknownClosesAndRepeatedReopenCyclesNeverRequestReplacementUI()`
- `-only-testing:NeoMDTests/NativeNavigationTests/capturedDestinationCancelFailureAndClosedWindowPreservePresentation()`
- `-only-testing:NeoMDTests/NativeNavigationTests/failedAndCanceledPreparationNeverPublish()`
- `-only-testing:NeoMDTests/NativeNavigationTests/suspendedOlderPreparationCannotWinOrClearNewerFragment()`
- `-only-testing:NeoMDTests/NativeNavigationTests/canonicalReservationsProtectSharedCandidatesAndOtherViewers()`
- `-only-testing:NeoMDTests/NativeNavigationTests/safeReadRejectsDirectoriesMissingFilesAndFIFOsWithoutBlocking()` — owned FIFO is opened only through the production O_NONBLOCK/validate path, never a blocking arbitrary read.
- `-only-testing:NeoMDTests/NativeNavigationTests/allFileLinksUseConservativeDispositionIncludingSymlinks()` — owned inert executable metadata, resolve only, no launch.
- `-only-testing:NeoMDTests/DocumentLinkActivationTests/readingFixtureCopiesPreservesBytesAndModificationDates()` — owned files and injected open; no native controller/dispatch.
- `-only-testing:NeoMDTests/DocumentLinkActivationTests/canceledStagingCannotCommitOrNotify()` — injected suspended staging only.

These are 38 existing methods before new coverage. Existing `DocumentLinkActivationTests/failuresReleaseReservationsAndOnlyNotifyLiveSource()` must be **updated and reinspected** to inject a recording reporter instead of expecting a notice; it is NOT authorized to invoke a new default native presenter. Add its selector only after that verification.

Excluded: broad `NeoMDTests`, broad `NativeNavigationTests`/`DocumentLinkActivationTests`/`MarkdownBlockRendererTests`/`DocumentOpeningTests`, all UI/E2E suites, `nativeWriteAndMetadataAPIsRejectWithoutChangingOwnedSource`, native NSDocument/controller/window close or save-selector tests, NSAlert/NSOpenPanel construction/presentation, real observers/presenter callbacks, event/host substitutes, NSWorkspace actions, clipboard, theme and AX actions. No actual production recent/history storage, menus, app launch or file permissions outside owned temporary paths.

## Proposed new non-interaction tests — worker-authored, not present or run

Names are design suggestions, not existing executable selectors. Inspect actual bodies before allowing new suites.

1. **DocumentRecoveryFixtureTests**: decode-to-render empty/BOM/whitespace; mixed UTF-8 endings/scalars and code/table leaves; invalid/truncated/binary fallback compatibility without strict rejection; bounded 3,000-quote/200-list/bracket/unclosed-fence parse/adapt/release sentinel assertions. Preserve literal source bytes. Do not treat thematic-break asterisks as missing text. No performance threshold or extreme lifecycle script.
2. **DocumentOpenFailureTests**: direct and wrapped missing/denied/unsuitable/decoder/I/O/unstable/unknown errors; generic Cocoa wrapper prefers meaningful inner cause; corrupt alone is generic; bounded/cyclic chain safe; cancellation silent; full attempted Unicode/space/symlink path and readable action; no technical error dump or source write action. Test purely formatted values and completion delivery decisions, not NSAlert.
3. **DocumentRecoveryRoutingTests**: captured destination/source/presentation/generation gates, no unrelated reader after await; ordinary/additional failures with injected classifier/open/reporter and reservation cleanup; closed/replaced/superseded/terminating/canceled silence; failed preparation preserves committed content/capture; no recents/history success intent. Update the existing link failure test through the same injected sink. Native app/picker/controller integration remains source-traced only.
4. **DocumentRecoveryReadTests**: five cycles per owned regular fixture of direct descriptor read/decode/render/new session commit/close, bytes/nanosecond mtime and no sidecars; denied/missing/nonregular failures retain source and last good data. Optional real chmod denial must record inapplicability for privileged hosts, with injected denial always covered; separate setup/cleanup chmod/writes from read comparison. Add pure refresh failure-kind matrix (decoder/EIO plus merged missing/denied) using logical time and automaticPolling=false; same/changed content recovers, quiet status does not become native error.

## Later worker gates — not run by triage

Use dedicated exact-base branch/worktree and coordinator's single-Xcode lease. Run proactive diagnostics before build; source-server output is not a replacement for the Debug build (the #23 worktree documented unreliable SourceKit diagnostics). Unique external DerivedData/log/xcresult paths required. From worker repo root:

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$STORY_DERIVED_DATA" build
```

Unit command uses the same project/scheme/configuration/destination/DerivedData, fresh `-resultBundlePath`, explicit inspected selectors above and separately inspected new tests, followed by `test`. Never broad target selection. Record exact head, actual full commands, exit codes, executed/pass/fail/skip counts including nonzero matches, logs/xcresults and limits. Failures block; no protection bypass or silent skips. `git diff --check` and final diff/scope inspection required. If main advances, reconcile leases/base and rerun gates on exact resulting head through coordinator; no duplicate reviewer/test stage.

## Deferred final-milestone verification

Everything native remains **DEFERRED/UNRUN**: real alert sheet/modal ownership and once-only presentation across Finder/Open/Recent/startup/drop/local link routes; long/Unicode path layout; native accessibility/focus/keyboard/light/dark; empty state distinction; actual emoji/RTL; preservation of reader selection/position/window on failure; moved/deleted/privacy/disconnected-volume and quiet refresh recovery; repeated native open/close and no save prompts or source mutation. README contains future human-only recipe, not current authorization. #14/#36/#38 remain deferred/open as previously recorded, with no new waiver or inferred repair. User owns combined native and milestone business acceptance.

## Worker evidence slot

**UNRUN / not supplied at triage.** Fill exact source head and integrated main SHA; runtime; installed fixture/catalog hashes and corrections; Debug command/result; allowed test selectors/counts/failures/skips; source-traced native routing changes; actual scope/lease reconciliations. Preserve DEFERRED/UNRUN native status regardless of model passes.
