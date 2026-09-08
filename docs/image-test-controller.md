# Image UI test controller (#12)

The sandboxed XCTest runner has outgoing-network access but no incoming-network entitlement. Run remote image tests through the external controller; do not add incoming-network access or disable the sandbox.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Scripts -p 'test_image_test_controller.py' -v
python3 Scripts/image_test_controller.py --timeout 600 -- \
  xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-12-DerivedData \
  -only-testing:NeoMDUITests/DocumentImageUITests/testRemoteImagesLoadWithoutBlockingText test
```

The controller binds only `127.0.0.1` on an OS-assigned nonzero port, serves a finite fixture allowlist, and verifies readiness with a fresh invocation identity. Xcode forwards `TEST_RUNNER_NEOMD_IMAGE_ENDPOINT` into the runner as `NEOMD_IMAGE_ENDPOINT`. The runner verifies identity over URLSession using existing outgoing-network permission. Missing, invalid or unready endpoints fail rather than skip. No control files are written from the sandbox.

The slow image response remains held until the runner observes retained end text and the image loading state, then POSTs to the identity-scoped release endpoint. Its 90-second server wait is a failure ceiling, not a delivery delay. Success, corrupt response, 404, refused connection, and HTTPS-to-plain-server TLS failure remain distinct cases. This is **loopback evidence only**, not arbitrary-host HTTP/HTTPS or ATS validation.

The controller owns the HTTP server in its process and starts its test command in a fresh process group. Exit, startup failure, timeout and interruption close the server and release pending handlers; only the command's owned process group is terminated if still running. Lifecycle tests cover bind failure, readiness timeout, absent command, command timeout, injected interruption, identity isolation and release. Do not launch unrelated jobs through this wrapper.

## Native clipboard test gate (exclusive window required)

Native-copy tests now require `--preserve-clipboard`. Before each copy, the runner requests a lease from an independent native guardian. The guardian materializes every original item/type into memory (no secret files or logs), refuses incomplete or changing snapshots, and restores on normal completion or controller-pipe EOF. It only restores after one expected fixture-copy ownership change; additional or unexpected changes are preserved rather than overwritten. It runs outside the test process group. Tests fail before copying when the guardian is unavailable.

**Remaining safety limitation:** `NSPasteboard` exposes `changeCount`, but no atomic compare-and-restore operation. The final check and write cannot exclude a concurrent user's write between them. Thus this is not an absolute non-clobber guarantee on a shared live clipboard. Three native-copy tests passed with this helper in an explicitly approved exclusive window; current-window restoration succeeded. That window is now released. Any rerun needs a newly approved isolated test login or explicitly exclusive clipboard session. The clipboard lost by the predecessor cannot be recovered by this helper.

Private-board-only validation (does not access `.general`):

```sh
xcrun swiftc Scripts/clipboard_guard.swift -o /tmp/neomd-clipboard-guardian
/tmp/neomd-clipboard-guardian --self-test
xcrun swift Scripts/test_clipboard_guard.swift /tmp/neomd-clipboard-guardian
```

Both probes passed: text/binary representations, multiple items, interruption before mutation, EOF after copy, and refusal to overwrite intervening/unexpected changes. Live native-copy integration subsequently passed 3/0/0, and guardian command-startup-failure cleanup passed. See [M1-12 validation](m1-12-validation.md) for artifacts, source-delta reuse assessment and current nonclipboard commands, including the required separate plain-app build/environment. Do not treat private probes as native UI or permission evidence.

## Historical controller evidence

- Five Python controller tests passed.
- Targeted remote image UI test passed in 20.952 seconds with the sandboxed URLSession readiness/release handshake and existing byte/mtime teardown assertions (`/tmp/neomd-12-external-helper-ui.log`).
- Standalone owned-host unavailable-image paragraph/button stable-height probe passed (`/tmp/neomd-12-host-probe.log`). This isolates basic paragraph measurement; it does not establish that the full reader scrolling hang is fixed.
- Original failed run remains preserved: listener bind denied, followed by requests to port 0 and the slow-image assertion failure **before** the later XCTest teardown assertion. No independent teardown defect has been established.
- Current full-reader unavailable-image/repeated-scroll and other story results are recorded in [M1-12 validation](m1-12-validation.md). Only the unchanged baseline full-reflow gate is BLOCKED/deferred under #36. These results are not milestone acceptance.
