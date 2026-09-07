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
# The scenarios that stand in for the app and the test runner need `cc` and
# /usr/bin/python3, and say so and skip when they are missing: a stand-in has to be a
# real executable at a real NeoMD.app path, and a *copy* of a system tool is not one. On
# Apple Silicon a copied platform binary is refused by the kernel with SIGKILL the moment
# it is executed, however it is signed, so those scenarios would have measured a process
# that was already dead. The stand-in is therefore compiled here.

set -u
set -o pipefail
# Job control, so a controller started here is signalled as itself: without it bash gives
# background commands an ignored SIGINT, which the controller could then not trap.
set -m 2>/dev/null

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
CONTROLLER=${NEOMD_TEST_CONTROLLER:-$SCRIPT_DIR/appearance-test-host.sh}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/neomd-appearance-host-tests.XXXXXX")
# The same directory under both of its names: on macOS a temporary directory is reached
# through /var (or /tmp), which is a symlink, so a process launched from one spelling is
# reported with the other. Both are watched here, or a survivor could go unnoticed.
WORK_PHYSICAL=$(cd "$WORK" && pwd -P)
# What the controller is configured with is a *parent*: it builds into a fresh directory
# inside it, so no fixture may assume this path is where the products are.
DERIVED_DATA_ROOT="$WORK/DerivedData"
OTHER_DERIVED_DATA_ROOT="$WORK/OtherDerivedData"
STATE="$WORK/appearance-state"
# What the stubbed osascript saw at the moment it changed the "appearance": whether the
# process standing in for the app under test was still running. Log order says the
# controller printed one line before another; this says the run was really stopped before
# the setting was put back.
ORDER_LOG="$WORK/appearance-writes"
WITNESS_PIDFILE="$WORK/witness.pid"
# The compiled stand-in for the app and the UI test runner.
STANDIN="$WORK/bin/standin"
STANDIN_AVAILABLE=0
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
    : > "$ORDER_LOG"
    rm -f "$WITNESS_PIDFILE"
}

# What the stubbed appearance saw when it made a particular change.
appearance_write() {
    grep "^write $1 " "$ORDER_LOG" 2>/dev/null | tail -1
}

check_matches() {
    local description=$1 pattern=$2 file=$3
    if grep -qE -- "$pattern" "$file"; then
        PASSED=$((PASSED + 1))
        printf '  ok    %s\n' "$description"
    else
        FAILED=$((FAILED + 1))
        printf '  FAIL  %s\n        %s does not match: %s\n' "$description" "$file" "$pattern"
    fi
}

own_run_directories() {
    find "${1:-$DERIVED_DATA_ROOT}" -maxdepth 1 -name 'run-*' 2>/dev/null | wc -l | tr -d ' '
}

# The processes a scenario is allowed to have left behind: none. The process list is
# taken first and matched afterwards, so the matching itself is never in the sample, and
# a command is matched by what it *is* rather than by what it mentions — a shell whose
# arguments merely name these paths is not a stray stub process.
#
# Everything this harness starts lives under its own work directory, so that is what is
# watched — under both spellings, and whatever per-run directory the controller chose
# inside it.
# Each prefix is passed as its own variable rather than one split string, because a
# directory may contain spaces — and a scenario below deliberately gives the controller
# one that does. Splitting on spaces would silently watch two prefixes that are neither
# of them a real path, and report that nothing was left behind.
stray_processes() {
    local snapshot
    snapshot=$(/bin/ps -Ao pid=,command=)
    printf '%s\n' "$snapshot" | awk \
        -v given="$WORK/" -v resolved="$WORK_PHYSICAL/" -v descendant='neomd-stub-descendant' '
        {
            sub(/^ */, "")
            command = substr($0, index($0, " ") + 1)
            if (substr(command, 1, length(given)) == given) { print; next }
            if (substr(command, 1, length(resolved)) == resolved) { print; next }
            if (substr(command, 1, length(descendant)) == descendant) { print; next }
        }'
}

