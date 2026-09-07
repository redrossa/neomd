#!/usr/bin/env python3
"""Run real-source lifetime cases in separate Xcode test processes.

Uses only stdlib. Output must be a new directory outside the repository. The
negative control is expected to fail; no other failure, skip or restart passes.
"""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
METHODS = (
    "testSynchronousRelease", "testDetachedRelease", "testDetachedReturnMainRelease",
    "testCancelledDiscard", "testReplacementAndAliases", "testRepeatedIndependentSnapshots",
    "testMixedAndAnnotated",
)


def execute(command, log, env, timeout):
    with log.open("w") as stream:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            # Only this invocation's process group; never global app/runner cleanup.
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise RuntimeError(f"Timed out: {log}") from None


def inspect(bundle):
    result = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(bundle)],
        capture_output=True, text=True, check=True, timeout=30,
    )
    return json.loads(result.stdout)


def passed(code, summary, text, depth):
    return (code == 0 and summary.get("result") == "Passed"
            and summary.get("totalTestCount") == 1 and summary.get("passedTests") == 1
            and summary.get("failedTests") == 0 and summary.get("skippedTests") == 0
            and f"NEOMD_LIFECYCLE_RELEASED depth={depth}" in text
            and not any(word in text.lower() for word in
                        ("restarting after", "test runner crashed", "unexpectedly exited")))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--depths", nargs="+", type=int, default=[1, 1000, 50000])
    parser.add_argument("--methods", nargs="+", choices=METHODS, default=list(METHODS))
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    if any(depth < 1 for depth in args.depths):
        parser.error("depths must be positive")
    if args.output:
        output = args.output.resolve()
        if output == ROOT or ROOT in output.parents:
            parser.error("output must be outside the repository")
        output.mkdir(parents=True, exist_ok=False)
    else:
        output = Path(tempfile.mkdtemp(prefix="NeoMD-lifecycle-"))
    print(f"Evidence: {output}", flush=True)
    base = ["xcodebuild", "-project", str(ROOT / "NeoMD.xcodeproj"), "-scheme", "RenderLifecycle",
            "-destination", "platform=macOS", "-derivedDataPath", str(output / "DerivedData"),
            "-parallel-testing-enabled", "NO", "ONLY_ACTIVE_ARCH=YES"]
    env = os.environ.copy()
    build = base + ["build-for-testing"]
    if execute(build, output / "build.log", env, args.timeout) != 0:
        raise RuntimeError(f"Build failed: {output / 'build.log'}")
    records = [{"command": build, "result": "build passed"}]
    cases = [("testHarnessNegativeControl", 1)] + [(m, d) for m in args.methods for d in args.depths]
    for method, depth in cases:
        name = f"{method}-{depth}"
        bundle = output / f"{name}.xcresult"
        log = output / f"{name}.log"
        command = base + ["test-without-building", f"-only-testing:RenderLifecycleTests/RenderLifecycleTests/{method}",
                          "-resultBundlePath", str(bundle)]
        env["TEST_RUNNER_NEOMD_LIFECYCLE_DEPTH"] = str(depth)
        code = execute(command, log, env, args.timeout)
        summary = inspect(bundle)
        text = log.read_text()
        success = passed(code, summary, text, depth)
        if method == "testHarnessNegativeControl":
            success = (not success and code != 0 and summary.get("totalTestCount") == 1
                       and summary.get("failedTests") == 1 and summary.get("skippedTests") == 0
                       and "Intentional failure: outer harness must reject this run" in text)
        record = {"method": method, "depth": depth, "command": command, "exit": code,
                  "accepted": success, "summary": summary}
        records.append(record)
        (output / "results.json").write_text(json.dumps(records, indent=2) + "\n")
        print(f"{name}: {'PASS' if success else 'FAIL'}", flush=True)
        if not success:
            raise RuntimeError(f"Lifecycle gate failed; see {log}")
    print(f"Passed {len(cases) - 1} isolated cases plus rejected negative control", flush=True)


if __name__ == "__main__":
    main()
