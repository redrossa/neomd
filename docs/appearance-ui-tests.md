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

# Check the controller itself, against stubs. Needs no Xcode, no graphical session, no
# Automation access, and never touches the real setting.
Scripts/appearance-test-host-tests.sh
```

The controller owns the project, scheme, destination, build directory and result bundle,
so it accepts only arguments that cannot take those away from it: `--rehearse-cleanup`,
`-only-testing`/`-skip-testing` (both spellings), `-test-iterations`,
`-test-repetition-relaunch-enabled`, `-retry-tests-on-failure`,
`-run-tests-until-failure`, `-parallel-testing-enabled`, `-test-timeouts-enabled`,
`-quiet` and `-verbose`. Anything else — including `-derivedDataPath`,
`-resultBundlePath` and build settings such as `SYMROOT=` — is refused with `64` before
anything is built, with the supported list printed.

`NEOMD_DERIVED_DATA` and `NEOMD_RESULT_BUNDLE` override where the build and the result
bundle go; both default to locations outside the repository, and a relative path is
resolved against the directory the script was called from rather than the project.

`NEOMD_DERIVED_DATA` names a **parent**, not the build directory: each run creates a
fresh `run-XXXXXXXX` directory inside it, builds there, and removes that directory
afterwards. Runs therefore never share build products, and the parent may be reused —
including by concurrent runs — but every run is a cold build. `NEOMD_KEEP_DERIVED_DATA=1`
keeps the run's own directory for inspection; a failing run prints how to ask for that.

The controller's exit status is the run's own status, including a failed launch of
`xcodebuild`. Otherwise it is `130` for `SIGINT`, `143` for `SIGTERM`, `69` when the
terminal cannot read the appearance at all, `70` when the appearance could not be
restored, `71` when something the run owned could not be stopped, and `72` if it somehow
exited before the run produced a status. **`0` means the run finished and said so; it is
never what an interrupted run reports.**

A plain `xcodebuild … test` still runs everything else. Without assistance the live
appearance test reports its limitation and **skips**, which is a recorded gap rather than
a pass.

## Why a host controller

A UI test runner is normally refused permission to send Apple events to System Events,
so it cannot change the appearance by itself. A terminal that already has Automation
access for System Events can. `Scripts/appearance-test-host.sh` is that terminal: it
starts `xcodebuild`, answers the test's requests, and restores the appearance afterwards.

The handshake is asymmetric, because the UI test runner is sandboxed: it is signed with a
read-only exception for the file system, so it can read anything but write only inside
its own container. It therefore asks on standard output and is answered with a file:

| Step | Who | What |
| --- | --- | --- |
| 1 | host | Records the current setting, creates the control directory, exports it to the runner as `NEOMD_UI_TEST_APPEARANCE_CONTROL_DIR` |
| 2 | test | Prints `NEOMD-APPEARANCE-REQUEST <id> <Dark\|Light> END`, where `<id>` is a fresh 16-character lowercase-hex token |
| 3 | host | Matches that exact shape in the build output, applies it with System Events, reads the real setting back, writes `response-<id>` containing `ok <value>` or `error <reason>` |
| 4 | test | Reads the response file, checks that it names the appearance the test asked for, and accepts the change only after reading the real setting back itself; an `error` fails the test immediately instead of timing out |

Only the request travels through the output stream, and it is matched by a marker,
identifier and terminator rather than by prose, so a half-written line is never acted on
and the surrounding log wording does not matter. A run either completes the switch or
fails with the reason.

The identifier is random rather than counted, because Xcode starts a **new runner
process** for every repetition of a test. A per-process counter restarts at 1 there,
while the controller keeps the answers it has already written for the whole `xcodebuild`
invocation and treats an existing one as a request it has already served — so a second
repetition would silently read the first one's answer. A fresh identifier per request
cannot collide with one from an earlier process, and the test additionally refuses an
answer that does not name the appearance it asked for.

A person can also assist without the script: run with
`TEST_RUNNER_NEOMD_UI_TEST_ASSISTED_APPEARANCE=1` and change the appearance in System
Settings when the test prints its prompt.

## How the appearance gets put back

Two independent mechanisms, because a test that leaves a Mac in the wrong appearance is
a defect of the test:

1. **The test's teardown.** `tearDownWithError` restores the setting the test found,
   using the same assistance the run was given, and only believes it after reading the
   real setting back. It runs after the test method whatever happened inside it, so it
   covers a failure at any point after the first switch, including one that never
   reaches the test's own switch-back.

   A restoration it cannot verify is **printed and attached to the results** with the
   appearance to set by hand, and thrown. The printing is the part that matters in
   practice: XCTest stops recording failures for a test that has already failed, and a
   restoration can only fail on a run that failed already — a run whose own switches all
   worked has nothing left to restore. Either way the instruction is never swallowed.
2. **The host controller's trap.** The script restores the setting on a normal exit, a
   failed run, and `Ctrl-C`/`SIGTERM`, and it exits non-zero if it could not read the
   restored value back. This covers a test process that dies without running teardown.

   It stops the run *before* restoring, and it stops the run itself rather than its
   leader. `xcodebuild` is started in a process group of its own, but the group leader
   exiting proves nothing: a descendant can ignore `SIGTERM` and outlive it, and macOS
   starts the UI test runner reparented to launchd in a **group of its own**, so it was
   never in that group to begin with. The controller therefore re-checks what it owns —
   members of that process group, and processes running out of this run's build products
   — until nothing is left, escalating from `SIGTERM` to `SIGKILL` and finally reporting
   `71` rather than restoring over a survivor in silence.

   Ownership is decided by a process group this run created and by the build directory
   this run created for itself, which is why that directory is fresh per run: a shared or
   reused one says only that a process was built from the same place, not that this
   invocation started it. A pre-existing app, another concurrent run under the same
   parent, and anything under an unrelated directory are all left alone.

   The control directory is removed before the restore as well, so nothing can have
   another switch *served* to it afterwards. That is a guarantee about the controller,
   not about the runner: on a host where the runner has Automation access it changes the
   setting directly, which is exactly why the run is stopped first rather than merely cut
   off from the handshake.

Neither can help if the script itself is `SIGKILL`ed or the machine loses power. In that
case, set the appearance in System Settings > Appearance.

`--rehearse-cleanup` exercises the first mechanism deliberately: the test fails
immediately after its first real switch, with the switch-back never reached, so the run
ends with a failed test and a restored appearance.

`Scripts/appearance-test-host-tests.sh` exercises the second one, and the paths a real
run does not reach. It runs the checked-in controller unmodified against a stubbed
`osascript` that keeps the "appearance" in a file and a stubbed `xcodebuild` that plays
one scenario, so the real setting is never touched: a passing run, a failing run, a run
that could not be launched, `SIGINT` and `SIGTERM` mid-run, a descendant that ignores
`SIGTERM`, a runner outside the process group, requests from separate runner processes, a
refused restoration, and requests that are not the agreed shape. It also covers what the
run may touch: a relative or space-containing parent, a refused argument, an owned
survivor reported as `71`, retention, and processes this run did not start — a
pre-existing app under the configured parent, another run's process beside it, and one
under a different directory — surviving a run that finishes and one that is cancelled.
Each scenario checks both the status reported and the state left behind, because either
one alone can hide a defect.

The processes those scenarios stand in for are compiled by the harness rather than copied
from `/bin`, because macOS `SIGKILL`s a relocated platform binary; they need `cc` and
`/usr/bin/python3`, and the harness says so and skips when they are missing.

## What the tests measure

Appearance cannot be judged from the element tree, so the tests sample the pixels of real
window screenshots: page backgrounds, text contrast against the surface behind it, the
selection highlight, the quotation rule, list markers, the thematic break, and the
unbroken run of marked pixels that distinguishes an underline from letterforms. The
measurements are attached to the test results as evidence, not only asserted.
