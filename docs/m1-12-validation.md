# M1-12 validation record

Issue: [#12](https://github.com/redrossa/neomd/issues/12). PR: [#37](https://github.com/redrossa/neomd/pull/37). Base: `265cd3e30fd94e859d6811705caff09ae48de132`. Branch: `story/12-images`. The PR records the exact committed head and final build/unit results. Coordinator acceptance and milestone business acceptance are separate; no independent reviewer stage is claimed.

## Approved boundary

[User-approved option B](https://github.com/redrossa/neomd/issues/12#issuecomment-5589023958) defers **only** `DocumentReaderLayoutUITests/testReadingColumnReflowsAndKeepsCodeOverflowLocal` under [baseline defect #36](https://github.com/redrossa/neomd/issues/36). Its original body is unchanged. Its result is **BLOCKED/deferred, NOT passed**; final milestone acceptance still requires resolving it. The initial-margin regression is not deferred.

The narrow correction uses `ScrollPosition()` (no eager edge/point request; default `Never` ID type), retaining the mutable binding, explicit point/ID navigation and existing document-generation, cancellation, user-scrolling and resize-restoration guards. The new focused test independently checks initial/wide/narrow top margin **>=30pt**, the leading edge of the centered 760pt column, width constraints, increasing prose height at narrow width, title visibility and unchanged source bytes/mtime, in Light and Dark. It does not exercise or replace the full selection/overflow reflow gate.

## Current-source nonclipboard evidence (2026-09-08)

All listed successful selectors have zero skips and zero expected failures. Bundles are temporary local evidence; durable fixtures and test methods are checked in. Production/test inputs are unchanged between these runs and implementation commit `2edad0fb54d321107a5578c7a6ce1d6764f1adb9`; only fixture README factual prose was corrected afterward. On that committed head, Debug build passed and `/tmp/NeoMD-12-CommittedHead.xcresult` passed 138/0/0 (all136 units plus focused margin and repeated image scroll), zero expected failures. This subsequent documentation-only commit records the PR link; the PR records the exact final head and post-commit checks.

| Bundle under `/tmp/` | Actual result and scope |
| --- | --- |
| `NeoMD-12-ApprovedUnits.xcresult` | 136 passed: entire `NeoMDTests` target (Swift Testing and XCTest native-host tests) |
| `NeoMD-12-FocusedMargin.xcresult` | 2 passed: `DocumentReaderLayoutUITests/testInitialReadingMarginAndTopPositionSurviveResize`, `DocumentImageUITests/testImageReaderRepeatedScrollingRetainsResponsiveContent` |
| `NeoMD-12-ApprovedImages.xcresult` | **9 passed, 1 failed**: all nonclipboard `DocumentImageUITests` selected. Plain-sandbox test failed closed because this invocation omitted the required plain-app environment variable. Not a passing batch. |
| `NeoMD-12-ApprovedPlain.xcresult` | 1 passed: `DocumentImageUITests/testPlainSandboxFolderGrantsAndArbitraryHostNetworking`, after a fresh separate plain Debug build and correct environment. Completes all ten nonclipboard image methods across the two runs. |
| `NeoMD-12-ApprovedNavigation.xcresult` | 8 passed: entire `DocumentLinkNavigationUITests` (internal IDs, headings, footnotes, keyboard, deep/mixed containers and file navigation) |
| `NeoMD-12-ApprovedResize.xcresult` | 4 passed: `DocumentReaderLayoutUITests/testResizeAndFullScreenPreserveMiddleAndTallReadingPositions`, `testLargeLazyDocumentResizeRoundTripPreservesExactMiddlePassage`, `testIntentionalKeyboardAndWheelScrollingInterruptResizeRestoration`, `testNestedQuoteLeafReadingPointSurvivesLazyResize` |
| `NeoMD-12-ApprovedLinks.xcresult` | 7 passed: all four `NearbyFileLinkUITests`; `WebLinkUITests/testWebLinkFormsAreLinksAndOpeningLaunchesNothing`, `testActivatingWebLinkOpensDefaultBrowserAndKeepsReadingPosition`, `testKeyboardWebLinkOpensDefaultBrowserAndKeepsReadingPosition` |
| `NeoMD-12-ApprovedStructure.xcresult` | 3 passed: `DocumentReaderLayoutUITests/testDocumentStructureAndEmphasis`, `testDarkReaderRemainsUnclutteredAtNarrowWidth`, `testNestedQuotationsAndHighlightedCodeInBothAppearances` |

Logs have corresponding `/tmp/neomd-12-{focused-margin,approved-images,approved-plain,approved-navigation,approved-resize,approved-links,approved-structure}.log` names. Fresh plain build succeeded at `/tmp/neomd-12-approved-plain-build.log`. All units passed (`/tmp/neomd-12-approved-units.log`); Python controller tests passed 5/0 (`/tmp/neomd-12-approved-controller.log`), and both uniquely named private-board Swift probes passed without accessing the general clipboard (`/tmp/neomd-12-approved-private-guardian.log`). Primary Swift LSP checked all 20 changed app/test Swift paths with zero errors.

The first new focused-test attempt (`NeoMD-12-ApprovedMargin.xcresult`) had one pass and one failure: a newly authored assertion wrongly equated the intrinsic text AX midpoint with the column midpoint. Its correction measures the leading edge of the actual centered column, not the text's used width. Original >=30pt and width/reflow assertions were retained, and the corrected test passes. This historical failure is not hidden or counted as success.

## Criteria mapping

1. **Local and HTTP(S), aspect ratio and sensible size:** `MarkdownImagesTests` decoder/path/layout tests; local image UI covers PNG/JPEG/GIF first frame/SVG with inert script fixture, original colours, adjacent/mixed images and screenshot bitmap footprints within ±2pt. `testImagesRefitDuringActualWindowResize` and `testNativeLinkedImagesWrapAndResizeWithoutUpscalingInBothThemes` cover actual native resize and no upscaling. Remote test uses controlled HTTP; plain signed-app test proves real HTTP and HTTPS to `httpbin.org`, not merely loopback ATS evidence.
2. **Documented picture form:** parser tests, malformed/literal fallback tests and `testPictureSourcesFollowAppearanceAndUpdateLive`; matching light/dark sources and `<img>` fallback. General HTML rendering remains out of scope.
3. **Original colours/live appearance:** screenshot sampling in both themes; live yellow/blue/yellow and fallback/blue/fallback transitions. Tests use the existing app-scoped appearance channel, not a claimed manual system-settings run.
4. **Failures/access:** loader classifies missing/inaccessible/undecodable/unavailable and refuses unsupported schemes; UI checks alt/status, empty-alt placeholder, retained text, missing/corrupt/404/refused/TLS cases. Plain signed-app test checks keyboard-accessible explicit folder action, Cancel, unrelated grant, successful read-only image-folder grant and retained text. No automatic permission prompt.
5. **Responsive loading:** external-server readiness and explicit release handshake holds slow response until loading status and retained `REMOTE END` are asserted. Repeat-image scrolling is uninstrumented and passes. Store tests verify same-URL cancellation/publication identity, idempotence and owner release.
6. **Existing asset links:** linked-image pointer/context-menu, heading/prose keyboard activation, native conversion and policy single-dispatch tests; existing nearby/web/internal regressions pass. No uploading, editing, automatic URL launching or general renderer migration introduced.

All image UI cases use copied fixtures with byte/mtime snapshots and owned app cleanup. Native linked-image leaves alone use the read-only NSTextView adapter; unlinked images/ordinary leaves retain SwiftUI. Unit tests cover finite width-constrained measurement, unchanged-update selection preservation and cleanup of retained native/AX objects.

## Clipboard evidence reuse — no new clipboard window

`NeoMD-12-ExclusiveClipboard.xcresult`: **3 passed, zero failures/skips/expected failures**, in the explicitly approved exclusive window, using the independent in-memory guardian. Selectors: `DocumentImageUITests/testNativeLinkedImageParagraphKeepsProseSelectionReadOnly`, `WebLinkUITests/testNativeSelectionInLinkBearingParagraphStillCopiesText`, `WebLinkUITests/testContextualMenuRevealsDestinationWithoutOpening`. Guardian restored that window's pre-test snapshot; previously lost original contents remain unrecoverable. Command-startup-failure cleanup also passed (`/tmp/neomd-12-clipboard-startup-failure.log`).

Relevant source-delta assessment: since that gate, the only lasting production delta is the reader's initial `ScrollPosition` construction/comment. Native text/attachment conversion, selection, menus, URL dispatch, guardian/controller/lease and copy-test bodies are unchanged. The added focused layout test never copies. New nonclipboard image/native-link/resize/navigation runs verify the affected initial placement and target reachability. Therefore prior copy evidence is reused for unchanged copy behavior, **not represented as a new exact-head clipboard execution**. Any later copy-path change requires reassessment and a newly approved exclusive window. The user may copy/cut freely now; do not run the full image or web class without the documented exclusions.

## Reproduce current gates

From the repository root, use the scheme/project/macOS destination below and fresh result-bundle paths. Serialize UI tests. Build a separate plain artifact before the real sandbox case:

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-12-Plain-DerivedData build
TEST_RUNNER_NEOMD_PLAIN_APP_PATH=/tmp/NeoMD-12-Plain-DerivedData/Build/Products/Debug/NeoMD.app \
python3 Scripts/image_test_controller.py --timeout 600 -- \
  xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-12-DerivedData -parallel-testing-enabled NO \
  -resultBundlePath /tmp/NeoMD-12-RecheckImages.xcresult \
  -only-testing:NeoMDUITests/DocumentImageUITests \
  -skip-testing:NeoMDUITests/DocumentImageUITests/testNativeLinkedImageParagraphKeepsProseSelectionReadOnly test
```

Use the same controller/Xcode prefix with each fully qualified selector in the table (prefix each with `-only-testing:NeoMDUITests/`). Navigation and nearby-file classes can be selected whole. Do **not** select the whole WebLink or layout class: those include general-clipboard tests or the deferred full-reflow gate. Unit command: same Xcode prefix, `-only-testing:NeoMDTests test`. Controller/private clipboard probe commands and safety contract: [image-test-controller.md](image-test-controller.md).

## Durable baseline reproduction and unresolved milestone gate

The complete fixture generator, open-via-native-panel setup, resize/scroll/selection operations and cleanup are in the unchanged `NeoMDUITests/DocumentReaderLayoutUITests/testReadingColumnReflowsAndKeepsCodeOverflowLocal`. It creates `layout.md` in an owned temporary directory, with title, 18 repeated prose phrases, 900-character unbroken token, long heading, quote/list and long local code overflow. No unavailable external asset is required.

To reproduce the accepted-base control, create a clean detached worktree at `265cd3e30fd94e859d6811705caff09ae48de132`, build/test there with a separate DerivedData directory, and run only that selector. The external controller is from this story (not present at the base): invoke its absolute path while the working directory is the base checkout.

```sh
# In a clean detached checkout at the base SHA; CONTROLLER points to this story's script.
python3 "$CONTROLLER" --timeout 240 -- xcodebuild -project NeoMD.xcodeproj \
  -scheme NeoMD -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-12-BaseProbe-DerivedData -parallel-testing-enabled NO \
  -resultBundlePath /tmp/NeoMD-12-BaseRecheck.xcresult \
  -only-testing:NeoMDUITests/DocumentReaderLayoutUITests/testReadingColumnReflowsAndKeepsCodeOverflowLocal test
```

Actual base run: initial margin passed, then native event-loop nonprogress while revealing the long heading at ~12s, timeout240. `/tmp/neomd-12-actual-base-reflow.log`, `/tmp/NeoMD-12-ActualBaseReflow.xcresult` (interrupted), `/tmp/neomd-12-actual-base-hang.sample.txt`. The owned app was sampled and terminated; clean control worktree removed. Samples show SwiftUI selection/layout graph churn; cause remains unknown (not proof of an OS defect or identical causes across runs). Controller process-group cleanup does not necessarily remove LaunchServices-spawned apps: inspect exact executable path/PID ownership and terminate only the test-owned instance before removing a control worktree.

Preserved story trials: eager `.top` initial margin7pt; `y:0` trial -25pt; no-eager/default, original Int initializer, request-only binding and direct-Text isolation still encountered later reflow hangs. Logs `/tmp/neomd-12-{remaining-layout,isolated-reflow,origin-reflow,unpositioned-reflow,base-initializer-reflow,request-only-reflow,direct-text-reflow}.log` retain those failures. All diagnostic alternatives except the approved default initializer were reverted. No full-reflow pass is claimed.

Final milestone still requires #36 repair/full unchanged reflow, combined E2E, real system appearance and offline/relaunch scenarios, broader public asset availability and VoiceOver speech-order checks. No milestone acceptance or issue closure follows from this record alone.
