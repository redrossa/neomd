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
# Arguments. This script owns the project, scheme, destination, build directory and
# result bundle, because what it promises depends on all five. Everything else it accepts
# is named here, and anything not named is refused before a run starts:
#
#   --rehearse-cleanup
#   -only-testing:<identifier>          -skip-testing:<identifier>
#   -only-testing <identifier>          -skip-testing <identifier>
#   -test-iterations <count>            -test-repetition-relaunch-enabled <YES|NO>
#   -retry-tests-on-failure             -run-tests-until-failure
#   -parallel-testing-enabled <YES|NO>  -test-timeouts-enabled <YES|NO>
#   -quiet                              -verbose
#
# A list of what is allowed is the only kind that can be complete. A refusal list has to
# name every spelling of every setting that could put the products somewhere else —
# -derivedDataPath, SYMROOT, OBJROOT, CONFIGURATION_BUILD_DIR, an -xcconfig file that
# sets one of them — and the first one it misses is a run that stops nothing, or one that
# decides it owns a directory it did not create. Ask for another argument here when a run
# needs it; do not widen the contract at the call site.
#
# Build directory. Cleanup has to stop the app under test and the UI test runner, and
# macOS gives each of them a process group of its own, so the only thing left to
# recognise them by is where they were launched from. A shared or reused build directory
# cannot answer that question: a reader someone opened from an earlier build of the same
# products sits at exactly the same path, and killing it would be this script destroying
# unrelated work. So every invocation builds into a directory it creates for itself, and
# only processes running out of *that* directory count as its own.
#
#   NEOMD_DERIVED_DATA         parent of those per-run directories, default
#                              /tmp/NeoMD-DerivedData. It is created when missing, never
#                              emptied, never adopted: anything already in it — another
#                              run's directory, another tool's output, an app someone is
#                              using — is left exactly as it was found. A relative path is
#                              taken from the directory this script was called in, and
#                              resolved before anything is built, because this script
#                              changes directory to the project and a relative path would
#                              mean somewhere else by then.
#   NEOMD_RESULT_BUNDLE        result bundle path, likewise resolved against the calling
#                              directory. It is outside the per-run directory, so results
#                              survive the run.
#   NEOMD_KEEP_DERIVED_DATA=1  keep this run's directory instead of removing it.
#
# The effective paths are logged when the run starts. Nothing is shared between runs, so
# each one is a full, cold build — minutes rather than seconds, and a fresh module cache
# and index every time. That is the price of being able to say which processes belong to
# this run, and it is deliberate. Its directory is removed when the run is over, unless
# NEOMD_KEEP_DERIVED_DATA=1 asks to keep it or something running out of it could not be
# stopped; ask for a result bundle with NEOMD_RESULT_BUNDLE to keep results regardless.
#
# Exit status. A run's own status is passed through unchanged, including a failed launch
# of xcodebuild. Otherwise:
#
#   130  interrupted with SIGINT      143  terminated with SIGTERM
#   64   an argument outside the contract above
#   69   this terminal cannot read the appearance at all
#   70   the appearance could not be restored     (reported instead of the run's status)
#   71   something this run owns could not be stopped
#   72   this script exited before the run produced a status
#   73   this run's own build directory could not be created
#
# An exit of 0 therefore means the run finished and said so; it is never the default.
#
# Limitations: the restore runs from a shell trap, so it covers a normal exit, a failed
# run, and SIGINT/SIGTERM. It cannot run if this script is killed with SIGKILL or the
# machine loses power; in that case set the appearance in System Settings > Appearance.
# The test's own teardown restores the setting too and fails the test when it cannot, so
# a run without this script still reports rather than hides the problem.
#
# What ownership does and does not promise: a process is this run's own only if it runs
# out of the directory this run created for itself moments earlier, or in the process
# group this run started. Sessions that were already running, and anything built
# anywhere else, are outside that set by construction. The one case this cannot rule out
# is a process deliberately started from inside this run's directory while the run is
# going on; nothing here claims otherwise.
#
# Scripts/appearance-test-host-tests.sh exercises the paths above against stubs, without
# touching the real setting.

set -u
set -o pipefail

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)

