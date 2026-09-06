#!/bin/bash
#
# appearance-test-host.sh — run NeoMD's tests with a host controller for the
# appearance tests, and always put the Mac's appearance back.
#
# AppearanceUITests has to change the real macOS light/dark setting to prove that an
# open document follows it. A test runner is normally refused permission to send that
# Apple event, while a terminal that has already been granted Automation access for
# System Events is allowed. This script is that terminal: it runs xcodebuild, answers
# the test's switch requests, and restores the appearance it found — after the suite
# passes, after it fails, and after it is interrupted with Ctrl-C.
#
# Protocol. The UI test runner is sandboxed: it is signed with a read-only exception for
# the file system, so it can read anything but write only inside its own container. The
# handshake is therefore asymmetric — the test asks on standard output, and this script
# answers with a file the test only has to read.
#
#   1. This script records the current setting and creates a control directory, passed
#      to the test runner as NEOMD_UI_TEST_APPEARANCE_CONTROL_DIR.
#   2. The test prints `NEOMD-APPEARANCE-REQUEST <n> <Dark|Light> END`. The request is
#      matched by that exact shape, not by the prose around it, and the terminator means
#      a half-written line is never acted on.
#   3. This script applies it, reads the real setting back, and writes `response-<n>`
#      containing `ok <value>` or `error <reason>` into the control directory.
#   4. The test accepts the change only after reading the setting back itself, and
#      fails immediately on `error`.
#
# Usage:
#
#   Scripts/appearance-test-host.sh                       # whole suite
#   Scripts/appearance-test-host.sh -only-testing:NeoMDUITests/AppearanceUITests
#   Scripts/appearance-test-host.sh --rehearse-cleanup    # prove cleanup after a failure
#
# Any further arguments are passed to xcodebuild. NEOMD_DERIVED_DATA and
# NEOMD_RESULT_BUNDLE override the derived data and result bundle paths, which default
# to locations outside the repository.
#
# Limitations: the restore runs from a shell trap, so it covers a normal exit, a failed
# run, and SIGINT/SIGTERM. It cannot run if this script is killed with SIGKILL or the
# machine loses power; in that case set the appearance in System Settings > Appearance.
# The test's own teardown restores the setting too and fails the test when it cannot, so
# a run without this script still reports rather than hides the problem.

set -u
set -o pipefail

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
DERIVED_DATA=${NEOMD_DERIVED_DATA:-/tmp/NeoMD-DerivedData}
RESULT_BUNDLE=${NEOMD_RESULT_BUNDLE:-}
CONTROL_DIR=$(mktemp -d "${TMPDIR:-/tmp}/neomd-appearance-control.XXXXXX")
STREAM_LOG="$CONTROL_DIR/xcodebuild-output.log"
REQUEST_MARKER='NEOMD-APPEARANCE-REQUEST'
ORIGINAL=""
XCODEBUILD_PID=""
EXIT_STATUS=0
RESTORE_STATUS=0
REHEARSE_CLEANUP=0

log() {
    printf '[appearance-host %s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

read_dark_mode() {
    osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>&1
}

write_dark_mode() {
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $1" 2>&1
}

# Waits for the real setting to report the requested value, so nothing is assumed.
observe_dark_mode() {
    local wanted=$1 attempt observed
    for attempt in $(seq 1 40); do
        observed=$(read_dark_mode) || observed=""
        if [ "$observed" = "$wanted" ]; then
            printf '%s' "$observed"
            return 0
        fi
        sleep 0.25
    done
    printf '%s' "$observed"
    return 1
}

# Reads the requests the test printed and answers each one exactly once. An already
# written response is the record of having served a request, so re-reading the whole
# stream every pass is harmless.
serve_requests() {
    local identifier response value target observed message
    [ -f "$STREAM_LOG" ] || return 0
    while read -r identifier value; do
        [ -n "$identifier" ] || continue
        response="$CONTROL_DIR/response-$identifier"
        [ -e "$response" ] && continue

        case "$value" in
            Dark) target=true ;;
            Light) target=false ;;
            *)
                log "request-$identifier: refusing unknown value '$value'"
                printf 'error unknown request value %s' "$value" > "$response.tmp"
                mv "$response.tmp" "$response"
                continue
                ;;
        esac

        log "request-$identifier: switching the system appearance to $value"
        if ! message=$(write_dark_mode "$target"); then
            log "request-$identifier: FAILED — $message"
            printf 'error %s' "$message" > "$response.tmp"
            mv "$response.tmp" "$response"
            continue
        fi
        if observed=$(observe_dark_mode "$target"); then
            log "request-$identifier: system dark mode read back as $observed"
            printf 'ok %s' "$value" > "$response.tmp"
        else
            log "request-$identifier: FAILED — the setting stayed $observed"
            printf 'error the setting stayed %s' "$observed" > "$response.tmp"
        fi
        mv "$response.tmp" "$response"
    done < <(
        sed -n "s/.*$REQUEST_MARKER \([0-9][0-9]*\) \([A-Za-z][A-Za-z]*\) END.*/\1 \2/p" \
            "$STREAM_LOG" | sort -n -u
    )
}