# Whether a process is really still there. A stand-in this harness started is its own
# child, so a signalled one lingers as a zombie until it is reaped: `kill -0` would say
# it is running long after it was killed, and a test asking "did this survive?" would
# answer yes for a process the controller had just terminated.
process_state() {
    local state
    state=$(/bin/ps -o stat= -p "$1" 2>/dev/null | tr -d ' ')
    case "$state" in
        "" | Z*) printf 'gone' ;;
        *) printf 'running' ;;
    esac
}

# The stand-in executable every process fixture is a copy of. It is compiled rather than
# copied from /bin, because macOS refuses to execute a relocated platform binary: a copy
# of /bin/sleep at another path is killed with SIGKILL immediately, re-signing it does
# not help, and a fixture that dies on launch would make every ownership scenario below
# pass without measuring anything.
build_standin() {
    printf '#include <unistd.h>\nint main(void) { sleep(600); return 0; }\n' > "$WORK/standin.c"
    if cc -o "$STANDIN" "$WORK/standin.c" > "$WORK/standin-build.log" 2>&1; then
        STANDIN_AVAILABLE=1
    fi
}

# Whether the process fixtures can run at all: a compiled stand-in, and python3 to put it
# in a session of its own with a chosen spelling of its path.
have_standin() {
    [ "$STANDIN_AVAILABLE" = "1" ] && [ -x /usr/bin/python3 ]
}

# A real executable at a real NeoMD.app path, started in its own session and process
# group *before* the controller: the stand-in for an app somebody else already had open.
# It is an executable at that path rather than a shell mentioning it, so it is owned or
# not owned for the same reason the real app would be.
#
# This harness runs with job control, so a background job is already a process group
# leader and `setsid` would fail with EPERM — it is asked for only when it is still
# needed, and the process is outside every group this run starts either way.
#
# Its output goes to a file rather than being inherited: this function's own output is
# read through a command substitution, and a surviving process holding that pipe open
# would keep the substitution — and the whole scenario — waiting for the stand-in to
# exit. A fixture that dies immediately hides that; one that really survives does not.
start_unowned_standin() {
    local root=$1 path
    path="$root/Build/Products/Debug/NeoMD.app/Contents/MacOS/NeoMD"
    mkdir -p "$(dirname "$path")"
    cp "$STANDIN" "$path"
    /usr/bin/python3 -c 'import os, sys
if os.getpid() != os.getpgid(0):
    os.setsid()
os.execv(sys.argv[1], [sys.argv[1], "600"])' "$path" > "$WORK/standin.out" 2>&1 &
    printf '%s' "$!"
}

stop_standin() {
    local pid=$1 attempt
    kill -KILL "$pid" 2>/dev/null
    for attempt in $(seq 1 40); do
        [ "$(process_state "$pid")" = "gone" ] && break
        sleep 0.1
    done
    wait "$pid" 2>/dev/null
}

# The stubs go in front of the real tools, so nothing a scenario runs can reach the real
# appearance: PATH resolves osascript to the stub. The controller is always started as
# `env ... "$CONTROLLER"` rather than through a wrapper function, so the pid a scenario
# signals is the controller itself and not a subshell standing in front of it.
CONTROLLER_ENV=()
build_controller_environment() {
    CONTROLLER_ENV=(
        "PATH=$WORK/bin:$PATH"
        "NEOMD_DERIVED_DATA=$DERIVED_DATA_ROOT"
        "NEOMD_STUB_STATE=$STATE"
        "NEOMD_STUB_READY=$WORK/ready"
        "NEOMD_STUB_STANDIN=$STANDIN"
        "NEOMD_STUB_ORDER_LOG=$ORDER_LOG"
        "NEOMD_STUB_WITNESS_PIDFILE=$WITNESS_PIDFILE"
    )
}