# A path as it will still mean the same place after this script changes directory to the
# project. Nothing is required to exist yet.
absolute_path() {
    case "$1" in
        /*) printf '%s' "$1" ;;
        *) printf '%s/%s' "${PWD%/}" "${1#./}" ;;
    esac
}

# The configured location is a parent, not this run's build directory. Nothing is read
# from it, nothing in it is removed, and this run's claim never extends past the child it
# creates inside it.
DERIVED_DATA_ROOT=$(absolute_path "${NEOMD_DERIVED_DATA:-/tmp/NeoMD-DerivedData}")
DERIVED_DATA_ROOT_GIVEN=${NEOMD_DERIVED_DATA:-/tmp/NeoMD-DerivedData}
RESULT_BUNDLE=${NEOMD_RESULT_BUNDLE:-}
[ -n "$RESULT_BUNDLE" ] && RESULT_BUNDLE=$(absolute_path "$RESULT_BUNDLE")
KEEP_DERIVED_DATA=${NEOMD_KEEP_DERIVED_DATA:-0}
# Filled in by create_own_directories, so the traps are already installed when the
# directories they remove come into existence.
CONTROL_DIR=""
# This run's own build directory: absolute, and the resolved spelling of it. /tmp is a
# symlink to /private/tmp, so a directory has more than one name; the resolved one is the
# only one that can be compared against what ps reports, and it is what xcodebuild is
# given, what is removed afterwards, and what ownership is decided by.
DERIVED_DATA=""
DERIVED_DATA_ROOT_RESOLVED=""
STREAM_LOG=""
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
# identity: they run out of the directory *this invocation* built into.
#
# That identity only means something because the directory is exclusive. It was created
# empty for this run, moments ago, under a name nothing else knows; a process running out
# of it was started by this run. Membership of the *configured* directory would prove
# nothing at all — it is shared by default and reusable by request, so an app someone
# opened from an earlier build of the same products lives at the same path and would be
# killed by this run's cleanup. That is why the configured path is only ever a parent.
#
# The comparison is between resolved directories, not spellings. A command line reports
# the path the process was launched with, and /tmp is a symlink to /private/tmp, so the
# same directory has more than one name; comparing text alone silently misses the app
# under test. Only a path that really is this run's own build products counts, so a
# separate Xcode or app session — including one built from the same configured directory
# — is never matched. Nothing is inferred from an app's name.
owned_processes() {
    local self=$$ group=$XCODEBUILD_PGID physical=$DERIVED_DATA
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
                # Everything before the first /Build/Products/ is the build directory
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

# Creates the two directories this run owns: the control directory, and the build
# directory it will hand to xcodebuild. The configured parent is created when missing,
# which adds to it and takes nothing away; the run's own directory is a fresh child of
# it, so it starts out empty and belongs to nobody else.
#
# The path is made absolute and resolved here, while this script is still in the
# directory it was called in. Later it changes directory to the project, and a relative
# path would quietly mean a different place from then on — products built somewhere
# nobody expects, an ownership check comparing against a directory nothing came out of,
# and a removal aimed at whatever happens to sit there instead.
create_own_directories() {
    CONTROL_DIR=$(mktemp -d "${TMPDIR:-/tmp}/neomd-appearance-control.XXXXXX") || return 1
    STREAM_LOG="$CONTROL_DIR/xcodebuild-output.log"
    mkdir -p "$DERIVED_DATA_ROOT" || return 1
    DERIVED_DATA_ROOT_RESOLVED=$(cd "$DERIVED_DATA_ROOT" && pwd -P) || return 1
    [ -n "$DERIVED_DATA_ROOT_RESOLVED" ] || return 1
    DERIVED_DATA=$(mktemp -d "${DERIVED_DATA_ROOT_RESOLVED%/}/run-XXXXXXXX") || return 1
    DERIVED_DATA=$(cd "$DERIVED_DATA" && pwd -P) || return 1
    # Refuse to go on with anything this run could not have made for itself: everything
    # below — what xcodebuild is told, what counts as owned, what is removed at the end —
    # trusts this one path.
    case "$DERIVED_DATA" in
        /*/run-*) ;;
        *) return 1 ;;
    esac
    return 0
}

