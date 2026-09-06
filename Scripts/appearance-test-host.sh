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
#   2. The test prints `NEOMD-APPEARANCE-REQUEST <id> <Dark|Light> END`. The request is
#      matched by that exact shape, not by the prose around it, and the terminator means
#      a half-written line is never acted on. The identifier is a compact random
#      lowercase-hex token, fresh for every request, so it is unique across the runner
#      processes Xcode starts for repeated tests — a counter would restart at 1 on a
#      relaunch and collide with an answer already written for this invocation.
#   3. This script applies it, reads the real setting back, and writes `response-<id>`
#      containing `ok <value>` or `error <reason>` into the control directory.
#   4. The test accepts the change only after checking that the answer names the
#      appearance it asked for and reading the setting back itself, and fails
#      immediately on `error`.
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
# Exit status. A run's own status is passed through unchanged, including a failed launch
# of xcodebuild. Otherwise:
#
#   130  interrupted with SIGINT      143  terminated with SIGTERM
#   69   this terminal cannot read the appearance at all
#   70   the appearance could not be restored     (reported instead of the run's status)
#   71   something this run owns could not be stopped
#   72   this script exited before the run produced a status
#
# An exit of 0 therefore means the run finished and said so; it is never the default.
#
# Limitations: the restore runs from a shell trap, so it covers a normal exit, a failed
# run, and SIGINT/SIGTERM. It cannot run if this script is killed with SIGKILL or the
# machine loses power; in that case set the appearance in System Settings > Appearance.
# The test's own teardown restores the setting too and fails the test when it cannot, so
# a run without this script still reports rather than hides the problem.
#
# Scripts/appearance-test-host-tests.sh exercises the paths above against stubs, without
# touching the real setting.

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
XCODEBUILD_PGID=""
# Empty until xcodebuild has actually been waited on, so an exit before the run produced
# a status can never be reported as a success.
RUN_STATUS=""
RESTORE_STATUS=0
STOP_STATUS=0
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
# stream every pass is harmless. Identifiers are unique per request rather than counted,
# so a repetition's runner cannot be handed the answer written for an earlier one.
serve_requests() {
    local identifier response value target observed message
    [ -f "$STREAM_LOG" ] || return 0
    while read -r identifier value; do
        [ -n "$identifier" ] || continue
        # The identifier names a file, so only the shape the test emits is accepted.
        case "$identifier" in
            *[!0-9a-f]*)
                log "ignoring a request with a malformed identifier"
                continue
                ;;
        esac
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
        sed -n "s/.*$REQUEST_MARKER \([0-9a-f]\{8,32\}\) \([A-Za-z][A-Za-z]*\) END.*/\1 \2/p" \
            "$STREAM_LOG" | awk '!seen[$0]++'
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