restore_appearance() {
    local current message observed
    current=$(read_dark_mode) || current=""
    if [ "$current" = "$ORIGINAL" ]; then
        log "system appearance is $ORIGINAL, as it was before this run"
        return 0
    fi

    log "restoring the system appearance to $ORIGINAL (found $current)"
    if ! message=$(write_dark_mode "$ORIGINAL"); then
        log "ERROR: the appearance could not be restored: $message"
        log "ERROR: set it in System Settings > Appearance."
        RESTORE_STATUS=70
        return 1
    fi
    if observed=$(observe_dark_mode "$ORIGINAL"); then
        log "system appearance restored and read back as $observed"
        return 0
    fi
    log "ERROR: the appearance is still $observed after restoring it."
    log "ERROR: set it in System Settings > Appearance."
    RESTORE_STATUS=70
    return 1
}

# Stops the run before anything is restored. xcodebuild is started in its own process
# group so its test processes go with it rather than outliving the controller.
stop_xcodebuild() {
    local attempt
    [ -n "$XCODEBUILD_PID" ] || return 0
    kill -0 "$XCODEBUILD_PID" 2>/dev/null || return 0

    log "stopping xcodebuild ($XCODEBUILD_PID) and its test processes"
    kill -TERM "-$XCODEBUILD_PID" 2>/dev/null || kill -TERM "$XCODEBUILD_PID" 2>/dev/null
    for attempt in $(seq 1 40); do
        kill -0 "$XCODEBUILD_PID" 2>/dev/null || break
        sleep 0.25
    done
    if kill -0 "$XCODEBUILD_PID" 2>/dev/null; then
        log "xcodebuild did not stop in time; killing it"
        kill -KILL "-$XCODEBUILD_PID" 2>/dev/null || kill -KILL "$XCODEBUILD_PID" 2>/dev/null
    fi
    wait "$XCODEBUILD_PID" 2>/dev/null
}

cleanup() {
    trap - EXIT INT TERM
    stop_xcodebuild
    # Stop answering before restoring. A test process that somehow outlived the run can
    # no longer have a switch served to it, so nothing can change the appearance behind
    # this restore — the runner has no Automation access of its own, which is the whole
    # reason it has to ask.
    rm -rf "$CONTROL_DIR"
    [ -n "$ORIGINAL" ] && restore_appearance
    if [ "$RESTORE_STATUS" -ne 0 ]; then
        exit "$RESTORE_STATUS"
    fi
    exit "$EXIT_STATUS"
}

ARGUMENTS=()
for argument in "$@"; do
    case "$argument" in
        --rehearse-cleanup) REHEARSE_CLEANUP=1 ;;
        *) ARGUMENTS+=("$argument") ;;
    esac
done

if ! ORIGINAL=$(read_dark_mode); then
    log "ERROR: this terminal cannot read the system appearance: $ORIGINAL"
    log "ERROR: allow it to control System Events in System Settings > Privacy & Security > Automation."
    rm -rf "$CONTROL_DIR"
    exit 69
fi
log "original system dark mode: $ORIGINAL"
log "control directory: $CONTROL_DIR"

trap cleanup EXIT INT TERM

export TEST_RUNNER_NEOMD_UI_TEST_ASSISTED_APPEARANCE=1
export TEST_RUNNER_NEOMD_UI_TEST_APPEARANCE_CONTROL_DIR="$CONTROL_DIR"

if [ "$REHEARSE_CLEANUP" -eq 1 ]; then
    log "rehearsing cleanup: the live appearance test will fail on purpose after its first switch"
    export TEST_RUNNER_NEOMD_UI_TEST_APPEARANCE_REHEARSE_CLEANUP=1
    if [ ${#ARGUMENTS[@]} -eq 0 ]; then
        ARGUMENTS=(
            "-only-testing:NeoMDUITests/AppearanceUITests/testSystemAppearanceChangeUpdatesTheOpenDocumentInPlace"
        )
    fi
fi

COMMAND=(
    xcodebuild
    -project "$PROJECT_DIR/NeoMD.xcodeproj"
    -scheme NeoMD
    -destination 'platform=macOS'
    -derivedDataPath "$DERIVED_DATA"
)
[ -n "$RESULT_BUNDLE" ] && COMMAND+=(-resultBundlePath "$RESULT_BUNDLE")
COMMAND+=(test)
COMMAND+=(${ARGUMENTS[@]+"${ARGUMENTS[@]}"})

log "running: ${COMMAND[*]}"
cd "$PROJECT_DIR" || exit 1
# Job control puts xcodebuild in its own process group, so cleanup can stop the whole
# run. Its output is echoed as usual and copied where serve_requests can read it.
set -m
NSUnbufferedIO=YES "${COMMAND[@]}" < /dev/null > >(tee "$STREAM_LOG") 2>&1 &
XCODEBUILD_PID=$!
set +m

while kill -0 "$XCODEBUILD_PID" 2>/dev/null; do
    serve_requests
    sleep 0.25
done
serve_requests
wait "$XCODEBUILD_PID"
EXIT_STATUS=$?
log "xcodebuild exited with $EXIT_STATUS"
