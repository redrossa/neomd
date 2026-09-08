# Milestone 1 cumulative E2E fixture catalog

## Validation policy and status

User-approved amendment during [M1-08 / PR #32](https://github.com/redrossa/neomd/pull/32): per-story E2E is the **story-targeted native SwiftUI/XCTest UI coverage of the new or changed implementation**, alongside the required build and unit tests. A separate comprehensive cross-story E2E sweep is deferred to final milestone verification. This supersedes the earlier per-story full-suite requirement, not story acceptance criteria or required GitHub checks. A current-story defect or unverified required criterion still blocks acceptance.

Update this version-controlled catalog in **every story PR**, preserving previous entries. Targeted passes are not comprehensive milestone acceptance. At [milestone 1](https://github.com/redrossa/neomd/milestone/1) completion, run the full suite plus the cumulative scenarios and outstanding cross-story/manual checks below; the user then personally tests and decides business acceptance. Do not infer acceptance from issue closure alone.

Commands run from the repository root with a compatible Xcode/macOS graphical session. Keep results outside the repository and use a fresh result-bundle path for each run. Serialize UI runs; preserve unrelated app sessions. For real system appearance switching, use `Scripts/appearance-test-host.sh` from a terminal authorized for System Events in System Settings → Privacy & Security → Automation. It owns an isolated build directory and restores the original appearance; permission failure or restoration failure is not a pass. See [appearance test instructions](appearance-ui-tests.md).

Final milestone command (all unit and UI tests, with real appearance controller):

```sh
NEOMD_RESULT_BUNDLE=/tmp/neomd-m1-final.xcresult Scripts/appearance-test-host.sh
```

The underlying full-suite Xcode command is `xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-DerivedData test`. A plain run that skips real appearance switching does not establish that coverage. Record exact final SHA, results, screenshots, remaining manual checks and failures; complete the historical backfill rather than treating this initial index as exhaustive.

## M1-01–M1-07 historical index — backfill incomplete

These are source navigation pointers, **not a new verification of merged stories or complete criterion/evidence mappings**. Test methods contain or construct their fixtures. PR/evidence links, full fixture setup, criterion mappings and remaining manual expectations still need backfill from each story's accepted contract/review. Unknown checks are not assumed passed.

| Story | Reliably located source/test pointers | Backfill gap |
|---|---|---|
| [M1-01](https://github.com/redrossa/neomd/issues/1), Finder opening | `NeoMDTests/DocumentOpeningTests.swift`, `MarkdownFileTypeTests.swift`, `MarkdownTextDecoderTests.swift` | Exact Finder/default-app fixture and UI selector not established in this documentation pass; manual expectations/evidence unknown pending contract backfill. |
| [M1-02](https://github.com/redrossa/neomd/issues/2), native opening | `NeoMDUITests/DocumentOpeningUITests.swift`: `testMenuAndCommandOInvokeTheNativeOpenPanel`, `testPickerCancellationPreservesScrolledReaderAndSourceFile`, `testDroppingOnNoFileWindowOpensTheDocument`, `testDroppingDistinctFileOnReaderOpensAnotherWindowAndPreservesOriginal` | Full lifecycle/Dock scenarios and evidence not backfilled. |
| [M1-03](https://github.com/redrossa/neomd/issues/3), document identity | Same file: `testNativeTitleLocationsDistinguishDocumentsWithTheSameFilename`, `testReopeningSameDocumentThroughNativePathsRefocusesExistingReader`, `testCommandWClosesReaderWithoutPromptOrSourceChange` | Full actions, manual checks and review evidence not backfilled. |
| [M1-04](https://github.com/redrossa/neomd/issues/4), reading window | `NeoMDUITests/DocumentReaderLayoutUITests.swift`: `testReadingColumnReflowsAndKeepsCodeOverflowLocal`, `testCodeOverflowSupportsKeyboardScrollingAndTextSelection`, `testResizeAndFullScreenPreserveMiddleAndTallReadingPositions`, `testLargeLazyDocumentResizeRoundTripPreservesExactMiddlePassage` | Full regression matrix not backfilled; intermittent hover hang remains below. |
| [M1-05](https://github.com/redrossa/neomd/issues/5), appearance | `NeoMDUITests/AppearanceUITests.swift`: `testOpeningInLightAndDarkRendersCoherentDocumentContent`, `testSystemAppearanceChangeUpdatesTheOpenDocumentInPlace`, `testSelectionStaysLegibleInLightAndDark`, `testLinksAreUnderlinedByDefaultInLightAndDark`; `docs/appearance-ui-tests.md` | Broader empty/error/cleanup evidence and criterion mapping not backfilled. |
| [M1-06](https://github.com/redrossa/neomd/issues/6), structure | `NeoMDUITests/DocumentReaderLayoutUITests.swift`: `testDocumentStructureAndEmphasis`; `NeoMDTests/MarkdownBlockRendererTests.swift` | Full source fixture, appearance/manual expectations and evidence not backfilled. |
| [M1-07](https://github.com/redrossa/neomd/issues/7), quotations/code | Same UI file: `testNestedQuotationsAndHighlightedCodeInBothAppearances`, `testInlineCodeBoundaryAndAllSpaceTextInEveryContext`, `testNestedQuoteLeafReadingPointSurvivesLazyResize`; `NeoMDTests/QuotationsAndCodeTests.swift`, `CodeSyntaxHighlighterTests.swift` | Full mappings/evidence not backfilled; combine nested reading-position and overflow scenarios at final verification. |

For a listed XCTest method, the exact selector form is `-only-testing:NeoMDUITests/<file's class name>/<method name>` (class names match the file stems above). Consult the source before running; this index does not claim each pointer alone covers its entire story.

## M1-08 — See checklist progress without changing it

[Issue #8](https://github.com/redrossa/neomd/issues/8) · [PR #32](https://github.com/redrossa/neomd/pull/32) · [accepted plan](https://github.com/redrossa/neomd/issues/8#issuecomment-5565174074) · [preservation amendment](https://github.com/redrossa/neomd/issues/8#issuecomment-5565179665).

Implementation base: `739a1034802abe217437b3cb2b235395cc02756a`. Source/test evidence head: `7199650b5507e4584d784d83f080e0ecf05a4f31`. This catalog addition changes documentation only; independent review must reconcile the new PR head. No review approval is claimed here.

### Durable fixture and setup

Canonical fixture: `NeoMDUITests/DocumentReaderLayoutUITests.swift`, `testReadOnlyTaskStatesInBothAppearances`. Actual Markdown (backslashes below are literal; preserve spaces inside code spans):

```markdown
- [ ] Pending
  - [x] Nested done
- [x] Ship **v1** with [docs](https://example.com) and `code`

5. [x] Ordered done
6. [ ] Ordered pending

> - [ ] Quoted pending

- \[ \] escaped
- `[ ]` code marker
- [ ] `  x  `
- [x] `   `
```

`setUpWithError` creates `NeoMD-Layout-<UUID>` under the test process's temporary directory. `makeDocument` writes UTF-8 `tasks.md` and sets modification time to Unix `1700000000`; `snapshot` captures exact bytes and modification date before interaction. Teardown terminates the test app and removes its fixture directory. For a manual reproduction, save the content above to a disposable local `tasks.md`, record bytes and mtime before opening, and compare again after all actions.

The test launches with `-ApplePersistenceIgnoreState YES`, separately sets `NEOMD_UI_TEST_APPEARANCE` to `Light` and `Dark`, and uses `NSWorkspace` to open the file in the running test app without relaunching. **These are app appearance overrides, not a live system appearance-change test.** This targeted test does not require the host appearance controller; the final full suite does.

```sh
# Focused task parser/presentation cases (7 methods, 32 expanded cases).
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-DerivedData \
  -only-testing:NeoMDTests/TaskListRenderingTests test

# Exact story UI selector.
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-DerivedData \
  -only-testing:NeoMDUITests/DocumentReaderLayoutUITests/testReadOnlyTaskStatesInBothAppearances test

# Optional isolated host-controller invocation of the same selector.
NEOMD_RESULT_BUNDLE=/tmp/neomd-m1-08-targeted.xcresult \
  Scripts/appearance-test-host.sh \
  -only-testing:NeoMDUITests/DocumentReaderLayoutUITests/testReadOnlyTaskStatesInBothAppearances
```

### Actions and criterion-linked expectations

1. **Distinct accessible checked/unchecked states, including nesting:** in each appearance, resize to 900×900. Expect eight `MarkdownTaskMarker-` elements, exposed as images, with parent `MarkdownTaskMarker-0` labelled “Incomplete task” and nested `MarkdownTaskMarker-2` labelled “Completed task”. Expect zero checkboxes and zero task-marker buttons. Nested marker X offset is 22pt ±1. Resize to 480×760 and require the same offset and unchanged labels. Screenshot expectations: distinguish empty/checkmarked shapes without relying solely on color; retain visible ordered `5.`/`6.` and quoted/nested structure at both widths.
2. **Click/Space never changes status or file:** capture all marker labels; click the incomplete marker and press Space, click the nested complete marker and press Space, then click the plain-text beginning of the description and press Space. Labels must remain unchanged after interactions and resizing. Compare exact file bytes and modification date with the initial snapshot in each appearance. The description click deliberately avoids activating its preserved link. This is read-only interaction coverage, not a claim that Space never scrolls.
3. **Descriptions retain links and inline formatting:** expect `Ship v1 with docs and code` and exact literal descriptions `[ ] escaped`, `[ ] code marker`, ` x ` and three spaces. Inspect screenshot attachments “Read-only tasks and ordered ordinals — Light/Dark” and “Read-only tasks narrow — Light/Dark” for bold, underlined link and monospaced code. `TaskListRenderingTests.attributedDescriptionsSurvive` independently asserts strong/emphasis/code attributes, the exact `https://example.com` link, default link underline and subscript style. External navigation is not exercised by this task test.

Additional canonical unit fixtures live directly in `NeoMDTests/TaskListRenderingTests.swift`: `basicMarkers` covers `[ ]`, `[x]`, `[X]` and bullet variants; `hierarchyIdentityAndOrdinals` covers three nesting levels, IDs/lazy ancestry, ordered starts and quote-contained tasks; `literalLookalikes` covers 16 escaped/code/formatted/linked/non-list/invalid-separator negatives; `onlyFirstDirectParagraphOwnsMarker` keeps later paragraphs literal; `separatorsPreserveExactDescriptionScalars` covers empty tasks, tabs/spaces and exact code scalars; `softContinuationSurvives` preserves a soft break. These are the stable sources for reproducing edge cases, not temporary artifacts.

Accessibility scope: AX image labels/roles and shape distinctions are covered; a complete VoiceOver reading-order session, keyboard traversal/selection across mixed tasks, live system switching while reading a task-heavy document, and long-document/full-screen cross-story behavior remain final-milestone combined checks, not newly claimed passes or extra story criteria.

### Existing evidence and unresolved risk

The pre-amendment PR evidence records, on unchanged source at the head above:

- Debug build passed (`/tmp/neomd-8-build.log`); full unit run passed, 76 methods / 101 expanded runs, no failures/skips (`/tmp/neomd-8-unit.xcresult`).
- Assisted full suite passed, exit 0: 109 methods / 135 runs, no failures/skips, including 34 XCTest UI runs and the task test (`/tmp/neomd-8-full-assisted.xcresult`, `/tmp/neomd-8-full-assisted.log`). This historical full pass remains evidence; the amendment does not erase it or require repeating the comprehensive suite per story.
- Four task screenshots were reported inspected (Light/Dark, wide/narrow), exported to `/tmp/neomd-8-final-attachments/`. These temporary artifacts may expire; regenerate via the durable selector above. This documentation-only update did not rerun tests or reinspect screenshots.
- Earlier full runs failed/timed out. A combined regression retry passed nested resize but intermittently hung at `testReadingColumnReflowsAndKeepsCodeOverflowLocal`, `proseElement.hover()` after horizontal code scrolling; a later targeted retry and full assisted suite passed without source/test changes. Historical logs: `/tmp/neomd-8-full.log`, `/tmp/neomd-8-regression-retry.log`, `/tmp/neomd-8-regression-unlocked.log`, `/tmp/neomd-8-overflow-diagnosis.xcresult`.

**The hover hang is unresolved: root cause is not established, and it is not claimed fixed or proven pre-existing.** Retain it for final cross-story verification/investigation, including horizontal code scrolling → offscreen prose hover and nested quote/reading-position resize combinations. If independent review establishes a current-story regression or failed required criterion, it still blocks this story. A subsequent pass is not proof of a fix. No source/test workaround or weakened assertion accompanies this policy amendment.

## M1-09 — Internal links and universal parser (implemented; awaiting independent review)

[Issue #9](https://github.com/redrossa/neomd/issues/9) · [baseline plan](https://github.com/redrossa/neomd/issues/9#issuecomment-5570562309) · [R2 universal parser](https://github.com/redrossa/neomd/issues/9#issuecomment-5571540097) · [binding corrections](https://github.com/redrossa/neomd/issues/9#issuecomment-5571540353) · [collision-safe allocation amendment](https://github.com/redrossa/neomd/issues/9#issuecomment-5571705057).

[PR #33](https://github.com/redrossa/neomd/pull/33). Accepted base: `2daa9e6b65c661578c091c2ef47ed333ba081094`; branch `story/9-in-document-links`. Validated implementation commit: `23d78b756394a240345df9a87a167f11fd39d8b0`; the following documentation-only commit records this PR link. The current PR head is the independent review target. **Implementation validation passed; independent acceptance is pending.**

### Durable fixtures and setup

Canonical reproducible fixture: `NeoMDUITests/DocumentLinkNavigationUITests.swift`, `fixture`. It contains the exact Markdown and expands `spacer(section)` into 18 numbered prose paragraphs per section. It covers the top link index, duplicate/formatted/Unicode headings, standalone and inline custom anchors, three reachable footnotes (one repeated, one structured, one quote-defined), an unused note, escaped and fenced reference syntax, and a quoted read-only task. `testEOFAnchorAndAnchorOnlyDocument` separately constructs 50 numbered paragraphs followed by a true trailing anchor, then an anchor-only document; this distinguishes actual EOF from an authored anchor followed by rendered notes.

`setUpWithError` writes UTF-8 `links.md` in an owned `NeoMD-Links-<UUID>` temporary directory and sets mtime to Unix `1700000000`. `open` launches with `-ApplePersistenceIgnoreState YES`, uses the per-app Light/Dark override, and opens through `NSWorkspace` in the running app. Teardown terminates that app, compares exact source bytes/mtime and removes only its fixture directory. No host appearance preference changes. UI runs must be serialized.

### Exact selectors and expectations

Use this command prefix from the repository root, followed by the selector and `test`:

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -destination 'platform=macOS' -parallel-testing-enabled NO \
  -derivedDataPath /tmp/NeoMD-M1-09-DerivedData
```

| Criterion | Selector suffix (`-only-testing:NeoMDUITests/DocumentLinkNavigationUITests/…`) | Actions and expected outcome |
|---|---|---|
| C1 | `testHeadingLinksReachDuplicateFormattedAndUnicodeSections` | Click each index link; correct heading at the reading viewport top (10pt allowance for heading typography), correct nearby return link; return to top. |
| C2 | `testCustomAnchorsNavigateWithoutVisibleMarkup` | Standalone/inline anchors reach the intended heading/paragraph; no empty markup; end link reaches the note section following the authored anchor. |
| C2 | `testEOFAnchorAndAnchorOnlyDocument` | True trailing anchor reaches final paragraph/document end; anchor-only file shows the empty-document message without markup. |
| C3 | `testFootnoteReferencesAndReturnLinks` | Native reference click reaches notes; structured note/list remain present, unused note absent; repeated return reaches reference paragraph. |
| C4 | `testMissingDestinationKeepsDocumentUsable` | Notice appears without moving ordinary prose or opening dialogs; PageDown still works; notice expires. Native focus may shift a link's AX bounds by one point, so unchanged prose frames establish no scroll. |
| C5 | `testKeyboardFocusAndActivationOfInternalLinks` | Option-Tab focuses index; Right selects second link; Return activates; Escape returns to reading. Keyboard also selects a repeated reference and activates it with Space, cycles to the note's second return, and activates that return with Space. Repeat Light/Dark and capture focus screenshots. |

Every method checks bytes/mtime. The keyboard test attaches `Link keyboard focus — Light` and `Link keyboard focus — Dark`. Full VoiceOver, live system appearance switching, combined full-screen/resize/selection scenarios remain final-milestone checks. Screenshot existence is not yet a completed visual review.

Exact unit class selectors: `-only-testing:NeoMDTests/CMarkDocumentTests`, `CMarkParityTests`, `MarkdownAnchorsTests`, `MarkdownFootnotesTests`, `DocumentLinkResolverTests`, and `DocumentReaderLayoutTests` (repeat the same `-only-testing:NeoMDTests/` prefix for each). Existing renderer/task/code/theme suites remain required via `-only-testing:NeoMDTests`.

The additional required migration UI selectors are:

- `-only-testing:NeoMDUITests/DocumentReaderLayoutUITests/testDocumentStructureAndEmphasis`
- `-only-testing:NeoMDUITests/DocumentReaderLayoutUITests/testReadOnlyTaskStatesInBothAppearances`
- `-only-testing:NeoMDUITests/DocumentReaderLayoutUITests/testInlineCodeBoundaryAndAllSpaceTextInEveryContext`
- `-only-testing:NeoMDUITests/DocumentReaderLayoutUITests/testNestedQuotationsAndHighlightedCodeInBothAppearances`
- `-only-testing:NeoMDUITests/AppearanceUITests/testLinksAreUnderlinedByDefaultInLightAndDark`

### Final worker evidence

The final gate supersedes the historical failures below (retained for traceability). Native markers are zero-size, top-leading points only on actual anchor destinations plus the document root. Full-size background hosts interfered with ordinary list-text hit testing even with hit testing disabled; the focused structure/custom/footnote regression passed 3/3 after this repair (`/tmp/neomd-9-point-markers.xcresult`). Late navigation completion does not override newer keyboard focus. Named resize frames remain unchanged; diagnostic-only offset state and tracing were removed.

- Full units: **97 methods / 155 expanded runs passed**, no skips; `/tmp/neomd-9-final-units.xcresult` and final diagnostic-state cleanup rerun `/tmp/neomd-9-clean-units.xcresult`.
- Required serialized UI matrix: **11/11 passed**, no skips; `/tmp/neomd-9-final-ui.xcresult`: six story selectors plus the five migration selectors above. Final diagnostic-state cleanup rerun `/tmp/neomd-9-clean-ui.xcresult` also passed 11/11. Source-byte/mtime teardown checks passed.
- Staged `git diff --check` reports only preserved upstream/generated-header trailing whitespace and unified-patch context whitespace under `ThirdParty/cmark-gfm`; these authenticated bytes are intentionally not normalized. The non-vendored diff is whitespace-clean, and hash/reverse-patch verification passes.
- Explicit Debug build and offline vendoring: `/tmp/neomd-9-final-build.log`, `/tmp/neomd-9-final-vendor.log`, and final cleanup `...clean-build.log` / `...clean-vendor.log`, all passed.
- The unchanged concurrency test ran in both `/tmp/neomd-9-lock-probe1.xcresult` and `...probe2.xcresult`: five methods/nine expanded runs each, all passed (640 parses each, zero mismatches). [Approved correction](https://github.com/redrossa/neomd/issues/9#issuecomment-5573078799): private static lock around C parser creation/attachment/feed/finish; defer unlock before concurrent adaptation. Audit and simultaneous-parse throughput trade-off are documented in `ThirdParty/cmark-gfm/UPSTREAM.md`; cleanup/getters do not mutate shared classification tables, though string getters may allocate within their owned node.
- Actual final Light/Dark focus images inspected: `Link keyboard focus — Light` and `— Dark` in the final UI bundle (exported `BFAB199D-2601-4719-A20C-71CBF5839988.png`, `C6FA2589-21D6-44F7-AAFD-64C9D3818F14.png`). Readable underlined links, outline focus ring, selected-link treatment and normal task/code presentation are visible in both appearances. Keyboard activation and expected landing are proven by native events/assertions, not screenshots alone.
- Prior `/tmp/neomd-9-lock-ui.xcresult` was 8/11 (custom final-note hit check, structure list hit check, nested-code scroll failed). Isolation reproduced structure without a window interruption. This prompted the point-marker repair; these failures were not waived. Final 11/11 passes supersede them. Comprehensive unrelated UI, full VoiceOver and combined milestone E2E remain deferred.

### Historical development evidence (superseded by final gate)

- Offline vendoring verification passed: `Scripts/verify-cmark-vendoring.sh`; `/tmp/neomd-9-vendor-final.log`.
- Explicit Debug build passed: same project/scheme/destination/derived-data arguments above, `-configuration Debug build`; `/tmp/neomd-9-build-final.log`. Subsequent targeted test builds also compiled the navigation revisions.
- Full units passed: `-only-testing:NeoMDTests test`, `/tmp/neomd-9-units-final-r2.xcresult` and `.log`: **95 methods, 153 expanded runs, zero failures/skips**. This precedes the latest navigation-loop-only adjustment; rerun the final gate after repairs.
- Initial collision coverage verifies every generated reference/return URL against distinct intended block IDs under authored heading/custom collisions, later note headings, repeated `x` versus `x-2`, Unicode case identity and percent-containing labels. Allocation separately reserves occupied suffixes and later preferred names.
- Previous serialized story run `/tmp/neomd-9-links-ui-r2.xcresult`: **3 passed, 3 failed**; superseded by the native-bridge run below, not treated as acceptance.
- Native positioning revision approved at https://github.com/redrossa/neomd/issues/9#issuecomment-5572856406. `DocumentNavigationBridgeTests` constructs two independent NSWindows and vertical scrollers, checks exact native target alignment and isolation, rejects nested horizontal/cross-document targets, and verifies cancellation, replacement-safe unregister, stale generation rejection and weak cleanup. Run with `-only-testing:NeoMDTests/DocumentNavigationBridgeTests test`: **2 passed**, `/tmp/neomd-9-native-probe.xcresult` and `.log`. This synthetic AppKit probe does not prove SwiftUI interaction synchronization.
- Previous serialized six-method story run `/tmp/neomd-9-native-ui.xcresult`: **4 passed, 2 failed** (footnote hit testing and keyboard return selection). Actual-host diagnostics found SwiftUI marker wrappers participating in hit testing and a late navigation-completion focus assignment racing Tab. Markers now disable SwiftUI hit testing as well as NSView hit testing; completion preserves newer user focus. The two unchanged methods `testFootnoteReferencesAndReturnLinks` and `testKeyboardFocusAndActivationOfInternalLinks` passed in `/tmp/neomd-9-native-repair1.xcresult` and `/tmp/neomd-9-native-hitproof.xcresult` (two methods each, actual mouse return `↩ 2`, keyboard return selection/Space and expected source landing, Light/Dark). Corrected native hit-point traces show `SwiftUI.SelectionTextField` before/after clip correction, matching metrics, and both mouse/keyboard `#fnref-x-2` callbacks. Temporary bounded diagnostics were removed; no source-global hooks remain. Six-method final rerun, five migration methods and screenshot inspection remain outstanding.
- Latest explicit build and vendoring verification passed (`/tmp/neomd-9-build-native-final.log`, `/tmp/neomd-9-vendor-native-final.log`). Full units `/tmp/neomd-9-units-native-final.xcresult` failed one of 96 methods (153 expanded passes/one failure): `supportedExtensionsAndFlattenedPresentation` sometimes retains `~single~`. Pinned cmark `process_inlines` mutates global SPECIAL_CHARS/SKIP_CHARS per parse. New durable `CMarkParityTests.concurrentParsingPreservesExtensions` runs 16 detached workers × 40 parses of 200 `~single~` paragraphs; run `-only-testing:NeoMDTests/CMarkParityTests test`. `/tmp/neomd-9-parser-concurrency-probe2.xcresult` reproduced **68/640 malformed results**, blocking parser parity. A first method-selector command selected zero tests and is not evidence. Subsequently resolved by the approved parsing lock and repeated regression above.
- Earlier individual story methods passed during development, but neither those nor the native probe waive the latest UI failures. The integrated bridge replaces global frame correction and retains named-frame resize restoration.
- Existing `testDocumentStructureAndEmphasis` passed during migration (`/tmp/neomd-9-heading-structure-ui.log`). The other four migration UI gates and final exact-source reruns remain outstanding.
- Intentional compatibility: cmark soft/hard breaks inside link labels (approved D1); exact original ineligible footnote spelling (D4 snapshot patch); empty thematic-break model text (D2); parser-owned nested/empty task patch (D3). Real table layout and image presentation remain later stories; cells remain flattened and images retain alt text. Unsupported HTML remains literal, never executable.
- Deferred risks: historical hover hang remains unexplained, not fixed or proven unrelated; full VoiceOver and comprehensive combined E2E remain deferred. No milestone acceptance is claimed.

## M1-09 R3 — stack-safe lifecycle and compressed nesting (in progress)

[Approved R3 baseline](https://github.com/redrossa/neomd/issues/9#issuecomment-5574780958) · [binding approval](https://github.com/redrossa/neomd/issues/9#issuecomment-5574783050). This supersedes earlier implementation-complete claims only for the depth repair: PR33 still requires repaired-head validation and independent review. See [R3 architecture/status](m1-09-stack-safe-rendering.md) for step-by-step mapping and current artifacts. Working base remains `d5a687443f8c8c5dde3ab469d35fa98a75c4c142`; R3 changes are not yet committed.

### Reproducible fixtures and selected gates

- Actual quote fixture in `Tests/RenderLifecycle/RenderLifecycleTests.swift`: `String(repeating: "> ", count: depth) + "text\n"`, at 1/1000/50000. Expected exactly depth+1 contiguous preorder nodes, every quote retained, one paragraph `text`, all parent/child/root/subtree/first-last-leaf relationships exact. Methods cover synchronous/detached/main-actor release, barrier-proven cancelled discard, replacement/aliases and repeated independent snapshots.
- The same file's annotated fixture contains duplicate `Hello café` headings (one emphasized), an explicit heading link/custom anchor, quote/task/nested quote and reachable note. Expected heading/custom IDs 0/1/2, one incomplete task, two quotes, one footnote, and every generated reference resolving. Its synthetic mixed arena retains alternating quote/list containers and two distinct adjacent paragraph leaves.
- `NeoMDTests/MarkdownContainerLayoutTests.swift`: shallow quote→ordered task→footnote→paragraph has offsets [0,15,51,87], exact marker/text baseline equality, top-aligned footnote, no compression at 320/760. Nested lists assert −14pt adjustment and paragraph Y=[0,34,68]. Width 300 gives exactly B=120 for eight quotes (no compression), width299 activates compression without affecting separate shallow roots. Branching fixtures at 2k/20k/100k nodes assert ≤6N operations, every leaf readable horizontally, strict source/spatial order and no colliding rows. A 50k unary quote run has exactly one compressed depth caption after the ordinary-width prefix.
- `NeoMDTests/MarkdownContainerHostingTests.swift`: actual 50k quote source `String(repeating: "> ", count: 50000) + "retained [link](#target) <a id='target'></a>"`; separate 2k-node branching source arena. Owned native window/host checks every leaf's actual frame, draws, changes width320→760, replaces snapshot with empty content, removes/closes host, and checks weak release after main-runloop cleanup. These tests do not themselves prove native link activation or source file opening.

Run from the repository root, with fresh output paths outside it:

```sh
python3 Scripts/test-render-lifecycle.py --output /tmp/NeoMD-R3-lifecycle

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-R3-DerivedData -parallel-testing-enabled NO \
  -only-testing:NeoMDTests/MarkdownContainerLayoutTests test

# Each host method must run in its own invocation/bundle.
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-R3-DerivedData -parallel-testing-enabled NO \
  -only-testing:NeoMDTests/MarkdownContainerHostingTests/testDeepQuoteHostRelease \
  -resultBundlePath /tmp/NeoMD-R3-host-quote.xcresult test
# Repeat separately with testDeepBranchingHostRelease and a fresh result bundle.
```

The lifecycle script's test-only environment selects depth; no production CLI flags are added. The intentional negative-control method is expected to fail and is explicitly selected by the orchestrator; do not run all methods of the isolated scheme directly and call that negative failure a product defect.

### Criteria, appearance and deferred proof

C1/C2 depend on exact arena identity/anchors and unchanged native ownership/landing. C3 depends on retained note/return allocation, structured children and marker ownership. C4/C5 retain existing notice/native focus policy and require all six existing link UI methods above. The additional five migration UI methods remain unchanged required gates. New deep actual-file opening/interaction, native mouse/Return/Space, light/dark screenshots, resize/read-only bytes+mtime, stable marker registry across compression and selected mixed VoiceOver context checks are **not completed yet**. No new deep UI selector is claimed before that test exists.

Current passes: 21 process-isolated lifecycle cases plus correctly rejected negative control; 102 methods/162 expanded unit runs; one selected quote-host pass and one selected branching-host pass. Exact artifacts and their source-timing limits are recorded in the linked R3 status note.

Current blocking attempt `/tmp/neomd-r3-ui1.xcresult` failed **before behavior tests started**: XCTest timed out enabling automation mode. Its one reported failure is the runner, not one of the eleven selected methods. No production R3 appearance screenshots/native-event passes, full VoiceOver parity, completed implementation, or independent acceptance is claimed. Restore native UI automation and finish the above gates before commit/review handoff.

### Resumed R3 fixtures and unresolved native gate (2026-09-07)

Existing required preservation matrix now passes 11/11 (`/tmp/neomd-r3-resume-preservation.xcresult`), after a one-method successful automation probe. This does not complete R3.

New durable source: `DocumentLinkNavigationUITests.testDeepQuoteFileNavigationResizeAndReadOnly`. Generator is exactly 50,000 repetitions of `"> "`, then `<a id='deep'></a>Deep retained [Jump target](#target)`, 30 blank-separated `Deep spacer N.` paragraphs, `# Target`, `[Back deep](#deep)`, and 20 `Target spacer N.` paragraphs. The existing fixture helper writes this UTF-8 source to owned temporary `links.md`, preserving its snapshotted fixed mtime. Normal NSWorkspace document opening, no new app flags. Planned actions: Light/Dark; widths900→480→900 at height760; Command-Home before visible-link mouse dispatch; target heading at viewport top; backlink to deep paragraph; Option-Tab plus Return/Space; unchanged bytes/mtime. Passive exact-depth caption and horizontally contained positive AX glyph bounds are asserted (glyph width is not allocated column width). Source/column widths remain separately asserted in native-host/numeric tests.

Run with the existing serialized Xcode prefix and `-only-testing:NeoMDUITests/DocumentLinkNavigationUITests/testDeepQuoteFileNavigationResizeAndReadOnly -test-timeouts-enabled YES -maximum-test-execution-time-allowance 900 -resultBundlePath <fresh-path> test`. **Latest run fails**, `/tmp/neomd-r3-deep-ui4.xcresult`: event synthesis times out on Command-Home after the first narrow resize. Do not repeat blindly or present screenshots as a pass. The detailed R3 status note records three preceding test-development failures/corrections and the latest precise timing. Wide Light screenshot inspected: retained deep text/native underline/passive depth caption. Narrow screenshot has spacer content only following failed top action; no Dark/native-keyboard completion claimed. Full mixed-marker/AX and selected VoiceOver checks are still missing.

New native selector `-only-testing:NeoMDTests/MarkdownContainerHostingTests/testLiveMarkerIdentityAcrossCompressionAndGenerations`: actual `"> " ×20 + "<a id='target'></a>retained [link](#target)"`, target ID20, real native vertical scroller/production marker. Widths760→320→760→320→760 cross compression on/off; the destination object must be identical. Three generation replacements must re-register, stale/pending requests remain unresolved, empty replacement unregisters, and final weak markers/owner clear. **1/1 passed**, `/tmp/neomd-r3-live-registry1.xcresult`. Run this separately like the other native-host methods. Existing cross-owner/horizontal rejection tests are retained, not replaced.

No production changes in this continuation; all existing R3 work remains uncommitted. Final full repaired-source gates and independent acceptance are pending. In particular, numeric linear work does not prove native responsiveness with 50k SwiftUI quote entries; investigate measured host work and the plan's batched Canvas/path requirement before further deep UI retries.

### Batched decoration follow-up — current passing deep gate

The preceding failures are retained history. The same50,000-quote actual-file generator and native deep selector now pass. Before each mouse round trip, the test uses `scroll.scroll(byDeltaX: 0, deltaY: 10000)` to reach the top through a real reader scroll interaction; Command-Home was not a reliable top-navigation precondition with native Text focus. Visibility and exact destination/backlink assertions remain, as do Light/Dark900→480→900, Option-Tab/Return/Space and bytes/mtime checks. This does not add a Command-Home product requirement or waive native keyboard activation.

Production quote drawing now uses one passive native path surface per root, not50k SwiftUI Rectangles/AX entries. The scalar arena and quote segment count remain complete. `MarkdownContainerLayoutTests.unaryGroupingDoesNotCrossMixedContainerOrLeafBoundary` additionally asserts exact sparse view IDs0…8,50000 at320pt: eight preserved ordinary quote AX contexts, one compressed-run caption and the stable native leaf. Existing numeric baseline/spacing tests and≤6N branching bound remain substantive (now include sparse selection work). Host selectors above print separate initial/draw/resize timings, with the same actual-frame and weak-release checks; observed initial/resize improved15.767s/2.804s→0.1874s/0.2230s. Not a universal timing promise or proof of the old event timeout's cause.

Current evidence:
- `/tmp/neomd-r3-batch-final-matrix.xcresult`:117 methods/177 expanded runs, no failures/skips; all units including three native hosts and12 targeted UI methods (eleven preservation plus deep).
- `/tmp/neomd-r3-batch-lifecycle/results.json`:21 separate actual-source lifetime cases and correctly rejected negative control.
- Explicit Debug build and offline verifier passed: `/tmp/neomd-r3-batch-build.log`, `/tmp/neomd-r3-batch-vendor.log`.
- Inspected final deep480pt Light/Dark screenshots in `/tmp/neomd-r3-batch-final-attachments`: `2B9170E5-9B9C-453B-BB49-70F5479FE274.png`, `47AD20D1-A207-4A85-82EB-A513487A40A0.png`; retained text/link and exact depth caption readable, rules stay out of content. Shallow Light quote/code `C7197B07-5332-4044-A375-B4D9F4E5C299.png` inspected too.
- Bounded owned-app profile `/tmp/neomd-r3-batch-deep2.sample.txt` collected using explicit `/usr/bin/sample`; it is post-change evidence, not a pre/post cost attribution.

Mixed actual-file marker/context/AX order and selected manual VoiceOver verification remain required and unperformed. No full VoiceOver parity, final repair acceptance, commit/push or milestone acceptance is claimed. Detailed failures, fixes and plan mapping are in `docs/m1-09-stack-safe-rendering.md`.

### Actual mixed-file fixture — automated AX pass, manual VoiceOver blocked

Durable generator and selector: `NeoMDUITests/DocumentLinkNavigationUITests/testMixedContainerFileAXOrderAndNativeActions`. The method joins explicit source lines with newlines: `quote = "> " ×40`; quoted `7. [x] Mixed completed [Mixed jump](#mixed-target)`, quoted blank line, quoted three-space continuation `Mixed adjacent continuation.`, quoted blank, quoted `8. [ ] Mixed pending.`; outside `# Mixed target`, `Mixed reference[^m].`; `[^m]: Mixed note first.`, then four-space-indented40-quote `- [ ] Mixed note task.`, quoted blank/continuation `Mixed note adjacent.`, and four-space `Mixed note last.`. The test source is authoritative for whitespace. Existing helper writes owned temporary `links.md`, opens normally with NSWorkspace, and checks fixed mtime and exact UTF-8 bytes before cleanup.

Run the usual serialized NeoMD Xcode test command with `-only-testing:NeoMDUITests/DocumentLinkNavigationUITests/testMixedContainerFileAXOrderAndNativeActions -resultBundlePath <fresh-path>`. Light/Dark,900→480 at height760; all eight unique leaf values remain in depth-first immediate-child AX tree order and increasing spatial order. Markers40/43/89 occur once with one completed/two incomplete states, before the associated leaf. Two explicit depth41 list rows and a quote depth-range caption remain; footnote1 has native accessible context. Visual expectation:7/check,8/unchecked, note ordinal1 and note unchecked marker exactly once; continuation paragraphs must not repeat markers; shallow note-last exits compressed context.

`/tmp/neomd-r3-mixed3.xcresult`:1/1 passed, no skips/failures. Full AX trees and Light/Dark wide/narrow screenshots retained in exported attachments. Inspected narrow Light `93C52780-CA3B-4DA5-BD73-2588AB6C556B.png`, narrow Dark `A92A755C-97C2-464A-9FA8-B1BF2B6C6D71.png`, wide Light `0A16C644-CCAF-4363-9791-F13F2FA16EEB.png`. Native mouse heading/ref/return events execute and content remains usable, but the compact fixture fits the viewport: these assertions are not independent distant-landing proof or mixed keyboard evidence. Existing deep/preservation methods cover distant mouse/Return/Space navigation. Prior `mixed1/2` failed new-test query assumptions (flat descendant indexes versus tree order; Text value versus label), not production fixes; see status note for restart caveat.

Maps to R3 steps4–6 (actual source, mixed layout/context, native leaves/AX and immutability), C1/C3 (heading/reference/return controls) and C5 supporting native AX exposure. Does not replace original criteria tests. Production app source is unchanged; only the new UI test and documentation changed in this continuation. Final combined gate refresh and full repair diff review remain pending.

Selected manual VoiceOver check is **blocked/unverified**. System VoiceOver launched after its welcome panel, but bounded `last phrase` AppleScript queries timed out and AX/caption queries exposed no output; no audio-observation tool is available in this worker session. No scripting/security permission was changed. VoiceOver was turned off again and verified absent, restoring the initial off state. A human or already-authorized observable session must check actual spoken leaf/context order, no duplicate content, task/ordinal announcements and context exit on this fixture. AX tree assertions are not a substitute. No commit/push or acceptance claimed.

### Final R3 gates and user-approved human speech deferral

[User amendment5576035842](https://github.com/redrossa/neomd/issues/9#issuecomment-5576035842) supersedes the preceding worker VoiceOver blocker **only**: actual spoken order, absence of duplicated speech and context exit remain unverified and required at final human milestone acceptance. No known defect or original criterion is waived. Automated AX order/markers do not prove spoken output.

Final refreshed evidence: `/tmp/neomd-r3-final-matrix.xcresult` passes118 methods/178 expanded runs (102 Swift Testing methods/162 runs,3 native hosts,13 UI), no failures/skips/restarts. Existing eleven preservation methods plus actual deep and mixed selectors all pass in one serialized invocation with full units. Explicit Debug build and vendoring pass in `...final-build.log`/`...final-vendor.log`; `...final-lifecycle2/results.json` passes21 separate cases plus rejected negative control. Three host methods also pass separately in `...final-<method>.xcresult`. Full repair review/diff-check and primary Swift diagnostics pass. Detailed commands, plan/criterion mapping and inspected final image filenames: `docs/m1-09-stack-safe-rendering.md`.

Lifecycle fixture refinement: `testMixedAndAnnotated` now releases all annotated snapshots inside explicit scopes before its completion sentinel. It asserts real40-level mixed input, separately annotated quote input at1/1000/50000 with exact IDs/custom/reference/return identities and payloads, and synthetic mixed depth at each selected value. `...final-lifecycle` preserves a failed experimental assumption that cmark recognizes a list at arbitrary quote depth; it emits literal list text at1000. No parser policy was altered. `...final-lifecycle2` is the complete passing final matrix.

The compact mixed file covers AX/tree/spatial/marker identity and native controls, not independent distant landing. The combined deep/preservation matrix supplies distant mouse/ref/return and native Return/Space evidence across widths/appearances. This meets the existing criterion set without duplicating every action in the compact fixture.

#### Required human milestone acceptance: selected mixed VoiceOver speech

Status: **NOT PERFORMED / NOT VERIFIED; user-deferred, not waived.** Owner: user conducting combined milestone acceptance. Record tested app commit, macOS/VoiceOver version, appearance/width, spoken sequence and any defects. Do not close the milestone merely because automated tests pass.

1. Reproduce the exact mixed source with this Python3 snippet in an owned temporary directory (do not overwrite an existing document):

   ```python
   from pathlib import Path
   import hashlib, tempfile
   folder = Path(tempfile.mkdtemp(prefix="NeoMD-human-voiceover-"))
   q = "> " * 40
   lines = [q + "7. [x] Mixed completed [Mixed jump](#mixed-target)", q,
            q + "   Mixed adjacent continuation.", q, q + "8. [ ] Mixed pending.",
            "", "# Mixed target", "", "Mixed reference[^m].", "",
            "[^m]: Mixed note first.", "", "    " + q + "- [ ] Mixed note task.",
            "    " + q, "    " + q + "  Mixed note adjacent.", "", "    Mixed note last."]
   file = folder / "mixed-voiceover.md"
   file.write_bytes("\n".join(lines).encode("utf-8"))
   print(file, hashlib.sha256(file.read_bytes()).hexdigest(), file.stat().st_mtime_ns)
   ```

2. Open that printed path using NeoMD File > Open or Finder Open With. Record initial VoiceOver/appearance state; use the normal local VoiceOver shortcut, without enabling scripting/security permissions. Have a human hear the output (or use already-authorized accessible captions).
3. At900pt then480pt window width, use VoiceOver navigation into and through the reader. Verify the quote compression range/reason is understandable; the completed task context precedes `Mixed completed Mixed jump`; `Mixed adjacent continuation` follows once without a repeated task marker; the incomplete item precedes `Mixed pending`; exiting that quote region does not carry its context into `Mixed target`/`Mixed reference`.
4. Continue through footnote1: `Mixed note first`, its quote/task context, `Mixed note task`, `Mixed note adjacent`, then the shallow `Mixed note last` and native return link. Verify each leaf is spoken once in source order, task state/footnote ordinal are understandable, adjacent content does not repeat markers/context, and the shallow final paragraph is no longer described as inside the compressed task/quote. Native link-role announcements are not themselves duplicate leaf speech. Record the actual wording, not just AX identifiers.
5. Repeat selected traversal after a width change and in the other appearance. Activate the native heading/reference/return links using VoiceOver's normal action and confirm continued usability; existing automated tests remain the distant-landing/Return/Space evidence.
6. Restore the prior VoiceOver/appearance state. Recheck SHA256 and `st_mtime_ns` against step1; both must be unchanged. Record any failure as a defect for user-agreed milestone handling; the deferral does not authorize ignoring it. Remove only the owned temporary fixture when done.

### R3-H1 native mixed host/storage release (review correction)

[Finding5576201960](https://github.com/redrossa/neomd/pull/33#issuecomment-5576201960) identified missing approved step6 coverage, not a reproduced leak. Earlier three-host evidence above checked quotes/paragraphs and weak host only; it did not prove mixed presentation-storage teardown. The new coverage supplements, not replaces, actual-file UI and21 isolated model cases.

Reproducible fixture lives in `MarkdownContainerHostingTests.testMixedContainerHostRelease`: build `q = "> "` repeated20, then the method's exact `lines` array. Unlike the40-depth UI fixture,20 crosses from compressed at320 to ordinary at760. It includes `q + "7. [x] Mixed completed [jump](#target)"`, a quoted adjacent paragraph and incomplete item8; `# Target`, `Reference[^m].`, and note `m` with first paragraph,20 quotes containing an incomplete task/adjacent paragraph, then shallow final paragraph. Assertions verify40 quotes, exact7./8./bullet markers, task states, one footnote, nine exact leaf strings and anchor. No file is written by this native host fixture.

Actions/expected outcomes (R3 steps6/7; C1–C3/C5 ownership/control protection):
1. Host **all actual document roots**, including footnote, with production `MarkdownContainerView`; no copied renderer/test-only semantic type.
2. At320×1600, assert all nine mixed leaves are present, ≥192pt wide, and vertically inside the native bitmap. Traverse actual AppKit descendants to weakly observe one production `QuotePathView` and its real `MarkdownQuoteDecoration` per root; require real nonempty quote bars.
3. Draw, resize to760 with fewer compressed records, draw again, and assert observed surface/storage pairs survive. Deep quote and branching cases use the same ownership checks, retaining their original sizes/depths.
4. Replace with empty, remove/close/release; let the async snapshot-owning exercise scope return. Permit bounded main-runloop cleanup (up to40×50ms suspensions). Assert nil host and **each actual** surface/storage before the completion sentinel. An app kill is not this assertion.
5. Retain existing live registry resize/generation/unresolved lookup/cleanup checks as the fourth separately invoked method.

Run each method separately, serially from the repository root:
```sh
for method in testMixedContainerHostRelease testDeepQuoteHostRelease testDeepBranchingHostRelease testLiveMarkerIdentityAcrossCompressionAndGenerations; do
  xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' \
    -derivedDataPath /tmp/NeoMD-DerivedData -parallel-testing-enabled NO \
    -only-testing:NeoMDTests/MarkdownContainerHostingTests/$method \
    -resultBundlePath /tmp/neomd-h1-$method.xcresult test \
    > /tmp/neomd-h1-$method.log 2>&1 || exit $?
done
```
Use fresh artifact paths on reruns. Inspect each xcresult summary: require actual passedTests=1, failedTests=0, skippedTests=0, exit0 and no restart/crash in logs; require `NATIVE_HOST_RELEASED` for the three lifecycle methods. All four final invocations pass those checks. First mixed probe `/tmp/neomd-h1-mixed1.xcresult` also passed; the final run additionally asserts all mixed leaves lie inside the bitmap and captures one surface per root.

Final corrected-source refresh: `/tmp/neomd-h1-lifecycle/results.json`21/21 plus rejected negative control; `...h1-vendor.log`/`...h1-build.log` pass; `...h1-matrix.xcresult`119 methods/179 expanded runs (102 Swift Testing/162 +4 host/registry + unchanged13 UI), zero failures/skips/restarts. Full units preserve negative bridge ownership/cleanup tests. LSP/session diagnostics and repair diff-check clear. Selected refreshed deep/mixed Light/Dark images inspected; full filenames/mapping in `docs/m1-09-stack-safe-rendering.md`.

No production, UI selection, read-only policy or VoiceOver setting changed. Only manual spoken order/duplicate speech/context exit remains unverified and user-deferred as above; this host gate is **not deferred**. Worker correction is ready for independent exact-head review, not acceptance or merge.

## M1-10 — Follow links to nearby files (worker validated; milestone acceptance pending)

[Issue #10](https://github.com/redrossa/neomd/issues/10) · [PR #34](https://github.com/redrossa/neomd/pull/34) · accepted plan: see the triage comment linked from the issue (2026-09-08) · approved decisions: [user decisions comment](https://github.com/redrossa/neomd/issues/10#issuecomment-5577686581).

Implementation base: `7fb3c4a5a4273a50bf28f53038d350d2e2d457b9`. No reviewer stage applies (user policy change recorded on the issue); the worker self-validates and the coordinator merges on evidence. Targeted units/UI, M1-09 regressions, a separate app build and native plain-build grant checks passed as detailed below. Selectors marked *existing* are on the accepted base; the M1-10 selectors are implemented. [Validation amendments](https://github.com/redrossa/neomd/issues/10#issuecomment-5578156000) preserve the baseline and record harness/fixture corrections.

### Durable fixture

Checked-in path: `docs/fixtures/m1-10-nearby-links/` (source document `docs/guide.md`; see its `README-fixture.md` for the link → target → marker table). `NearbyFileLinkUITests.fixtureTree()` reads all 13 authored durable files relative to the test source, then setup writes their exact bytes inside `FileManager.default.temporaryDirectory`. This avoids a divergent inline copy. The UI test asserts on-disk bytes and modification dates of every fixture file are unchanged at teardown.

Meaningful details: `docs/my notes.md` (space), `docs/café.md` (NFC `é`; linked both as `caf%C3%A9.md` and `café.md`), `docs/100%.md` (malformed-escape edge, not a criterion), `docs/root-target.md` versus the decoy `root-target.md` at the fixture root (the decoy prints `ROOT POLICY WRONG`), `docs/private.md` (made `chmod 000` by the test/manual step; restored before removal), `docs/notes.txt`, `docs/img/diagram.png` (1×1 PNG), and deliberately absent `docs/missing.md`, `docs/sub/absent/nowhere.md`, `docs/img/absent.png`.

### Setup, isolation and cleanup

- Copy the fixture to a fresh temporary folder; never open the repository copy (app launches and `chmod` must not touch version-controlled files).
- Opening route: same `NSWorkspace.shared.open(_:withApplicationAt:configuration:)` route as `DocumentLinkNavigationUITests.open` (*existing*), launched with `-ApplePersistenceIgnoreState YES` and `NEOMD_UI_TEST_APPEARANCE`.
- Host state: the "other local type" check launches the host's default application for `.txt` (`NSWorkspace.shared.urlForApplication(toOpen:)`, usually TextEdit). Record whether that app was running before the test; terminate it afterwards only if it was not. Close any of its windows the test created. Skip (not pass) the check if no default application exists.
- Sandbox caveat: `xcodebuild … test` products carry an Xcode-injected `com.apple.security.temporary-exception.files.absolute-path.read-only` for `/` (verified 2026-09-08 by `codesign -d --entitlements` on `/tmp/NeoMD-DerivedData/Build/Products/Debug/NeoMD.app`; plain `build` products carry only `files.user-selected.read-only`). Therefore UI tests **cannot** observe sandbox denial; the inaccessible branch is exercised with POSIX `chmod 000`, and the real sandbox grant is a manual check with a plain build (below).
- Cleanup: `chmod 644` the private file, remove the temporary folder, terminate NeoMD.

### Selectors and commands (implemented)

Unit (Swift Testing): `NeoMDTests/DocumentLinkResolverTests/localPathsResolveFromTheDocumentFolder`, `NeoMDTests/LocalFileAccessTests/probeDistinguishesReadableMissingAndUnreadable`, `NeoMDTests/MarkdownBlockRendererTests/localImagesUseTheDocumentPathPolicy`, `NeoMDTests/DocumentOpeningTests/sectionRequestsAreKeyedByCanonicalURLAndConsumedOnce`.

UI (XCTest): `NeoMDUITests/NearbyFileLinkUITests/testRelativePathsOpenNearbyMarkdownAtRequestedSections`, `…/testMissingAndInaccessibleTargetsKeepTheCurrentDocument`, `…/testOtherLocalTypesOpenInTheDefaultApplicationOnlyAfterActivation`, `…/testAlreadyOpenTargetRefocusesAndNavigates`.

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-DerivedData -only-testing:NeoMDTests \
  -resultBundlePath /tmp/neomd-10-units.xcresult test
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-DerivedData -parallel-testing-enabled NO \
  -only-testing:NeoMDUITests/NearbyFileLinkUITests \
  -only-testing:NeoMDUITests/DocumentLinkNavigationUITests \
  -resultBundlePath /tmp/neomd-10-ui.xcresult test
```

Use fresh result-bundle paths on reruns. `DocumentLinkNavigationUITests` (*existing*) is included as the M1-09 regression gate because the reader's link handling changes.

### Criteria → actions → expected outcomes → evidence

| Criterion | Actions (from `docs/guide.md`) | Expected outcome | Planned evidence |
|---|---|---|---|
| 1. Resolve `./`, `../`, spaces, encoded names from the document folder | Click `Intro second section`, `Parent readme`, `Deep target`, `Spaces bracketed`, `Spaces encoded`, `Encoded Unicode`, `Literal Unicode`, `Root target` | Windows titled `intro.md`, `README.md`, `deep.md`, `my notes.md`, `café.md`, `root-target.md` appear; `root-target.md` shows `ROOT POLICY CORRECT`, never `ROOT POLICY WRONG`; both spellings of the spaces/Unicode links open the same file (one window, M1-03 identity) | Unit resolver table + `testRelativePathsOpenNearbyMarkdownAtRequestedSections` |
| 2. Linked Markdown opens in NeoMD at the requested section | Same clicks with fragments; also keyboard: Option-Tab to the block, Right-arrow to `Deep target`, Return | Target window front; `SECOND SECTION LANDED`, `PARENT SECTION LANDED`, `DEEP TARGET LANDED` are at the top of their scroll views (`assertAtTop` pattern, *existing*); `Plain sibling` opens `intro.md` at `INTRO START`; source window keeps its scroll position | Same UI test; keyboard branch in the same method |
| 3. Other local types open in the appropriate app after an explicit click | Render the document and wait 3 s (no launch); click `Plain text notes`; separately click `Linked image` | No foreign app launches on render or hover; after the click the default app for `.txt` becomes running/frontmost and NeoMD opens no new window; the PNG link opens the default image viewer (or is skipped with a recorded reason if none) | `testOtherLocalTypesOpenInTheDefaultApplicationOnlyAfterActivation` |
| 4. Missing/inaccessible targets: readable message, current document retained | Click `Missing file`, `Missing nested`, `Private file` (chmod 000), `Missing section` | `DocumentLinkNotice` (*existing*) shows a message naming the link (e.g. `Couldn’t find “missing.md” next to this document.` / `NeoMD doesn’t have permission to read “private.md”.`), no new window, no alert; guide scroll position unchanged; the notice auto-dismisses. For `Private file`, an `NSOpenPanel` folder request (title/prompt *proposed*: message mentioning read-only access for this session, prompt `Allow Access`) appears first; the test presses Cancel and then expects the permission notice. `Missing section` opens `intro.md` and that window shows the existing `No “nowhere” destination in this document` notice | `testMissingAndInaccessibleTargetsKeepTheCurrentDocument` + `LocalFileAccessTests` |
| 5. Same path policy for images | Render `docs/guide.md` | Rendered `imageURL` runs for `img/diagram.png` equal `file://<fixture>/docs/img/diagram.png` (unit-level via `MarkdownBlockRenderer.render(from:documentURL:)`, *proposed*); remote image URLs untouched; the linked image's link opens the PNG through criterion 3 | `localImagesUseTheDocumentPathPolicy`; the linked-image click in the criterion-3 method. Image display itself is M1-12 |

Already-open target: click `Same document section` in `guide.md` → the same window stays (no duplicate window), scrolls to `GUIDE END`; then open `intro.md` via `Plain sibling`, return to `guide.md`, click `Intro second section` → the existing `intro.md` window comes to front and lands on `SECOND SECTION LANDED` (`testAlreadyOpenTargetRefocusesAndNavigates`).

### Appearance, keyboard, accessibility, read-only

- Light/Dark: run the section-navigation method under both `NEOMD_UI_TEST_APPEARANCE` values and attach a screenshot of the notice in each.
- Keyboard: Option-Tab / arrows / Return / Space activation reaches local targets exactly like internal links; Escape unchanged.
- AX: the notice is announced (`AccessibilityNotification.Announcement`, *existing* pattern); link labels unchanged. VoiceOver spoken order is not covered here (deferred as in M1-09).
- Read-only: bytes and modification dates of every fixture file, including targets opened in NeoMD and the `.txt` opened elsewhere, are unchanged at teardown; no bookmark data is written (assert `UserDefaults.standard.dictionaryRepresentation()` for the app's suite contains no key introduced by this story — *proposed*; simplest is that the implementation stores no bookmarks at all and the worker states so).
- Not covered by automation: real sandbox denial and a successful folder grant (see manual), width/full-screen (unchanged reader layout), VoiceOver.

### Manual checks (plain build, real sandbox; execution scope below)

Build with `xcodebuild … build` (not `test`) and confirm `codesign -d --entitlements :- /tmp/NeoMD-DerivedData/Build/Products/Debug/NeoMD.app` lists **no** `absolute-path.read-only` exception. Copy the fixture to `~/Documents/NeoMD-M1-10/` (a location outside the app container), open `docs/guide.md` from Finder, then:

1. Click `Intro second section` → an explicit native folder panel appears preselecting `docs/`; Cancel → permission notice, guide retained, no new window.
2. Click again → panel → choose `docs/` → `intro.md` opens at `SECOND SECTION LANDED`. Subsequent clicks inside `docs/` (`Spaces encoded`, `Plain text notes`, `Linked image`) open without another panel; `Plain text notes` opens in the default app.
3. Click `Parent readme` → panel again (target is outside the granted folder) → choose the fixture root → `README.md` opens at `PARENT SECTION LANDED`.
4. Reserve a never-opened sibling (for example, omit `Spaces encoded` in step 2). Quit and relaunch NeoMD, open `guide.md`, click that sibling → the panel appears again (no persisted folder grant). Previously opened individual documents may remain accessible through macOS recent-document machinery; they do not establish whether a folder grant persisted.
5. Confirm `Console.app` shows no sandbox violation from NeoMD during steps 2–3, and that `Missing file` yields the missing message, not the permission message, in a granted folder.

### Actual commands/results

Worker runtime verified `openai-codex/gpt-6-astra`, low. Branch `story/10-nearby-file-links` from the accepted base. All final gates used the source included in this story commit; subsequent edits only record evidence. Baseline: https://github.com/redrossa/neomd/issues/10#issuecomment-5577784954; binding refinements: https://github.com/redrossa/neomd/issues/10#issuecomment-5577793780.

- Targeted units passed 33 tests, zero failures/skips: `/tmp/neomd-10-cheap2.xcresult`, log `/tmp/neomd-10-cheap2.log`. Command: `xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-M1-10-DerivedData -parallel-testing-enabled NO -only-testing:NeoMDTests/DocumentLinkResolverTests -only-testing:NeoMDTests/LocalFileAccessTests -only-testing:NeoMDTests/DocumentOpeningTests -only-testing:NeoMDTests/MarkdownBlockRendererTests -resultBundlePath /tmp/neomd-10-cheap2.xcresult test`. Includes denied-parent/nonexistent-child classification, unreadable file, FIFO nonblocking rejection, decoded percent/Unicode/delimiter fragments, stale cleanup/no-fragment supersession and actual image URLs. First compile attempt `cheap1` exposed a nested Testing macro expansion in a new test; splitting the nested `#require` corrected it before this pass.
- Native opening probe **blocked before story actions**, twice: `/tmp/neomd-10-ui-probe1.xcresult` and `...probe2.xcresult`, corresponding `.log` files. Same command prefix, selecting only `-only-testing:NeoMDUITests/NearbyFileLinkUITests/testAlreadyOpenTargetRefocusesAndNavigates`. NeoMD launches, then `NSWorkspace.shared.open` reports Cocoa260 / LaunchServices-43 (`fnfErr`) for the running application's existing `/private/tmp/NeoMD-M1-10-DerivedData/Build/Products/Debug/NeoMD.app`. Second attempt explicitly matches M1-09's activates/no-substitution/no-new-instance configuration. Executable existence was confirmed. Each run failed1, passed0; these are not behavior passes. Resolved by bounded diagnosis: the fixture helper incorrectly sliced `/private/tmp` enumeration URLs using a `/tmp` root length, creating the source at the wrong relative path. The existing M1-09 opening method passed on the same bundle. Relative enumeration plus explicit fixture/source assertions fixed the helper; no host registration/security change was needed.
- New native selectors retain the four authored names above. Section landing asserts the **heading** at viewport top, with the authored marker body below it; no claim that a paragraph below a heading lands at the exact same coordinate. The no-fragment already-open case preserves the current reading position per M1-03; new-window plain sibling opens at the beginning.
- Final nearby UI gate: `xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-M1-10-DerivedData -resultBundlePath /tmp/neomd-10-nearby-final2.xcresult -only-testing:NeoMDUITests/NearbyFileLinkUITests test`: **4 passed, 0 failed/skipped**. Log: `/tmp/neomd-10-nearby-final2.log`. This repeats the passing `nearby-final` gate after removing one redundant final blank line from triage's `docs/sub/deep.md` fixture for `git diff --check`; all other authored fixture bytes are preserved. Earlier class run exposed the duplicate Touch Bar Cancel selector and reached the command timeout; the fixed selector targets `open-panel/CancelButton`. Final run completed normally. Light/Dark notice screenshots exported to `/tmp/neomd-10-final-attachments`; inspected Light missing and Dark permission notices: readable, source retained, no clipping.
- Broader gate: same command prefix/data path, `-resultBundlePath /tmp/neomd-10-regression.xcresult -only-testing:NeoMDTests -only-testing:NeoMDUITests/DocumentLinkNavigationUITests test`: **119 tests passed (111 unit + 8 UI; 179 parameterized executions), 0 failed/skipped**. Log `/tmp/neomd-10-regression.log`.
- Plain build: `xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-M1-10-Plain build`: passed, log `/tmp/neomd-10-plain-build.log`. `codesign -d --entitlements :-` confirmed sandbox + user-selected read-only, **no** XCTest absolute-path exception.
- Actual plain-build native checks used a fresh fixture copy under `~/Documents/`, opened through the explicitly selected built app, with PID-scoped System Events inspection and physical CGEvent clicks (not XCTest injection). Cancel showed `NeoMD doesn’t have permission to read “intro.md”.`, guide only. Choosing an unrelated sibling folder produced the same notice and no dispatch. Choosing `docs` opened `intro.md` at the second section; choosing Parent readme prompted again, and granting the fixture root opened `README.md` at its parent section. Normal process termination/relaunch: the never-opened `my notes.md` prompted again, proving no retained folder grant. The originally specified already-open `intro.md` relaunch check did not prompt; see the explicit fixture correction above. Source bytes matched all 13 originals after manual checks; UI teardown additionally verifies all mtimes. Both owned plain processes terminated; unrelated PR25 NeoMD remained untouched.
- Primary LSP diagnostics clean. No bookmark/default persistence or signing/sandbox changes. Supplemental manual external-app checks under a plain grant, Console inspection, and VoiceOver remain unrun for final milestone verification; automated explicit external-app activation passed. Window-only plain screenshot capture was unavailable, so native AX/window/position evidence supports grant checks; this is not a screenshot claim. Full combined E2E and business acceptance remain pending.

### Deferred and cross-story

- Image display and image permission/missing-image fallback: M1-12 must consume the resolved `imageURL` and reuse the access probe and folder-grant session; not verified here.
- Web links keep today's behavior (`.external` → system action) until M1-11.
- Final-milestone sweep: combine nearby-file navigation with resize restoration, Light/Dark switching and multiple windows (M1-03/M1-04) in one session; verify the notice never overlaps the M1-09 notice queue.
- Risk: LaunchServices default-app variance across hosts for `.txt`/`.png`; the test derives the expected app from `urlForApplication(toOpen:)` rather than hard-coding TextEdit/Preview.

## Future story entry template

Copy and complete in every subsequent story PR; do not replace prior entries.

### M1-XX — Title

- Issue / PR / accepted plan / agreed revision links:
- Implementation base and exact evidence head; independent review status:
- Durable fixture content or checked-in path **and symbol**, including meaningful whitespace/encoding:
- Setup: fixture creation, opening route, host permissions/controller, isolation, cleanup:
- Exact unit and native UI `-only-testing` selectors and reproducible commands:
- Each approved criterion → actions → observable expected outcome → test/manual evidence:
- Applicable Light/Dark, width/full-screen, keyboard, AX/VoiceOver, links/selection, exact source bytes and mtime checks; explicitly state what is not covered:
- Actual commands/results, failures/skips, result bundles and screenshot names (temporary evidence supplements, never replaces, durable fixtures):
- Deferred combined scenarios, known unresolved risks and missing backfill; do not claim them fixed or accepted:
