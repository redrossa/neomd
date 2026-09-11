# M1-P6 / #50 — Command-click routing: triage and validation

Contract: [original issue #50](https://github.com/redrossa/neomd/issues/50), [approved pivot/order](milestone-1-command-click-pivot.md). Exact canonical `main` base: `71cdd6acef777526f16f4020bc54fb273060b9a0` (#48 / PR #49). Runtime verified before research: `PI_PROVIDER=openai-codex`, `PI_MODEL=gpt-6-astra`, `PI_REASONING_LEVEL=high`.

Status: **ACCEPTED for implementation; source/docs research only. No app code, executable tests, builds, prototypes or interactions performed.** Acceptance here means ready to implement, not criteria checked or native behavior verified. No reviewer stage. Later gates are Debug build and selected non-interaction units only. #14 is deferred and #15–24 remain paused even after #50.

## Criterion assessment

| Criterion | Base evidence and required change | Readiness / validation limit |
| --- | --- | --- |
| C1 — additional reader, source unchanged, already-open target | `MarkdownLinkedImageTextView.textView(_:clickedOnLink:at:)` currently forwards URL only. `DocumentReaderView.openLocalTarget` always calls `session.begin()` and opens into that source. `DocumentOpeningCoordinator.destination(newWindow: true)` already reserves an independent session; `open` acquires without display and creates its window only after stage succeeds. It adds a new controller even when native acquisition returns `alreadyOpen`. | ACCEPTED; implement explicit pointer disposition and independent request session. Do not call `source.begin()` for Command-click: it cancels work and clears source section. Actual new window, source scroll/selection and other-reader preservation remain deferred. |
| C2 — ordinary replacement, paths and new-reader fragments | Reader's current URL resolver and coordinator already accept `DocumentLocalTarget` and fragment; `DocumentReadSession.SectionRequest` is keyed to presentation/serial and is session-local. A same-session same-URL open navigates rather than rebuilding. | ACCEPTED; ordinary route stays source-bound. A fresh session has no prepared input, so Command-click self/already-open links bypass that same-session fast path and commit their own fragment. Do not use URL-global fragment queues. Native landing remains deferred. |
| C3 — failed acquisition, feedback, no empty reader, no writes | `open` preflights, calls `acquireWithoutDisplaying`, stages off-main render, then creates/installs/shows a controller in a no-await commit. `NativeDocumentReservations` protects shared native candidates. Existing notice/failure copy gives path, moved/volume/permissions/Privacy & Security recovery advice. Read-only NSDocument guards and safe regular-file read remain in force. | ACCEPTED; every preflight/acquire/stage/cancel failure must clean the new-session reservation and leave all prepared source/other state intact. Report through the captured live source, not an empty destination's modal alert. Model/file assertions support the transaction, not actual failure UI or interaction immutability. |
| C4 — unchanged other routes | Separate keyboard OpenURLAction, context-menu URL-only Open/Copy and AX press paths already exist. File links go through `LocalFileDisposition`: Markdown/external/reveal, including executable symlinks. Command-N/Open/drop routes capture sessions independently. #48 focus wrapper changes are separate. | ACCEPTED; modifier intent affects only pointer-activated supported local Markdown. No native menu/sandbox/parser rewrite. Negative routing can be unit tested with spies; real key/menu/drop/AX/external behavior remains deferred. |

Dependencies #43 and #48 are merged at this base. No missing product decision blocks the story. No claim that the requested Command-click behavior is already implemented.

## Actual event-to-native-owner trace

1. `MarkdownBlockView.inlineContent` uses `MarkdownLinkedImageText` for ordinary nonempty prose, headings and link-bearing content. Image leaves pass through `MarkdownImageParagraph`; linked images and mixed prose use the same `MarkdownLinkedImageTextView`, including loaded attachments and loading/unavailable text. It is selectable, noneditable, has native `.link` attributes and a pointing-hand link style.
2. `MarkdownLinkedImageTextView` is its own NSTextView delegate. Its `textView(_:clickedOnLink:at:)` accepts URL or String, invokes `open(URL)` and always returns true so AppKit never independently launches the URL. The representable's `updateNSView` binds `view.open = { openURL($0) }` to SwiftUI's environment action. This drops all pointer modifiers.
3. `DocumentReaderView.body` overrides `openURL` with `handleLink(url)` and supplies a separate `documentKeyboardOpenURL` with `keyboardDriven: true`. `handleLink` resolves relative paths/internal anchors. Absolute `file:` URLs have query/fragment split and join the same local handler; external non-file URLs return system action or explicitly call inherited `systemOpenURL` for the custom keyboard action.
4. `openLocalTarget` currently begins the **source** session before creating a Task, resolves `LocalFileDisposition` off-main, then calls `openingCoordinator.open(... in: session, token:)` for Markdown, `NSWorkspace` for safe other files, or Finder reveal for applications/executables. Failures show a transient source notice.
5. `DocumentOpeningCoordinator.open` reserves canonical native identity, preflights, calls `MarkdownDocumentController.acquireWithoutDisplaying`, stages `PreparedReadingDocument` off-main, then attaches the target controller with `document.addWindowController`. `acquireWithoutDisplaying` deliberately calls **super** with `display: false`, avoiding the controller's active-window override. No window is allocated until all preparation and token guards succeed. `alreadyOpen` does not short-circuit attachment.
6. `DocumentWindowController.install` hosts a reader keyed by the new presentation ID; section consumption is session-local. `shouldCloseDocument = false` and reservation/viewer-count cleanup protect other readers sharing the NSDocument. Existing per-reader URL remains the relative-path base, even when native identity is symlink-canonicalized.

### Synchronous modifier and source capture: implementation boundary

Prefer a small explicit activation value (ordinary vs additional reader, with pointer provenance), not ambient/global event state. In the existing NSTextView subclass, scope pointer metadata around `mouseDown(with:)`: copy the passed event's modifiers/type (and view/window identity if needed) **before** calling `super.mouseDown`, retain only the value for that tracking scope, restore/clear it with `defer`. Continue to let `super` perform link hit testing, tracking and selection. The native clicked-link delegate consumes this scoped value synchronously and forwards the URL plus requested disposition. Do not activate from mouseDown itself, overlay a gesture, create a global monitor, retain the NSEvent for later, or query `NSApp.currentEvent`, `NSEvent.modifierFlags`, keyWindow or mainWindow after an await.

Installed SDK evidence: `AppKit.framework/Headers/NSTextView.h:202–203` documents `clickedOnLink:atIndex:` being invoked during mouse tracking and sending clicked-link delegation; `:580` declares the delegate signature without an event argument. `:347–348` describes native link text attributes. This supports the bounded tracking-scope bridge, not a tested guarantee of actual Command-click behavior. Keep direct/programmatic delegate calls without pointer scope ordinary. Nested scope cleanup and detach must not leave stale intent. Control-click remains the existing secondary-menu gesture, not Command-click-new-reader; right-click/menu/keyboard/accessibility actions must not inherit a prior mouse intent.

`OpenURLAction` itself accepts only URL. Add a narrow typed environment callback for native pointer activation alongside, rather than trying to smuggle disposition through URL/fragment or changing the standard environment API. Bind it in `DocumentReaderView` to the **same common resolver/handler**, with explicit ordinary default for the existing OpenURLAction. In the representable, use the typed callback for actual scoped pointer delegation and retain URL-only `open` for AX/non-pointer fallback. Keep keyboard and menu routes ordinary even if Command is down; no new keyboard/context-menu disposition is approved. A custom callback cannot rely on returning `.systemAction` to receive SwiftUI's automatic fallback: explicitly use inherited `systemOpenURL` exactly once for its external path, while preserving `keyboardDriven` separately for internal-anchor focus behavior.

At reader entry, synchronously capture the source `DocumentReadSession` (and presentation ID for stale-view checks), resolved local URL/fragment and requested disposition before starting asynchronous work. Never rediscover the source via the active window. Ordinary requests keep their existing source session/token. Additional requests reserve an independent session/token before the first await and place task/cancellation state there; neither source nor another reader gets `begin`, `navigate`, `commit` or `install`. After asynchronous file classification, only `.markdown` uses this additional session; safe external/reveal outcomes retain their existing dispatch and discard the unused reservation. Pure anchors never enter local acquisition or reserve a window.

Use the existing coordinator transaction for both paths. Centralize the new request's cleanup so classification failure, non-Markdown routing, acquire failure, cancellation, termination and early guards all release its reservation: `open`'s current defer begins after some guards, so it alone is not sufficient for an outer reserved request. Finish/cancel only the captured token; do not clear a newer request. Report actionable failure on the captured source while it is live, with no fallback into an unrelated/key reader and no late failure alert after source closure/termination. A separate additional-reader request has its own lifetime like Command-N; ordinary source navigation must not mutate or redirect it. Preserve per-destination cancellation and termination guards. If a broader close-source policy is desired, escalate rather than changing the accepted native transaction model silently.

### Pure SwiftUI/image edge

`requiresNativeText` currently skips whitespace-only non-image runs. Therefore a supported authored link with a whitespace-only label can fall through to `Text(text)` and lose the new pointer bridge. The smallest coverage fix is to choose native text for **any link-bearing run**, then retain the current nonwhitespace-prose condition. Verify this with parser/model inputs and native attributed ranges, not an interaction prototype. Linked image-only leaves already choose native text; loaded, missing and loading links keep the same URL. Unlinked image-only/whitespace leaves remain SwiftUI composed Text with image semantics; no actionable link exists there and no modifier handler is needed. Do not rewrite image loading, Retry, or native cursor/context-menu layers.

## Concrete worker scope

- `NeoMD/Views/MarkdownLinkedImageText.swift`: scoped native pointer value, typed activation binding/cleanup, preserve ordinary AX fallback; close the link-bearing whitespace fallback.
- `NeoMD/Views/DocumentReaderView.swift`: shared typed/ordinary URL routing; synchronously source-bound request capture, independent additional session, correct external fallback and source failure notice; preserve scroll/focus/image state methods.
- `NeoMD/Documents/DocumentOpeningCoordinator.swift`: narrowly expose/own new-request reservation lifecycle and testable request seam if needed. Reuse `open`, native acquisition and late commit. Do not change global Open/New/drop defaults.
- A small `DocumentLinkActivation` / captured-request helper may live beside these or in one focused new file. Avoid an abstract window/navigation framework. `DocumentReadSession` changes only if needed for correct token cleanup/testing, not a broad state refactor.
- Add narrowly scoped non-interaction production-seam tests, suggested `NeoMDTests/DocumentLinkActivationTests.swift`; add cases in resolver/opening suites only where directly needed. Use injected classification/acquisition/commit/dispatch closures or a small captured-request helper used by production so tests do not create native windows or launch handlers. Preserve existing interaction tests and historical failures, do not run them.
- Install triage documentation/fixtures from the external manifest. No change to `project.pbxproj`, settings, entitlements, parser, menus or unlinked image store is expected. If any such change becomes necessary, report why before broadening scope.

## Allowed later tests (all NOT RUN by triage)

Inspected bodies at the accepted base:

- `DocumentLinkResolverTests` — both methods: relative/leading-slash/encoded/Unicode/query paths and exact-once fragments.
- `MarkdownWebLinksTests` — all five: parser destinations, external classification, authored menu order and generated-link exclusions; no browser/menu actions.
- `LinkCursorTests` — both: detached attributed text/image ranges, native link attributes and selection-range preservation; no events/windows/actions/network.
- `DocumentOpeningTests` — all nine: session-local fragments, lifecycle and drop-filter state; coordinator lifecycle invocation has no controller/window/panel attached.
- Exact `NativeNavigationTests` methods only: `batchPolicyRejectsInsteadOfSilentlyChoosingOrOpeningExtraReaders()`, `capturedDestinationCancelFailureAndClosedWindowPreservePresentation()`, `failedAndCanceledPreparationNeverPublish()`, `suspendedOlderPreparationCannotWinOrClearNewerFragment()`, `canonicalReservationsProtectSharedCandidatesAndOtherViewers()`, `allFileLinksUseConservativeDispositionIncludingSymlinks()`. These use model/session state or owned inert filesystem inputs. The last changes executable metadata on inert text solely to classify it; it never launches it.
- `KeyboardTraversalTests/semanticCandidatesKeepSeparateTextAndActionStops()` — semantic candidates only.

25 existing methods in this allowlist. Add actual new suite selectors only after inspection confirms non-interaction bodies and nonzero discovery. Do not run all `NativeNavigationTests`: its native write/rename/menu guard method invokes action APIs. Exclude `NativeInlineLeafTests`, broad linked-image/hosting/navigation-bridge/keyboard suites, all UI tests, direct native delegate/AX press/keyDown/mouseDown invocation, real or synthetic event dispatch, window presentation/focus/scrolling, clipboard, NSWorkspace, NSOpenPanel, appearance settings, executable programs and app interactions. New tests should pass plain modifier bits/provenance into the production capture policy; do not send NSEvents as a surrogate interaction test.

Required new non-interaction cases, connected to production rather than duplicate test policy:

1. Pointer Command vs ordinary/Control-secondary/non-pointer origins; immutable snapshot remains correct after simulated ambient changes; scoped intent clears after no activation/error/detach. Keyboard/menu/AX fallback remains ordinary.
2. Capture from source A while a fake active-reader provider changes to C; ordinary destination remains A; additional destination is distinct from A and existing B even for same URL/self-link. Assert source generation, task identity, prepared ID, notice and pending section unchanged by additional-request preparation/success/failure.
3. New reader fragment commits only to its own presentation/serial; source and existing B retain distinct pending fragments. No-fragment new reader does not clear theirs. Pure anchors stay internal; encoded/query/leading-slash and absolute file URLs preserve existing classification.
4. Inject classification/acquisition/staging errors and cancellation/termination at suspension boundaries. Assert zero create/install/display calls before success, no commit on failure, all reservations released, exactly one success commit, source-bound failure sink and no late unrelated-window report. Retain shared candidate when another viewer/reservation exists.
5. External/non-Markdown/reveal spies receive exactly one dispatch; no additional reader for them and no default AppKit second dispatch. Linked attachment/fallback, whitespace-only link and unlinked-image-only selection policy/ranges remain correct.
6. Read/decode/render disposable fixture copies without windows; compare exact bytes and non-nil modification dates before/after. This is only file-path/model evidence, not interaction immutability.

Later command prefix (worker's isolated story branch, fresh external output paths):

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-50-DerivedData build

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-50-DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:NeoMDTests/DocumentLinkResolverTests \
  -only-testing:NeoMDTests/MarkdownWebLinksTests \
  -only-testing:NeoMDTests/LinkCursorTests \
  -only-testing:NeoMDTests/DocumentOpeningTests \
  '-only-testing:NeoMDTests/NativeNavigationTests/batchPolicyRejectsInsteadOfSilentlyChoosingOrOpeningExtraReaders()' \
  '-only-testing:NeoMDTests/NativeNavigationTests/capturedDestinationCancelFailureAndClosedWindowPreservePresentation()' \
  '-only-testing:NeoMDTests/NativeNavigationTests/failedAndCanceledPreparationNeverPublish()' \
  '-only-testing:NeoMDTests/NativeNavigationTests/suspendedOlderPreparationCannotWinOrClearNewerFragment()' \
  '-only-testing:NeoMDTests/NativeNavigationTests/canonicalReservationsProtectSharedCandidatesAndOtherViewers()' \
  '-only-testing:NeoMDTests/NativeNavigationTests/allFileLinksUseConservativeDispositionIncludingSymlinks()' \
  '-only-testing:NeoMDTests/KeyboardTraversalTests/semanticCandidatesKeepSeparateTextAndActionStops()' \
  -resultBundlePath /tmp/neomd-50-units-1.xcresult test
```

Run primary changed-source diagnostics before build. The existing hosted-unit startup suppresses the picker; do not manually launch the app. Record exact head, full command, exit, discovered/executed/pass/fail/skip counts and artifacts; missing selectors/zero tests are not a pass. Build/units do not prove physical NSWindow identity or actual mouse tracking semantics. If the permitted seam cannot validate an engineering requirement, report that limitation rather than substituting native interaction tests.

## Final user-owned native checks — DEFERRED/UNRUN

The [inert fixture README](fixtures/m1-p6-command-click/README-fixture.md) defines future setup and C1–C4 oracles, including already-open B, self-link and source/other-reader state checks. All physical windows, actual Command-click, fragment landing, keyboard/context-menu/AX, source scroll/selection, failures/OS-access UI, Command-N/Open/drop, appearance/resize and interaction bytes/mtime remain **DEFERRED/UNRUN**. No recipe grants present authorization. Keep #36/#38 and prior evidence. Do not check original issue criteria from this triage or close the milestone.

## Worker implementation evidence

The triage evidence above remains historical. Worker runtime verified `openai-codex/gpt-6-astra`, `low`, before repository work. Dedicated branch `story/50-command-click` starts at accepted base `71cdd6acef777526f16f4020bc54fb273060b9a0`; original checkout and its unrelated changes were untouched. Exact final tested/pushed SHA and PR are recorded in the worker handoff and PR validation record (the commit cannot embed its own hash).

All 18 supplied artifact SHA-256 values and all six replacement-base hashes were verified before installation; new destinations were absent. Only this validation document's worker evidence was subsequently amended. Fixture bytes are unchanged.

Production changes are limited to the native text bridge, reader link entry, coordinator reservation cleanup and a focused `DocumentLinkActivation.swift` helper. Pointer metadata is copied synchronously around `super.mouseDown` with nested/defer cleanup and detach invalidation. Non-pointer `open` remains separate. Any link-bearing run now takes the native path. The common reader resolver captures source presentation and target before a request starts; only Command pointer intent reserves an independent session. Classification/non-Markdown/cancellation/early coordinator guards all release unused reservations without canceling newer work. Additional request success leaves source task, generation, prepared presentation, notice and section untouched; failure feedback requires the captured source presentation still be live. The unchanged coordinator still acquires without display and creates/installs a controller only after successful staging, including already-open documents. Explicit custom external fallback is dispatched exactly once.

Validation on the implementation tree:

- Debug build: command above, exit 0; `/tmp/neomd-50-build-2.log` (earlier build also passed).
- Units: exact 25-method allowlist above plus all 12 non-interaction `DocumentLinkActivationTests` methods. Runner command is the command above with `-only-testing:NeoMDTests/DocumentLinkActivationTests` added and fresh result path `/tmp/neomd-50-units-3.xcresult`; durable exact script `/tmp/neomd-50-units.sh`. Exit 0, **37 discovered/executed/passed, 0 failed, 0 skipped**, 7 suites, one Swift Testing run, no observed crash/restart. `/tmp/neomd-50-units-3.log` and `-3-summary.json` preserve evidence. The XCTest wrapper's 0 tests is not the Swift Testing count.
- Earlier unit attempt 1 failed at compilation (missing AppKit import for `.link` in the new test); no tests executed. Fixed import, no assertions weakened. Attempt 2 passed 36/36 before the final external-dispatch regression was added. Earlier logs/bundles remain preserved.
- Primary changed-Swift diagnostics: no findings before builds. This did not detect the initial test import problem; compiler evidence is authoritative. Final session cached diagnostics reported no issues across its three dispatched files; this is not a project-wide scan. `git diff --check` passed.
- Source inspection verified all 25 existing selected bodies; no broad native/keyboard/hosting suite, UI test, native delegate/AX/event action, Workspace launch, window/panel, clipboard or appearance mutation was invoked by new tests.

Criterion mapping and limits:

- C1/C2: production-connected captured-request tests exercise ordinary source identity, independent self/already-open model destinations, source task/generation/notice/section invariance, isolated fragments and replacement-independent additional lifetime. Resolver units retain encoded/Unicode/leading-slash policy. Actual physical new-window identity, mouse tracking, selection/scroll and fragment landing remain deferred.
- C3: classification/open-stage failure injection, suspended cancellation/termination, real coordinator missing-controller early guard, stale cleanup, shared native reservation model and read/decode/render of owned fixture copies with exact bytes/non-nil mtime checks pass. Injected open seams deliberately do not acquire real NSDocuments or create/install/display native controllers; real acquisition failure UI and no-empty-window observation remain deferred. Zero-window model assertions are not native display proof.
- C4: pure pointer provenance/Command/Control cases, nested/error/detach cleanup, custom external fallback and external/reveal dispatch spies, linked/fallback/whitespace ranges, unlinked-image policy and selected existing menu/drop/lifecycle models pass. Actual menu/AX/keyboard/Open/New/drop behavior remains deferred.

Final exact-head build/allowlisted-unit repetition is recorded in the external worker handoff/PR before push. All native interaction observations remain **DEFERRED/UNRUN**, not passed. Original issue checkboxes and milestone acceptance are not changed.