install_stubs() {
    mkdir -p "$WORK/bin" "$DERIVED_DATA_ROOT" "$OTHER_DERIVED_DATA_ROOT"
    build_standin

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
# What was still running at the moment the setting changed. The restore is only safe if
# the process standing in for the app was already gone by then.
ORDER_LOG=${NEOMD_STUB_ORDER_LOG:-}
WITNESS=${NEOMD_STUB_WITNESS_PIDFILE:-}
if [ -n "$ORDER_LOG" ]; then
    witness=none
    if [ -n "$WITNESS" ] && [ -s "$WITNESS" ]; then
        case "$(/bin/ps -o stat= -p "$(cat "$WITNESS")" 2>/dev/null | tr -d ' ')" in
            "" | Z*) witness=gone ;;
            *) witness=running ;;
        esac
    fi
    printf 'write %s witness=%s\n' "$target" "$witness" >> "$ORDER_LOG"
fi
printf '%s' "$target" > "$STATE"
STUB

    cat > "$WORK/bin/ps" <<'STUB'
#!/bin/bash
# Stands in for ps only to add one process that will not go away, so the controller's
# "something I own could not be stopped" path can be reached without a process that
# really resists SIGKILL — there is no such thing. Everything else is the real ps.
#
# The phantom is pid 1: it certainly exists, it is certainly not this run's, and a
# non-root user cannot signal it, so the controller's escalation is a guaranteed no-op
# instead of a signal aimed at a pid that might have been reused. The scenario refuses to
# run as root.
set -u
snapshot=$(/bin/ps "$@")
status=$?
printf '%s\n' "$snapshot"
if [ -n "${NEOMD_STUB_PHANTOM:-}" ]; then
    case " $* " in
        *" -Ao "*)
            run=$(/bin/ls -d "${NEOMD_DERIVED_DATA:-/nonexistent}"/run-* 2>/dev/null | head -1)
            [ -n "$run" ] && printf '    1 1 S %s\n' \
                "$run/Build/Products/Debug/NeoMD.app/Contents/MacOS/NeoMD 600"
            ;;
    esac
fi
exit $status
STUB

    cat > "$WORK/bin/xcodebuild" <<'STUB'
#!/bin/bash
# Stands in for xcodebuild. Plays one scenario of the appearance handshake and its
# aftermath, and never builds or tests anything.
set -u
CONTROL=${TEST_RUNNER_NEOMD_UI_TEST_APPEARANCE_CONTROL_DIR:-}
SCENARIO=${NEOMD_STUB_SCENARIO:-success}
READY=${NEOMD_STUB_READY:-/dev/null}
STANDIN=${NEOMD_STUB_STANDIN:-}
WITNESS=${NEOMD_STUB_WITNESS_PIDFILE:-}

# What the controller actually forwarded, so a scenario can check the argument contract
# at the far end rather than in the controller's own log line.
printf 'stub xcodebuild args: %s\n' "$*"

# Where this run's products really go, read from the command line the controller built.
# The controller creates a fresh directory for every invocation, so a fixture that wants
# to stand in for something this run launched has to be put where this run was actually
# told to build — the configured parent is somebody else's directory.
DERIVED_DATA=""
previous=""
for argument in "$@"; do
    [ "$previous" = "-derivedDataPath" ] && { DERIVED_DATA=$argument; break; }
    previous=$argument
done

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

# A process outside this stub's process group, running out of this run's own build
# products: the stand-in for the UI test runner macOS launches and reparents to launchd,
# and for the app it drives. NEOMD_STUB_RUNNER_SPELLING=physical launches it through the
# resolved spelling of the same directory, which is not the spelling the controller was
# given — /tmp and /private/tmp are one directory with two names.
# NEOMD_STUB_RUNNER_SPELLING=alias launches it through the configured parent's spelling
# of the same directory, which is not the spelling the controller was given: the
# controller resolves its own build directory, so a symlinked parent reaches the same
# place under another name.
spawn_detached_runner() {
    local real spelling
    real="$DERIVED_DATA/Build/Products/Debug/NeoMDUITests-Runner.app/Contents/MacOS/NeoMDUITests-Runner"
    mkdir -p "$(dirname "$real")"
    cp "$STANDIN" "$real"
    spelling=$real
    if [ "${NEOMD_STUB_RUNNER_SPELLING:-given}" = alias ]; then
        spelling="${NEOMD_DERIVED_DATA%/}/$(basename "$DERIVED_DATA")/Build/Products/Debug/NeoMDUITests-Runner.app/Contents/MacOS/NeoMDUITests-Runner"
    fi
    /usr/bin/python3 -c 'import os, sys; os.setsid(); os.execv(sys.argv[1], [sys.argv[2]])' \
        "$real" "$spelling" &
    # The process the appearance stub reports on when it writes: it has to be gone before
    # the setting is put back.
    [ -n "$WITNESS" ] && printf '%s' "$!" > "$WITNESS"
}

case "$SCENARIO" in
    success) request Light ;;
    no-app) printf 'stub xcodebuild: finishing without launching an app or a runner\n'; sleep 1 ;;
    detached-runner-alias-spelling) spawn_detached_runner; request Light ;;
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

    chmod +x "$WORK/bin/osascript" "$WORK/bin/ps" "$WORK/bin/xcodebuild" \
        "$WORK/bin/xcodebuild-missing"
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
    if ! have_standin; then
        note "SKIPPED: cc and /usr/bin/python3 are needed for the stand-in runner"
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
    # Ordering as the appearance itself saw it, rather than as the controller narrated
    # it: the runner was running when the run's own switch was served, and really gone
    # when the setting was put back.
    check "the runner was still running when its own request was served" \
        "write false witness=running" "$(appearance_write false)"
    check "the runner was gone before the appearance was restored" \
        "write true witness=gone" "$(appearance_write true)"
}

# The defect this covers: a relative NEOMD_DERIVED_DATA was still relative when the
# controller changed directory to the project, so the products were built somewhere
# nobody had asked for, ownership was decided against a directory nothing came out of,
# and the removal at the end pointed at whatever sat at that name inside the project.
test_relative_derived_data() {
    scenario "a relative parent is resolved before the run changes directory"
    local log="$WORK/relative.log" status relative='neomd-host-regression-relative-dd'
    if ! have_standin; then
        note "SKIPPED: cc and /usr/bin/python3 are needed for the stand-in runner"
        return
    fi
    (cd "$WORK" && env "${CONTROLLER_ENV[@]}" "NEOMD_DERIVED_DATA=$relative" \
        NEOMD_STUB_SCENARIO=detached-runner "$CONTROLLER") > "$log" 2>&1
    status=$?
    check "exit status" 0 "$status"
    check "appearance restored" true "$(cat "$STATE")"
    check "nothing left running" "" "$(stray_processes)"
    check "the run built under the directory it was called in" 1 \
        "$(grep -cF "build directory: $WORK_PHYSICAL/$relative/run-" "$log" | tr -d ' ')"
    check "the runner was recognised and stopped before the restore" \
        "write true witness=gone" "$(appearance_write true)"
    check "nothing was built inside the project" absent \
        "$([ -e "$PROJECT_DIR/$relative" ] && printf present || printf absent)"
    check "the run's own directory was removed afterwards" 0 \
        "$(own_run_directories "$WORK/$relative")"
    rm -rf "$PROJECT_DIR/$relative" "$WORK/$relative"
}

# Paths with spaces are one path, everywhere: what is handed to xcodebuild, what a
# process is compared against, and what is removed afterwards.
test_spaced_derived_data() {
    scenario "a parent directory containing spaces is treated as one path"
    local log="$WORK/spaced.log" status root="$WORK/Derived Data With Spaces"
    if ! have_standin; then
        note "SKIPPED: cc and /usr/bin/python3 are needed for the stand-in runner"
        return
    fi
    env "${CONTROLLER_ENV[@]}" "NEOMD_DERIVED_DATA=$root" \
        NEOMD_STUB_SCENARIO=detached-runner "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 0 "$status"
    check "appearance restored" true "$(cat "$STATE")"
    check "nothing left running" "" "$(stray_processes)"
    check "the runner was recognised and stopped before the restore" \
        "write true witness=gone" "$(appearance_write true)"
    check "the run's own directory was removed afterwards" 0 "$(own_run_directories "$root")"
    rm -rf "$root"
}

# The defect this covers: a refusal list can only name the ways of moving the build
# products that somebody thought of. Everything the contract does not name is refused
# before a run starts, and everything it does name still reaches xcodebuild.
test_argument_contract() {
    scenario "an argument outside the contract is refused before anything is built"
    local log="$WORK/arguments.log" status argument
    local elsewhere='/tmp/neomd-host-regression-elsewhere'
    local refused=(
        "-derivedDataPath $elsewhere"
        "-derivedDataPath=$elsewhere"
        "SYMROOT=$elsewhere"
        "OBJROOT=$elsewhere"
        "BUILD_DIR=$elsewhere"
        "CONFIGURATION_BUILD_DIR=$elsewhere"
        "TARGET_BUILD_DIR=$elsewhere"
        "-resultBundlePath $elsewhere.xcresult"
        "-xcconfig $elsewhere.xcconfig"
        "-scheme SomethingElse"
        "-destination platform=iOS"
        "-only-testing:"
        "-only-testing"
        "-only-testing -quiet"
        "-test-iterations"
        "-test-iterations twice"
        "-test-repetition-relaunch-enabled MAYBE"
        "--unheard-of"
        "NeoMDUITests"
    )
    for argument in "${refused[@]}"; do
        # Unquoted on purpose: each fixture is the word sequence a caller would type.
        env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=success "$CONTROLLER" \
            $argument > "$log" 2>&1
        status=$?
        check "refuses '$argument'" 64 "$status"
    done
    check "a refused run never reached xcodebuild" 0 \
        "$(grep -c 'stub xcodebuild' "$log" | tr -d ' ')"
    check "a refused run built nothing" 0 "$(own_run_directories)"
    check "a refused run never touched the appearance" true "$(cat "$STATE")"
    check_contains "the refusal says what is supported" 'this script supports:' "$log"

    scenario "the arguments the contract names reach xcodebuild"
    env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=success "$CONTROLLER" \
        -only-testing:NeoMDUITests/AppearanceUITests -skip-testing:NeoMDUITests/LaunchTests \
        -test-iterations 2 -test-repetition-relaunch-enabled YES -quiet \
        > "$log" 2>&1
    status=$?
    check "exit status" 0 "$status"
    check_matches "the test selection is forwarded" \
        'stub xcodebuild args:.*-only-testing:NeoMDUITests/AppearanceUITests.*-skip-testing:NeoMDUITests/LaunchTests' \
        "$log"
    check_matches "the repetition options are forwarded" \
        'stub xcodebuild args:.*-test-iterations 2 -test-repetition-relaunch-enabled YES' "$log"
    check_matches "a plain flag is forwarded" 'stub xcodebuild args:.*-quiet' "$log"
    check "appearance restored" true "$(cat "$STATE")"
}

# A run that cannot have a directory of its own cannot tell its processes from anybody
# else's, so it does not start.
test_allocation_failure() {
    scenario "a parent directory that cannot be created stops the run before it starts"
    local log="$WORK/allocation.log" status
    env "${CONTROLLER_ENV[@]}" 'NEOMD_DERIVED_DATA=/dev/null/neomd-host-regression' \
        NEOMD_STUB_SCENARIO=success "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 73 "$status"
    check "the appearance was never touched" true "$(cat "$STATE")"
    check "xcodebuild was never started" 0 "$(grep -c 'stub xcodebuild' "$log" | tr -d ' ')"
    check_contains "the reason is printed" "own build directory could not be created" "$log"
}

