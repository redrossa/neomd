#!/bin/bash
#
# appearance-test-host-tests.sh — regression tests for appearance-test-host.sh.
#
# The controller is the only part of the appearance tests that can leave a tester's Mac
# in the wrong appearance, or report a run that never finished as a success. Those are
# the paths that are hardest to reach by running the real suite, so they are exercised
# here against stubs instead: a stubbed `osascript` that keeps the "system appearance" in
# a file and never touches the real setting, and a stubbed `xcodebuild` that plays one
# scenario. The checked-in controller itself is run unmodified.
#
# Every scenario checks both halves of the guarantee — the exit status the controller
# reports, and the state it leaves behind — because either one alone can hide a defect.
#
#   Scripts/appearance-test-host-tests.sh            # all scenarios
#   Scripts/appearance-test-host-tests.sh sigterm    # only the named ones
#
# Nothing here needs Xcode, a graphical session, Automation access, or the real setting.

set -u
set -o pipefail
# Job control, so a controller started here is signalled as itself: without it bash gives
# background commands an ignored SIGINT, which the controller could then not trap.
set -m 2>/dev/null

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONTROLLER="$SCRIPT_DIR/appearance-test-host.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/neomd-appearance-host-tests.XXXXXX")
PRODUCTS="$WORK/DerivedData/Build/Products/Debug"
RUNNER="$PRODUCTS/NeoMDUITests-Runner.app/Contents/MacOS/NeoMDUITests-Runner"
STATE="$WORK/appearance-state"
PASSED=0
FAILED=0
CURRENT=""

# Stray stub processes belong to this harness, so it is the one that cleans them up. A
# scenario that leaves one is a failure, reported before this runs.
finish() {
    local pid
    for pid in $(stray_processes | awk '{ print $1 }'); do
        [ "$pid" = "$$" ] || kill -KILL "$pid" 2>/dev/null
    done
    rm -rf "$WORK"
}
trap finish EXIT

note() { printf '  %s\n' "$*"; }

check() {
    local description=$1 expected=$2 actual=$3
    if [ "$expected" = "$actual" ]; then
        PASSED=$((PASSED + 1))
        printf '  ok    %s\n' "$description"
    else
        FAILED=$((FAILED + 1))
        printf '  FAIL  %s\n        expected: %s\n        actual:   %s\n' \
            "$description" "$expected" "$actual"
    fi
}

check_contains() {
    local description=$1 needle=$2 file=$3
    if grep -qF -- "$needle" "$file"; then
        PASSED=$((PASSED + 1))
        printf '  ok    %s\n' "$description"
    else
        FAILED=$((FAILED + 1))
        printf '  FAIL  %s\n        %s does not contain: %s\n' "$description" "$file" "$needle"
    fi
}

scenario() {
    CURRENT=$1
    printf '\n%s\n' "$CURRENT"
    printf 'true' > "$STATE"
}

# The processes a scenario is allowed to have left behind: none. The process list is
# taken first and matched afterwards, so the matching itself is never in the sample, and
# a command is matched by what it *is* rather than by what it mentions — a shell whose
# arguments merely name these paths is not a stray stub process.
stray_processes() {
    local snapshot
    snapshot=$(ps -Ao pid=,command=)
    printf '%s\n' "$snapshot" | awk -v p="$PRODUCTS" -v d="neomd-stub-descendant" '
        {
            sub(/^ */, "")
            command = substr($0, index($0, " ") + 1)
            if (substr(command, 1, length(p)) == p || substr(command, 1, length(d)) == d) print
        }'
}

# The stubs go in front of the real tools, so nothing a scenario runs can reach the real
# appearance: PATH resolves osascript to the stub. The controller is always started as
# `env ... "$CONTROLLER"` rather than through a wrapper function, so the pid a scenario
# signals is the controller itself and not a subshell standing in front of it.
CONTROLLER_ENV=()
build_controller_environment() {
    CONTROLLER_ENV=(
        "PATH=$WORK/bin:$PATH"
        "NEOMD_DERIVED_DATA=$WORK/DerivedData"
        "NEOMD_STUB_STATE=$STATE"
        "NEOMD_STUB_RUNNER=$RUNNER"
        "NEOMD_STUB_READY=$WORK/ready"
    )
}

install_stubs() {
    mkdir -p "$WORK/bin" "$(dirname "$RUNNER")"

    cat > "$WORK/bin/osascript" <<'STUB'
#!/bin/bash
# Stands in for osascript. Keeps the "system appearance" in a file; the real setting is
# never read or written.
set -u
STATE=${NEOMD_STUB_STATE:?}
REFUSE=${NEOMD_STUB_REFUSE_WRITE_TO:-}
script=""
while [ $# -gt 0 ]; do
    [ "$1" = "-e" ] && { shift; script=${1:-}; }
    shift || break
done
case "$script" in
    *"set dark mode to true"*) target=true ;;
    *"set dark mode to false"*) target=false ;;
    *"get dark mode"*) cat "$STATE"; exit 0 ;;
    *) printf 'stub osascript: unsupported script\n' >&2; exit 1 ;;
