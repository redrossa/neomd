# M1-P8 / #64 — selection repair validation

[Issue #64](https://github.com/redrossa/neomd/issues/64) repairs user-observed selection defects in [#16](https://github.com/redrossa/neomd/issues/16) / [PR #62](https://github.com/redrossa/neomd/pull/62). Triage **ACCEPTED implementation readiness** at `1738b1d2e9e7f74411f0d63e4aab401c1522109b`, runtime `openai-codex/gpt-6-astra/high`. Not native acceptance. Source-only triage ran no builds, tests, prototypes, app interactions or clipboard operations.

## Diagnosis and bounded contract

The owned leaf already runs an explicit drag/up loop (`MarkdownLinkedImageText.swift:104–135`); adding another loop on the theory that `super.mouseDown` consumes owned drags is not justified. The concrete target defect is controller 104–113's unbounded visibleRect search with unordered ties; a nearby context-menu adapter documents that SwiftUI visibleRect can exceed bounds. Correct clipped, owned, deterministic two-dimensional target choice, owner-scoped gesture lifetime and final mouse-up endpoint. Actual user-event causality remains unconfirmed without native evidence.

Gray slices follow independent native layout-manager selection activity. Share active-selection appearance across the current reader without moving actual focus or merging text storage. Prefer the bounded public layout-manager responder predicate, preserving find's separate temporary-attribute channel. Native API availability/build and pure policy tests do not prove drawing color. If a fallback compositor is necessary, report the correction and keep one highlight owner with explicit selection-over-find precedence; never independent removers of the same temporary background attribute.

| Required outcome | Permitted worker evidence | Native limit |
| --- | --- | --- |
| Continuous forward/reverse pointer selection across prose/code/metadata/table cells | Pure target/gesture state + ordered extraction units; source adapter trace | Pointer delivery, clipping, lazy mount/autoscroll DEFERRED/UNRUN |
| One active selection appearance in the active reader | Pure shared-activity/decorations policy + compile/API evidence | AppKit drawing, responder transitions and light/dark DEFERRED/UNRUN |
| Shift-click, Select All, Copy across leaves | Fixed-anchor and existing projection/array-writer units | Actual keyboard/menu/clipboard DEFERRED/UNRUN |
| Preserve links/context menu/Command-click | Pure captured pointer intent/cancel/dispatch effects | Browser/local opening and secondary menus DEFERRED/UNRUN |
| Preserve find/reflow/lazy/focus/AX/source immutability | Existing index/selection/reflow values; source review of unchanged seams | Actual native/visual/AX/interaction bytes/mtime DEFERRED/UNRUN |

## Worker gates and exclusions

Debug build and inspected relevant **non-interaction units only**. No reviewer. Serialize Xcode through coordinator; use a dedicated story branch/worktree and unique external DerivedData, log and result-bundle paths. Do not use `swift test`, broad `NeoMDTests`, UI/E2E/manual scripted interactions, native window/view-host or event substitutes, AX actions, clipboard mutation, workspace launches, system appearance switches or hidden scratch interaction tests. This triage did not use the optional scratch reproduction: source already contradicts the stock-loop hypothesis.

The exact existing methods below were read at this base. They use value models, parser/conversion data, in-memory session state, fixture reads, or an injected string-array writer; none hosts windows or synthesizes events. Conversion-only `NSAttributedString`/font data is not a native interaction proof. Reinspect changed bodies before invoking them. A selector is an explicit `-only-testing:` argument, including trailing `()` for these Swift Testing methods. Do not automatically include future methods by selecting whole suites.

```text
NeoMDTests/DocumentSelectionProjectionTests/authoredPartialOracleAndReverseAreExact()
NeoMDTests/DocumentSelectionProjectionTests/tableAndMetadataJoinsKeepEmptyCells()
NeoMDTests/DocumentSelectionProjectionTests/literalWhitespaceAndSeparatorsAreNeverTrimmed()
NeoMDTests/DocumentSelectionProjectionTests/attachmentsKeepSelectablePositionsButEmitNoCopyCharacters()
NeoMDTests/DocumentSelectionProjectionTests/utf16BoundsExpandGraphemesAndSnapCollapsedCaretsBackward()
NeoMDTests/DocumentSelectionProjectionTests/collapsedInvalidAndEndpointOnlySelectionsDoNotInventSeparators()
NeoMDTests/DocumentSelectionStateTests/fakeMountsNeverLimitLogicalOffscreenCopy()
NeoMDTests/DocumentSelectionStateTests/staleDetachAndTwoReadersCannotReleaseReplacementRegistrations()
NeoMDTests/DocumentSelectionStateTests/cancelledOperationCannotEndSuccessorOrClearSelection()
NeoMDTests/DocumentSelectionStateTests/genuineReplacementRemapsOnlyItsEndpointsAndRejectsStaleToken()
NeoMDTests/DocumentSelectionStateTests/refreshResolvesFreshIDsAndNewInteriorWithoutReadingPositionFallback()
NeoMDTests/DocumentSelectionStateTests/ambiguousRefreshClearsAndTransferIsConsumedOnceByMatchingHost()
NeoMDTests/DocumentSelectionStateTests/findStateAndSelectionRemainIndependentValues()
NeoMDTests/DocumentSelectionIntegrationTests/renderedTableMetadataAndCodeUseIndependentPlainTextOracle()
NeoMDTests/DocumentSelectionIntegrationTests/injectedWriterReceivesOnlyExtractionWithoutAnyPasteboard()
NeoMDTests/DocumentSelectionIntegrationTests/finalArenaListIdentitiesDistinguishAdjacentAndNestedTasks()
NeoMDTests/DocumentSelectionIntegrationTests/sessionRefreshTransfersSelectionOnceWithoutConsumingFind()
NeoMDTests/DocumentSelectionIntegrationTests/focusedLinkAttributesAndUnavailableImageProjectionRemainIndependent()
NeoMDTests/DocumentSelectionIntegrationTests/keyboardExtentValuesRetainAnchorAcrossFragmentsAndReverse()
NeoMDTests/DocumentSelectionIntegrationTests/imageStateUpdatesOffscreenProjectionWithoutNativeHosts()
NeoMDTests/DocumentFindIndexTests/metadataMatchesStayInsideOneKeyOrValue()
NeoMDTests/DocumentFindIndexTests/rangesAreUTF16AndComposedCharacterSafe()
NeoMDTests/ReadingSizePresentationTests/scaleKeepsSelectionEndpointsFindRangesAndTableSeparators()
NeoMDTests/ReadingSizePresentationTests/removedDepthCaptionClearsOnlyAnAffectedEndpoint()
NeoMDTests/ReadingSizeRestorationTests/queuedCommandsPrepareBeforePublishingAndKeepLatestDesiredOnly()
NeoMDTests/DocumentLinkActivationTests/immutablePointerPolicyAndBoundedNestedCleanup()
```

26 existing methods. Explicitly excluded examples: `MarkdownLinkedImageTextTests/textSystemMeasuresAndPreservesSelectionOnUnchangedUpdates()` hosts a key window and performs AX press; its dismantling test invokes an AX action too. `KeyboardTraversalTests`, linked-image feasibility and broad native/table suites are not blanket allowlisted. Preserve their source; do not delete or weaken them to meet policy.

## New worker-authored non-interaction expectations

Triage supplies only inert fixtures, not executable tests. Factor pointer selection transitions/geometry into value-only production helpers used by the actual native adapter. Add exact named methods (names worker-chosen, reported in evidence), inspect before execution, and enumerate selectors rather than a broad suite:

1. **Clipped target resolution**: consume `fixtures/m1-p8-selection/pointer-cases.json`. Inflated origin visibleRect cannot beat a true neighbour; same-row right metadata/table part wins; fully clipped cell excluded; reversed candidate input order yields same gap result. Add hidden/wrong-window/stale-registration/empty/nonfinite candidates, actual-hit precedence and a no-candidate result. Native view-bound coordinate conversion remains adapter source evidence, not proven by synthetic rectangles.
2. **Drag transitions**: down in A, >3-point move into B, reverse through A; anchor fixed, expected per-leaf UTF-16 slices/plain text exact. Feed copied positions/resolved endpoints and intent enums, not NSEvents. Preserve initial word/paragraph span on reversal. Apply final mouse-up endpoint and clear tracking once; subthreshold click does not masquerade as a drag; crossing then returning stays a drag.
3. **Shift and command policy**: Shift-click any part retains existing anchor, including reverse and no-initial-anchor cases; Shift-link never activates. Non-drag link click emits one effect, link-origin drag/cancel emits none, Command intent captured at down survives changed modifiers at up. Control/right-click returns unhandled without selection side effects; no menu, URL opener or pasteboard calls in tests.
4. **Lifetime/busy tokens**: origin unmount alone retains owner operation; window/presentation/owner invalidation cancels; stale event/finish cannot clear a successor; idle/tick/up/cancel/detach each balance the owning operation exactly once. Newly supplied mount geometry becomes eligible without changing projection/forcing view creation. Vertical outer and horizontal local scroll intents stay separated in value policy. A queued #22 size request becomes eligible only after the owning gesture finishes.
5. **Unified appearance policy**: two different leaf/manager identities in the same active reader share active state; other reader/window, stale registration and ordinary editor contexts cannot borrow activity. A genuinely inactive window yields a uniform inactive policy. No actual `NSWindow`, `makeFirstResponder`, NSView host, drawing screenshot or appearance switch. Map logical style descriptors to adaptive AppKit colors in production; unit values are not visual proof.
6. **Find/selection composition and remap**: selection updates do not mutate find descriptors, and vice versa; overlap selection wins while underlying find remains available after deselection. If temporary-attribute compositor is used, test its exact bounded segment output for disjoint/partial/full overlap, then remove each channel in both orders. No source-string/font/link-focus/geometry signature mutation. Reflow/image replacement re-derives slices; decoration-only changes do not rebuild projection/storage. Use pure descriptors/storage-independent functions, not a native host test.
7. **Commands**: Select All equals entireProjection including unmounted leaves, metadata and table parts; Copy's injected writer gets exact reverse/partial/code/Unicode text without Markdown style delimiters or invented attachment characters. Empty selection emits no write. Preserve existing find-editor command-routing source guard, not a simulated responder-chain interaction test.

Do not label these tests end-to-end or report native outcomes from them. If permitted tests fail, diagnose/fix or report BLOCKED; #36/#38 deferrals do not waive new failures.

## Commands and exact-head evidence slots

From the worker worktree, run proactive diagnostics before the build; xcodebuild is authoritative compile evidence if SourceKit lacks worktree configuration.

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath <unique-external-derived-data> build

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath <same-derived-data> \
  -parallel-testing-enabled NO -resultBundlePath <fresh-external-result.xcresult> \
  <one -only-testing: argument per inspected existing/new method> test
```

Placeholders are intentional, not runnable shell. Record the **fully expanded** actual command in worker logs/PR. Verify nonzero test discovery and exact counts with xcresult summary, not merely TEST SUCCEEDED. Use `Refs #64`, exact built/tested head, runtime, base reconciliation, failures/skips, logs/results and triage artifact corrections. If main advances, reconcile and rerun on exact new head before integration. Run `git diff --check`; no generated output in Git.

- Built/tested head/runtime: **UNRUN at triage**.
- Debug command/result/log: **UNRUN at triage**.
- Exact selected/new methods and total/pass/fail/skip counts: **UNRUN at triage**.
- Diff/artifact corrections and narrow source evidence: **UNRUN at triage**.
- Native pointer/keyboard/clipboard/menu/link/visual/light-dark/AX/lazy/reflow results: **DEFERRED/UNRUN**.

See the [inert packet and pending human observation matrix](fixtures/m1-p8-selection/README-fixture.md). Worker supplies actual gate evidence without changing native status to passed. All #64 behavior remains subject to user-owned native verification; triage/merge is not final milestone acceptance. Preserve #14 deferred/open and #36/#38 historical failed/deferred coverage.
