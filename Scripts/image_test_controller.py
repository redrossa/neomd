#!/usr/bin/env python3
"""Own a loopback fixture server for exactly one xcodebuild invocation."""
import argparse
import contextlib
import http.server
import json
import os
from pathlib import Path
import secrets
import select
import signal
import subprocess
import threading
import tempfile
import urllib.request


class FixtureServer(http.server.ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, fixtures, address=("127.0.0.1", 0)):
        self.identity = secrets.token_hex(24)
        self.fixtures = Path(fixtures)
        self.released = threading.Event()
        self.closed = threading.Event()
        self.clipboard = None
        super().__init__(address, Handler)
        if not self.server_port:
            self.server_close()
            raise RuntimeError("No bound port")

    @property
    def endpoint(self):
        return f"http://127.0.0.1:{self.server_port}/{self.identity}"


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def respond(self, status, body):
        self.send_response(status)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        with contextlib.suppress(BrokenPipeError, ConnectionResetError):
            self.wfile.write(body)

    def do_GET(self):
        prefix = f"/{self.server.identity}/"
        if not self.path.startswith(prefix):
            self.respond(403, b"Unknown invocation")
            return
        name = self.path[len(prefix):]
        if name == "ready":
            self.respond(200, self.server.identity.encode())
            return
        if name == "slow.png":
            if not self.server.released.wait(90) or self.server.closed.is_set():
                self.respond(503, b"Release not received")
                return
            name = "small.png"
        # Deliberately finite fixture allowlist; never resolve request paths.
        if name == "not-an-image.png":
            self.respond(200, b"This is not an image")
            return
        if name not in {"small.png", "wide.png"}:
            self.respond(404, b"Not found")
            return
        self.respond(200, (self.server.fixtures / "img" / name).read_bytes())

    def do_POST(self):
        if self.path == f"/{self.server.identity}/clipboard":
            length = int(self.headers.get("Content-Length", "0"))
            if not self.server.clipboard or not 0 < length <= 4096:
                self.respond(409, b"Clipboard guardian unavailable")
                return
            try:
                command = json.loads(self.rfile.read(length))
                success = self.server.clipboard.request(command)
            except (ValueError, OSError, TimeoutError):
                success = False
            self.respond(200 if success else 409, b"ok" if success else b"Clipboard lease refused")
            return
        if self.path != f"/{self.server.identity}/release":
            self.respond(403, b"Unknown invocation")
            return
        self.server.released.set()
        self.respond(200, self.server.identity.encode())


@contextlib.contextmanager
def serving(fixtures):
    server = FixtureServer(fixtures)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with urllib.request.urlopen(server.endpoint + "/ready", timeout=5) as response:
            if response.read().decode() != server.identity:
                raise RuntimeError("Fixture identity mismatch")
        yield server
    finally:
        server.closed.set()
        server.released.set()
        server.shutdown()
        server.server_close()
        thread.join()


class ClipboardGuardian:
    """Keep representations in an independent native process, never in logs/files."""

    def __init__(self, executable):
        self.lock = threading.Lock()
        self.process = subprocess.Popen([str(executable)], stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
            start_new_session=True)
        try:
            if self.response() != "ready":
                raise RuntimeError("Clipboard guardian did not start")
        except BaseException:
            self.close()
            raise

    def response(self):
        if not select.select([self.process.stdout], [], [], 10)[0]:
            raise TimeoutError("Clipboard guardian did not respond")
        return self.process.stdout.readline().strip()

    def request(self, command):
        with self.lock:
            self.process.stdin.write(json.dumps(command) + "\n")
            self.process.stdin.flush()
            return self.response() == "ok"

    def close(self):
        # EOF also occurs on controller SIGKILL. The guardian is deliberately
        # outside the test command's process group and restores before exiting.
        self.process.stdin.close()
        try:
            code = self.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.process.terminate()
            self.process.wait(timeout=5)
            raise RuntimeError("Clipboard guardian cleanup timed out")
        if code:
            raise RuntimeError("Clipboard restoration refused; concurrent/unexpected change preserved")


@contextlib.contextmanager
def clipboard_guard(enabled):
    if not enabled:
        yield None
        return
    with tempfile.TemporaryDirectory(prefix="NeoMD-Clipboard-Guardian-") as temporary:
        executable = Path(temporary) / "guardian"
        source = Path(__file__).with_name("clipboard_guard.swift")
        subprocess.run(["xcrun", "swiftc", str(source), "-o", str(executable)], check=True, timeout=60)
        guardian = ClipboardGuardian(executable)
        try:
            yield guardian
        finally:
            guardian.close()


def run(command, fixtures, timeout, preserve_clipboard=False):
    # No runner filesystem writes: URLSession controls release using network.client.
    with clipboard_guard(preserve_clipboard) as guardian, serving(fixtures) as server:
        server.clipboard = guardian
        environment = os.environ.copy()
        environment["TEST_RUNNER_NEOMD_IMAGE_ENDPOINT"] = server.endpoint
        process = subprocess.Popen(command, env=environment, start_new_session=True)
        old_handlers = {}

        def interrupt(signum, _frame):
            raise InterruptedError(f"Interrupted by signal {signum}")

        try:
            for signum in (signal.SIGINT, signal.SIGTERM):
                old_handlers[signum] = signal.signal(signum, interrupt)
            return process.wait(timeout=timeout)
        finally:
            for signum, handler in old_handlers.items():
                signal.signal(signum, handler)
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=float, default=600)
    parser.add_argument("--preserve-clipboard", action="store_true")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command[:1] == ["--"]:
        command = command[1:]
    if not command:
        parser.error("Supply xcodebuild command after --")
    fixtures = Path(__file__).resolve().parents[1] / "docs/fixtures/m1-12-images"
    try:
        return run(command, fixtures, args.timeout, args.preserve_clipboard)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(json.dumps({"image_test_controller_error": str(error)}), flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
