# M1-P5 / #48 — focus-decoration validation

Contract: [#48](https://github.com/redrossa/neomd/issues/48), [approved pivot](milestone-1-focus-outline-pivot.md), [milestone order](https://github.com/redrossa/neomd/milestone/1). Accepted source-research base: `8704fb2225fdd9eb373fcc30d4655e6f7eb9f398` (merged #43 / PR #47).

Status: **IMPLEMENTED; DEBUG BUILD AND 28 SCOPED NON-INTERACTION UNITS PASS. VISUAL/NATIVE BEHAVIOR DEFERRED/UNRUN.** Triage authored the source research, fixture packet and final-testing documentation; the worker installed all nine deliverables after verifying every manifest artifact/source/replacement hash and filled this evidence section. Triage performed no build or interaction. No reviewer stage. Only #48 is authorized; #14 is entirely deferred and #15–24 remain paused even after this pivot.

## Criterion mapping and limits

| Criterion | Source evidence / smallest implementation | Current validation |
| --- | --- | --- |
| C1 — no enclosing link-block ring | `MarkdownBlockView.body` explicitly draws an accent rounded rectangle for `.links(block.id)` at base lines 65–70. Remove only that overlay. Keep the selected link's underline/background and all semantics/key handlers. Locally suppress the framework effect of `MarkdownLinkFocus`, without leaking into its children. | Explicit overlay removed; production boundary environment units pass. Visible result DEFERRED/UNRUN. |
| C2 — no enclosing viewport/window-content ring | `DocumentReaderView` has a separately focusable vertical ScrollView; `MarkdownCodeBlockView` has a conditionally focusable horizontal ScrollView. Apply local public focus-effect suppression to these targets, retaining focusability. `DocumentWindowController.install` hosts the reader without a custom window-focus overlay. Native `MarkdownLinkedImageTextView` has no explicit enclosing focus drawing. The document-sized `MarkdownFileDropModifier` overlay is conditional on actual drag targeting and excluded. | Separate source investigation completed; the reported whole-window effect is NOT reproduced and its framework/native source is NOT proven. The hypothesis is not merged with the confirmed block overlay cause. |
| C3 — preserve keyboard/focus/AX | Preserve reader/link/code focus bindings and interactions, native selectable-text target, candidate ordering, key handlers, bridge registrations/acquisition and accessibility labels/hints/traits. Do not remove `.focusable` or set `.disabled`, intercept Tab differently, disable selection, or change responder/window ownership. | Source invariants plus targeted model units are suitable supporting evidence, not event/focus/AX proof. |
| C4 — preserve selection/link/control/drop feedback | Preserve text storage/selection, native link color/underline/cursor policy, selected-link-local styling, image Retry overlay and native-control effects, and file-drop overlay. A descendant environment boundary is essential; blanket `.focusEffectDisabled(true)` would suppress children. No system preference or permission changes. | Source scope and passive environment/attributed-text units are suitable supporting evidence. Real control rings, cursor/selection pixels and drag behavior are DEFERRED/UNRUN. |
| C5 — source remains read-only | Restrict production edits to decoration. Keep all read/write/opening code unchanged. Add/retain an owned-copy read/render bytes+mtime regression without opening windows or invoking native actions. | Non-interaction file assertions may support read-only code paths, not establish real focus/reading immutability. Future user interaction bytes+mtime check remains DEFERRED/UNRUN. |

## Public API and containment requirement

Apple's [`focusEffectDisabled(_:)`](https://developer.apple.com/documentation/swiftui/view/focuseffectdisabled(_:)) says it controls default focus rings/hover effects and explicitly warns that an ancestor disabling effects overrides a child's `.focusEffectDisabled(false)`. Do not rely on that child modifier to restore ordinary controls.

[`EnvironmentValues.isFocusEffectEnabled`](https://developer.apple.com/documentation/swiftui/environmentvalues/isfocuseffectenabled) is publicly get/set, defaults to true, and controls whether the associated view allows focus effects. Both APIs are available on macOS 14+, below this project's target; the installed Xcode SwiftUI interface confirms the declarations.

Use the narrow boundary: capture the incoming effect-enabled environment **before** local suppression; restore that exact value with a direct environment write on the focus target's content; keep `.focusable(..., interactions: .edit)` outside the restored content and suppress its effect outside that focusable wrapper. For ScrollView the child restoration belongs inside its content closure, while suppression belongs on the scroll target. For the link-focus modifier restore its incoming content before its own focusable wrapper. This lets native/ordinary descendant controls inherit their original policy and lets nested document targets establish their own local suppression. Preserve an inherited false rather than force-enabling all descendants. A small focused helper is acceptable; do not create a new focus subsystem.

Worker must verify the actual modifier/environment order using a passive non-interaction unit on the production boundary: incoming true and false, descendant control policy, and nested boundary isolation. No key/main window, event dispatch, focus request, AX press, visual screenshot or app interaction is permitted. If this cannot be established with the permitted tools, stop and report the limitation; do not substitute blanket suppression or broaden to global AppKit changes. Native text/hosting is inspected but not preemptively altered without concrete local evidence. A persistent or newly evidenced wider cause requires escalation, not scope expansion.

## Worker gate allowlist

Run from the worker's dedicated story branch. First verify runtime `openai-codex/gpt-6-astra` / low and run primary source diagnostics before building. Use fresh external result paths. Existing selected bodies were inspected at the accepted base:

- `ReaderThemeTests` — all seven methods; attributed-string/font policy only.
- `LinkCursorTests` — both methods; detached native text storage/ranges, cursor attributes and programmatic selection-range preservation; no events, windows or actions.
- `DocumentReaderLayoutTests` — all six methods; pure sizing/anchor/restoration state.
- `DocumentLinkResolverTests` — both methods; pure destination classification.
- `KeyboardTraversalTests/semanticCandidatesKeepSeparateTextAndActionStops()` — pure semantic order.
- `KeyboardTraversalTests/lazyOriginDetachDoesNotCancelAnotherTargetAcquisition()` — detached NSView registry/state only.
- `MarkdownDocumentTests` — all four methods; read-only model contract.

That is 23 existing methods before new scoped regression cases. Add a narrowly named `DocumentFocusEffectTests` suite for the implemented containment boundary and owned-copy fixture read/render immutability. The name is **proposed, not an existing selector**; record actual non-interaction bodies/selectors and counts when implemented. Do not add tautological enum tests that are not connected to production decoration.

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-48-DerivedData build

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-48-DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:NeoMDTests/ReaderThemeTests \
  -only-testing:NeoMDTests/LinkCursorTests \
  -only-testing:NeoMDTests/DocumentReaderLayoutTests \
  -only-testing:NeoMDTests/DocumentLinkResolverTests \
  '-only-testing:NeoMDTests/KeyboardTraversalTests/semanticCandidatesKeepSeparateTextAndActionStops()' \
  '-only-testing:NeoMDTests/KeyboardTraversalTests/lazyOriginDetachDoesNotCancelAnotherTargetAcquisition()' \
  -only-testing:NeoMDTests/MarkdownDocumentTests \
  -resultBundlePath /tmp/neomd-48-units-1.xcresult test
```

Append the actual new suite selector only after it exists. Confirm nonzero expected test discovery and individual method coverage; exit zero with missing selectors is not a pass. Record failures/skips honestly. Hosted unit startup already suppresses the picker in `NeoMDApplicationDelegate`; do not launch the standalone app.

**Excluded now:** all `NeoMDUITests`; full `NeoMDTests`; full `KeyboardTraversalTests` (contains native selection actions/window lifecycle); `NativeInlineLeafTests` and broad `MarkdownLinkedImageTextTests` (AX/link actions and key-window presentation); `NativeNavigationTests` native write/rename/menu guards; navigation-bridge/hosting suites that create windows or scroll/focus; all clipboard/system-appearance/NSWorkspace/NSOpenPanel/event synthesis. Do not infer authorization from the test target being called “unit”. Release build, broad parser audit, performance runs and milestone full suite are not #48 gates.

## Durable final-testing packet

[Fixture README](fixtures/m1-p5-focus-outlines/README-fixture.md) provides the inert files, isolation, independent link-free viewport control, separate focus/control/drop oracles, appearance/width and keyboard/selection/AX observations, and exact bytes/mtime comparison. All native checks are **DEFERRED/UNRUN**, not passed. No interaction command is authorized by this document. Existing #36/#38 failures/deferrals remain separate and unchanged. Final milestone acceptance is user-owned.

## Worker evidence to complete

- Branch: `story/48-quiet-focus`, base `8704fb2225fdd9eb373fcc30d4655e6f7eb9f398`. Exact committed/validated head and PR are recorded in the worker's PR evidence and durable handoff. Production files: `DocumentReaderView.swift`, `MarkdownBlockView.swift`, and the 14-line `DocumentFocusEffect.swift`. The helper captures the incoming environment before suppression and makes the same boundary directly testable at all three targets. Each ScrollView restores the captured policy inside its content closure; the link target restores it before the unchanged focusable/focused/key wrappers. No forced true, native/global overrides or removed focus targets.
- Debug command: the build command above, exit **0**, `/tmp/neomd-48-build-final.log` (initial build also passed: `/tmp/neomd-48-build-1.log`). DerivedData remains outside the repository. No project/settings/dependency changes.
- Unit command: exactly the allowlist command above plus `-only-testing:NeoMDTests/DocumentFocusEffectTests`, changing the result path to `/tmp/neomd-48-units-final.xcresult`. Exit **0**; log `/tmp/neomd-48-units-final.log`. Expected/discovered/executed **28 methods in 7 suites: 23 existing + 5 new; 28 passed, 0 failed, 0 skipped, 0 expected failures**, independently confirmed by `xcrun xcresulttool get test-results summary --path /tmp/neomd-48-units-final.xcresult --format json`. The XCTest adapter's zero-test preamble is not the Swift Testing count. Host: arm64 macOS 26.5.1.
- New selectors in `DocumentFocusEffectTests`: `enabledIncomingPolicyIsRestoredForOrdinaryControl()`, `disabledIncomingPolicyIsNotForcedOnForOrdinaryControl()`, `nestedTargetsRemainQuietWithEnabledControlPolicy()`, `nestedTargetsPreserveDisabledControlPolicy()`, and `fixtureReadRenderPreservesBytesModificationTimeAndLinkCandidates()`. The first four evaluate the actual production helper with SwiftUI `ImageRenderer`, checking suppressed outer/nested targets and inherited true/false at a real Button's background environment probe. They do **not** inspect native control style/ring pixels. There are no windows, focus requests, actions, events, clipboard or setting changes in the final tests. The fifth reads/decodes/renders an owned disposable copy of triage's `focus.md`, verifies separate text/link candidates and code candidates, and checks identical bytes/non-nil unchanged mtime before removing only its own temporary directory.
- Harness correction history: runs `/tmp/neomd-48-units-1.{log,xcresult}` and `-2.{log,xcresult}` each executed 28 methods with **24 passed / 4 failed / 0 skipped** (exit 65). Both attempted to observe a native ButtonStyle that was never evaluated (nil observation), first via ImageRenderer and then a detached, windowless NSHostingView. Target-policy assertions passed; these failures were not evidence that controls received false. The final harness probes the Button boundary's inherited environment directly, without claiming native style evaluation. Run `-3.{log,xcresult}` passed 28/28 before indentation cleanup; the final run above passed after cleanup. No window or action was used in any attempt.
- Primary Swift LSP diagnostics on all four changed Swift files: **0 diagnostics**, clean/available for each, before the final build. Session `lens_diagnostics(mode=all)`: **no blocking errors**; two unrelated cached MD041 warnings in original-checkout untracked agent definitions, which were not changed. `git diff --check` passed. Reviewed the source scope diff: only the single explicit link overlay is removed, and three local environment boundaries are added. All native text/selection/link-cursor, navigation/window/document, Retry/drop sources remain byte-identical to the accepted base. Existing weak-variable compiler warnings in unrelated tests and AppIntents metadata notices remain unchanged; their presence is not a failed test.
- Unrun visual/Tab/window-wide/light-dark/control/selection/cursor/drop/VoiceOver/focus-file-invariance checks: **DEFERRED/UNRUN**.

No criterion checkbox or milestone acceptance is asserted by this triage record.
