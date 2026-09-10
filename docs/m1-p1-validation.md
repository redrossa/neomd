# M1-P1 / #40 validation

Issue: https://github.com/redrossa/neomd/issues/40. Base: `861a1ca4c6c3efa7621333c5db19fac0aa0ad772`. Worker runtime verified `openai-codex/gpt-6-astra`, low. Coordinator acceptance remains pending; no issue checkbox, closure or merge is performed by the worker.

## Implementation and criteria

- C1: `NeoMDApp` restores the viewing `DocumentGroup`'s native launch default and suppresses automatic launch of the instruction `Window`. No custom picker or launch timer.
- C2: explicit document-opening launch remains entirely under native document-group arbitration; no unconditional startup panel is introduced.
- C3: the existing nonterminating application delegate, native Open command and read-only command group remain intact. The instruction scene remains registered but launch-suppressed.
- #41 is **not implemented**: reader disappearance still explicitly presents the instruction scene after last close. Actual empty Markdown still presents its own reader/message. Rendering, identity, permissions, file access, drops and section routing are unchanged.

Opening tests cover native startup selection, Unicode/space/uppercase-extension cold opening, windowless cancellation and menu/keyboard commands. Historical opening/appearance setup now reaches the retained instruction scene via last close rather than startup. Rendered text selectors retain exact content and position assertions while accommodating native text roles. New startup scenarios read the triage-authored fixture files; their manifest bytes are unchanged. The catalog's historical prefix is preserved byte-for-byte.

## Current validation policy

During implementation the user explicitly requested **“pls dont do e2e testing”**. All further UI/E2E and manual scripted flows were stopped. Final-head UI criteria, screenshots/video/transient-window inspection and uncompleted regressions are **deferred/unverified, not passed**. This is an explicit testing waiver, not evidence of acceptance or a claim that a failure passed. No clipboard mutation or host permission/toolchain/sandbox change was made.

## Build and units

Run from the story checkout with Xcode 26.3 on macOS 26.5.1:

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-40-Plain build
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-40-DerivedData -parallel-testing-enabled NO \
  -only-testing:NeoMDTests/DocumentOpeningTests \
  -only-testing:NeoMDTests/MarkdownFileTypeTests \
  -only-testing:NeoMDTests/MarkdownTextDecoderTests \
  -resultBundlePath /tmp/neomd-40-units.xcresult test
```

Build passed (`/tmp/neomd-40-final-build.log`); units **20 passed, 0 failed, 0 skipped** (`/tmp/neomd-40-units.log`, result bundle above). These first completed on the uncommitted source tree; PR/handoff records the exact committed-head rerun. Proactive Swift diagnostics initially confirmed all three changed Swift files clean; a later batch confirmed two and timed out on one (not treated as clean). Xcode compilation passed. Final `git diff --check` and session diagnostics are recorded in the handoff.

## Pre-waiver UI history — not final-head acceptance

1. `/tmp/neomd-40-focused.xcresult` and `.log`: completed before the waiver, **24 passed, 0 failed, 0 skipped** (20 units + four UI methods). Actual UI selectors under `NeoMDUITests/DocumentOpeningUITests/`:
   - `testStartupPickerSelectsDocumentWithoutStarterWindow`
   - `testColdExplicitUnicodeFileOpensWithoutStartupPanel`
   - `testMenuAndCommandOInvokeTheNativeOpenPanel`
   - `testNoFileLifecycleAndEmptyDocumentStayDistinct`

   At that time startup tests used inline fixture contents. They checked settled window counts, correct content, Escape, File > Open and Command-O; selection/cold-open tests compared bytes and fixed mtimes. They did not inspect transient video. They have since been wired to canonical triage fixtures and have **not** been rerun under the waiver.

2. `/tmp/neomd-40-regression.log`: a serialized batch selected all `DocumentOpeningUITests` plus appearance `testDropErrorStaysLegibleInLightAndDark`, `testEmptyDocumentAndNoFileWindowStayLegibleInLightAndDark`, and `testOpeningInLightAndDarkRendersCoherentDocumentContent`. It hit the 500-second tool timeout. Its `.xcresult` is incomplete (missing Info.plist), not a successful result bundle.
   - Log records 11 completed method passes, including pinned light/dark empty/startup and drop-error scenarios, two-reader close, Command-W, drops and title-location coverage.
   - Appearance coherence failed in test setup waiting for startup panel dismissal after Escape. The helper now clicks the panel-scoped native Cancel button; correction is unverified.
   - Picker-cancellation regression failed looking for heading `Start` as a TextView. Heading queries now match the exact value independent of AX role, retaining the same content oracle; correction is unverified.
   - Same-document reopening lost its automation connection while looking for the File menu. The batch never completed. No successful revalidation or equivalence to prior hangs is claimed.
   - At waiver receipt no xcodebuild/UI runner remained. Only the owned app process at `/tmp/NeoMD-40-DerivedData/Build/Products/Debug/NeoMD.app` (PID 76976) remained and was terminated explicitly; no unrelated app/process was killed. Artifacts were retained.

These observations do not establish a production defect from the two scene-default changes, but unresolved UI results remain visible rather than being silently waived into passes. Broader warm-open helpers in other suites were not exercised or broadly rewritten. Full combined milestone E2E, saved-state launches, VoiceOver, actual system appearance and all historical #36/#38 deferrals remain user-owned future validation.
