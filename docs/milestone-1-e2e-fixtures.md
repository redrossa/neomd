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