# Removes the directory this run built into, once nothing that came out of it is running.
#
# Only this run's own child is removed, never the configured parent: the parent may hold
# another run's directory, another tool's output, or an app someone is using, and this
# run has no claim on any of it. A result bundle is written outside this directory, so
# asking for one keeps the results whatever happens here.
release_own_build_directory() {
    [ -n "$DERIVED_DATA" ] && [ -d "$DERIVED_DATA" ] || return 0
    if [ "$STOP_STATUS" -ne 0 ]; then
        log "keeping $DERIVED_DATA: something running out of it could not be stopped."
        return 0
    fi
    if [ "$KEEP_DERIVED_DATA" != "0" ]; then
        log "keeping $DERIVED_DATA as asked (NEOMD_KEEP_DERIVED_DATA)"
        return 0
    fi
    rm -rf "$DERIVED_DATA"
    if [ -n "$RUN_STATUS" ] && [ "$RUN_STATUS" -ne 0 ]; then
        log "removed $DERIVED_DATA; keep a failed run's logs with NEOMD_KEEP_DERIVED_DATA=1"
        log "or write its results outside it with NEOMD_RESULT_BUNDLE."
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
    [ -n "$CONTROL_DIR" ] && rm -rf "$CONTROL_DIR"
    [ -n "$ORIGINAL" ] && restore_appearance
    # After the restore, because removing files cannot change the appearance and the
    # tester's setting is the thing worth hurrying for.
    release_own_build_directory

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

# Everything this script forwards to xcodebuild, and nothing else.
#
# The refusal is deliberate rather than cautious. This script recognises the app and the
# runner by the directory they came out of, so an argument that moves the products —
# -derivedDataPath, SYMROOT, OBJROOT, CONFIGURATION_BUILD_DIR, an -xcconfig that sets one
# of them — leaves a run that stops nothing, or one that claims a directory it did not
# create. A list of refusals is never finished; a list of what is allowed is. Add to it
# here, where the reason is written down, rather than at a call site.
log_supported_arguments() {
    log "ERROR: this script supports:"
    log "ERROR:   --rehearse-cleanup"
    log "ERROR:   -only-testing:<identifier>          -skip-testing:<identifier>"
    log "ERROR:   -only-testing <identifier>          -skip-testing <identifier>"
    log "ERROR:   -test-iterations <count>            -test-repetition-relaunch-enabled <YES|NO>"
    log "ERROR:   -retry-tests-on-failure             -run-tests-until-failure"
    log "ERROR:   -parallel-testing-enabled <YES|NO>  -test-timeouts-enabled <YES|NO>"
    log "ERROR:   -quiet                              -verbose"
    log "ERROR: the project, scheme, destination, build directory and result bundle are this"
    log "ERROR: run's own. Point NEOMD_DERIVED_DATA at a parent directory and ask for results"
    log "ERROR: with NEOMD_RESULT_BUNDLE instead of passing them here."
}

refuse_argument() {
    log "ERROR: refusing '$1': $2"
    log_supported_arguments
    exit 64
}

ARGUMENTS=()
while [ $# -gt 0 ]; do
    argument=$1
    case "$argument" in
        --rehearse-cleanup)
            REHEARSE_CLEANUP=1
            shift
            continue
            ;;
        -only-testing:?*|-skip-testing:?*|-retry-tests-on-failure|-run-tests-until-failure\
            |-quiet|-verbose)
            ARGUMENTS+=("$argument")
            shift
            continue
            ;;
        -only-testing|-skip-testing) expected=identifier ;;
        -test-iterations) expected=count ;;
        -test-repetition-relaunch-enabled|-parallel-testing-enabled|-test-timeouts-enabled)
            expected=boolean
            ;;
        *) refuse_argument "$argument" "it is not one of the arguments this script supports." ;;
    esac

    shift
    [ $# -gt 0 ] || refuse_argument "$argument" "it needs a value, and none was given."
    value=$1
    case "$expected" in
        identifier)
            case "$value" in
                ''|-*) refuse_argument "$argument $value" "a test identifier was expected." ;;
            esac
            ;;
        count)
            case "$value" in
                ''|*[!0-9]*) refuse_argument "$argument $value" "a count was expected." ;;
            esac
            ;;
        boolean)
            case "$value" in
                YES|NO) ;;
                *) refuse_argument "$argument $value" "YES or NO was expected." ;;
            esac
            ;;
    esac
    ARGUMENTS+=("$argument" "$value")
    shift
done

# Separate traps, because the three are different outcomes: an interrupted run has not
# passed, whatever it had done so far. They are installed before anything exists to clean
# up, so no failure below — a build directory that cannot be created, an appearance that
# cannot be read, a launch that never happens — leaves this run's directories behind.
trap 'cleanup EXIT' EXIT
trap 'cleanup INT' INT
trap 'cleanup TERM' TERM

if ! create_own_directories; then
    log "ERROR: this run's own build directory could not be created under $DERIVED_DATA_ROOT."
    log "ERROR: set NEOMD_DERIVED_DATA to a writable parent directory."
    exit 73
fi

if ! ORIGINAL=$(read_dark_mode); then
    log "ERROR: this terminal cannot read the system appearance: $ORIGINAL"
    log "ERROR: allow it to control System Events in System Settings > Privacy & Security > Automation."
    ORIGINAL=""
    exit 69
fi
log "original system dark mode: $ORIGINAL"
log "control directory: $CONTROL_DIR"
log "build directory parent: $DERIVED_DATA_ROOT_RESOLVED"
[ "$DERIVED_DATA_ROOT_GIVEN" = "$DERIVED_DATA_ROOT_RESOLVED" ] \
    || log "build directory parent as given: $DERIVED_DATA_ROOT_GIVEN"
log "build directory: $DERIVED_DATA"
log "this run builds from scratch into that directory and removes it afterwards"

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
