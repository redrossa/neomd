# M1-13 validation

[Issue #13](https://github.com/redrossa/neomd/issues/13) · [approved baseline](m1-13-cues-plan.md) · [fixtures and final-milestone recipes](milestone-1-e2e-fixtures.md#m1-13--notice-alerts-emoji-and-color-references-implementation-handoff)

Implementation handoff, **not acceptance or merge approval**. Base: `add27876bca4036ed0c6c023c08cf94f46481e6b`; branch: `story/13-alerts-emoji-colors`. The PR records the exact committed head. Runtime independently verified from environment/session metadata: `openai-codex/gpt-6-astra`, thinking `low`; no delegation.

## Current scope and explicit deferrals

- C1–C4 implemented: five semantic alerts with adaptive words/symbols/rules; pinned offline Unicode emoji; strict passive inline-code colors.
- C5 remains **unchecked, deferred—not passed**, to [#38](https://github.com/redrossa/neomd/issues/38), per [approval](https://github.com/redrossa/neomd/issues/13#issuecomment-5610876429). Larger-size intermittent hangs are not fixed by this PR. [#36](https://github.com/redrossa/neomd/issues/36) remains separate; common cause is unproven.
- Latest direct user instruction authorizes production traversal integration and waives **further keyboard-navigation E2E execution**. Event-level semantic focus, boundaries, offscreen traversal, cancellation, two-window isolation and selection coverage are **deferred/not passed**, not inferred from units. No Accessibility permission is required or changed. No new UI/E2E test was executed during integration.
- Manual VoiceOver speech/order, comprehensive combined E2E and milestone business acceptance remain user-owned. Clipboard tests were not run. Stop before #14; no reviewer stage, worker merge or issue closure.

## Integration and focused corrections

The complete six-file prototype patch applied cleanly against dirty production; all six prototype source hashes matched its final manifest. Integrated four app files plus regression units. The permission-dependent semantic UI test and its ApplicationServices import were **not integrated**. Only the previously passing native full-value landing lookup was retained in the existing footnote roundtrip test; original 5/6/12 budgets, Return/Space actions, unique full equality and strictly less than 10pt landing remain unchanged.

Traversal uses per-reader weak identity/generation text/code registrations, actual native responder/action-focus confirmation, semantic forward/reverse text and link stops, measured code overflow, bounded lazy materialization and native-window-control exits. Other native chords call super; link/code/page activation handlers are retained. An instance-scoped, weak, own-window local monitor cancels stale mouse/key intent and is removed on detach/replacement/deinit.

Static integration review corrected concrete gaps rather than calling the waived E2E a pass:

1. Detaching an origin/unrelated lazy leaf no longer cancels acquisition of a different target. Detaching the actual requested text/code target still cancels; a focused regression asserts both branches.
2. Failed text/materialization/action acquisition now reports an actionable notice rather than silently returning. Failed boundary restoration uses actual native `focusText` for a text origin (there is no SwiftUI text FocusState binding), falling back to reader focus if unavailable.
3. Navigation-start indexing now bounds-checks the arena ID.

These corrections have build/unit evidence, **not event-level E2E proof**. No parser/layout/image-routing changes were introduced by traversal integration.

## Final integrated build and units (2026-09-10)

Commands executed serially from the story checkout, each with a 300-second bound (neither reached):

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/neomd-13-integrated/DerivedData \
  -parallel-testing-enabled NO -resultBundlePath /tmp/neomd-13-integrated/build.xcresult build

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -destination 'platform=macOS' -derivedDataPath /tmp/neomd-13-integrated/DerivedData \
  -parallel-testing-enabled NO -resultBundlePath /tmp/neomd-13-integrated/units.xcresult \
  -only-testing:NeoMDTests test
```

- Explicit Debug build: **exit 0**, 11.806 seconds.
- Full unit suite: **exit 0**, 24.330 seconds; xcresult summary **156 passed / 0 failed / 1 skipped** (216 expanded passes). The single skip is the explicitly disabled historical failed SwiftUI TextRenderer feasibility probe, not passing production coverage.
- Includes `KeyboardTraversalTests` (four tests), all cue/native/font/lifecycle/anchor/image/quote/layout/parser tests and existing concurrent parser regression. Strict weak native/owner release assertions pass after conditional main-runloop `beforeWaiting` cleanup bounded by a two-second deadline; no arbitrary sleep substitutes for release.
- Primary Swift LSP: six integration files clean before build. Xcode remains authoritative; existing actor-isolation/compiler advisories are not presented as errors or silently fixed out of scope.
- `sh Scripts/verify-cmark-vendoring.sh`: passed; no vendor changes. Independent fixture alias map equals all **1,913** bundled aliases. Full MIT notice equals pinned fixture notice; built app map and license are byte-identical to source resources.
- Full scoped diff inspected; `git diff --check` clean. External logs, xcresults, outcome JSON and summary remain outside the repository. Research sources, generated outputs and machine-specific research runners are excluded from the commit.

## C1–C4 evidence mapping

| Criterion | Implementation and verified evidence |
| --- | --- |
| C1 | `MarkdownAlert`, source/AST eligibility, measured header and passive rules. `AlertCueTests`: all 31 vectors, empty/multiblock arena retention and header geometry. Historical default-size Light/Dark matrix tests both pass, each five alerts plus ten mixed samples at 900/480. |
| C2 | Adaptive `ReaderTheme` labels/rules and preserved primary body styling. Historical default-size actual system Light→Dark→Light test passes for all five labels in the same document/window/reading point; original appearance restored and source bytes/mtimes unchanged. |
| C3 | Public cmark raw-inline hook retains escape/entity/image provenance. `EmojiCueTests`: 22 vectors, 1,913 aliases, raw HTML/URL/image exclusions, 16×40 concurrent parses; built offline map and complete MIT notice verified. Visible emoji in both-theme mixed screenshots. Unknown/image-only names remain literal. |
| C4 | `MarkdownColorReference` full-value finite parser; `MarkdownColorSwatch` passive native drawing without character/AX/action insertion. All 49 independent vectors; native drawing, exact strings/selections, unchanged storage updates, image states and authored links pass. Both-theme screenshots show white/black borders and HEX/RGB/HSL cues across headings, prose, tasks, quotes, alerts and footnotes. |

### Historical UI evidence reused, not rerun on the integrated head

| Selector | Actual historical result |
| --- | --- |
| `DocumentCueUITests/testScaleOneLight` | 1 pass, 0 failures/skips, 105.351s test (114.671s command) |
| `DocumentCueUITests/testScaleOneDark` | 1 pass, 0 failures/skips, 106.436s test (111.412s command) |
| `DocumentCueUITests/testDefaultSizeAllAlertsFollowLiveSystemAppearance` | 1 pass, 0 failures/skips/restarts, 105.388s test; actual system switching/restoration |
| `DocumentReaderLayoutUITests/testInitialReadingMarginAndTopPositionSurviveResize` | 1 pass, 0 failures/skips, 33.307s command; full native value selector, unchanged geometry/immutability assertions |
| `DocumentOpeningUITests/testMenuAndCommandOInvokeTheNativeOpenPanel` | exit 0, 17.873s command |
| `DocumentImageUITests/testNativeLinkedImagesWrapAndResizeWithoutUpscalingInBothThemes` | exit 0, 22.897s command, both themes |
| `DocumentLinkNavigationUITests/testKeyboardFocusAndActivationOfInternalLinks` | Prototype historical pass in both themes, 31.428s command; final prototype regression batch also 10 passes (9 units + this UI), 0 failures/skips, 34.036s command. Not rerun after integration corrections. |

Default-size visual inspection completed during integration **using existing captures only**: all 60 matrix images reviewed in ten contact sheets (30 per theme, five alerts and ten mixed samples × two widths). Persistent labels/symbols/rules, intact multiblock structure, visible emoji/swatches including black/white borders, literal image metadata/invalid controls, ordered task/quote/footnote content and narrow wrapping are visible without overlap in the sampled content. This is screenshot review, not new execution, pixel-perfect equivalence or VoiceOver proof. Capture names follow `Alerts-{kind}-{theme}-1.0x-{width}` and `Mixed-{sample}-{theme}-1.0x-{width}` in the exported attachment manifests.

C2's prior worker inspected all 15 live-switch screenshots. Label/body Y stayed identical across triplets (8pt assertion tolerance), label contrast 6.596–10.671 and body 12.130–20.878. **Oracle limitation:** runtime `ruleContrast` samples glyphs because AX label bounds exclude the rule; do not use it as independent rule evidence. Independent offline sampling of actual captured rule pixels gave minimum 5.449 Light / 6.832 Dark. No rule-oracle rerun is claimed.

## Preserved failure history and limits

This compact shipping record supersedes chronological checkpoint status headings, not their results. Full original research/validation histories and artifacts remain preserved externally/untracked; they are not app resources.

- Selectable SwiftUI TextRenderer failed (zero draws); inline-image alternative created unwanted AX children. Replaced under explicit approvals by the native bridge. Historical disabled feasibility test remains a skip, not a pass.
- Larger-size wheel/resize hangs persisted through bounded research, including a standard SwiftUI selection reproduction and a native-era 2× loop. Successful 1.5× runs do not erase intermittent failures. C5 is deferred to #38; no causal fix or #36 equivalence claimed.
- Initial margin and footnote landing failures included obsolete StaticText/predicate oracles. Full native `.value`/unique-match adaptation passed without relaxing geometry. Earlier wrapper/blanket key-view exclusions and nextResponder forwarding failed or were incomplete and were reverted; they are not shipped.
- Font representation assertions initially failed. Independent accepted-main resolved-font/glyph tests exposed and corrected heading-5 inline-code bold parity; final units pass. No assertion now derives its baseline font expectations from the implementation.
- Prototype hosted native weak-release initially failed synchronously. Matched unregistered/registered owner graphs showed native deferred timer retention; strict nil checks pass after actual bounded runloop cleanup, not a waived leak.
- Semantic native-focus UI oracle failed with `AXIsProcessTrusted() == false`: **0 passed / 1 failed**, exit 65. Its early async assertion originally allowed later actions; the scratch guard was corrected. No subsequent event assertions count as valid proof. The unvalidated test is not an active committed gate; further keyboard E2E is explicitly user-deferred.
- Native range/Shift-arrow method tests and paired cross-paragraph drag screenshots are limited evidence: the drag selected only its originating paragraph in both baseline and production. Universal cross-block selection, Copy/Select All and manual VoiceOver equivalence are not established.
