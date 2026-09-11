# Current milestone fixture authority — M1-DAG-001

#15 is completed via PR #54; its native/visual/AX criteria remain unverified. The adopted [dependency plan](milestone-1-dependency-plan.md) governs parallel #16–24 triage/implementation, documented holds and narrow catalog integration leases. #14 remains deferred/open. No reviewer or UI/E2E/manual scripted interactions, prototypes or event/host substitutes. Later gates are Debug build and inspected relevant non-interaction units only. Triage stages unique per-story entries with hashes; do not replace this catalog from stale snapshots. Preserve all entries and #36/#38 failures/deferrals. Combined business acceptance remains user-owned. Historical authority statements below are superseded for scheduling, not rewritten as passing evidence.

## M1-19 / #19 — compare information in tables

[Issue #19](https://github.com/redrossa/neomd/issues/19) · [complete criteria/validation map](m1-19-validation.md) · [inert table packet](fixtures/m1-19-tables/README-fixture.md).

Triage **ACCEPTED implementation readiness**, exact base `acc932318bda21a9cafde3e2ea53d612d1bcbe5a`, verified openai-codex/gpt-6-astra/high. Source is unchanged from the adopted DAG base by documentation-only PR #55. Table parsing exists but rows/headers/cells are flattened and empty cells lost; new scope is flat owned table/header/alignment with attributed cell leaves, bounded local overflow and real native table/header AX associations. YAML metadata is separate, not table proof. No dependency on #22 public size controls or unmerged #16 selection architecture; #16's broader selection proposal remains blocked/unapproved. #19's cell address/payload/projection is a data adapter boundary only. Coordinate narrow native conversion/range/navigation seams rather than inventing a whole-story dependency.

Fixture packet covers four alignments, inline/cue/image/link/footnote preservation, missing/excess/empty cells, header-only/duplicate/empty headers, hidden comments, parser-normalized escaped pipes/code spaces, Unicode/line endings, literal controls and nested metadata/task/quote/alert/footnote contexts. Two wide tables expose independent overflow with prose sentinels. No app/test/prototype/interactions were run by triage. Later worker gates are Debug build plus the inspected exact non-interaction allowlist; whole NeoMDTests and native host/event substitutes are not allowed.

Worker evidence: **UNRUN at triage**; record actual exact head, commands, nonzero tests/failures/skips and artifact corrections in `m1-19-validation.md`. All native/visual/AX/keyboard/selection/resize/large-size/read-only interaction evidence remains **DEFERRED/UNRUN**, not passed by parser/geometry/conversion tests. Preserve #14/#36/#38 deferrals and every historical catalog entry. Successor #21/#22 readiness requires #19 merge and completion records; final native and business acceptance remains user-owned.

# Historical milestone fixture authority — M1-15

Stories #1–13 and priorities #40–43/#48/#50/#52 are completed. The user renewed sequential **#15–24** implementation authorization, explicitly skipping **#14, still entirely deferred/open**. [Canonical milestone order](https://github.com/redrossa/neomd/milestone/1) controls sequencing; #15 is next. No reviewer. Later gates are Debug build and relevant NON-INTERACTION units only; **no UI/E2E/manual scripted interactions or prototypes**. Historical commands and old “only/next/paused” statements below are retained records/future recipes, not current permission or validation. #36 full-reflow failure/defer and #38 cue C5 unchecked/deferred status remain unchanged; neither is fixed or passed by this story. Combined business acceptance stays user-owned.

## M1-15 / #15 — intended content, comments and YAML metadata

[Issue #15](https://github.com/redrossa/neomd/issues/15) · [table clarification](https://github.com/redrossa/neomd/issues/15#issuecomment-5628747670) · [D1 offline libyaml approval](https://github.com/redrossa/neomd/issues/15#issuecomment-5628830891) · [D2 boundary/recovery approval](https://github.com/redrossa/neomd/issues/15#issuecomment-5628889673).

Triage base `f0bd08806013ae8cb4ac994676b30bbe19dc19f5`; Astra/high verified. **ACCEPTED for implementation readiness, not implemented or passed behavior.** [Concrete plan/source evidence](m1-15-content-plan.md), [all seven criteria and non-interaction selector allowlist](m1-15-validation.md), and [inert fixture packet/future human recipe](fixtures/m1-15-content/README-fixture.md) are triage-owned. Worker installs authenticated staging, supplies actual tests/corrections and records exact-head evidence. No app, test, prototype, UI or interaction was run by triage.

The new packet has ordinary/nested YAML tables, aliases/tags/structured keys, malformed literal recovery, BOM/CRLF/CR bytes, true HTML comments and escaped/code/attribute/rawtext controls, and independent JSON boundary/semantic/comment/resource recipes. `metadata.md` adds original-line alerts, heading/custom/footnote anchors, cues/tasks and distinct adjacent local image occurrences after metadata. `nearby.md` is local; `absent.png` is deliberately missing. No network fixture, executable test script or arbitrary HTML execution is needed. This is a metadata-specific native table, not early #19 GFM table implementation. Delimited scalar and empty roots follow the explicit D2 precedence; unclosed input is ordinary Markdown and closed invalid/over-limit input is lossless non-executing literal recovery, not a successful table pass.

All #15 native table appearance/reflow/scale/selection, actual AX/VoiceOver reading order, link/image behavior, no-auto-launch and interacted bytes/mtime observations remain **DEFERRED/UNRUN**, not passed by source inspection or future pure model units. Future recipe requires renewed authorization and user-owned final testing. Preserve existing deferred evidence and do not close the milestone from implementation completion.

Worker evidence slot: **UNRUN at triage**. Record actual PR/source SHA, Debug command/result, exact existing/new unit selectors with nonzero pass/failure/skip counts and fresh external logs/xcresults in `m1-15-validation.md`; append a concise summary here without rewriting history.

The complete original catalog begins below, retained byte-for-byte from the triage base, including its title and historical authority statements.

# Milestone 1 cumulative E2E fixture catalog

## M1-P7 / #52 — source-relative Command-click window placement

The [approved published window-cascade pivot](milestone-1-window-cascade-pivot.md) is next after completed #50 / PR #51 at `918cfa40f9fdb7323400021b3a06b11f1ff8cf69`. **Only #52 is authorized; #14 is entirely deferred and #15–24 remain paused even after #52.** #50 routing is implemented; its unconditional `window.center()` does not implement the requested source-relative placement. Earlier claims of completed placement are incorrect.

The triage-owned [inert geometry packet and deferred final-testing recipe](fixtures/m1-p7-window-cascade/README-fixture.md) reuses the unchanged #50 content fixtures and adds full-frame numeric vectors. Oracles cover a small source-relative down/right shift (24 points is an engineering choice), source capture before async work, unequal source/new sizes and title-bar-inclusive bounds, current source-screen visibleFrame, menu bar/Dock, all edges/corners, negative/nonzero display coordinates, oversized windows and deterministic removed-screen/source-closure fallback. Source/other readers must not move/resize; #50 independent fragments/failure behavior and ordinary/Cmd-N/Open/drop routes stay unchanged.

[Criterion mapping, source trace, concrete scope and allowed unit selectors](m1-p7-window-cascade-validation.md) records **ACCEPTED for implementation**, not passed behavior. Triage ran no builds, executable tests, prototypes or interactions. Later worker gates are Debug build and relevant non-interaction units only; no reviewer, UI/E2E, window-host probes, real/synthetic events, AX actions, pickers or manual scripted interactions. **All native/visual/physical-display/interaction checks remain DEFERRED/UNRUN**, not passed by geometry/model tests. The linked recipe is future user-owned testing, not current authorization. Preserve #36/#38 and all prior evidence/deferrals; combined milestone acceptance stays user-owned.

The #50 entry immediately below and all earlier catalog content are retained verbatim as historical triage/evidence records. Their old “next/only authorized” wording is superseded by this header and the canonical milestone order, not authorization to rerun or advance.

## M1-P6 / #50 — Command-click local Markdown into an additional reader

The [approved Command-click pivot](milestone-1-command-click-pivot.md) is next after completed #48 / PR #49 at `71cdd6acef777526f16f4020bc54fb273060b9a0`. **Only #50 is authorized; #14 is entirely deferred and #15–24 remain paused even after #50.** This supersedes only #43's Command-N-only additional-reader restriction. Ordinary links still replace the source reader; Command-click gets a distinct additional reader even when its destination is already open. Other readers and their fragments/state must remain untouched.

Triage's [inert fixture packet](fixtures/m1-p6-command-click/README-fixture.md) and [criterion mapping / validation allowlist](m1-p6-command-click-validation.md) cover native text and linked-image destinations, whitespace-only links, relative/encoded/leading-slash/self paths, already-open destinations, per-reader fragments, failed acquisition and unchanged external/non-Markdown/internal routing. All interaction checks are **DEFERRED/UNRUN**, not passed. Triage performed source/docs research only. Worker must supply exact-head Debug build and explicitly scoped non-interaction unit evidence; no reviewer, UI/E2E, scripted interaction, real events, AX press, NSWorkspace launch, picker or key-window host test is authorized. Do not treat model units as native-window proof. Historical evidence/commands below remain preserved; #36/#38 and user-owned combined milestone acceptance are unchanged.

## M1-P5 / #48 — quiet document focus (historical triage and worker evidence)

The [approved focus-outline pivot](milestone-1-focus-outline-pivot.md) is completed as PR #49; [worker evidence](m1-p5-focus-validation.md) records a passing Debug build and 28 scoped non-interaction units. Native/visual outcomes remain deferred/unverified. Historical interaction commands below are preserved evidence/recipes, not present authorization. The following source-triage paragraphs retain the original base and investigation limits.

The triage-owned [fixture packet](fixtures/m1-p5-focus-outlines/README-fixture.md) supplies wrapping link blocks and heading/list/task/quote/alert/footnote cases, short/wide code, linked/unlinked local images and an optional disposable permission-control image. A separate link-free document isolates viewport/native-focus hypotheses from the confirmed custom link-block overlay. No network or external application is required. See [criterion mapping, API containment, allowlist and worker evidence fields](m1-p5-focus-validation.md).

At base `8704fb2225fdd9eb373fcc30d4655e6f7eb9f398`, source triage confirms the explicit enclosing link-block rectangle and separately identifies the focusable reader/code scrollers; it does **not** reproduce or diagnose the reported whole-window native effect. Ancestor SwiftUI effect suppression can disable child controls, so child-environment preservation is an implementation gate, not an assumption.

All #48 visual, Tab/traversal/activation, scrolling, window-wide, light/dark, selection/cursor, ordinary control/Retry/drop, VoiceOver and interaction bytes/mtime observations are **DEFERRED/UNRUN**, not passed. Worker must record exact-head build and selected-unit evidence without promoting model/environment checks to native behavior proof. The approved change supersedes the historical enclosing block-focus indicator only; selected-link styling and keyboard/accessibility semantics remain. Prior screenshots showing that outline are historical evidence, not the new desired appearance. Preserve #36/#38 failures and every prior catalog entry. Final combined acceptance remains user-owned; do not close the milestone or auto-resume paused stories.

## M1-P4 / #43 — same-window native navigation

The triage-owned [M1-P4 fixture catalog](m1-p4-fixture-catalog.md) and [approved native ownership plan](m1-p4-native-navigation-plan.md) define the inert packet and future native oracles. Command-N picker and batch rejection are approved. [Worker evidence](m1-p4-validation.md) records non-interaction unit selectors/builds and exclusions. All #43 physical window/menu/Finder/drop/selection/OS-prompt behavior is **DEFERRED/UNRUN**, not passed. The latest no-reviewer/build-and-units-only instruction supersedes the historical interaction mandate below; preserve previous evidence, failures and #36/#38 deferrals. Final milestone acceptance remains user-owned.

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

## M1-11 — Open web references (worker-validated; milestone acceptance pending)

[Issue #11](https://github.com/redrossa/neomd/issues/11) · PR: linked from the issue · [baseline plan](https://github.com/redrossa/neomd/issues/11#issuecomment-5578397508) · revisions: [keyboard selection oracle](https://github.com/redrossa/neomd/issues/11#issuecomment-5578543964), [keyboard dispatch](https://github.com/redrossa/neomd/issues/11#issuecomment-5578594417), [user-approved investigation](https://github.com/redrossa/neomd/issues/11#issuecomment-5579017450), [approved background attachment](https://github.com/redrossa/neomd/issues/11#issuecomment-5579096053).

Implementation base: `ced176677ec9cb1d00bdb29242f5940fb9136625`. Exact evidence head is recorded in the story PR; final commands below ran against that unchanged source/test tree before commit. No reviewer stage; the worker self-validates and the coordinator merges on evidence. The authored scenarios below are now implemented except the explicitly deferred manual checks.

### Durable fixture

Checked-in path: `docs/fixtures/m1-11-web-links/` — source `web-links.md`, sibling `nearby.md` (only so the M1-10 link resolves), and `README-fixture.md` with the link → form → destination table. Meaningful details: full/collapsed/shortcut reference definitions at the end of the file; a bare `www.` autolink whose destination gains `http://`; a two-link paragraph whose second URL contains `&`; links inside a heading, list item and quotation; a link-free paragraph for the native-menu check; 30 filler paragraphs so `Far link` (`http://127.0.0.1:1/neomd-m1-11-far`, connection-refused, no network dependence) sits below the first screen with the `FAR END.` marker after it. Actual loader: `WebLinkUITests.setUpWithError()` copies the folder relative to the test source; it also includes `keyboard-links.md` for the approved keyboard oracle.

### Setup, isolation and cleanup

- Copy the fixture to `FileManager.default.temporaryDirectory`; never open the repository copy. Opening route, launch arguments and `NEOMD_UI_TEST_APPEARANCE` as in `NearbyFileLinkUITests.open` (*existing*).
- Default browser: derive from `NSWorkspace.shared.urlForApplication(toOpen: URL("https://example.com/")!)`; record its running PIDs before each launch-sensitive step. Terminate it afterwards only if it was not running before; if it was, its new tab/window is tolerated host state and must be recorded, not cleaned by force.
- Pasteboard: save all item representations before Copy Link/selection tests and restore in `defer` (not merely the plain string). An externally killed test cannot execute this cleanup; see interrupted-run evidence below.
- Cleanup: remove the temporary folder, terminate NeoMD, assert fixture bytes and modification dates unchanged.

### Selectors and commands

Unit (Swift Testing): `NeoMDTests/MarkdownWebLinksTests/…` — link forms produce exact link runs; web URLs resolve `.external` with a file `documentURL`; `MarkdownLinkMenu` entry order/titles.

UI (XCTest): `NeoMDUITests/WebLinkUITests/testWebLinkFormsAreLinksAndOpeningLaunchesNothing`, `…/testActivatingWebLinkOpensDefaultBrowserAndKeepsReadingPosition`, `…/testContextualMenuRevealsDestinationWithoutOpening`.

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-DerivedData -only-testing:NeoMDTests \
  -resultBundlePath /tmp/neomd-11-units.xcresult test
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-DerivedData -parallel-testing-enabled NO \
  -only-testing:NeoMDUITests/WebLinkUITests \
  -only-testing:NeoMDUITests/DocumentLinkNavigationUITests \
  -only-testing:NeoMDUITests/NearbyFileLinkUITests \
  -resultBundlePath /tmp/neomd-11-ui.xcresult test
```

`DocumentLinkNavigationUITests` (M1-09) and `NearbyFileLinkUITests` (M1-10) are regression gates because `MarkdownBlockView` gains a background menu attachment on each authored-link-bearing leaf. Additional actual selectors: `NeoMDTests/MarkdownLinkAttachmentTests`, `NeoMDUITests/WebLinkUITests/testKeyboardWebLinkOpensDefaultBrowserAndKeepsReadingPosition`, and `NeoMDUITests/WebLinkUITests/testNativeSelectionInLinkBearingParagraphStillCopiesText`.

### Criteria → actions → expected outcomes → evidence

| Criterion | Actions (from `web-links.md`) | Expected outcome | Planned evidence |
|---|---|---|---|
| 1. Labeled, reference-style and ordinary web URLs recognizable/actionable | Open the fixture; query `window.links[...]` for `Example site`, `Spec reference`, `GFM spec`, `CommonMark`, `https://autolink.example/bare`, `https://angle.example/path`, `www.plain.example/site`, `Heading site`, `List site`, `Quote site` | Every element exists as an `AXLink` (link labels are what the base already exposes; a bare autolink's label is its URL), underlined and tinted in both appearances (M1-05 *existing* `testLinksAreUnderlinedByDefaultInLightAndDark` remains the visual gate) | Unit link-form test + `testWebLinkFormsAreLinksAndOpeningLaunchesNothing` |
| 2. HTTP(S) activation opens the default browser and preserves the reading position | Scroll until `Far link` is visible; record its frame and `FAR END.`; click it; separately open `keyboard-links.md`, Option-Tab/Right until `MarkdownLinkBlock-0` changes from `Link 1 of 2: First web link` to `Link 2 of 2: Keyboard web link`, then press Return (see fixture README) | The default browser becomes frontmost/running within 10 s; after `app.activate()` the link and marker frames are unchanged (±1 pt), `app.windows.count == 1`, no `DocumentLinkNotice` (*existing*) appears, no re-render | `testActivatingWebLinkOpensDefaultBrowserAndKeepsReadingPosition` |
| 3. Destination inspectable through a contextual menu, no permanent controls | Right-click `Example site`; right-click `First site`; right-click `Section link` and choose `Open Link`; right-click the link-free paragraph; `window.toolbars.count` | Menu shows a disabled `https://example.com/path?q=1` item plus `Open Link`/`Copy Link`; `Copy Link` puts exactly that string on the pasteboard and launches nothing; the two-link paragraph lists `https://first.example/` and `https://second.example/?x=1&y=2`; `Open Link` on the section link lands `Far section` at the top without any launch; the link-free paragraph still shows the native `Copy` menu and no `Copy Link`; Escape dismisses; the window has no toolbar and only its standard title-bar buttons | `testContextualMenuRevealsDestinationWithoutOpening` (+ menu-model unit test) |
| 4. Opening never auto-opens a browser or launched app | Open the fixture, wait 3 s after links appear | Browser PID set identical before/after; no foreign app frontmost; same holds while the contextual menu is open | `testWebLinkFormsAreLinksAndOpeningLaunchesNothing` (assertion shared with criterion 1) |

### Appearance, keyboard, accessibility, read-only

- Light/Dark: run the contextual-menu method under both `NEOMD_UI_TEST_APPEARANCE` values; attach a screenshot of the open menu in each.
- Keyboard: existing Option-Tab / arrows / Return / Space link flow (M1-09) must be unchanged; Return on a web link is covered by criterion 2. Keyboard invocation of the new menu is not a criterion and not planned.
- AX: `AXLink` + `AXURL` exposure is *existing*; the background attachment adds no accessibility element (`isAccessibilityElement = false`), so `MarkdownLinkBlock-<id>` labels/values (*existing*) are unchanged. VoiceOver spoken order remains deferred.
- Read-only: fixture bytes and modification dates unchanged at teardown; no preference keys written.
- Not covered by automation: physical (non-synthesized) right-click behaviour of the native menu, browser page content, VoiceOver.

### Manual checks (final milestone)

1. Open the fixture copy from Finder; hover a link (pointing-hand cursor), right-click it before any left-click: the menu shows the destination; `Copy Link` then paste into any text field yields the URL.
2. Click `Example site`: the default browser opens `https://example.com/path?q=1`; return to NeoMD: same scroll position, same window, no notice.
3. Select text across a link by dragging, Cmd-C: copied text is the selection (selection is not blocked by the attachment). Right-click the link-free paragraph: native text menu.
4. Confirm no toolbar/button appears in any appearance and that opening the document with no network launches nothing.

### Actual commands/results

Historical keyboard failure (corrected below). Revised native selector `NeoMDUITests/WebLinkUITests/testKeyboardWebLinkOpensDefaultBrowserAndKeepsReadingPosition` proves selection change, but its browser-frontmost assertion fails identically on the story and accepted base `ced176677ec9cb1d00bdb29242f5940fb9136625`. Evidence: `/tmp/neomd-11-revised-probe.{log,xcresult}` and `/tmp/neomd-11-base-keyboard.{log,xcresult}`. Both use `xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:NeoMDUITests/WebLinkUITests/testKeyboardWebLinkOpensDefaultBrowserAndKeepsReadingPosition test`, separate external DerivedData and fresh result bundles. The story run also executes `-only-testing:NeoMDTests/MarkdownWebLinksTests`: all 5 tests pass, including styled-label coalescing, separate authored links and generated-reference exclusion. Full required gates remain pending. Browser sessions existing before tests are preserved; pasteboard representations are restored by the menu test. Triage feasibility probe evidence (synthesized right-click on the built base app and a minimal SwiftUI app, 2026-09-08) is summarized in the accepted plan comment; it is research, not story evidence.

Dispatch correction approved at https://github.com/redrossa/neomd/issues/11#issuecomment-5578594417: a custom environment-key `OpenURLAction` does not receive the built-in openURL system fallback. `DocumentReaderView` now invokes its inherited `openURL` for external keyboard activation and returns `.handled`; local and keyboard-driven internal routing remain unchanged. The unchanged keyboard regression passes in `/tmp/neomd-11-dispatch-probe.xcresult` and the combined gate.

Historical overlay gate (superseded by the passing attachment gate below): Debug build passed (`/tmp/neomd-11-final-build.log`); all 112 unit tests passed (`/tmp/neomd-11-final-units.xcresult`); proactive diagnostics found no errors in five changed Swift files. Combined targeted UI (`WebLinkUITests`, `DocumentLinkNavigationUITests`, `NearbyFileLinkUITests`, serialized with the command flags above) is **15 passed, 1 failed, 0 skipped**, `/tmp/neomd-11-final-ui.xcresult`. All four WebLinkUITests and four NearbyFileLinkUITests pass. Remaining blocker: `DocumentLinkNavigationUITests/testHeadingLinksReachDuplicateFormattedAndUnicodeSections`, line 325, immediate `Back second.isHittable`. Reproduces in full-class rerun and isolation; accepted base passes and disabling only the new overlay passes. Therefore it is a current-story regression, not waived. A failure video shows the backlink visibly rendered, but accessibility hit availability fails. SwiftUI accessibility hiding and a nil NSView accessibility-hit override did not fix it; both probes were reverted. No PR is ready.

Inspected actual menu screenshots from the combined run: `EEBE7D39-CC36-4903-BF0E-3774828BCF45.png` (Light), `E899437E-13B8-4BB6-9BF3-E97C6245C6BE.png` (Dark), exported under `/tmp/neomd-11-final-ui-attachments`. Destination text fits, native disabled appearance is dim, Open Link/Copy Link are legible, document links remain underlined, no permanent controls. Physical input and full VoiceOver remain unrun.

### Approved attachment and final worker evidence

Baseline steps 1–2 and 4–7 remain; step 3 now uses `MarkdownLinkContextMenuAttachment` as a background whose NSView always returns nil from hitTest. A weak local event monitor owns only secondary/Control-clicks in its exact window, in both bounds and visibleRect, while visible and not sheet-blocked. Native controls are excluded; noneditable NSTextField backing selectable Text is permitted. Token ownership is idempotent and released on transition/dismantle/deallocation; dismantling clears action captures. No global monitor, private view discovery or swizzling. Menu contents/actions and keyboard dispatch correction are unchanged.

Final commands used the command prefix above with `-derivedDataPath /tmp/NeoMD-M1-11-Worker`, serial testing, and fresh bundles:
- Debug `build`: passed, `/tmp/neomd-11-accepted-build.log`.
- `-only-testing:NeoMDTests test`: **115 Swift Testing tests / 21 suites plus 4 XCTest hosting tests passed**, `/tmp/neomd-11-accepted-units.{log,xcresult}`. Three new attachment tests cover wrong-window/nonsecondary/outside/hidden/clipped/detached events, overlapping buttons/editable fields/scrollbars, native text backing, no hit/AX/focus target, reattachment, token ownership and action-capture release. The release test drains AppKit autoreleases before asserting view deallocation.
- All three targeted UI classes together: **17 passed, 0 failed, 0 skipped**, `/tmp/neomd-11-accepted-ui-complete.{log,xcresult}`. Includes unchanged Back-second hittability, M1-09/M1-10 regressions, all five web tests, fresh Light right-click/Dark Control-click, native plain menu, and drag-selection/Command-C of `Labeled` in a link-bearing paragraph.
- Primary LSP diagnostics: six changed Swift files clean. `git diff --check` passed.
- Inspected final Light `D7A545DF-439B-448A-89D6-56BC193E64DF.png` and Dark `BF41DB51-BFB4-48B7-A18E-A7FFE8EA6DE0.png` in `/tmp/neomd-11-accepted-attachments`: destination fits in native disabled styling, actions are readable, links remain underlined, no permanent controls.

The first final combined run (`/tmp/neomd-11-accepted-ui.xcresult`) was externally interrupted by a 600-second command timeout after 12 regression tests and the Far-link test passed, during the menu test. It is not a passing gate. The owned test app was terminated by its exact PID; PR25 app PID31721 remained alive. Interrupted teardown may leave a temporary fixture and its Copy Link clipboard value; the original clipboard representations from that killed process cannot be recovered. The complete rerun used a 1000-second budget and passed all teardown assertions, preserving its starting clipboard and existing browser sessions. Browser tabs opened in preexisting sessions are intentionally retained. This host-state limitation is not hidden by the subsequent pass.

Physical input, full VoiceOver, browser page content and combined milestone business acceptance remain unrun/deferred. No independent review is claimed.

### Deferred and cross-story

- Combine web-link activation with resize restoration, multiple windows and Light/Dark switching in the final sweep.
- M1-12 must not turn `imageURL` loading into an automatic launch; M1-16 selection/copy inside link-bearing blocks should be re-checked against the background attachment.
- Risk: default-browser variance across hosts (Safari vs Chrome tab behaviour); the test derives the browser from LaunchServices and never hard-codes it.

## M1-12 — View illustrations and screenshots

**Current execution record:** [M1-12 validation](m1-12-validation.md) contains actual selectors/results, plain-build setup, clipboard source-delta assessment and exact gate mapping. [Approved option B](https://github.com/redrossa/neomd/issues/12#issuecomment-5589023958) defers only the unchanged full reflow test under [#36](https://github.com/redrossa/neomd/issues/36): **BLOCKED/deferred, not passed**. The separate initial-margin/resize and repeated-image-scroll checks pass. Final milestone acceptance remains user-owned.

The triage plan and recovery history below are preserved as historical context; superseded proposed setup/oracles are not current execution instructions.

[Issue #12](https://github.com/redrossa/neomd/issues/12) · [PR #37](https://github.com/redrossa/neomd/pull/37) · [blocked assessment and feasibility probes](https://github.com/redrossa/neomd/issues/12#issuecomment-5579457860) · [approved decisions 1C/2A/3B/4/5](https://github.com/redrossa/neomd/issues/12#issuecomment-5584759706) · [accepted plan (baseline)](https://github.com/redrossa/neomd/issues/12#issuecomment-5584922066).

Implementation base: `265cd3e30fd94e859d6811705caff09ae48de132`. No reviewer stage; the worker self-validates with the gates below and the coordinator merges on evidence. Everything in this entry is **planned**; nothing below is executed evidence until the worker records results in "Actual commands/results". Selectors marked *existing* are on the accepted base; all `MarkdownImage…` identifiers and `DocumentImageUITests` are *proposed*.

### Durable fixture

Checked-in path: `docs/fixtures/m1-12-images/` — `illustrated.md` (local cases, markers `LOCAL START`/`LOCAL END`), `remote.md` (loopback template; the literal `PORT` is replaced by the test), `network.md` (real GitHub-hosted assets, manual only), `README-fixture.md` (file → bytes → expected table), and `img/` with deterministic solid-colour bitmaps: `wide.png` 1200×300 orange, `small.png` 64×32 green, `photo.jpg` 320×240 magenta, `anim.gif` 48×48 two frames (red then blue), `vector.svg` purple with an inert `<script>`, `sun.png` yellow / `moon.png` blue / `fallback.png` gray for `<picture>`, `private.png` (chmod 000 by the test), `not-an-image.png` (text bytes); `img/absent.png` is deliberately missing. Solid colours let a screenshot sample prove original colours in both appearances.

### Setup, isolation and cleanup

- Copy the folder to `FileManager.default.temporaryDirectory/NeoMD-Images-<UUID>`; never open the repository copy. Set a fixed modification date and record bytes/mtimes of every file (M1-10 pattern, *existing* in `NearbyFileLinkUITests`).
- Opening route, launch arguments (`-ApplePersistenceIgnoreState YES`), `NEOMD_UI_TEST_APPEARANCE`, and the DEBUG-only `NEOMD_UI_TEST_APPEARANCE_CHANNEL=1` distributed notification are all *existing* (`NearbyFileLinkUITests.open`, `AppearanceUITests`).
- Loopback server: the test process owns an `NWListener` on `127.0.0.1` with an ephemeral port serving `/wide.png` and `/not-an-image.png` immediately, `/slow.png` (bytes of `small.png`) after a 4 s delay, `/absent.png` as 404. Write `remote.md` with `PORT` substituted. No real network; the app's new outgoing-network entitlement is exercised by loopback. Stop the listener in teardown.
- Sandbox caveat (*existing*, M1-10): `xcodebuild … test` products carry an absolute-path read exception, so UI tests cannot observe real sandbox denial; `chmod 000 img/private.png` exercises the inaccessible branch and the folder panel; the real grant is the manual plain-build check.
- Cleanup: `chmod 644 img/private.png`, assert bytes/mtimes unchanged, remove the folder, terminate NeoMD, stop the listener. Assert no `UserDefaults` key is introduced (the implementation stores no bookmarks or image caches on disk).

### Historical selectors and commands (superseded)

**Do not run the historical broad UI command below on a shared clipboard.** Use the current nonclipboard commands/exclusions in [M1-12 validation](m1-12-validation.md); copy tests require a newly approved exclusive window.

Unit (Swift Testing, new `NeoMDTests/MarkdownImagesTests.swift`): `pictureBlockBecomesAnImageParagraph`, `pictureSourcesUseTheDocumentPathPolicy`, `pictureWithoutImgOrWithExtraContentStaysLiteral`, `emptyAltImagesKeepACarrierRun`, `appearanceSelectionPrefersMatchingSourceThenFallback`, `displaySizeClampsToWidthPreservingAspectRatio`, `loaderClassifiesMissingInaccessibleUndecodableAndUnavailable`, `loaderRefusesNonImageSchemesWithoutNetwork`. Existing image tests remain green: `MarkdownBlockRendererTests/localImagesUseTheDocumentPathPolicy`, `CMarkParityTests/supportedExtensionsAndFlattenedPresentation`.

UI (XCTest, new `NeoMDUITests/DocumentImageUITests.swift`): `testLocalImagesDisplayWithPreservedAspectRatioAndOriginalColors`, `testPictureSourcesFollowAppearanceAndUpdateLive`, `testUnavailableImagesShowAlternativeTextAndOfferFolderAccess`, `testRemoteImagesLoadWithoutBlockingText`.

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-DerivedData -resultBundlePath /tmp/neomd-12-build.xcresult build
codesign -d --entitlements :- /tmp/NeoMD-DerivedData/Build/Products/Debug/NeoMD.app   # expect network.client + user-selected read-only
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-DerivedData -only-testing:NeoMDTests \
  -resultBundlePath /tmp/neomd-12-units.xcresult test
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-DerivedData -parallel-testing-enabled NO \
  -only-testing:NeoMDUITests/DocumentImageUITests \
  -only-testing:NeoMDUITests/DocumentLinkNavigationUITests \
  -only-testing:NeoMDUITests/NearbyFileLinkUITests \
  -only-testing:NeoMDUITests/WebLinkUITests \
  -only-testing:NeoMDUITests/DocumentReaderLayoutUITests/testDocumentStructureAndEmphasis \
  -resultBundlePath /tmp/neomd-12-ui.xcresult test
```

The M1-09/M1-10/M1-11 classes and the M1-06 structure test are regression gates because paragraph rendering in `MarkdownBlockView` changes for every leaf. Use fresh result-bundle paths on reruns.

### Criteria → actions → expected outcomes → evidence

| Criterion | Actions | Expected outcome | Planned evidence |
|---|---|---|---|
| 1. Local and HTTP(S) images, aspect ratio, sensible sizing | Open `illustrated.md` (Light); locate `MarkdownImageBlock-<id>` for `Wide orange screenshot` and `Small green figure`; read their frames; sample the screenshot pixel at each frame centre; open `remote.md` | Wide block width equals the reading column width (±2 pt) and height equals width/4 (±2 pt); small block is 64×32 (±2 pt), not stretched; centre pixels are orange / green; JPEG, GIF (red first frame) and SVG (purple, window title never `SCRIPT EXECUTED`) blocks report value `Image displayed`; inline badge sentence keeps its words on either side of the images; the fast loopback `http://` image reports `Image displayed` | `displaySizeClampsToWidthPreservingAspectRatio` + `testLocalImagesDisplayWithPreservedAspectRatioAndOriginalColors` + `testRemoteImagesLoadWithoutBlockingText` |
| 2. Documented `<picture>` use case with appearance-specific sources and image fallback | Same document: the two `<picture>` blocks and the non-documented `<picture>` | The first picture is an image block (label = its alt) showing yellow in Light; the dark-only picture shows gray (fallback) in Light; the `<picture>` without `<img>` remains literal text (`window.staticTexts` containing `<picture>`), exactly as on the base | `pictureBlockBecomesAnImageParagraph`, `pictureWithoutImgOrWithExtraContentStaysLiteral`, `appearanceSelectionPrefersMatchingSourceThenFallback` + `testPictureSourcesFollowAppearanceAndUpdateLive` |
| 3. Original colours in both themes; appearance-specific sources switch live | Launch with `NEOMD_UI_TEST_APPEARANCE_CHANNEL=1`, Light; scroll so the wide image and the first picture are visible; record the `LOCAL END`/picture frames; post `Dark` on `io.neomd.uitest.setAppearance` (*existing*); wait ≤ 5 s; post `Light` | Wide image centre stays orange in Dark (no inversion/transform); first picture centre changes yellow → blue → yellow; dark-only picture gray → blue → gray; block frames unchanged (±1 pt, reading position kept); no re-render (marker element identity/frames unchanged) | `testPictureSourcesFollowAppearanceAndUpdateLive`; real system switch via `Scripts/appearance-test-host.sh` at final milestone |
| 4. Missing/inaccessible/offline → alternative text or quiet placeholder, non-blocking | `illustrated.md` unavailable section (after `chmod 000 img/private.png`); `remote.md` unreachable section | `Missing diagram`, `Private diagram`, `Corrupt diagram` are visible static texts; their blocks report `Image unavailable`; `Text after the unavailable images…` and `LOCAL END` exist; only the private block shows button `MarkdownImageAccessButton-<id>` (`Allow folder access`); clicking it presents the native folder panel (`open-panel`, *existing*); Cancel keeps the placeholder and text, no alert, no window; the empty-alt block shows a placeholder with no visible text and value `Image unavailable` when its file is later made unreadable (optional); refused, TLS-failed, 404 and text-bodied remote images all report `Image unavailable` within 10 s and `REMOTE END` is present throughout | `loaderClassifiesMissingInaccessibleUndecodableAndUnavailable` + `testUnavailableImagesShowAlternativeTextAndOfferFolderAccess` + `testRemoteImagesLoadWithoutBlockingText` |
| 5. Opening text remains responsive while remote images load | Open `remote.md` while `/slow.png` is delayed 4 s | `REMOTE START` and `REMOTE END` exist within 2 s of the window appearing; the slow block reports `Image loading` first, then `Image displayed` by 10 s; scrolling and text selection work during the delay | `testRemoteImagesLoadWithoutBlockingText` |
| 6. Existing uploaded-asset links usable; no uploading | Automated: ordinary `![alt](https://…)` and `[![badge](img)](href)` forms; the retired attachment address in `network.md` | The linked badge's `https://example.com/badge` remains in the block's keyboard link cycle (`MarkdownLinkBlock-<id>` value, *existing*) and contextual menu (*existing* M1-11); nothing in the UI offers upload/drag-in of assets (no toolbar, no drop target other than the existing Markdown file drop). Manual: `network.md` displays GitHub's documented sun/moon assets and shows alt text for the retired attachment | Existing link tests + manual network check |

### Appearance, keyboard, accessibility, read-only

- Light/Dark: criterion 3 test runs in one session across both; also run the local test once with `NEOMD_UI_TEST_APPEARANCE=Dark` and attach screenshots.
- Width/full-screen: resize the window narrower than 1200 pt; the wide image tracks the column width and the reading position restoration (M1-04, *existing*) still lands.
- Keyboard: Option-Tab / arrows / Return on the inline linked badge activates its link exactly as M1-09/M1-11; `Allow folder access` is a native button reachable by Tab and Space.
- AX: image-only paragraphs are single elements with `.isImage`, label = alt (or `Image` when alt is empty) and value = `Image displayed` / `Image loading` / `Image unavailable`; inline images inside sentences carry their alt as the attachment's accessibility label; placeholders keep the alt as real text so VoiceOver reads it. VoiceOver speech order stays deferred.
- Read-only: bytes/mtimes unchanged; no bookmark or preference written; no cache files inside the fixture.
- Security: `vector.svg` script never executes; remote loads are `URLSession` fetches decoded by ImageIO/NSImage only; no image click launches an application; `data:` and non-HTTP(S)/file schemes are never fetched.
- Not covered by automation: real sandbox grant, real system appearance switch, real network, animated playback (not a criterion), VoiceOver.

### Manual checks (plain build, real sandbox and network; final milestone)

1. Build with `xcodebuild … build`; `codesign -d --entitlements :-` lists `com.apple.security.network.client` and user-selected read-only, no absolute-path exception. Copy the fixture to `~/Documents/NeoMD-M1-12/`, open `illustrated.md` from Finder.
2. Every local image shows alt text with `Allow folder access` (no automatic panel); text is fully readable. Click one `Allow folder access` → panel preselects `img/` → choose it → all images in the document display without another prompt; Cancel instead keeps placeholders.
3. Switch System Settings → Appearance: picture blocks swap sun/moon; orange, green, magenta, purple images keep their colours.
4. Open `network.md` online: documented assets display; the retired attachment shows alt text. Then go offline (Wi-Fi off) and reopen: alt text for all, text readable immediately.
5. Quit and relaunch: opening `illustrated.md` prompts again through the button (no persisted grant). Console shows no sandbox violation during step 2.

### Actual commands/results

Recovery checkpoint (2026-09-08), branch `story/12-images`, base/HEAD `265cd3e30fd94e859d6811705caff09ae48de132`, uncommitted implementation; **not a validated final head or acceptance**. The tables above preserve the authored plan, not execution claims. Binding revisions: [eager system decoding](https://github.com/redrossa/neomd/issues/12#issuecomment-5584997087), [screenshot bitmap oracle](https://github.com/redrossa/neomd/issues/12#issuecomment-5585145630), [external test controller](https://github.com/redrossa/neomd/issues/12#issuecomment-5585488204), [narrow linked-image native leaf](https://github.com/redrossa/neomd/issues/12#issuecomment-5585720602).

Corrections to the planned setup/oracles: remote fixtures use the external `Scripts/image_test_controller.py`, fresh token/nonzero port/readiness and explicit delayed-response release, **not** an in-runner listener or a fixed four-second delivery delay. Bitmap dimensions come from solid-colour screenshot footprints converted to points, with independently expected fitted dimensions and the unchanged ±2pt threshold; native text AX frames are checked separately. Linked-image leaves (including headings) use the approved NSTextView attachment adapter, not the ordinary unlinked-image SwiftUI path. `fallback.png` is blue-gray (#8c959f), not neutral gray. See `docs/image-test-controller.md` for current commands and clipboard safety limitations.

Recovered exact-source evidence before the new clipboard test-harness changes:
- Controller: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Scripts -p 'test_image_test_controller.py' -v`: 5/0, `/tmp/neomd-12-final-controller.log`.
- App: command prefix above, Debug, `-derivedDataPath /tmp/NeoMD-12-Plain-DerivedData build`: succeeded, `/tmp/neomd-12-final-source-build.log`.
- All units: command prefix above, `-derivedDataPath /tmp/NeoMD-12-DerivedData -resultBundlePath /tmp/NeoMD-12-FinalUnits.xcresult -only-testing:NeoMDTests test`: 136 passed, 0 failed/skipped, `/tmp/neomd-12-final-source-units.log`.
- Image UI: `TEST_RUNNER_NEOMD_PLAIN_APP_PATH=/tmp/NeoMD-12-Plain-DerivedData/Build/Products/Debug/NeoMD.app PYTHONDONTWRITEBYTECODE=1 python3 Scripts/image_test_controller.py --timeout 420 -- xcodebuild` with the project/scheme/macOS destination above, `-derivedDataPath /tmp/NeoMD-12-DerivedData -resultBundlePath /tmp/NeoMD-12-FinalImages.xcresult -only-testing:NeoMDUITests/DocumentImageUITests test`: 11 passed/0 failed, 272.730s, `/tmp/neomd-12-final-source-images.log`.
- Actual image selectors include the four original methods plus `testImagesRefitDuringActualWindowResize`, `testLinkedBadgeRetainsActivationAndContextMenu`, `testLinkedHeadingRetainsProseAndKeyboardNavigationInBothThemes`, `testNativeLinkedImageParagraphKeepsProseSelectionReadOnly`, `testNativeLinkedImagesWrapAndResizeWithoutUpscalingInBothThemes`, `testImageReaderRepeatedScrollingRetainsResponsiveContent`, and `testPlainSandboxFolderGrantsAndArbitraryHostNetworking`.
- Plain test (68.710s within that 11/0 result) verified signed sandbox/network.client/user-selected-read-only and no temporary-exception entitlement; real `http://httpbin.org/image/png` and `https://httpbin.org/image/png` displayed from the separate plain artifact. It exercised keyboard access action, Cancel, unrelated folder, successful image-folder grant, retained text and the suite's source byte/mtime teardown. This is not a claim that every public host works or that all final-milestone manual steps were run.
- Latest combined serialized regression attempt, `/tmp/NeoMD-12-FinalRegressions.xcresult`, timed out at 1500s: navigation class 8/0 completed; structure/emphasis failed at line148 amid Terminal interruption and later missing-window snapshots. The entire attempt **did not pass**. Recovery sampled its exact orphan PID18597: idle AppKit loop, 94.7MB footprint (not earlier 6.5GB SwiftUI churn); terminated only that owned process.
- Recovery reran only `-only-testing:NeoMDUITests/DocumentReaderLayoutUITests/testDocumentStructureAndEmphasis` with `-parallel-testing-enabled NO`, the same project/scheme/destination/DerivedData and `/tmp/NeoMD-12-ResumeStructure.xcresult`: 1/0, 35.413s; `/tmp/neomd-12-resume-structure.log`. No source repair was inferred from the interrupted run.
- Earlier smaller regressions passed: WebLinkUITests 5/0 in67.463s (`/tmp/neomd-12-web-regressions.log`); three layout resize/restoration tests 3/0 in106.768s (`/tmp/neomd-12-layout-regressions.log`). These predate final quoted-style adjustments; they are not substitutes for final-head evidence.

Original layout failure remains preserved. Later controlled uninstrumented investigation found that disabling observers/single-root wrapping/top anchor did not cure it; removing the ScrollPosition binding passed, and retaining the binding with `ScrollPosition(edge: .top)` instead of continuous `idType` tracking passed. The inherited narrow initializer change is in `DocumentReaderView`, with explicit point/ID requests retained. Repeated scrolling also passed in the final image suite. This supplies controlled intervention evidence beyond the earlier instrumented pass; it does not establish SwiftUI's internal physical root cause or waive restoration regression gates.

Post-clipboard-harness compilation/unit gate: same project/scheme/macOS destination, `-derivedDataPath /tmp/NeoMD-12-DerivedData -resultBundlePath /tmp/NeoMD-12-ResumeUnits.xcresult -only-testing:NeoMDTests test`: 136 passed, 0 failed/skipped; `/tmp/neomd-12-resume-units.log`. This compiles the new UI helper without running clipboard-mutating UI. `git diff --check` and the five Python lifecycle tests passed again.

**Superseded clipboard checkpoint:** live integration subsequently passed 3/0/0 in the user-approved exclusive window and current-window restoration succeeded. The window is now released. Previously lost contents remain unrecoverable; the final check/write race is not eliminated by NSPasteboard. See [current evidence and source-delta assessment](m1-12-validation.md#clipboard-evidence-reuse--no-new-clipboard-window). Do not rerun general-clipboard tests without renewed agreement.

### Deferred and cross-story

- [#36 baseline reflow hang](https://github.com/redrossa/neomd/issues/36): unchanged `testReadingColumnReflowsAndKeepsCodeOverflowLocal` remains BLOCKED until final milestone validation. Reproduction, failed control evidence and cleanup are in [M1-12 validation](m1-12-validation.md#durable-baseline-reproduction-and-unresolved-milestone-gate). Focused margin checks do not replace it.
- M1-13 alerts and M1-15 HTML: standalone `<img>` / `<p align="center"><img …></p>` blocks stay literal in this story (only Markdown images and the documented `<picture>` form are in scope); decide their treatment in M1-15.
- M1-16: verify selection/copy across paragraphs containing inline images; M1-21: find must ignore the empty-alt carrier character.
- M1-22 reading size and M1-23 external changes: image sizing under text scaling and cache invalidation on re-render are not exercised here.
- Final sweep: combine image loading with resize restoration, multiple windows and Light/Dark; verify the folder grant from an image button also unlocks M1-10 links in the same folder.
- Risk: `Text` inline-image attachment metrics differ from GitHub for very tall images inside sentences; block-level (image-only) paragraphs are the primary sizing contract.

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


## M1-13 — Notice alerts, emoji, and color references (implementation handoff)

**Current authoritative handoff:** [final validation](m1-13-validation.md). C1–C4 implemented; final integrated Debug build passes and full units are **156 passed / 0 failed / 1 historical disabled-probe skip** (216 expanded passes). Exact source head/PR are recorded in the PR handoff. No merge or acceptance is claimed here. All earlier checkpoint statuses below are historical and superseded by this paragraph and the final validation, not newly asserted blockers or passes.

The latest user instruction explicitly waives further keyboard-navigation E2E: **deferred/not passed**. No Accessibility permission or new UI execution. C5 stays **unchecked/deferred—not passed—to #38**; #36 stays separate. Existing scale tests and failures are preserved for final milestone testing. The four-source traversal implementation and four `NeoMDTests/KeyboardTraversalTests` regressions are integrated, including actual-target detach cancellation and native origin restoration. The permission-dependent scratch semantic UI test is not installed as an active gate. Existing Light/Dark footnote roundtrip keeps its exact full native-value unique-match/<10pt landing oracle; its pass is historical prototype evidence, not an integrated-head UI rerun.

### Actual implemented coverage and final-milestone recipe

- `NeoMDTests/AlertCueTests`: 31 alert vectors, marker-only/multiblock arena and header geometry.
- `NeoMDTests/EmojiCueTests`: 22 provenance vectors, all 1,913 aliases, metadata/raw/URL exclusions and 16×40 concurrent parses. Independent pinned alias map and shipped MIT notice verified.
- `NeoMDTests/ColorCueTests`, `NativeColorCueTests`, `NativeColorLeafTests`: 49 color vectors, passive real native drawing, exact strings/ranges/update identity, image states and authored links. `NativeInlineLeafTests`, `FontPolicyParityTests` protect ordinary native leaves and independent font baselines.
- `NeoMDTests/KeyboardTraversalTests`: semantic separate text/action order, exact native chord classification, clipboard-free selection methods, weak identity/generation/two-owner isolation and actual-target versus unrelated detach cancellation. These are **method-level units**, not event-level E2E.
- Historical `NeoMDUITests/DocumentCueUITests/testScaleOneLight` and `testScaleOneDark` each pass; all 60 captured matrix images inspected during final integration, no new app run. Historical `testDefaultSizeAllAlertsFollowLiveSystemAppearance` passes all five alert triplets with restoration; its rule-stripe limitation remains documented. Current build/units commands, counts and historical margin/menu/image/roundtrip evidence are in final validation.

Final user testing: copy `docs/fixtures/m1-13-cues/` intact, snapshot bytes/mtimes, and run the six `DocumentCueUITests/testScale{One,OneAndHalf,Two}{Light,Dark}` selectors in separate bounded serialized invocations. Record actual fonts, wrapping, cue baselines, label/body order and responsiveness at 900/480; C5 needs reliable completion, not one successful intermittent run. Use the authorized appearance controller for `testDefaultSizeAllAlertsFollowLiveSystemAppearance` and restore the original setting. Do not run larger-size tests now merely because this recipe exists.

Deferred semantic keyboard recipe (not a runnable guaranteed test): ordinary paragraph → linked paragraph native-text stop → separate link-action stop → truly overflowing code → offscreen ordinary leaves; reverse the exact sequence with Option-Shift-Tab. Short code is not a code-action stop. At both document ends confirm actual native-window-control acquisition without wrapping. Use exact native full values and an independently authorized focus oracle, not FocusState appearance alone. Verify Left/Right and single Return/Space activation, Escape/page behavior, mouse and Shift-arrow selection without clipboard, all negative chords, equal IDs in two windows, new mouse/key/scroll/resize intent during acquisition, replacement/detach and weak release. Preserve fixture bytes/mtimes. The earlier direct AX oracle lacked trust and failed; obtain an explicitly authorized oracle/host at final testing, never silently grant permissions. Manual VoiceOver label→body order/duplicate speech and combined cross-story E2E remain user-owned. Stop before #14.

### Historical checkpoint record (superseded status, retained evidence)

**Current approved disposition:** [approval5610876429](https://github.com/redrossa/neomd/issues/13#issuecomment-5610876429) transfers complete C5 to [#38](https://github.com/redrossa/neomd/issues/38): unchecked/deferred, not passed; no longer a #13 pre-merge blocker. Preserve all historical failures and larger-size tests. The C5 matrix/selection/accessibility coverage below belongs to final milestone validation; no further1.5×/2× runs now. #36 is separate, common cause unproven. C1–C4 and ordinary1× preservation remain required; see the [current remaining-gate checklist](m1-13-validation.md#current-scope-and-explicit-deferrals). C2 evidence below is reused without rerun. User owns milestone acceptance; stop before #14. Historical blocked statements below retain their original evidentiary meaning, superseded only as to C5 pre-merge disposition.

**Latest nondeferred gate:** [default-size results and stop](m1-13-validation.md#preserved-failure-history-and-limits). Current production unchanged `testScaleOneLight`/`testScaleOneDark` each1pass/0fail/0skip,105.351/106.436s;30 screenshots+30 AX per theme exported in `/tmp/neomd-13-final/`, four Light screenshots inspected, full review pending. Required unchanged `DocumentReaderLayoutUITests/testInitialReadingMarginAndTopPositionSurviveResize` then fails1/0pass at line196 (paragraph StaticText not found),53.180s, exit65. Captured prose is visible; potential AX-role selector mismatch, not established content loss/hang. STOP without retry/test weakening; normal-size margin gate remains unverified, not covered by #38. Final build/units/remaining regressions pending; no PR.

**Latest C2-only evidence:** [targeted live-system validation](m1-13-validation.md#historical-ui-evidence-reused-not-rerun-on-the-integrated-head). New `NeoMDUITests/DocumentCueUITests/testDefaultSizeAllAlertsFollowLiveSystemAppearance` passes1/0fail/0skip/0restart105.388s on the current production dirty app. Unchanged triage `alerts.md`, public default1×,900×760; each of all five real labels/first bodies stays at its reading point through system Light→Dark→Light. All15 screenshots inspected; word/symbol/rule/body structure and adaptive contrast retained; full fixture bytes+mtime teardown passes. Original Dark restored/read back by test and controller; no owned survivors. `/tmp/neomd-13-c2/{c2.xcresult,c2.log,summary.json,attachments/manifest.json}`. Runtime rule-stripe oracle samples glyphs because AX bounds exclude the rule: do not cite it as rule proof. Actual rule pixels were independently sampled from these same screenshots (`rules.swift`, `rules.txt`, minima5.449 Light/6.832 Dark), with no UI rerun; post-run source change is comment-only. Exact hashes/limits in validation. Existing1.5× live gate and all old assertions unchanged. **C5 remains blocked**, no PR/acceptance/#14; VoiceOver speech still user-deferred. No new fixture data authored.

Latest approved production migration and exact results: [validation checkpoint](m1-13-validation.md#preserved-failure-history-and-limits). Approval5609963406 extends native selectable inline prose while preserving unlinked pure-image/picture and SwiftUI labels/code. New exact selectors: `NeoMDTests/NativeInlineLeafTests/ordinaryLeavesKeepStorageSelectionFontsBaselinesAndDispatch` (1pass), `NeoMDTests/NativeColorLeafTests/routingPreservesUnlinkedImageOnlyLeaves` (included in3pass suite), and clipboard-free `NeoMDUITests/DocumentCueUITests/testCrossParagraphDragWithoutClipboard` (paired pre-migration/production screenshot evidence: drag stops in originating paragraph in both). Original eight-pair responsiveness selector passes29.663s; genuine complete1.5×Light/Dark matrices pass115.725/113.110s. Historical failed Dark run and underbudget diagnostic remain recorded, not erased. **2×Light matrix still hangs after900→480 resize/return-to-top**, sampled sustained native/lazy layout work; no selection-overlay attribution or #36 equivalence established. Stop before14; full final matrix/live appearance/affected regression and manual acceptance still outstanding. No new fixture content authored; existing triage fixtures preserved.

[Issue #13](https://github.com/redrossa/neomd/issues/13) · [D1–D3 approval](https://github.com/redrossa/neomd/issues/13#issuecomment-5594012782) · [accepted implementation baseline](m1-13-cues-plan.md) · [published baseline](https://github.com/redrossa/neomd/issues/13#issuecomment-5594124438). Base SHA: `add27876bca4036ed0c6c023c08cf94f46481e6b`. No story PR/evidence head yet. Triage Astra/high verified; worker Astra/low must verify at launch. Current override: no reviewer stage, coordinator accepts/merges from exact-head worker evidence. Only #13 is authorized; pause before #14.

### Durable data and setup

Canonical path: [`docs/fixtures/m1-13-cues/`](fixtures/m1-13-cues/README-fixture.md). The README specifies exact file/case authority, bytes/whitespace, independent JSON parsing, opening/isolation/cleanup and criterion-linked actions. Inventory: five-type `alerts.md`, `alert-controls.md` plus 31 `alert-cases.json` vectors; `emoji.md` plus 22 exact `emoji-cases.json` vectors; all-1,913-alias `emoji-corpus.md`; `colors.md` plus 49 parser-normalized `color-cases.json` vectors (15 valid/34 invalid); nine `context-cases.json` vectors; `mixed-cues.md`; newly authored16×8 #28a745 `img/badge.png`; absent `img/absent.png`; fixture SHA256/byte-length manifest. These are **data, not executable tests or passing evidence**.

Pinned corpus: `github/gemoji@0eca75db9301421efc8710baf7a7576793ae452a`, 1,870 records/1,913 Unicode aliases, exact scalar strings. Pristine JSON, expected alias map, provenance and full MIT notice are preserved in `corpus/`. Worker must bundle the offline derived map **and notice** in the app, not load fixtures at runtime. The research-only current GitHub API has the same Unicode name set and23 additional custom-image names; custom names such as shipit/octocat stay literal. No custom images, Unicode font assets, account or runtime lookup is added.

Copy the entire fixture folder to an owned temporary location, record all source bytes and mtimes, open through existing NSWorkspace test patterns, serialize UI and clean only that fixture/app. All image references are local; do not activate example.com URLs in parser controls. Mixed-file links are internal `#mixed-target`/`#mixed-start`. Plain builds may need the existing explicit image-folder grant; no sandbox/identity changes. Do not mutate clipboard, email or unrelated app sessions. Appearance controller restoration remains required.

### Criteria → actions → expected evidence

| Criterion | Fixture/actions | Required outcome and planned coverage |
| --- | --- | --- |
| C1 | Five alerts in `alerts.md`, independent alert controls | Distinct persistent NOTE/TIP/IMPORTANT/WARNING/CAUTION word labels with passive symbol/rule/treatment in both themes; intact multiblock body/task/code/link order; negatives retain ordinary content, not removed marker text. New parser/host/story UI assertions. |
| C2 | Open each theme; same open alert during actual system Light→Dark→Light and restoration | Readable coherent adaptive labels/bodies/rules, noncolor meaning, same document/window/snapshot IDs and preserved reading point; inspect real screenshots. App override/debug channel is not a substitute for actual live-system coverage. |
| C3 | All pinned aliases and escape/entity/code/autolink/image/unknown cases; offline visible samples | Exact Unicode including aliases/ZWJ/VS16; no false promotion after cmark unescaping/consolidation, URL/code/metadata unchanged. Parser vectors plus actual SwiftUI/native glyph rendering. |
| C4 |49 full-value color vectors and mixed native/unlinked image paths | Correct finite swatches only on valid normalized inline-code values; invalid ordinary code; original value selectable and accessible; black/white border contrast; no new swatch action/focus/AX duplicate. Pure parser oracle, native content/selection and screenshots. |
| C5 | Both themes × actual scales1/1.5/2 × widths900/480; alerts plus mixed paths | Actual font points increase, measured label height precedes body, glyph/swatch baselines and task markers align, wraps remain ordered/nonoverlapping, image size policy retained. Deterministic native-host geometry plus visible story UI at all three scales; keyboard/mouse links remain usable. |

All opening/scroll/appearance/resize/close actions compare exact bytes **and** mtimes. Use normal link mouse/Option-Tab/arrows/Return/Space and Escape on the mixed fixture; no independent swatch focus/action. Native selection-range or drag checks are clipboard-free; any copy selector still needs a fresh exclusive-window approval. Image loaded/loading/unavailable states must be covered in native-host inputs and mixed paths without introducing remote-network dependence.

### Executable selectors and evidence — worker must complete

Suggested new group names only (not implemented selectors): `MarkdownCueParsingTests`, `MarkdownCuePresentationTests`, `MarkdownCueHostingTests`, `DocumentCueUITests`. Worker supplies real methods/commands, actual nonzero pass/failure/skip counts, exact evidence SHA/PR, outside-repo xcresults, measured font/frame values and inspected screenshot filenames. No build/app/test run was performed by triage. Do not claim JSON vectors or names establish correctness.

Command families remain the repository Xcode Debug build and targeted `-only-testing:NeoMDTests/<actual-suite>` / `-only-testing:NeoMDUITests/<actual-class>/<actual-method>` commands with external DerivedData/fresh result bundles and `-parallel-testing-enabled NO`. Selectors must exist before they are published as runnable commands. Run diagnostics before builds. Actual system switching uses the existing authorized `Scripts/appearance-test-host.sh` flow; see [appearance instructions](appearance-ui-tests.md). Select precise nonclipboard regressions after reading their source; no broad historical class command containing Copy Link/Command-C is authorized. Build/relevant units/story UI must pass before merge; failures/unavailable required validation block, not silently defer.

### Current worker status — native amendment implemented; BLOCKED on 1.5× narrow scrolling

[Recovery commands, failures, screenshots and accepted narrow amendment](m1-13-validation.md). Approval5595759256 is implemented: native routing only for linked-image or valid-color leaves, preserving other SwiftUI text; rejected SwiftUI prototype is test-only historical evidence. Final recovery build `/tmp/neomd-13-recovery-build.log` passed. `NeoMDTests/NativeColorLeafTests`, `NativeColorCueTests`, `ColorCueTests` passed6 tests/0 failures/0 skips in `/tmp/neomd-13-recovery-units.xcresult`; no-image selectable native drawing, text/selection/update/AX/cleanup and scale geometry are now covered.

`NeoMDUITests/DocumentCueUITests/testScaleOneLight` and `testScaleOneDark` each passed1 matrix test/0 failures/0 skips at900/480 (`neomd-13-ui-native-light4`, `neomd-13-ui-native-dark1` xcresults under `/tmp`). They include five alerts and ten mixed body/image/heading/task/quote/footnote samples, baseline alignment and copied fixture bytes+mtime teardown. The1.5× Light matrix hung during narrow scrolling; focused `testScaleOneAndHalfNarrowAlertScrollRemainsResponsive` independently reproduces the main-thread selection-overlay/layout loop. Samples/logs and owned-PID cleanup are recorded in validation. This is a current required C5 blocker, not the #36 waiver. Remaining scales, live-system, interaction/nonregression gates and exact-head acceptance are incomplete. No commit/PR or acceptance is claimed. The parser-only checkpoint below is historical.

### Worker checkpoint — raw-token provenance gate only

Implementation remains incomplete and unaccepted. The first parser gate passed on the uncommitted `story/13-alerts-emoji-colors` tree based on `add27876bca4036ed0c6c023c08cf94f46481e6b`. The public cmark inline hook emits private owned custom-inline candidates before unescaping/consolidation; the iterative adapter expands eligible labels and retains image alternatives. No vendor bytes changed. All staged artifact/base-document hashes were checked before installation.

Actual commands used `xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-M1-story13-DerivedData`:

- `-configuration Debug build`: **BUILD SUCCEEDED**, `/tmp/neomd-13-build-gate1.log`. Bundled `gemoji-aliases.json` and complete `gemoji-LICENSE.txt` were byte-compared to the source resources; both match the pinned artifacts.
- `-resultBundlePath /tmp/neomd-13-gate1.xcresult -only-testing:NeoMDTests/EmojiCueTests -only-testing:NeoMDTests/CMarkDocumentTests test`: 7 methods/35 expanded passes, 0 failures, 0 skips (initial three-method emoji suite).
- `-resultBundlePath /tmp/neomd-13-parity-gate1.xcresult -only-testing:NeoMDTests/CMarkParityTests test`: 5 methods/9 expanded passes, 0 failures, 0 skips, including the unchanged 16-worker extension concurrency regression.
- `-resultBundlePath /tmp/neomd-13-emoji-gate1-final.xcresult -only-testing:NeoMDTests/EmojiCueTests test`: final 5 methods passed, 0 failures, 0 skips. Actual selectors: `approvedProvenanceVectors`, `everyPinnedAliasPreservesUnicodeScalars`, `imageAlternativesAndReferenceLabelsRetainContext`, `concurrentCandidatesKeepTheirOwnPayloads`, `rawMarkupAndDestinationsAreNotRewritten`. These execute all 22 staged emoji vectors, all 1,913 aliases, additional reference/image/HTML/autolink context checks, and 16×40 concurrent candidate parses.
- Primary Swift LSP diagnostics confirmed clean before build/tests. `sh Scripts/verify-cmark-vendoring.sh` and `git diff --check` passed.

These are unit-only commands (default Xcode parallel setting); no UI, clipboard, appearance switch or screenshot was performed. C1/C2/C4/C5 implementation, native hosting proof and all story UI gates remain outstanding. This checkpoint does not establish complete C3 visual/AX acceptance either. No exact final head, PR or acceptance is claimed. Continue the accepted ordered plan; do not publish this partial tree as finished work.

### Final milestone additions and preserved deferrals

Human combined run: open the mixed fixture from Finder, navigate alert/task/footnote and native image links, resize/switch real appearance/multiple documents, then hear VoiceOver label→body order, emoji/color value meaning, no duplicate decorative speech and context exit. Record actual utterances and SHA/macOS/VoiceOver state, restore settings and recheck bytes/mtime. Comprehensive combined E2E and manual speech remain user-owned and unverified; this does not defer current-story AX/scale/live-system UI or any approved criterion.

[#36](https://github.com/redrossa/neomd/issues/36)'s unchanged full reflow hang remains **BLOCKED/deferred, not passed or fixed**, with its reproduction and final investigation retained. It does not waive new cue reflow, normal resize/initial margins, image/native link or selection preservation. Earlier catalog entries are preserved byte-for-byte; their historical status remains historical rather than newly verified. No #14 work, public #22 controls, icons/DMG publication or milestone closure follows from this plan.

## M1-P1 — Native startup Open dialog

**Worker update / user waiver:** Further E2E/UI and manual scripted interaction testing was explicitly stopped by the user ("pls dont do e2e testing"). Final-head UI acceptance, transient-window/video inspection and remaining regressions are **deferred/unverified, not passed**. The following retains the triage plan for final milestone use; it is not authorization to run UI now. See [actual commands, pre-waiver outcomes and limitations](m1-p1-validation.md). Build and relevant unit tests remain the current gate.

[Issue #40](https://github.com/redrossa/neomd/issues/40) · [milestone 1](https://github.com/redrossa/neomd/milestone/1).
Accepted inspection base: `861a1ca4c6c3efa7621333c5db19fac0aa0ad772`. Astra/high runtime verified. The canonical issue has three unchecked criteria and no comments at triage. First open ordered story is #40, followed by #41–43, then #14–24. No reviewer stage under the current user policy. This entry is a **plan, not test evidence**; worker records the actual implementation SHA/PR/results below after executing it.

### Scope and sequencing

Startup only: launch with no requested document shows the native macOS Open panel, with no separate blank/instruction window; an explicit opening launch goes directly to its document; Cancel leaves the process running with no windows and usable File > Open / Command-O. Real empty files retain the empty-document reader. No custom browser, file-type/access change, renderer refactor or clipboard action.

Do not delete the entire no-document lifecycle as a shortcut: #41 owns last-document-close behavior. At this base `DocumentReaderView.onDisappear` explicitly opens the instruction scene; retain that behavior for this story. A launch-suppressed instruction scene can remain as a transitional last-close destination while the document group's native startup behavior is restored. Prefer native launch arbitration rather than unconditional delayed panel presentation. If this separation fails in actual SwiftUI execution, report the overlap for user/coordinator resolution rather than quietly implementing #41. Dock reactivation is not newly specified.

### Durable data, isolation and observable oracles

Canonical data: `docs/fixtures/m1-p1-startup/`, exact files and setup in `README-fixture.md`, hashes in `manifest.json`. Copy to an owned temporary directory, use fixed mtime, capture bytes/mtime, and compare after interactions. Nothing requires network or a permission grant.

Use an owned tested app, `-ApplePersistenceIgnoreState YES` for deterministic launch (existing `DocumentOpeningUITests.configuredApplication`), and a fresh stopped process for every cold-launch case. Do not infer cold opening from `app.launch()` followed by `NSWorkspace.open`: that is a warm-file event. Existing `app.open(url)` is the cold explicit-document pattern; verify process is stopped first. Also exercise a real Finder Open With or explicit `open -a "$APP" "$COPY/launch.md"` launch against the exact separately built bundle, without changing the host's default app association. Do not kill other NeoMD copies by bundle-wide/PID-name commands.

Known native selectors on the inspected base: `app.windows.matching(identifier: "open-panel").firstMatch`; File menu item title starts with `Open` but not `Open Recent`; Go to Folder field `PathTextField`; reader window named by `url.lastPathComponent`; empty message `This document is empty.`; old instruction `NoDocumentInstruction`. Scope native Cancel/Open button queries to the panel, not Touch Bar duplicates. Use actual native keyboard events for Command-O and Escape, no direct action-method substitute.

Document paragraphs now use native selectable text: query an exact full text value using its observed AX role (often `textViews`), not only the old `staticTexts` role. Require a unique visible marker, filename window and reader surface; do not weaken content/position assertions to window existence alone.

For absence requirements, inspect all owned visible windows, not just absence of `NoDocumentInstruction`. Poll boundedly during launch and after content becomes readable, and retain startup video/window observations to catch transient starter/panel flashes. A single eventual screenshot does not prove no startup flash. No-window checks must include app still running plus zero visible app windows; the native panel is itself a window while open.

### Criteria → actions → expected outcome

| Criterion | Actions | Required observable outcome | Planned selector (not implemented at triage) |
| --- | --- | --- | --- |
| C1 | Cold launch with no file in Light and Dark; inspect windows; choose `launch.md` through the already-present native panel using Go to Folder and Open | Exactly the native Open panel, no extra starter/reader; selection opens the correct rendered document once and dismisses panel; unchanged bytes/mtime | `NeoMDUITests/DocumentOpeningUITests/testStartupPickerSelectsDocumentWithoutStarterWindow` |
| C2 | Cold open `launch.md`, then separate cold launch with `Meeting café.MD`; observe startup and settled state | Correct filename/content, one reader, no unnecessary Open panel or starter, no raw-source starter flash | `NeoMDUITests/DocumentOpeningUITests/testColdExplicitUnicodeFileOpensWithoutStartupPanel` |
| C3 | Cold launch; cancel startup panel with Escape; observe process/windows; invoke File > Open, cancel; invoke Command-O, choose `launch.md` | Still running with zero windows after each cancellation; each command presents a native usable picker; selection creates the correct reader without extra starter | `NeoMDUITests/DocumentOpeningUITests/testMenuAndCommandOInvokeTheNativeOpenPanel` |
| Scope preservation | Cold explicit open `empty.md`; repeat via startup picker if practical | Real filename-titled reader with `This document is empty.`, no startup picker remaining; source remains zero bytes with same mtime | `NeoMDUITests/DocumentOpeningUITests/testNoFileLifecycleAndEmptyDocumentStayDistinct` |

The table now uses actual worker selectors. The startup picker test covers the default appearance; the appearance suite covers pinned Light/Dark. The command test cancels both reopened panels (selection is separately covered by the startup-picker test). Empty-document coverage opens via a warm explicit request after cancellation, then preserves the current last-close instruction. Cold empty-file and transient-window/video observations remain deferred. These selectors are retained for future authorized validation, not current execution.

### Build, unit and story UI commands — all UNRUN by triage

Run from the worker checkout; perform proactive Swift diagnostics first. Use fresh external result paths and serialize UI; keep plain build and test products separate. Xcode 26.3 / macOS 26.5.1 were inspected, but graphical automation usability has NOT been tested by triage. Stop/report actual automation/signing failure; do not grant permissions.

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug   -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-P1-Plain build
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD   -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-P1-Tests   -parallel-testing-enabled NO -only-testing:NeoMDTests/DocumentOpeningTests   -only-testing:NeoMDTests/MarkdownFileTypeTests -only-testing:NeoMDTests/MarkdownTextDecoderTests   -resultBundlePath /tmp/neomd-p1-units.xcresult test
```

Use the same project/scheme/macOS/test DerivedData prefix with `-parallel-testing-enabled NO`, a fresh result bundle and `test` for story UI. Select the four proposed methods above **after implementation**, plus existing regressions below. Add relevant units for any new launch-arbitration state; native scene defaults alone are not meaningfully proven by mocked launch state.

Existing regression selectors under `NeoMDUITests/DocumentOpeningUITests/`:
- `testPickerCancellationPreservesScrolledReaderAndSourceFile` — ordinary reader/picker cancellation, actual marker position and bytes/mtime. Native text-role adaptation may be needed after #13; preserve the full oracle.
- `testClosingOneOfMultipleDocumentsKeepsTheOtherReader` and `testCommandWClosesReaderWithoutPromptOrSourceChange` — preserve current last-close behavior in #40, no save prompt, immutable sources; #41 changes expectations later.
- `testCommandWTargetsTheOpenPanelAndCloseDisablesWithoutWindows` and `testSavingCommandsAreUnavailable` — update obsolete startup setup, preserve read-only command semantics and actual native events.

Existing opening/appearance tests contain now-superseded startup-instruction assumptions: migrate the startup portions of `testMenuAndCommandOInvokeTheNativeOpenPanel`, `testNoFileLifecycleAndEmptyDocumentStayDistinct`, `testDroppingOnNoFileWindowOpensTheDocument`, and `AppearanceUITests.testEmptyDocumentAndNoFileWindowStayLegibleInLightAndDark` / `testDropErrorStaysLegibleInLightAndDark`. Keep real empty-file/last-close/error/drop coverage: for a specifically retained last-close instruction test, first open and close a real disposable document. Do not delete all assertions to make them pass. Run any test whose behavior is edited.

Many historical rendering suites launch without a file then deliver a warm NSWorkspace open. Check that their setup is not blocked by the new startup modal; handle the expected initial panel explicitly in test setup if needed, never introduce a production test-only skip-startup flag. Do not broadly rerun clipboard suites, deferred #36 reflow or #38 scaling gates. Their historical failures and permissions limitations are unchanged; #13's keyboard waiver does not cover this story's Command-O/Escape tests.

### Required worker evidence and final combined milestone checks

Worker fills in: exact tested source head/PR; actual commands; nonzero pass/failure/skip counts; xcresult/log paths; observed native AX/window timelines; inspected Light/Dark startup screenshots and explicit-file startup video; immutable-file checks; precise automation limitations and any repairs. No test/build/UI execution or screenshot inspection was performed at triage.

At final milestone acceptance, repeat no-file launch → Cancel → menu/Command-O → document; Finder cold/warm requests including Unicode filename; actual empty file; explicit Quit and relaunch; then combine with #41 last-close no-window/no-panel behavior after it is implemented. Verify native menu discoverability without a key reader. Check fresh launches and the user's ordinary saved-state environment without deleting preferences/history, recording restoration behavior separately from requested new #24 persistence. User owns business acceptance. Full VoiceOver and combined appearance/resize/navigation checks remain final-milestone work, not claims of this startup-only gate.

## M1-P2 — Stay running without windows after last close

[Issue #41](https://github.com/redrossa/neomd/issues/41) · [milestone 1](https://github.com/redrossa/neomd/milestone/1).
Triage base: `823809000f25a2c45ac4c2c8510d36962c6cdcbc` (merged [PR #44](https://github.com/redrossa/neomd/pull/44)); runtime `openai-codex/gpt-6-astra`, high. Triage verdict **ACCEPTED for implementation**, not behavioral acceptance. #41 is the first open ordered story; #43 decisions are unchanged and pending.

### Current validation amendment

The latest user instruction, **“pls dont do e2e testing”**, applies now, superseding earlier per-story interaction mandates and the earlier #13-only waiver wording. Build and relevant units are the current implementation gates. All further UI/E2E and manual scripted end-to-end checks are **DEFERRED/UNRUN, not passed**, including the scenarios below. Historical catalog commands are reproduction references, not authorization to execute them now. Preserve all #40 pre-waiver passes, failures, incomplete bundles and unverified corrections in [M1-P1 validation](m1-p1-validation.md); preserve #13 C5/#38, #36 and earlier final-human deferrals. Final combined milestone acceptance remains user-owned and requires renewed authorization for deferred testing. No automatic milestone closure.

### Durable fixtures and expected future observations

Reuse [M1-P1 document bytes](fixtures/m1-p1-startup/README-fixture.md) through the [M1-P2 reuse manifest and setup](fixtures/m1-p2-last-close/README-fixture.md). No redundant document copies are added. Fresh owned copies use fixed mtime and exact byte/mtime snapshots; never alter originals. No network, clipboard or permission/appearance changes are required.

**Every row is DEFERRED/UNRUN; no scenario was executed during triage.** These are final-milestone reproduction plans, not current commands or new product requirements.

| Criterion | Future actions | Observable oracle |
| --- | --- | --- |
| C1/C2 | Open `launch.md`, close the sole reader using native close; repeat after reopening and with Command-W | Owned app remains running, zero visible reader/starter windows, zero Open panels/save dialogs. Observe the close transition and a bounded settled interval to catch delayed replacement windows, not only a final screenshot. Do not click Dock during the interval. |
| C1/C2 preservation | Open both nonempty fixtures, close one and then the other; repeat with the real empty document | First close retains the correct remaining content; final close produces no replacement window/picker. Empty file had a real reader/message before close. |
| C3 | From the post-close no-window state, invoke File > Open and cancel; invoke Command-O and select the Unicode fixture; repeat with menu selection | Each explicit action presents the native picker; cancellation remains windowless/running; selection produces exactly the correct filename/content reader, no starter. Native menu and keyboard events, not direct method calls, are the required future oracle. |
| C4 | Snapshot all copied source files; close through each native path and repeat open/close; inspect alerts and recheck files | No save prompt; bytes and nanosecond mtime unchanged for every file, including zero-byte input. |
| Scope preservation | Explicit Quit while windowless, then separate fresh no-file and explicit-file launches | Quit exits normally; #40 native startup arbitration remains intact. Dock reactivation remains native, not a newly specified pass/fail policy. |

Existing `DocumentOpeningUITests` pointers requiring expectation migration before future execution: `testNoFileLifecycleAndEmptyDocumentStayDistinct`, `testClosingOneOfMultipleDocumentsKeepsTheOtherReader`, and `testCommandWClosesReaderWithoutPromptOrSourceChange` currently expect a starter after final close. `testDroppingOnNoFileWindowOpensTheDocument` and two `AppearanceUITests` (`testEmptyDocumentAndNoFileWindowStayLegibleInLightAndDark`, `testDropErrorStaysLegibleInLightAndDark`) use that obsolete starter as setup. Preserve actual empty-reader, reader-drop/error readability and source-immutability coverage when migrating these; do not delete substantive assertions merely to obtain a pass. Migration/run status remains deferred unless worker records an actual source update; no new UI selector is claimed here.

### Current unit/build plan and evidence boundary

Worker performs proactive Swift diagnostics, a separate Debug app build, then relevant units using the project Xcode commands. Select `NeoMDTests/DocumentOpeningTests`, `NeoMDTests/MarkdownDocumentTests`, `NeoMDTests/MarkdownFileTypeTests`, `NeoMDTests/MarkdownTextDecoderTests`, and `NeoMDTests/DocumentLinkResolverTests`. No UI target or broad full-suite command now. Use fresh external logs/result bundles and record exact tested SHA, counts, failures/skips and limitations.

Update the lifecycle units that currently demand reopening the instruction. Cover final close, one-of-many close, repeated/unknown callbacks, repeated close/reopen cycles, termination, and coordinator forwarding with intact canonical section requests. Preserve the viewing DocumentGroup, native Open/Quit commands, read-only document implementation, reader cleanup and session-only folder grants. Units can verify production state/policy; they do not prove native no-window menus, timing, save-dialog absence or actual source mtime preservation.

Triage ran **no build, unit, UI/E2E or manual scripted app test**. Worker must append actual implementation/PR/head/build/unit evidence without converting the deferred interactions into passes. The complete earlier catalog, including #40 evidence, is retained unchanged.


## M1-P3 — Pointing-hand link cursor

[Issue #42](https://github.com/redrossa/neomd/issues/42) · [milestone 1](https://github.com/redrossa/neomd/milestone/1).
Triage inspection base: `56ca6e622ae4e6c1996c160347f4624a3bbb3d1b`, merged [PR #45](https://github.com/redrossa/neomd/pull/45). Runtime `openai-codex/gpt-6-astra`, high. Verdict **ACCEPTED for implementation**, not interaction acceptance. Canonical ordered stories #1–13/#40/#41 are closed; #42 is first open, then #43; #14 is not authorized.

### Current execution boundary

The latest user instruction **“pls dont do e2e testing”** supersedes historical catalog/issue statements requiring per-story interaction testing. No reviewer stage; worker Astra/low, coordinator verifies/merges. Build and relevant units only. All UI/E2E and manual scripted interactions below are **UNRUN/DEFERRED, not passed**, pending renewed authorization. Triage ran no build, unit tests or app interactions. Preserve #40 historical failures, #13 C5/#38, #36 and final-human deferrals; this appendix neither erases them nor claims milestone acceptance.

### Durable fixture and minimal implementation hypothesis

New focused data: [fixture README](fixtures/m1-p3-link-cursor/README-fixture.md), `cursor.md`, `nearby.md`, `img/badge.png`, and hash inventory. The PNG is byte-identical reuse of `fixtures/m1-12-images/img/small.png`; `img/absent.png` is deliberately absent. No remote image/server dependency. The README specifies exact copy/snapshot/isolation, controls and final-testing expectations. Previous broader link/image/cue fixtures remain unchanged; this compact fixture combines cursor-critical cases without importing unrelated rendering gates.

At this base, selectable ordinary text, generated footnotes and linked-image leaves use `MarkdownLinkedImageTextView`. Its initializer replaces `linkTextAttributes` with color and underline only, omitting the native cursor. The installed public AppKit `NSTextView.h` documents default link attributes as blue, single underline and pointing hand, applied temporarily to `.link` ranges; `NSAttributedString.h` documents cursor default as I-beam. This is source/API evidence for restoring `.cursor: NSCursor.pointingHand` in that existing dictionary, **not an observed baseline hover reproduction**. Keep AppKit owning text/attachment hit regions and cursor restoration; no overlay, global monitor, manual cursor stack or URL routing changes.

### Each criterion → future observable evidence (all UNRUN/DEFERRED)

| Criterion | Focused data/actions after renewed authorization | Expected observable outcome |
| --- | --- | --- |
| C1 text links | External reference, Local file, In-document target, long styled label (including each wrapped line), both footnote references and generated returns | Native pointing hand on actual linked text; no destination/panel opens or reading position change from hover. Quote/task links share the same behavior. |
| C2 linked images | Image-only internal image and mixed local/external images; hover edges/interior after an existing explicit bitmap-folder grant; also missing/loading linked fallback text | Hand over current clickable bitmap/text area, not only baseline or surrounding paragraph. No new grant/fetch/open action from hover. |
| C3 off-link restoration | Move to adjacent selectable prose, line-end whitespace, margins and unlinked pure/mixed images; repeat after scroll and 900/480 resize | Native normal cursor off links, selectable text not a hand region, no stuck hand or rectangular paragraph-wide capture. |
| C4 preserve interaction | Separately select text across a link; use existing mouse activation, Option-Tab/arrows/Return/Space/Escape, authored-link right-click/Control-click menu | Selection/action/menu behavior remains unchanged. Generated footnotes keep their existing exclusion from authored-link menus. Command-click routing changes remain #43, not a new test oracle here. |

Repeat representative cases in Light/Dark; record cursor shape through a genuinely pointer-observable method, not AX roles alone or screenshots without cursor. Record exact source/build/OS, actual results and copied-source bytes/mtime comparison. Preserve other app/browser sessions and clipboard; no copy action is necessary. These instructions are a future catalog, not permission to execute them now.

### Current worker build/unit validation needs

Add focused method-level regressions using real `MarkdownLinkedImageTextView`/`MarkdownLinkedImageContent` and parsed source, not a disconnected cursor-policy mock. Assert native `linkTextAttributes[.cursor]` is pointing hand while link color/underline remain; enumerate exact `.link` ranges for external/local/internal and generated references/returns; cover loaded linked attachments plus loading/unavailable fallback and unlinked text/image controls. Confirm no global cursor applied to text storage, no new dispatch on init/update/measure, stable selection and existing explicit dispatch/cleanup. A missing cursor expectation should catch this base configuration. These assertions establish configured native policy, **not real hover or off-link event behavior**. Add no event synthesis or hidden E2E substitute.

Existing non-E2E regression suites: `NeoMDTests/MarkdownLinkedImageTextTests`, `NeoMDTests/NativeInlineLeafTests`, `NeoMDTests/MarkdownLinkAttachmentTests`, `NeoMDTests/MarkdownWebLinksTests`, `NeoMDTests/MarkdownFootnotesTests`, `NeoMDTests/DocumentLinkResolverTests`, and `NeoMDTests/KeyboardTraversalTests`. Read test source and retain the method-level/native-host boundary; do not run `NeoMDUITests` or full-suite historical commands. Use proactive Swift diagnostics, separate Debug app build and targeted units with external DerivedData/fresh xcresults. Worker supplies actual new selectors, exact tested SHA, build/test commands, nonzero counts and failures/skips. No cursor-specific executable selector exists at triage and none is claimed passed.

Production scope should be the link-attribute dictionary in `NeoMD/Views/MarkdownLinkedImageText.swift`, necessary regression tests and these triage-owned fixture/docs. Preserve parser semantics, `.link` destinations, image loading/permissions, context-menu ownership, selection/key handlers, lifecycle, document identity, source immutability, and #43 permission/file-type decisions. If native public-attribute behavior proves insufficient, report that evidence before expanding to custom hit testing. Final combined milestone acceptance remains user-owned.

## M1-23 / #23 — settled external changes

[Issue #23](https://github.com/redrossa/neomd/issues/23) · [validation map and inspected non-interaction allowlist](m1-23-validation.md) · [inert snapshot packet and deferred final-testing recipe](fixtures/m1-23-refresh/README-fixture.md).

Final triage at `acc932318bda21a9cafde3e2ea53d612d1bcbe5a`: **ACCEPTED for implementation readiness only**; Astra/high runtime verified. No builds, tests, prototypes, file-watcher experiments, UI/E2E/manual scripted interactions or event/host substitutes were run. The unique packet covers metadata/body insertion, duplicate text context, deleted target neighbors, recovery and stable empty content, with logical burst/revision/failure scenarios. Worker supplies actual exact-head Debug build and inspected non-interaction unit evidence; none is asserted here.

The accepted scope is one refresh pipeline owned by the existing native document, public presenter invalidation with a shared background path-check/retry fallback, settled read-only snapshot preparation, generation/close/navigation guards, independent viewer content-locator/fraction remapping and quiet last-good recovery. Cached reopening is not refresh. #24 owns private bounded persisted reopen history; #22 public size commands and #17 encoding/initial-open policy are not prerequisites or added scope. #23 has the first contended capture/apply-method lease, not exclusive ownership of the reader file.

Actual native external-save/atomic-replace observation, coalescing interruption, reading-position/focus/selection, status/AX and interacted no-save/bytes/mtime outcomes remain **DEFERRED/UNRUN**, not passed. Preserve #14's complete deferral and #36/#38 failures and limited deferrals; this entry neither repairs nor extends waivers. Applicable known failures still block affected work. Combined native testing and milestone business acceptance remain user-owned.

Worker evidence: implemented and validated on integration base `1d06906579e9f320f6d15bc4bc4c75d053563ee5` (canonical `main` after #19). Debug build succeeded; one selector-scoped unit run passed **87/87 cases, 0 failed, 0 skipped** across 15 suites, covering the five new refresh/locator suites, the allowlisted existing selectors and, as coordinator-authorized integration regression, `DocumentNavigationBridgeTests` plus the four merged #19 table suites. All 11 staged artifacts re-verified by SHA-256; no oracle changed. Full command, per-suite counts and limits are in [m1-23-validation.md](m1-23-validation.md). No UI/E2E/manual/event/host test was run, so every native outcome above stays deferred.