# What is kept and what is removed, and why: a run's own directory is this run's to
# remove, but not when it was asked for, and not while something out of it is running.
test_retention() {
    scenario "a run's own directory is kept when asked for and removed otherwise"
    local log="$WORK/retention.log" status
    env "${CONTROLLER_ENV[@]}" NEOMD_KEEP_DERIVED_DATA=1 NEOMD_STUB_SCENARIO=success \
        "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 0 "$status"
    check "the run's own directory was kept" 1 "$(own_run_directories)"
    check_contains "keeping it is explained" 'NEOMD_KEEP_DERIVED_DATA' "$log"
    rm -rf "$DERIVED_DATA_ROOT"/run-*

    scenario "a failed run is cleaned up, and says how to keep its build next time"
    env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=failing "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 65 "$status"
    check "the run's own directory was removed" 0 "$(own_run_directories)"
    check_contains "how to keep it is printed" 'NEOMD_KEEP_DERIVED_DATA=1' "$log"
}

# The defect this covers: a run that could not stop everything it owns must say so rather
# than restore over a survivor, and must not remove the directory that survivor is
# running out of. There is no process that really resists SIGKILL, so the stubbed ps adds
# one that cannot be signalled at all.
test_unstoppable_owned_process() {
    scenario "a survivor this run owns is reported, and its directory is kept"
    local log="$WORK/unstoppable.log" status
    if [ "$(id -u)" = "0" ]; then
        note "SKIPPED: this scenario relies on not being able to signal pid 1"
        return
    fi
    env "${CONTROLLER_ENV[@]}" NEOMD_STUB_PHANTOM=1 NEOMD_STUB_SCENARIO=success \
        "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 71 "$status"
    check "the appearance was restored anyway" true "$(cat "$STATE")"
    check_contains "the run's own status is still reported" 'the run itself: 0' "$log"
    check_contains "the survivor is named" 'ERROR: could not stop' "$log"
    check_contains "the directory is kept for it" 'could not be stopped' "$log"
    check "the run's own directory was kept" 1 "$(own_run_directories)"
    rm -rf "$DERIVED_DATA_ROOT"/run-*
}