esac
if [ -n "$REFUSE" ] && [ "$REFUSE" = "$target" ]; then
    printf 'System Events got an error: Not authorized to send Apple events.\n' >&2
    exit 1
fi
printf '%s' "$target" > "$STATE"
STUB

    cat > "$WORK/bin/xcodebuild" <<'STUB'
#!/bin/bash
# Stands in for xcodebuild. Plays one scenario of the appearance handshake and its
# aftermath, and never builds or tests anything.
set -u
CONTROL=${TEST_RUNNER_NEOMD_UI_TEST_APPEARANCE_CONTROL_DIR:-}
SCENARIO=${NEOMD_STUB_SCENARIO:-success}
READY=${NEOMD_STUB_READY:-/dev/null}
RUNNER=${NEOMD_STUB_RUNNER:-}

identifier() {
    local raw
    raw=$(uuidgen | tr 'A-F' 'a-f' | tr -d '-')
    printf '%s' "${raw:0:16}"
}

# Asks for an appearance the way the real test does, and waits for its own answer.
request() {
    local value=$1 id attempt
    id=$(identifier)
    printf 'NEOMD-APPEARANCE-REQUEST %s %s END\n' "$id" "$value"
    for attempt in $(seq 1 200); do
        if [ -e "$CONTROL/response-$id" ]; then
            printf 'stub: request-%s %s answered "%s"\n' \
                "$id" "$value" "$(cat "$CONTROL/response-$id")"
            return 0
        fi
        sleep 0.1
    done
    printf 'stub: request-%s %s was never answered\n' "$id" "$value"
    return 1
}

# A descendant in this stub's own process group that ignores SIGTERM, standing in for a
# test process that outlives the group leader.
spawn_resistant_descendant() {
    /bin/bash -c 'exec -a neomd-stub-descendant /bin/bash -c "trap \"\" TERM; while :; do /bin/sleep 1; done"' &
}

# A process outside this stub's process group whose argv[0] is under this run's build
# products, standing in for the UI test runner macOS launches and reparents to launchd,
# and for the app it drives. NEOMD_STUB_RUNNER_PATH is the spelling it is launched with,
# which is not always the spelling the controller was given.
spawn_detached_runner() {
    local path=${NEOMD_STUB_RUNNER_PATH:-$RUNNER}
    cp /bin/sleep "$RUNNER"
    /usr/bin/python3 -c 'import os, sys; os.setsid(); os.execv("/bin/sleep", [sys.argv[1], "600"])' \
        "$path" &
}

case "$SCENARIO" in
    success) request Light ;;
    detached-runner-other-spelling) spawn_detached_runner; request Light ;;
    failing) request Light; exit 65 ;;
    hang) request Light; : > "$READY"; sleep 600 ;;
    resistant-descendant) spawn_resistant_descendant; request Light ;;
    detached-runner) spawn_detached_runner; request Light ;;
    relaunch) request Light && request Dark && request Light ;;
    unknown-value)
        id=$(identifier)
        printf 'NEOMD-APPEARANCE-REQUEST %s Sepia END\n' "$id"
        for attempt in $(seq 1 100); do
            [ -e "$CONTROL/response-$id" ] && break
            sleep 0.1
        done
        printf 'stub: request-%s answered "%s"\n' "$id" "$(cat "$CONTROL/response-$id" 2>/dev/null)"
        ;;
    partial-line)
        # A half-flushed request, and a request whose identifier is not the shape the
        # protocol allows. Neither may be acted on.
        printf 'NEOMD-APPEARANCE-REQUEST %s Light\n' "$(identifier)"
        printf 'NEOMD-APPEARANCE-REQUEST ../escape Light END\n'
        sleep 2
        ;;
    *) printf 'stub xcodebuild: unknown scenario %s\n' "$SCENARIO" >&2; exit 2 ;;
esac
STUB

    cat > "$WORK/bin/xcodebuild-missing" <<'STUB'
#!/bin/bash
exec /nonexistent/appearance-host-regression-xcodebuild
STUB

    chmod +x "$WORK/bin/osascript" "$WORK/bin/xcodebuild" "$WORK/bin/xcodebuild-missing"
}

# Waits for the stub to say it has reached the point a signal should arrive at.
wait_for_ready() {
    local attempt
    for attempt in $(seq 1 300); do
        [ -e "$WORK/ready" ] && return 0
        sleep 0.1
    done
    return 1
}

