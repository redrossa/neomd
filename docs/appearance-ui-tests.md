# Running the appearance UI tests

`NeoMDUITests/AppearanceUITests.swift` verifies that the reader follows the Mac's light
and dark appearance. Most of it needs nothing special. One test —
`testSystemAppearanceChangeUpdatesTheOpenDocumentInPlace` — changes the **real** macOS
setting while a document is open, because that is the only way to show that an open
document follows the system rather than an appearance the test pinned itself.

This page explains how to run that test, and what guarantees the tester's own setting is
put back.

## Running

```sh
# Whole suite, with the host controller driving the appearance switches.
Scripts/appearance-test-host.sh

# Only the appearance tests.
Scripts/appearance-test-host.sh -only-testing:NeoMDUITests/AppearanceUITests

# Prove the cleanup: the live test fails on purpose after its first real switch.
Scripts/appearance-test-host.sh --rehearse-cleanup
```

Further arguments are passed to `xcodebuild`. `NEOMD_DERIVED_DATA` and
`NEOMD_RESULT_BUNDLE` override the derived data and result bundle paths, which default
to locations outside the repository.

A plain `xcodebuild … test` still runs everything else. Without assistance the live
appearance test reports its limitation and **skips**, which is a recorded gap rather than
a pass.

## Why a host controller

A UI test runner is normally refused permission to send Apple events to System Events,
so it cannot change the appearance by itself. A terminal that already has Automation
access for System Events can. `Scripts/appearance-test-host.sh` is that terminal: it
starts `xcodebuild`, answers the test's requests, and restores the appearance afterwards.

The two sides talk through files in a control directory, not through the build log:

| Step | Who | What |
| --- | --- | --- |
| 1 | host | Records the current setting, creates the control directory, exports it to the runner as `NEOMD_UI_TEST_APPEARANCE_CONTROL_DIR` |
| 2 | test | Writes `request-<n>` containing `Dark` or `Light` |
| 3 | host | Applies it with System Events, reads the real setting back, writes `response-<n>` containing `ok <value>` or `error <reason>` |
| 4 | test | Accepts the change only after reading the setting back itself; an `error` fails the test immediately instead of timing out |

Nothing in this handshake depends on log formatting or timing guesses, so a run either
completes the switch or fails with the reason.

A person can also assist without the script: run with
`TEST_RUNNER_NEOMD_UI_TEST_ASSISTED_APPEARANCE=1` and change the appearance in System
Settings when the test prints its prompt.

## How the appearance gets put back

Two independent mechanisms, because a test that leaves a Mac in the wrong appearance is
a defect of the test:

1. **The test's teardown.** `tearDownWithError` restores the setting the test found,
   using the same assistance the run was given, and only believes it after reading the
   real setting back. A restoration it cannot verify is thrown, so the test fails with
   an explanation instead of finishing quietly. This covers a failure at any point after
   the first switch, including one that never reaches the test's own switch-back.
2. **The host controller's trap.** The script restores the setting on a normal exit, a
   failed run, and `Ctrl-C`/`SIGTERM`, and it exits non-zero if it could not read the
   restored value back. This covers a test process that dies without running teardown.

Neither can help if the script itself is `SIGKILL`ed or the machine loses power. In that
case, set the appearance in System Settings > Appearance.

`--rehearse-cleanup` exercises the first mechanism deliberately: the test fails
immediately after its first real switch, with the switch-back never reached, so the run
ends with a failed test and a restored appearance.

## What the tests measure

Appearance cannot be judged from the element tree, so the tests sample the pixels of real
window screenshots: page backgrounds, text contrast against the surface behind it, the
selection highlight, the quotation rule, list markers, the thematic break, and the
unbroken run of marked pixels that distinguishes an underline from letterforms. The
measurements are attached to the test results as evidence, not only asserted.
