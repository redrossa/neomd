# M1-P7 / #52 — Window placement triage and validation

Contract: [issue #52](https://github.com/redrossa/neomd/issues/52), [approved pivot](milestone-1-window-cascade-pivot.md), [canonical milestone order](https://github.com/redrossa/neomd/milestone/1). Exact clean detached research base: `918cfa40f9fdb7323400021b3a06b11f1ff8cf69`, matching canonical remote `main` when queried; #50 / PR #51 is merged there. #43 is closed. Runtime verified before research: `PI_PROVIDER=openai-codex`, `PI_MODEL=gpt-6-astra`, `PI_REASONING_LEVEL=high`.

Status: **ACCEPTED for implementation**, not implemented or criteria passed. Triage performed source/documentation research only, with no builds, executable tests, prototypes, windows or interactions. Only #52 is authorized. #14 stays entirely deferred and #15–24 paused, also after this fix. No reviewer stage; later Debug build plus explicitly scoped non-interaction units only.

## Criterion-by-criterion assessment

| Criterion | Exact-base evidence | Required work / limits |
| --- | --- | --- |
| C1 — successful additional reader down/right from captured source | `DocumentWindowController.swift:8–20` creates a 900×720 **content** rectangle and unconditionally centers. `DocumentReaderView.swift:337–341` constructs `DocumentLocalLinkRequest` before creating its Task. `DocumentLinkActivation.swift:53–63` captures the actual source/session/presentation and reserves a distinct destination before awaiting. No frame/screen placement exists. | ACCEPTED. Capture immutable geometry synchronously from `openingCoordinator.windows[source.id]?.window`, not key/main window. Carry it with this request to the new controller in the existing late commit. Native placement remains unrun. |
| C2 — source screen, usable frame, edges and oversized readers | `DocumentOpeningCoordinator.swift:109–125` creates/installs/shows only after all staging guards. `DocumentWindowController.swift:11–13` has default content 900×720 and min frame 480×320; `DocumentReaderView.swift:115` independently imposes a 480×320 content minimum. Current centering has no explicit visible-area policy. | ACCEPTED. Add a pure global-coordinate placement policy and a thin main-actor screen adapter. Use full new frame including chrome, current source-screen visible area and size-to-fit before origin clamping. Address both native and hosting minimum constraints for genuinely smaller screens; minSize alone is not enough. Physical title-bar/controls and display behavior remain deferred. |
| C3 — unchanged existing readers, routing, fragments, failures/other routes | Request additional destination is independent; `run` classifies first and uses coordinator only for Markdown. `open` performs no controller creation until preparation succeeds, and existing controllers use `install` which preserves their frame. `MarkdownDocumentController.showPicker` separately calls `destination(newWindow:)`; Command-N and ordinary opens currently have no placement context. Existing session-local fragments and failure notices are source-bound. | ACCEPTED. Apply placement only when constructing a new controller for the Command-click request. Never mutate source/other controllers, do not move/rescale existing readers, never create early. Leave ordinary/Cmd-N/Open/drop routing and nil-placement path unchanged. Preserve failure/cancellation cleanup and #50 independent lifetime. Model units support preservation; actual scroll/selection/fragments/failure UI remain unrun. |

No dependency, ambiguity or product decision blocks this scope. The user's report is consistent with source; earlier claims that placement was already done are not evidence.

## Actual #50 flow and narrow capture seam

1. `MarkdownLinkedImageTextView.mouseDown(with:)` (`MarkdownLinkedImageText.swift:69–72`) copies pointer Command/Control provenance into `DocumentLinkPointerScope`, then lets `super` do tracking/hit testing. `textView(_:clickedOnLink:at:)` (`:202–208`) forwards the scoped activation synchronously through `pointerOpen`. The representable binds that callback from the reader environment (`:50`). This bridge already covers linked image/whitespace native ranges. No pointer/renderer change is needed for #52.
2. Reader body binds `documentPointerOpenURL` to `handleLink`. It rejects stale presentation/closed session/termination; resolved local/file targets reach `openLocalTarget`, which constructs the request synchronously before its Task. Pure anchors and external URLs keep their current separate routes.
3. `DocumentLocalLinkRequest.init` is main-actor isolated by the target's defaults. It has the **originating** `source` session and coordinator, whose `windows` dictionary is keyed by session UUID. Add capture here (before destination reservation/task/await), using only the source's registered controller/window. No new SwiftUI window-reader representable or ambient event/window lookup is necessary. A small injected value-provider seam can support passive tests; production must use this source-ID lookup.
4. Store the copied placement context on the request. The smallest lifetime design passes it explicitly as an optional parameter to `DocumentOpeningCoordinator.open`, then `DocumentWindowController.init`; the default is nil for every old caller. This avoids a new reservation/placement dictionary and extra cleanup lifecycle. `destination(newWindow:)` need not change. If the injected `run(open:)` seam is extended to include placement, update existing spies; do not bypass transport in production while testing a duplicate implementation.
5. Only `.markdown` forwards the context to the coordinator. Non-Markdown/reveal outcomes discard it along with the unused reservation; no native window is allocated. Keep guards, reservation defers and source notice behavior untouched.
6. After successful preflight/acquire/render, `open` must use the context only in the nil-existing-controller branch of its no-await commit. Existing controllers must not be repositioned even if a caller supplies context accidentally. Set the new frame without animation before it is first shown; `install` must preserve it across hosting. Do not center then visibly animate/cascade after display.

## Concrete engineering placement policy

Suggested focused file: `NeoMD/Documents/DocumentWindowPlacement.swift`. Plain value types should be `nonisolated`/Sendable where appropriate; AppKit reads stay on the main actor. Use the production policy in numeric units, not a test-only reimplementation.

### Capture and screen selection

- Snapshot source **full `window.frame`**, source `window.screen` display identity and its `visibleFrame` as copied numbers. Use a stable display identifier from the screen's device description, not `NSScreen` object identity or its position in a later array. The actual source frame is authoritative for the requested top-left; do not substitute another reader or copy the source size as the default new size.
- Keep an explicit Command-click placement request even if source geometry is unavailable; distinguish that fallback from nil context meaning the unchanged legacy opening route.
- At successful creation, sample current screen descriptors. Prefer the captured source display ID and its **current** `visibleFrame` (Dock/menu bar and display configuration may have changed while awaiting). This updates available bounds, never the captured source frame. Do not use `NSScreen.main`, which follows the key window.
- If the source's screen is nil at capture or removed before commit, choose the current visible rectangle nearest the captured source top-left (squared point-to-rectangle distance, zero when contained); break ties by numeric display ID. Clamp the original desired source-relative frame into that selected rectangle. Do not monitor display changes, move existing readers or add persistence.
- If the source frame itself cannot be captured, use the zero/primary display (`NSScreen.screens.first`, whose ordering is documented), center the new full frame within its visible rectangle and fit it. This branch must not look at another active reader. Preserve the copied source-screen visible rectangle (or capture-time primary visible rectangle when source-screen geometry is unavailable) as a last resort if no current valid screens exist. If no captured or current usable rectangle exists at all, retain the valid default full size at global origin (0,0), without querying active windows; no physical onscreen guarantee can be made when no screen exists. Record this limitation, not a pass.
- Source movement/resizing/focus change/closure after capture does not change the captured origin. Source closure does **not** cancel this independent #50 additional request; it can still succeed from the copied snapshot. Failure after closure must not notify an unrelated reader. Do not retain/re-read a source NSWindow through asynchronous work.

### Full-frame arithmetic

For valid visible rectangle V, default **full frame** size (W,H), captured source frame S, and offset d=24 points:

- w = min(W, V.width), h = min(H, V.height).
- desired x = S.minX + d; desired top = S.maxY − d; desired y = desired top − h.
- x = clamp(desired x, V.minX, V.maxX − w).
- y = clamp(desired y, V.minY, V.maxY − h).
- Output full frame (x,y,w,h). In AppKit's global bottom-left-origin coordinates, **down subtracts Y**. Use S.maxY, not S.minY minus d; source and destination heights may differ. Never assume V starts at zero or join displays into one bounding box.

Use the actual freshly created window's `frame.size` or AppKit's `frameRect(forContentRect:)` with the actual style. The hard-coded content height 720 is not its frame height; a fixture's 742/750 is synthetic test input, not a promised OS chrome height. Only shrink the **new** reader when required; do not enlarge it to the source's size. At an edge, clamping can reduce/eliminate the visible offset: keeping the full frame in the usable area takes precedence. No persistent sequence accumulator, wraparound feature or reliance on undocumented native cascade increments is needed. Repeated activations from the same unchanged source may yield the same desired origin; activations from the new reader cascade from that reader.

Guard nonfinite/empty/invalid geometry so clamp bounds cannot invert. Filter invalid screen rectangles; use the documented deterministic fallback. For physically impossible areas smaller than native controls themselves, numeric containment does not prove control usability; report the limit rather than claiming native coverage.

### Hosting/minimum-size integration risk

Installed AppKit SDK `NSWindow.h` declares full/content rect conversions (:285–291), explicit-screen creation (:294), `setFrame`/`setFrameTopLeftPoint`/`cascadeTopLeftFromPoint` (:347–352); it documents `screen` may be nil for offscreen/no-screen windows (:509–511), and **minSize/contentMinSize are ignored with Auto Layout** (:560). `NSScreen.h:25–26` documents first screen as zero screen and `mainScreen` as the key-window screen. These are source/API facts, not executed window evidence.

Current `DocumentReaderView` hard-coded `.frame(minWidth: 480, minHeight: 320)` and default `NSHostingController` sizing can defeat a shrunken frame on a small visible area. Scope any adjustment to the additional reader: derive allowed content minimum from the chosen full frame with `contentRect(forFrameRect:)`, cap that reader's existing minimum accordingly, and ensure hosting does not expand it back outside the area during `install`. A small per-controller minimum input passed into `DocumentReaderView` is permissible if needed; preserve 480×320 defaults for other readers/routes. Do not globally remove minimum constraints or alter existing readers' frames. Worker must record the exact chosen sizing API and passive assertions/source audit; no window-host experiment is authorized to resolve uncertainty. Keep inability to validate native hosting behavior explicit.

## Exact concrete worker file scope

Required production files:

- New `NeoMD/Documents/DocumentWindowPlacement.swift`: value snapshot/screen descriptors, deterministic screen fallback and full-frame fit policy; narrowly scoped AppKit capture adapter may be here or in the coordinator.
- `NeoMD/Documents/DocumentLinkActivation.swift`: capture placement before async work only for additional-reader intent; carry through the production open call/test seam.
- `NeoMD/Documents/DocumentOpeningCoordinator.swift`: source-session window snapshot method and optional placement parameter on `open`; pass only to new-controller creation. Preserve all transactional ordering/cleanup.
- `NeoMD/Documents/DocumentWindowController.swift`: optional initial placement; preserve legacy default centering when absent, derive full size, fit new frame before display and retain it through install; contain small-screen minimum/hosting adjustments.
- `NeoMD/Views/DocumentReaderView.swift`: only a small scoped minimum-size input if required to prevent small-screen hosting overflow. Its event routing and reader state methods need no change.

Tests: new passive `NeoMDTests/DocumentWindowPlacementTests.swift`; extend `NeoMDTests/DocumentLinkActivationTests.swift` for synchronous source snapshot transport and independent lifetime. No executable test is supplied by triage. Install the six triage docs/data artifacts from the external manifest. No `project.pbxproj`, menu, native-document ownership, parser, pointer tracking, sandbox, permission, entitlement, history or settings edits expected. Report any necessary broader change before expanding scope.

## Permitted later tests — NOT RUN by triage

Actual bodies inspected at this base:

- `-only-testing:NeoMDTests/DocumentLinkActivationTests` — all 12 existing methods: pure activation/scope values, model requests, injected async classification/open/dispatch, reservation guards, detached attributed content and owned inert file read/decode/render. No native window/controller is installed. Its early real `open` returns at the missing-document-controller guard. Preserve these boundaries when extending its seams.
- `-only-testing:NeoMDTests/DocumentOpeningTests` — all 9 methods: session fragments, lifecycle and drop models only; lifecycle coordinator has no native controller/windows.
- `-only-testing:NeoMDTests/DocumentLinkResolverTests` — both methods: local path and fragment values only.
- Exact `NativeNavigationTests` methods only: `batchPolicyRejectsInsteadOfSilentlyChoosingOrOpeningExtraReaders()`, `capturedDestinationCancelFailureAndClosedWindowPreservePresentation()`, `failedAndCanceledPreparationNeverPublish()`, `suspendedOlderPreparationCannotWinOrClearNewerFragment()`, `canonicalReservationsProtectSharedCandidatesAndOtherViewers()`, `allFileLinksUseConservativeDispositionIncludingSymlinks()`. Six model/owned-filesystem cases, no windows or handler launches. The final method adds executable metadata only to inert owned text for classification; it never runs a program.

This is **29 existing methods**, plus new inspected passive placement/transport cases; discovered/expanded counts must come from actual results, not this inventory. Do not run all `NeoMDTests` or all `NativeNavigationTests`: other bodies invoke native actions/windows. Exclude every UI/E2E/hosting/window probe, event/delegate/AX invocation, NSWorkspace launch, picker/menu action, focus/scroll/clipboard/appearance interaction. Use raw modifier/geometry values, never NSEvent dispatch or NSWindow construction as a surrogate UI test. No triage commands/builds/tests were run.

New production-connected unit obligations:

1. Exact 24-point source-top-left shift when it fits, unequal source/destination sizes, all edges/corners, negative X/Y, nonzero visible origins and title-bar-inclusive size. Run the inert [numeric vectors](fixtures/m1-p7-window-cascade/geometry-cases.json), also asserting finiteness/full containment/input immutability and size never greater than default or visible size.
2. Source screen ID wins even when another display is active or screen list order changes; updated visible area is used. Removed/nil source screen chooses deterministic nearest/tie-break fallback. Closed/replaced/moved source after capture does not alter the copied snapshot. Missing source geometry and no-valid-screen fallback are explicit.
3. Oversized full frame shrinks per axis; output remains contained even below 480×320. Assert associated content-minimum calculation does not exceed available content bounds and legacy defaults remain unchanged. Pure math is not native hosting/control proof.
4. A source-ID keyed injected capture provider is invoked synchronously in actual request construction, before a suspended classifier/acquirer. After fake active/source geometry changes or source closure, the same snapshot reaches the production open seam on success. Ordinary activation has nil placement and no geometry lookup; `destination(newWindow: true)` alone (Command-N model) does not silently acquire cascade policy.
5. Preserve source and existing other session generation/task/prepared/section state; independent target fragment; failure/cancellation/termination and external/reveal have no placement application or leaked reservation. New placement cannot escape the existing success-only controller branch. Injected spies are not proof of actual window count/display.

Later commands from the worker's isolated story branch, fresh external outputs:

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-52-DerivedData build

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-52-DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:NeoMDTests/DocumentLinkActivationTests \
  -only-testing:NeoMDTests/DocumentOpeningTests \
  -only-testing:NeoMDTests/DocumentLinkResolverTests \
  '-only-testing:NeoMDTests/NativeNavigationTests/batchPolicyRejectsInsteadOfSilentlyChoosingOrOpeningExtraReaders()' \
  '-only-testing:NeoMDTests/NativeNavigationTests/capturedDestinationCancelFailureAndClosedWindowPreservePresentation()' \
  '-only-testing:NeoMDTests/NativeNavigationTests/failedAndCanceledPreparationNeverPublish()' \
  '-only-testing:NeoMDTests/NativeNavigationTests/suspendedOlderPreparationCannotWinOrClearNewerFragment()' \
  '-only-testing:NeoMDTests/NativeNavigationTests/canonicalReservationsProtectSharedCandidatesAndOtherViewers()' \
  '-only-testing:NeoMDTests/NativeNavigationTests/allFileLinksUseConservativeDispositionIncludingSymlinks()' \
  -resultBundlePath /tmp/neomd-52-units-1.xcresult test
```

After authoring and inspecting the new passive suite, add `-only-testing:NeoMDTests/DocumentWindowPlacementTests` to the second command. Run changed-source primary diagnostics before build; record exact SHA, full actual command, exit, discovered/executed/passed/failed/skipped counts, logs/result bundles and any compiler failures/corrections. Zero-test selectors are not passes. The existing hosted-unit startup suppresses the picker; do not manually open the app. If validation is unavailable, stop and report rather than substituting interactions or weakening requirements.

## Final user-owned testing and worker evidence

[Deferred recipe](fixtures/m1-p7-window-cascade/README-fixture.md) covers actual source-relative placement and multi-screen/edge/title-bar assertions, plus #50 state/failure/route preservation. **All native/visual/interaction outcomes remain DEFERRED/UNRUN**, not passed. Physical screen removal/acquisition races require a future authorized observable environment, not a newly added delay hook/prototype now. Keep #36/#38 and all historical failures. Combined milestone acceptance is the user's decision.

Worker evidence: **pending**. Worker installs the hashed staging artifacts, records actual implementation/API choices and allowed Debug/unit evidence here, and lists any remaining limits/corrections without rewriting triage history or promoting numeric tests to native behavior passes. No original issue checkbox is checked by this triage.

### Worker implementation and allowed evidence — 2026-09-11

The preceding pending/triage statements are historical. Worker runtime was verified from the active session's `model_change` and `thinking_level_change` records as `openai-codex/gpt-6-astra`, `low`, before repository work. Work is isolated in branch `story/52-source-window-cascade`, based exactly on the accepted SHA above. All six staged artifacts and replacement-base preconditions were SHA-256 verified before installation. Only this evidence section changes triage-supplied content; numeric vectors and deferred recipes remain unchanged.

Implementation:

- `DocumentLocalLinkRequest` captures placement synchronously, before destination reservation/begin, only for additional-reader intent. The default capture uses `windows[source.id]?.window`; the copied struct contains no native object. The existing production `run` and injected passive open seam carry the same optional value.
- `DocumentWindowPlacement` uses the captured full top-left and a 24-point down/right offset; fits the new full frame per axis and clamps against current visible bounds. Captured display identity wins; removed/nil identity selects nearest visible rectangle with numeric-ID tie-breaking. Distance uses `hypot` for the same ordering as squared distance without squaring overflow. Missing source uses the first current usable display; captured bounds are the no-current-screen fallback. No bounds yields finite default size at global origin, with no visibility claim. Invalid default dimensions become one point; invalid raw rectangle dimensions/nonfinite bounds are rejected.
- `DocumentOpeningCoordinator.open` defaults placement to nil and only supplies it to the lazily constructed new controller after preparation/staging succeeds. Existing readers never receive a placement operation. No destination/reservation/fragment/pointer/parser changes were needed.
- `DocumentWindowController` supplies the freshly created `window.frame.size`, not content size or a synthetic chrome constant. For additional readers it caps native frame minimums and derives the root content minimum using `window.contentRect(forFrameRect:)`; `NSHostingController.sizingOptions = []` prevents hosting-inferred native size preferences on those readers only. `install` preserves its incoming full frame as before. The root view has only a minimum-size input with unchanged 480×320 default. Nil-placement readers retain legacy centering, native minimum and hosting options.

Allowed validation (exact finalized head and repeat-run evidence are recorded in the PR/handoff, avoiding a self-referential commit SHA here):

- Primary LSP diagnostics: all seven changed Swift files clean before the first build; changed corrections rechecked clean before subsequent compilation. No unavailable/unsupported outcomes. Session diagnostics report no blocking errors; two unrelated Markdown first-heading warnings concern agent definitions outside this worktree.
- Debug build command above: exit 0, `BUILD SUCCEEDED`, log `/tmp/neomd-52-build-1.log`. Warnings were existing CMark actor isolation, legacy Objective-C deprecated methods, and AppIntents metadata without framework dependency; no project/signing/settings edits.
- Units use the **exact selector command above plus `-only-testing:NeoMDTests/DocumentWindowPlacementTests`**, with fresh result paths for each attempt. Attempt 1: exit 65, test compilation failed because the new test needed explicit `import CoreGraphics`; no tests executed. Log `/tmp/neomd-52-units-1.log`, bundle `/tmp/neomd-52-units-1.xcresult`.
- Attempt 2: exit 65, 37 tests executed, 35 passed / 2 failed / 0 skipped; 23 assertion issues. The additional edge assertions mixed CGFloat and Double through Swift Testing's macro (18 issues); typing vector coordinates as CGFloat corrected the assertions without changing expectations. The invalid rectangle test found a production defect: `CGRect.width` normalizes negative width. The guard now checks raw `rect.size.width/height` (five issues resolved). Log `/tmp/neomd-52-units-2.log`, bundle `/tmp/neomd-52-units-2.xcresult`. These failures are retained, not erased.
- Attempt 3: exit 0, **37 discovered/executed/passed, 0 failed, 0 skipped, 0 expected failures**, confirmed by `xcresulttool get test-results summary`. Log `/tmp/neomd-52-units-3.log`, bundle `/tmp/neomd-52-units-3.xcresult`. Counts: activation 14 (12 existing + two new), opening 9, resolver 2, exact native-navigation allowlist 6, new placement suite 6. The XCTest wrapper's zero count is not the result: Swift Testing and xcresult both report 37. Other suites, including UI, may be compiled as scheme dependencies but were not executed.
- New suite executes every one of the 12 staged geometry and six staged screen-selection vectors, checks all edge/corner combinations, current visible-area changes, invalid/missing geometry fallback and scoped content-minimum arithmetic. New request units exercise real synchronous source-ID capture and transport across suspended classification with moved/replaced/closed source values; ordinary activation never captures, and the Command-N reservation/default-nil early guard remains passive. Existing tests retain independent source/destination state, fragments, failure/cancel/termination cleanup and non-Markdown nonapplication assertions.
- `git diff --check` passes. No original-checkout, project, source fixture byte, settings or other-story changes. No reviewer, UI/E2E, native-window construction test, event/delegate/AX invocation or scripted app interaction was run.

**Limits remain DEFERRED/UNRUN:** actual window placement/count, multiple physical displays, title-bar/control accessibility, native hosting at very small sizes, selection/scroll preservation and fragment landing. Numerical containment cannot prove control usability on physically impossible visible areas or visibility when there are no screens. No original issue checkbox was checked. #36/#38 and user-owned final milestone acceptance remain unchanged; remaining stories stay paused.