# Starts a controller that is about to be signalled, with SIGINT and SIGTERM at their
# default disposition.
#
# A shell that starts a background command without job control gives it an ignored
# SIGINT, and a signal ignored on entry cannot be trapped afterwards. That is a property
# of however this harness was itself started, not of the controller, so it is undone here
# rather than being allowed to decide what the test proves.
start_signalled_controller() {
    local log=$1
    if [ -x /usr/bin/python3 ]; then
        /usr/bin/python3 -c '
import os, signal, sys
signal.signal(signal.SIGINT, signal.SIG_DFL)
signal.signal(signal.SIGTERM, signal.SIG_DFL)
os.execvp(sys.argv[1], sys.argv[1:])
' env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=hang "$CONTROLLER" > "$log" 2>&1 &
    else
        env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=hang "$CONTROLLER" > "$log" 2>&1 &
    fi
}

# A scenario that will not finish is a failure, not a reason for this harness to hang.
guard_with_watchdog() {
    { sleep "$2"; kill -KILL "$1" 2>/dev/null; } &
    WATCHDOG=$!
    disown "$WATCHDOG" 2>/dev/null || true
}

stop_watchdog() {
    [ -n "${WATCHDOG:-}" ] && kill "$WATCHDOG" 2>/dev/null
    WATCHDOG=""
}

# --- scenarios ---------------------------------------------------------------------

test_success() {
    scenario "a run that passes reports 0 and puts the appearance back"
    local log="$WORK/success.log" status
    env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=success "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 0 "$status"
    check "appearance restored" true "$(cat "$STATE")"
    check_contains "the switch was served" 'switching the system appearance to Light' "$log"
}

test_failing_run() {
    scenario "a failing run reports the run's own status"
    local log="$WORK/failing.log" status
    env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=failing "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 65 "$status"
    check "appearance restored" true "$(cat "$STATE")"
}

test_failed_launch() {
    scenario "a run that cannot be launched reports 126"
    local log="$WORK/launch.log" status
    cp "$WORK/bin/xcodebuild" "$WORK/bin/xcodebuild.saved"
    cp "$WORK/bin/xcodebuild-missing" "$WORK/bin/xcodebuild"
    env "${CONTROLLER_ENV[@]}" "$CONTROLLER" > "$log" 2>&1
    status=$?
    cp "$WORK/bin/xcodebuild.saved" "$WORK/bin/xcodebuild"
    check "exit status" 126 "$status"
    check "appearance untouched" true "$(cat "$STATE")"
}

# The defect this covers: one trap for EXIT/INT/TERM exiting with a status that is only
# assigned after a normal wait, so an interrupted run reported success.
test_signal() {
    local signal=$1 expected=$2
    scenario "a run stopped with SIG$signal reports $expected and puts the appearance back"
    local log="$WORK/sig$signal.log" status pid
    rm -f "$WORK/ready"
    start_signalled_controller "$log"
    pid=$!
    if ! wait_for_ready; then
        check "the stub reached its request" ready "not ready"
        kill -KILL "$pid" 2>/dev/null
        return
    fi
    check "the appearance was really changed first" false "$(cat "$STATE")"
    guard_with_watchdog "$pid" 60
    kill -"$signal" "$pid"
    wait "$pid"
    status=$?
    stop_watchdog
    check "exit status" "$expected" "$status"
    check "appearance restored" true "$(cat "$STATE")"
    check "nothing left running" "" "$(stray_processes)"
    sleep 2
    check "no late appearance change" true "$(cat "$STATE")"
}

# The defect this covers: cleanup returned as soon as the process-group leader was gone,
# so a descendant that ignores SIGTERM outlived the run and the restore.
test_resistant_descendant() {
    scenario "a descendant that ignores SIGTERM is escalated to, not left behind"
    local log="$WORK/resistant.log" status
    env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=resistant-descendant "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 0 "$status"
    check "appearance restored" true "$(cat "$STATE")"
    check "nothing left running" "" "$(stray_processes)"
    check_contains "the survivor was escalated to" 'ignoring SIGTERM:' "$log"
}