# Lists what this run owns, one `<pid> <command>` per line.
#
# Two things are owned, and they are not in the same place. xcodebuild is started in a
# process group of its own, so its own children are found by that group. The UI test
# runner is not one of them: macOS launches it, and it comes up reparented to launchd in
# a process group of its own — and so does the app it drives. Those are found by
# identity: they run out of *this* run's build products.
#
# The comparison is between resolved directories, not spellings. A command line reports
# the path the process was launched with, and /tmp is a symlink to /private/tmp, so the
# same directory has more than one name; comparing text alone silently misses the app
# under test. Only a path that really is this run's build products counts, so a separate
# Xcode or app session is never matched.
owned_processes() {
    local self=$$ group=$XCODEBUILD_PGID physical
    physical=$(cd "${DERIVED_DATA%/}" 2>/dev/null && pwd -P)
    ps -Ao pid=,pgid=,stat=,command= 2>/dev/null | while read -r pid pgid stat command; do
        [ "$pid" = "$self" ] && continue
        case "$stat" in Z*) continue ;; esac
        case "$command" in *'<defunct>'*) continue ;; esac
        if [ -n "$group" ] && [ "$pgid" = "$group" ]; then
            printf '%s %s\n' "$pid" "$command"
            continue
        fi
        [ -n "$physical" ] || continue
        case "$command" in
            */Build/Products/*)
                # Everything before the first /Build/Products/ is the derived data path
                # this process was launched from, unless the command started with
                # something else — in which case it is not a directory and resolves to
                # nothing.
                [ "$(cd "${command%%/Build/Products/*}" 2>/dev/null && pwd -P)" = "$physical" ] \
                    && printf '%s %s\n' "$pid" "$command"
                ;;
        esac
    done
}

# Signals everything this run owns: the process group, and each owned process by pid so
# a member outside that group, or one whose group leader has already gone, is covered.
signal_owned() {
    local signal=$1 pid command
    if [ -n "$XCODEBUILD_PGID" ]; then
        kill -"$signal" "-$XCODEBUILD_PGID" 2>/dev/null || true
    elif [ -n "$XCODEBUILD_PID" ]; then
        kill -"$signal" "$XCODEBUILD_PID" 2>/dev/null || true
    fi
    while read -r pid command; do
        [ -n "$pid" ] || continue
        kill -"$signal" "$pid" 2>/dev/null || true
    done < <(owned_processes)
}

# Waits until nothing this run owns is left, checking before it ever sleeps.
wait_for_owned_to_stop() {
    local attempts=$1 attempt
    for attempt in $(seq 1 "$attempts"); do
        [ -n "$(owned_processes)" ] || return 0
        sleep 0.25
    done
    [ -n "$(owned_processes)" ] || return 0
    return 1
}

report_owned() {
    local prefix=$1 pid command
    while read -r pid command; do
        [ -n "$pid" ] || continue
        log "$prefix $pid $command"
    done < <(owned_processes)
}

# Stops the run, and everything it owns, before anything is restored.
#
# Whether the group leader is still alive answers the wrong question: a descendant can
# ignore TERM and outlive it, and the UI test runner was never in that group to begin
# with. So the owned set itself is re-checked until it is empty, and a set that will not
# go is escalated to KILL and finally reported rather than passed over in silence.
stop_run() {
    [ -n "$XCODEBUILD_PID" ] || return 0

    # A run that is already finishing is given a moment to go on its own.
    if wait_for_owned_to_stop 8; then
        wait "$XCODEBUILD_PID" 2>/dev/null
        return 0
    fi

    log "stopping the run and everything it owns"
    report_owned "  running:"
    signal_owned TERM
    if ! wait_for_owned_to_stop 40; then
        log "the run did not stop within 10s of SIGTERM; killing what is left"
        report_owned "  ignoring SIGTERM:"
        signal_owned KILL
    fi
    if ! wait_for_owned_to_stop 20; then
        report_owned "ERROR: could not stop"
        log "ERROR: the appearance is restored below, but a surviving process could change it again."
        STOP_STATUS=71
    fi
    wait "$XCODEBUILD_PID" 2>/dev/null
    return 0
}

# The status this run should exit with.
#
# A signal is an outcome in its own right and is never reported as the run's success:
# the run did not finish. Anything else passes through the status the run produced, or —
# if it never produced one — whatever was already on its way out.
resolve_status() {
    local trigger=$1 pending=$2
    case "$trigger" in
        INT) printf '%s' 130; return 0 ;;
        TERM) printf '%s' 143; return 0 ;;
    esac
    if [ -n "$RUN_STATUS" ]; then
        printf '%s' "$RUN_STATUS"
    elif [ "$pending" -ne 0 ]; then
        printf '%s' "$pending"
    else
        printf '%s' 72
    fi
}

cleanup() {
    local pending=$?
    local trigger=${1:-EXIT} status
    trap - EXIT INT TERM

    case "$trigger" in
        INT) log "interrupted (SIGINT): stopping the run before restoring the appearance" ;;
        TERM) log "terminated (SIGTERM): stopping the run before restoring the appearance" ;;
    esac

    stop_run
    # Stop answering before restoring, so a test process that somehow outlived the run
    # cannot have another switch served to it behind this restore. That is a guarantee
    # about this script, not about the runner: the test changes the setting directly on a
    # host where it is allowed to, which is why the run is stopped first as well.
    rm -rf "$CONTROL_DIR"
    [ -n "$ORIGINAL" ] && restore_appearance

    status=$(resolve_status "$trigger" "$pending")
    if [ "$RESTORE_STATUS" -ne 0 ]; then
        log "exiting $RESTORE_STATUS: the appearance could not be restored (the run itself: $status)"
        exit "$RESTORE_STATUS"
    fi
    if [ "$STOP_STATUS" -ne 0 ]; then
        log "exiting $STOP_STATUS: the run could not be stopped completely (the run itself: $status)"
        exit "$STOP_STATUS"
    fi
    log "exiting $status"
    exit "$status"
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

# Separate traps, because the three are different outcomes: an interrupted run has not
# passed, whatever it had done so far.
trap 'cleanup EXIT' EXIT
trap 'cleanup INT' INT
trap 'cleanup TERM' TERM

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
# Job control puts xcodebuild in a process group of its own, so cleanup can stop its
# children together. Its output is echoed as usual and copied where serve_requests can
# read it.
set -m
NSUnbufferedIO=YES "${COMMAND[@]}" < /dev/null > >(tee "$STREAM_LOG") 2>&1 &
XCODEBUILD_PID=$!
set +m

# Read that group back rather than assuming it. Without job control the child would
# share this script's group, and signalling that group would kill this script along with
# the terminal's other jobs; owned processes are then stopped one by one instead.
XCODEBUILD_PGID=$(ps -o pgid= -p "$XCODEBUILD_PID" 2>/dev/null | tr -d ' ')
if [ -z "$XCODEBUILD_PGID" ] \
    || [ "$XCODEBUILD_PGID" = "$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')" ]; then
    log "note: xcodebuild has no process group of its own; stopping owned processes individually"
    XCODEBUILD_PGID=""
fi

while kill -0 "$XCODEBUILD_PID" 2>/dev/null; do
    serve_requests
    sleep 0.25
done
serve_requests
wait "$XCODEBUILD_PID"
RUN_STATUS=$?
log "xcodebuild exited with $RUN_STATUS"
