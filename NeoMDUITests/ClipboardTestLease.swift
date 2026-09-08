import Foundation
import XCTest

/// The external guardian holds all representations across runner/controller death.
/// Fails before copying if the controller is absent or the snapshot is incomplete.
@MainActor enum ClipboardTestLease {
    static func copy(expected: String, action: () -> Void) async throws {
        try await request(["action": "begin", "expected": expected])
        action()
        try await request(["action": "finish"])
    }

    private static func request(_ command: [String: String]) async throws {
        let endpoint = try XCTUnwrap(ProcessInfo.processInfo.environment["NEOMD_IMAGE_ENDPOINT"],
            "Run through Scripts/image_test_controller.py --preserve-clipboard before native copy tests")
        let url = try XCTUnwrap(URL(string: endpoint + "/clipboard"))
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: command)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data == Data("ok".utf8) else {
            // Do not attach request/response/clipboard data to test failures.
            throw LeaseError.refused
        }
    }

    private enum LeaseError: Error { case refused }
}