# The defect this covers: the UI test runner is not in xcodebuild's process group, so
# signalling that group alone never reaches it.
test_detached_runner() {
    scenario "a runner outside the process group is still stopped before the restore"
    local log="$WORK/detached.log" status stop_line restore_line
    if [ ! -x /usr/bin/python3 ]; then
        note "SKIPPED: /usr/bin/python3 is needed to detach the stand-in runner"
        return
    fi
    env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=detached-runner "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 0 "$status"
    check "appearance restored" true "$(cat "$STATE")"
    check "nothing left running" "" "$(stray_processes)"
    stop_line=$(grep -n 'stopping the run and everything it owns' "$log" | head -1 | cut -d: -f1)
    restore_line=$(grep -n 'restoring the system appearance' "$log" | head -1 | cut -d: -f1)
    if [ -n "$stop_line" ] && [ -n "$restore_line" ] && [ "$stop_line" -lt "$restore_line" ]; then
        check "the run is stopped before the appearance is restored" ordered ordered
    else
        check "the run is stopped before the appearance is restored" ordered \
            "stop=${stop_line:-none} restore=${restore_line:-none}"
    fi
}

# The defect this covers: a process launched through a different spelling of the same
# directory — /tmp and /private/tmp are the same place — was not recognised as this run's
# own, so the app under test outlived a cancelled run.
test_symlinked_derived_data() {
    scenario "a runner launched through another spelling of the same path is still owned"
    local log="$WORK/symlink.log" status link
    if [ ! -x /usr/bin/python3 ]; then
        note "SKIPPED: /usr/bin/python3 is needed to detach the stand-in runner"
        return
    fi
    link="$WORK/link"
    ln -sfn "$WORK" "$link"
    # The controller is told about the derived data through the symlink; the stand-in
    # runner is launched with the direct path. Both are the same directory.
    env "${CONTROLLER_ENV[@]}" "NEOMD_DERIVED_DATA=$link/DerivedData" \
        "NEOMD_STUB_RUNNER_PATH=$RUNNER" \
        NEOMD_STUB_SCENARIO=detached-runner-other-spelling "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 0 "$status"
    check "appearance restored" true "$(cat "$STATE")"
    check "nothing left running" "" "$(stray_processes)"
    rm -f "$link"
}

# The defect this covers: per-process request numbers restarted at 1 when Xcode relaunched
# the runner, so a repetition was handed the answer written for an earlier one.
test_relaunch_identity() {
    scenario "requests from separate runner processes are answered on their own terms"
    local log="$WORK/relaunch.log" status answers identifiers
    env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=relaunch "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 0 "$status"
    check "appearance restored" true "$(cat "$STATE")"
    answers=$(sed -n 's/^stub: request-[0-9a-f]* .* answered "\(.*\)"$/\1/p' "$log" | tr '\n' ',')
    check "each request got the answer it asked for" "ok Light,ok Dark,ok Light," "$answers"
    identifiers=$(sed -n 's/^stub: request-\([0-9a-f]*\) .*/\1/p' "$log" | sort -u | wc -l)
    check "no identifier was reused" 3 "$(printf '%s' "$identifiers" | tr -d ' ')"
}

test_restore_refused() {
    scenario "a refused restoration reports 70 and says what to set by hand"
    local log="$WORK/refused.log" status
    env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=failing NEOMD_STUB_REFUSE_WRITE_TO=true \
        "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 70 "$status"
    check "the appearance really is still wrong" false "$(cat "$STATE")"
    check_contains "the run's own status is still reported" 'the run itself: 65' "$log"
    check_contains "the instruction is printed" 'System Settings > Appearance' "$log"
    printf 'true' > "$STATE"
}

test_rejected_requests() {
    scenario "a request that is not the agreed shape is refused, not guessed at"
    local log="$WORK/rejected.log" status
    env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=unknown-value "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 0 "$status"
    check_contains "an unknown value is refused" 'refusing unknown value' "$log"
    check "the appearance was never changed" true "$(cat "$STATE")"

    scenario "a half-written line and a malformed identifier are ignored"
    env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=partial-line "$CONTROLLER" > "$log" 2>&1
    check "the appearance was never changed" true "$(cat "$STATE")"
    check "nothing was served" 0 \
        "$(grep -c 'switching the system appearance' "$log" | tr -d ' ')"
}

# --- runner ------------------------------------------------------------------------

install_stubs
build_controller_environment
printf 'true' > "$STATE"

REQUESTED=("$@")
wanted() {
    [ ${#REQUESTED[@]} -eq 0 ] && return 0
    local name
    for name in "${REQUESTED[@]}"; do
        [ "$name" = "$1" ] && return 0
    done
    return 1
}

wanted success && test_success
wanted failing && test_failing_run
wanted failed-launch && test_failed_launch
wanted sigterm && test_signal TERM 143
wanted sigint && test_signal INT 130
wanted resistant-descendant && test_resistant_descendant
wanted detached-runner && test_detached_runner
wanted relaunch && test_relaunch_identity
wanted symlinked-derived-data && test_symlinked_derived_data
wanted restore-refused && test_restore_refused
wanted rejected-requests && test_rejected_requests

printf '\n%s passed, %s failed\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