# The defect this covers: a process launched through a different spelling of the same
# directory — /tmp and /private/tmp are the same place — was not recognised as this run's
# own, so the app under test outlived a cancelled run.
test_symlinked_derived_data() {
    scenario "a runner launched through another spelling of the same path is still owned"
    local log="$WORK/symlink.log" status link
    if ! have_standin; then
        note "SKIPPED: cc and /usr/bin/python3 are needed for the stand-in runner"
        return
    fi
    link="$WORK/link"
    ln -sfn "$WORK" "$link"
    # The controller is told about the parent directory through a symlink and resolves
    # it, so what it builds into is spelled one way and the same place is reachable
    # through the symlink under another. The stand-in runner is launched with that other
    # spelling; both are the same directory.
    env "${CONTROLLER_ENV[@]}" "NEOMD_DERIVED_DATA=$link/DerivedData" \
        NEOMD_STUB_RUNNER_SPELLING=alias \
        NEOMD_STUB_SCENARIO=detached-runner-alias-spelling "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 0 "$status"
    check "appearance restored" true "$(cat "$STATE")"
    check "nothing left running" "" "$(stray_processes)"
    check "the runner was recognised and stopped before the restore" \
        "write true witness=gone" "$(appearance_write true)"
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

# The defect this covers: everything running out of the *configured* derived data
# directory was treated as this run's own. That directory is shared by default and
# reusable by request, so a reader somebody opened from an earlier build of the same
# products was terminated by a run that had launched nothing at all.
#
# Both stand-ins are real executables at a real NeoMD.app path, started before the
# controller, in their own sessions and process groups: one under the very directory the
# controller is configured with, one under an unrelated directory. Neither belongs to the
# run, so neither may be signalled — and it has to hold for a run that finishes and for
# one that is cancelled, because cleanup is the same code either way.
test_unowned_processes_are_never_signalled() {
    scenario "processes this run did not start are left alone when it finishes"
    local log="$WORK/unowned.log" status same sibling different pid signal expected
    local sibling_root="$DERIVED_DATA_ROOT/run-siblingaaaa"
    if ! have_standin; then
        note "SKIPPED: cc and /usr/bin/python3 are needed to start the stand-in processes"
        return
    fi

    same=$(start_unowned_standin "$DERIVED_DATA_ROOT")
    sibling=$(start_unowned_standin "$sibling_root")
    different=$(start_unowned_standin "$OTHER_DERIVED_DATA_ROOT")
    sleep 0.5
    check "the stand-ins are running before the controller starts" "running running running" \
        "$(process_state "$same") $(process_state "$sibling") $(process_state "$different")"

    env "${CONTROLLER_ENV[@]}" NEOMD_STUB_SCENARIO=no-app "$CONTROLLER" > "$log" 2>&1
    status=$?
    check "exit status" 0 "$status"
    check "a pre-existing process in the configured directory survives" running \
        "$(process_state "$same")"
    check "another run's process under the same parent survives" running \
        "$(process_state "$sibling")"
    check "a process under a different directory survives" running \
        "$(process_state "$different")"
    check "the run built into a directory of its own" 1 \
        "$(grep -cF "build directory: $WORK_PHYSICAL/DerivedData/run-" "$log" | tr -d ' ')"
    check "the configured directory itself was not emptied" exists \
        "$([ -x "$DERIVED_DATA_ROOT/Build/Products/Debug/NeoMD.app/Contents/MacOS/NeoMD" ] \
            && printf exists || printf gone)"
    check "only the other run's directory is left behind" "$sibling_root" \
        "$(find "$DERIVED_DATA_ROOT" -maxdepth 1 -name 'run-*' 2>/dev/null)"

    # Cleanup is the same code whichever way a run ends, so the same three processes have
    # to survive both ways of cancelling one.
    for signal in TERM INT; do
        case $signal in
            TERM) expected=143 ;;
            *) expected=130 ;;
        esac
        scenario "processes this run did not start are left alone when SIG$signal arrives"
        rm -f "$WORK/ready"
        log="$WORK/unowned-cancelled-$signal.log"
        start_signalled_controller "$log"
        pid=$!
        if ! wait_for_ready; then
            check "the stub reached its request" ready "not ready"
            kill -KILL "$pid" 2>/dev/null
            continue
        fi
        guard_with_watchdog "$pid" 60
        kill -"$signal" "$pid"
        wait "$pid"
        status=$?
        stop_watchdog
        check "exit status" "$expected" "$status"
        check "appearance restored" true "$(cat "$STATE")"
        check "a pre-existing process in the configured directory survives" running \
            "$(process_state "$same")"
        check "another run's process under the same parent survives" running \
            "$(process_state "$sibling")"
        check "a process under a different directory survives" running \
            "$(process_state "$different")"
    done

    stop_standin "$same"
    stop_standin "$sibling"
    stop_standin "$different"
    rm -rf "$sibling_root"
    check "nothing else was left running" "" "$(stray_processes)"
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
wanted relative-derived-data && test_relative_derived_data
wanted spaced-derived-data && test_spaced_derived_data
wanted argument-contract && test_argument_contract
wanted allocation-failure && test_allocation_failure
wanted retention && test_retention
wanted unstoppable-owned-process && test_unstoppable_owned_process
wanted relaunch && test_relaunch_identity
wanted symlinked-derived-data && test_symlinked_derived_data
wanted unowned-processes && test_unowned_processes_are_never_signalled
wanted restore-refused && test_restore_refused
wanted rejected-requests && test_rejected_requests

printf '\n%s passed, %s failed\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
