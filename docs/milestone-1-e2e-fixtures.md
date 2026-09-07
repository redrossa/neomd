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

Accepted base: `2daa9e6b65c661578c091c2ef47ed333ba081094`; branch `story/9-in-document-links`. The PR head identifies the implementation under review. **Implementation validation passed; independent acceptance is pending.**

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
