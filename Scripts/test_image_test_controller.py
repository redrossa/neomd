import concurrent.futures
from pathlib import Path
import socket
import subprocess
import sys
import unittest
import urllib.error
import urllib.request
from unittest.mock import patch

import image_test_controller as controller

FIXTURES = Path(__file__).resolve().parents[1] / "docs/fixtures/m1-12-images"


class ControllerTests(unittest.TestCase):
    def test_identity_release_and_cleanup(self):
        with controller.serving(FIXTURES) as server:
            port = server.server_port
            with self.assertRaises(urllib.error.HTTPError):
                urllib.request.urlopen(f"http://127.0.0.1:{port}/wrong/ready")
            with concurrent.futures.ThreadPoolExecutor() as executor:
                pending = executor.submit(urllib.request.urlopen, server.endpoint + "/slow.png")
                self.assertFalse(server.released.is_set())
                request = urllib.request.Request(server.endpoint + "/release", method="POST")
                with urllib.request.urlopen(request) as response:
                    self.assertEqual(response.read().decode(), server.identity)
                with pending.result(timeout=5) as response:
                    self.assertEqual(response.read(), (FIXTURES / "img/small.png").read_bytes())
            with urllib.request.urlopen(server.endpoint + "/not-an-image.png") as response:
                self.assertEqual(response.read(), b"This is not an image")
            with self.assertRaises(urllib.error.HTTPError):
                urllib.request.urlopen(server.endpoint + "/absent.png")
        with socket.socket() as probe:
            self.assertNotEqual(probe.connect_ex(("127.0.0.1", port)), 0)
        with controller.serving(FIXTURES) as next_server:
            self.assertNotEqual(server.identity, next_server.identity)

    def test_bind_failure(self):
        with controller.serving(FIXTURES) as server:
            with self.assertRaises(OSError):
                controller.FixtureServer(FIXTURES, ("127.0.0.1", server.server_port))

    def test_readiness_failure_closes_server(self):
        instances = []
        real_server = controller.FixtureServer

        def create(*args):
            server = real_server(*args)
            instances.append(server)
            return server

        with patch.object(controller, "FixtureServer", side_effect=create), patch.object(
            controller.urllib.request, "urlopen", side_effect=TimeoutError("readiness timeout")
        ):
            with self.assertRaises(TimeoutError):
                with controller.serving(FIXTURES):
                    self.fail("Must not start test command")
        self.assertEqual(instances[0].socket.fileno(), -1)

    def test_command_start_failure_and_timeout(self):
        with self.assertRaises(FileNotFoundError):
            controller.run(["/nonexistent/neomd-test-command"], FIXTURES, 1)
        with self.assertRaises(subprocess.TimeoutExpired):
            controller.run([sys.executable, "-c", "import signal; signal.pause()"], FIXTURES, 0.1)

    def test_interruption_cleans_owned_child(self):
        real_popen = subprocess.Popen
        children = []

        def start(*args, **kwargs):
            child = real_popen(*args, **kwargs)
            children.append(child)
            original_wait = child.wait
            calls = 0

            def wait(*args, **kwargs):
                nonlocal calls
                calls += 1
                if calls == 1:
                    raise InterruptedError("injected controller interruption")
                return original_wait(*args, **kwargs)

            child.wait = wait
            return child

        with patch.object(controller.subprocess, "Popen", side_effect=start):
            with self.assertRaises(InterruptedError):
                controller.run([sys.executable, "-c", "import signal; signal.pause()"], FIXTURES, 5)
        self.assertIsNotNone(children[0].poll())


if __name__ == "__main__":
    unittest.main()
