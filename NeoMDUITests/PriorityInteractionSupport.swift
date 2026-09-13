import AppKit
import ApplicationServices
import CryptoKit
import XCTest

/// Only the seven priority selectors use this support. No clipboard, event monitor,
/// permission changes, first-bundle-match adoption, or unchecked XCUI termination.
@MainActor
final class PriorityInteractionSupport {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    private func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(description: message) }
    }

    private func unwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) throws -> T {
        guard let value else { throw Failure(description: "Required value missing at \(file):\(line)") }
        return value
    }

    struct Fragment: Decodable { let id: String; let text: String; let separatorBefore: String }
    struct Oracle: Decodable { let fragments: [Fragment] }
    struct Point {
        let fragment: Int
        let offset: Int
        let screen: CGPoint
    }
    struct Window {
        let element: XCUIElement
        let ax: AXUIElement
        let document: URL
    }
    struct FileSnapshot { let url: URL; let bytes: Data; let modified: Date }

    let app = XCUIApplication()
    let run = UUID().uuidString
    let directory: URL
    let product: URL
    let executable: URL
    let executableHash: String
    let head: String
    let test: XCTestCase
    private var owned: NSRunningApplication?
    private var launched: Date?
    private var sources: [FileSnapshot] = []
    private var evidenceSerial = 0
    private var failureCaptured = false
    private var lastWindow: Window?
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    init(test: XCTestCase) throws {
        self.test = test
        let env = ProcessInfo.processInfo.environment
        guard let path = env["NEOMD_PRIORITY_PRODUCT_PATH"],
              let hash = env["NEOMD_PRIORITY_EXECUTABLE_SHA256"],
              let head = env["NEOMD_PRIORITY_HEAD"], head.count == 40,
              env["NEOMD_PRIORITY_GRAPHICAL_LEASE"] == "1" else {
            throw XCTSkip("BLOCKED: coordinator product/hash/head and exclusive graphical lease required")
        }
        self.head = head
        product = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        executable = product.appendingPathComponent("Contents/MacOS/NeoMD")
        executableHash = hash
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("neomd-priority-\(run)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard Self.hash(try Data(contentsOf: executable)) == hash else {
            throw XCTSkip("BLOCKED: built executable hash does not match coordinator provenance")
        }
    }

    static func hash(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }

    func record(_ text: String, name: String) {
        evidenceSerial += 1
        let payload = "run=\(run) head=\(head)\n\(text)"
        let attachment = XCTAttachment(string: payload)
        attachment.name = name
        attachment.lifetime = .keepAlways
        test.add(attachment)
        try? Data(payload.utf8).write(to: directory.appendingPathComponent("\(evidenceSerial)-\(name).txt"))
    }

    func launch(appearance: String = "Light", delay: Int? = nil) throws {
        let existing = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == "io.neomd.NeoMD" || $0.executableURL?.lastPathComponent == "NeoMD"
        }
        record(existing.map { "pid=\($0.processIdentifier) start=\(String(describing: $0.launchDate)) executable=\(String(describing: $0.executableURL))" }.joined(separator: "\n"), name: "preflight")
        guard existing.isEmpty else { throw XCTSkip("BLOCKED: unowned NeoMD; user must close normally") }
        guard AXIsProcessTrusted() else { throw XCTSkip("BLOCKED: AX unavailable; no permission request made") }
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["NEOMD_UI_TEST_APPEARANCE"] = appearance
        if let delay { app.launchEnvironment["NEOMD_UI_TEST_RESIZE_RESTORATION_DELAY_MILLISECONDS"] = String(delay) }
        let before = Date()
        app.launch()
        let candidates = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == "io.neomd.NeoMD" }
        guard candidates.count == 1, let candidate = candidates.first,
              candidate.executableURL?.resolvingSymlinksInPath() == executable,
              let start = candidate.launchDate, start >= before.addingTimeInterval(-1) else {
            throw XCTSkip("BLOCKED: launched process cannot be owned; no unchecked cleanup attempted")
        }
        owned = candidate
        launched = start
        try verifyProcess()
        let dylib = product.appendingPathComponent("Contents/MacOS/NeoMD.debug.dylib")
        record("pid=\(candidate.processIdentifier) start=\(start) bundle=\(product.path) executable=\(executable.path) sha256=\(executableHash) debugDylibSHA256=\((try? Self.hash(Data(contentsOf: dylib))) ?? "absent") appearance=\(appearance) instrumentation=off", name: "product-identity")
        let panel = app.windows["open-panel"]
        if panel.exists { app.typeKey(.escape, modifierFlags: []) }
    }

    func verifyProcess() throws {
        guard let owned, let live = NSRunningApplication(processIdentifier: owned.processIdentifier),
              !live.isTerminated, live.launchDate == launched,
              live.executableURL?.resolvingSymlinksInPath() == executable,
              Self.hash(try Data(contentsOf: executable)) == executableHash else {
            throw XCTSkip("BLOCKED: owned PID/start/path/hash continuity lost")
        }
    }

    func fixture(_ relative: String, name: String? = nil, copies: Int = 1) throws -> URL {
        let original = root.appendingPathComponent("docs/fixtures/" + relative)
        let data = try Data(contentsOf: original)
        var bytes = Data()
        for index in 0..<copies {
            if index > 0 { bytes.append(10) }
            bytes.append(data)
        }
        let url = directory.appendingPathComponent(name ?? original.lastPathComponent)
        try bytes.write(to: url)
        let date = try unwrap(url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        sources.append(.init(url: url, bytes: bytes, modified: date))
        record("url=\(url.absoluteString) bytes=\(bytes.count) sha256=\(Self.hash(bytes)) mtime=\(date)", name: "fixture")
        return url
    }

    func open(_ url: URL, fragment: String? = nil) async throws -> Window {
        try verifyProcess()
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.fragment = fragment
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.allowsRunningApplicationSubstitution = false
        config.createsNewApplicationInstance = false
        let returned = try await NSWorkspace.shared.open([try unwrap(components.url)], withApplicationAt: product, configuration: config)
        try require(returned.processIdentifier == owned?.processIdentifier, "Open returned a different process")
        try verifyProcess()
        let element = app.windows[url.lastPathComponent].firstMatch
        try require(element.waitForExistence(timeout: 8), "Opened document window did not appear within 8 seconds")
        let ax = try axWindow(document: url, frame: element.frame)
        let window = Window(element: element, ax: ax, document: url)
        try checkpoint(window, "opened")
        return window
    }

    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    func axElement(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    func applicationAX() throws -> AXUIElement {
        try verifyProcess()
        return AXUIElementCreateApplication(try unwrap(owned).processIdentifier)
    }

    func windows() throws -> [AXUIElement] {
        try verifyProcess()
        let application = AXUIElementCreateApplication(try unwrap(owned).processIdentifier)
        return try unwrap(attribute(application, kAXWindowsAttribute) as? [AXUIElement])
    }

    func axWindow(document: URL, frame: CGRect) throws -> AXUIElement {
        let candidates = try windows().filter {
            let doc = attribute($0, kAXDocumentAttribute) as? String
            return doc.flatMap(URL.init(string:))?.standardizedFileURL == document.standardizedFileURL
                && abs(rect($0).minX - frame.minX) < 3 && abs(rect($0).minY - frame.minY) < 3
        }
        guard candidates.count == 1 else { throw XCTSkip("BLOCKED: unique PID/window/document AX identity unavailable") }
        return candidates[0]
    }

    /// Observation-only native identity gate; no XCUI counterpart or focus action.
    func verifyRetainedWindow(ax: AXUIElement, document: URL, phase: String) throws {
        let owner = try verifyCleanupOwner()
        var pid: pid_t = 0
        try require(AXUIElementGetPid(ax, &pid) == .success && pid == owner.processIdentifier
            && AXUIElementSetMessagingTimeout(ax, 0.25) == .success, "Retained native window ownership unavailable")
        let native = try windows()
        try require(native.count <= 32 && native.filter { CFEqual($0, ax) }.count == 1,
                    "Retained native window membership unavailable/ambiguous")
        try require((attribute(ax, kAXDocumentAttribute) as? String).flatMap(URL.init(string:))?.standardizedFileURL
            == document.standardizedFileURL, "Retained native window document changed")
        var point = CGPoint.zero, size = CGSize.zero
        guard let p = attribute(ax, kAXPositionAttribute), let s = attribute(ax, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID(),
              AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size),
              [point.x, point.y, size.width, size.height].allSatisfy(\.isFinite), size.width > 0, size.height > 0 else {
            throw Failure(description: "Retained native window geometry unavailable")
        }
        _ = try verifyCleanupOwner()
        record("pid=\(pid) start=\(String(describing: launched)) executable=\(executable.path) sha256=\(executableHash) document=\(document.absoluteString) AX=\(ax) frame=\(CGRect(origin: point, size: size)) membership=CFEqual nativeWindowNumber=unavailable; observation only", name: "native-identity-" + phase)
    }

    /// Diagnostic only: preserve the original error even if role/parent queries also fail.
    func axFailure(_ element: AXUIElement, parent: AXUIElement?, attribute name: String, error: AXError) -> String {
        var role: CFTypeRef?, actualParent: CFTypeRef?
        let roleError = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let parentError = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &actualParent)
        return "node=\(element) role=\(String(describing: role)) roleError=\(roleError.rawValue) traversalParent=\(String(describing: parent)) AXParent=\(String(describing: actualParent)) parentError=\(parentError.rawValue) attribute=\(name) error=\(error.rawValue)"
    }

    private struct ReaderNotReady: Error { let reason: String }

    /// Async NEW-window setup only. No input, geometry sampling, or landing predicate.
    /// Uses the existing wait cadence (50ms), bounded by BOTH 60 attempts and 3s.
    /// AX failure is not assumed transient: every error is retained and exhaustion fails.
    func waitForNewReaderAX(_ window: AXUIElement, document: URL, heading: String, phase: String) async throws {
        let start = Date(), deadline = start.addingTimeInterval(3)
        var attempts: [String] = []
        defer { record(attempts.joined(separator: "\n"), name: "new-reader-readiness-" + phase) }
        let owner = try verifyCleanupOwner()
        let membership = try windows()
        try require(membership.count <= 32 && membership.filter { CFEqual($0, window) }.count == 1,
                    "Readiness initial exact membership/cap failed")
        func checked(_ element: AXUIElement) throws {
            var pid: pid_t = 0
            try require(AXUIElementGetPid(element, &pid) == .success && pid == owner.processIdentifier,
                        "Readiness fatal PID mismatch node=\(element)")
            try require(Date() < deadline, "Readiness overall 3s deadline exceeded node=\(element)")
            try require(AXUIElementSetMessagingTimeout(element, Float(min(0.25, deadline.timeIntervalSinceNow))) == .success,
                        "Readiness messaging bound unavailable node=\(element)")
        }
        func value(_ element: AXUIElement, _ name: String, parent: AXUIElement? = nil, optional: Bool = false) throws -> CFTypeRef? {
            try checked(element)
            var result: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, name as CFString, &result)
            if error == .success, result != nil { return result }
            let detail = axFailure(element, parent: parent, attribute: name, error: error)
            attempts.append("elapsed=\(Date().timeIntervalSince(start)) \(detail)")
            if optional && (error == .noValue || error == .attributeUnsupported) {
                if name == kAXChildrenAttribute && error == .attributeUnsupported {
                    try checked(element)
                    var names: CFArray?
                    let namesError = AXUIElementCopyAttributeNames(element, &names)
                    if namesError != .success {
                        let namesDetail = axFailure(element, parent: parent, attribute: "AXAttributeNames", error: namesError)
                        attempts.append(namesDetail)
                        if namesError == .failure || namesError == .cannotComplete { throw ReaderNotReady(reason: namesDetail) }
                        throw Failure(description: "Readiness fatal childless proof: " + namesDetail)
                    }
                    try require((names as? [String]).map { !$0.contains(kAXChildrenAttribute) } == true,
                                "Readiness fatal unproven childless node=\(element)")
                }
                return nil
            }
            if error == .failure || error == .cannotComplete || error == .noValue {
                throw ReaderNotReady(reason: detail)
            }
            throw Failure(description: "Readiness fatal required attribute: " + detail)
        }
        func consistentMembership() throws {
            _ = try verifyCleanupOwner()
            let current = try windows()
            try require(current.count == membership.count && membership.allSatisfy { old in current.filter { CFEqual(old, $0) }.count == 1 },
                        "Readiness fatal exact window membership changed")
            let actual = try value(window, kAXDocumentAttribute) as? String
            try require(actual.flatMap(URL.init(string:))?.standardizedFileURL == document.standardizedFileURL,
                        "Readiness fatal document mismatch node=\(window) actual=\(String(describing: actual))")
        }
        for attempt in 1...60 {
            let began = Date()
            attempts.append("attempt=\(attempt) begin elapsed=\(began.timeIntervalSince(start))")
            do {
                try consistentMembership()
                var pending: [(AXUIElement, AXUIElement?)] = [(window, nil)]
                var tree: [(AXUIElement, String)] = []
                while let (node, parent) = pending.popLast() {
                    try require(tree.count < 4096 && pending.count < 4096, "Readiness fatal traversal/node cap node=\(node)")
                    try require(!tree.contains { CFEqual($0.0, node) }, "Readiness fatal duplicate/cyclic node=\(node)")
                    guard let role = try value(node, kAXRoleAttribute, parent: parent) as? String else {
                        throw Failure(description: "Readiness invalid role type node=\(node)")
                    }
                    tree.append((node, role))
                    if let parent {
                        let reciprocal = axElement(try value(node, kAXParentAttribute, parent: parent))
                        let relationship = "node=\(node) role=\(role) requestedAttribute=AXParent enumeratedBy=AXChildren expectedParent=\(parent) expectedParentRole=\(String(describing: attribute(parent, kAXRoleAttribute))) actualParent=\(String(describing: reciprocal)) actualParentRole=\(String(describing: reciprocal.flatMap { attribute($0, kAXRoleAttribute) }))"
                        attempts.append(relationship)
                        // AXChildren may enumerate virtual table row groupings while
                        // AXParent names the table. Prove actual owned ancestry for
                        // EVERY node, not a role-based AXCell exemption.
                        var current = node, ancestors: [AXUIElement] = []
                        while !CFEqual(current, window) {
                            try checked(current)
                            try require(ancestors.count < 32 && !ancestors.contains { CFEqual($0, current) },
                                        "Readiness fatal actual ancestry cycle/cap node=\(node)")
                            try require(try value(current, kAXRoleAttribute) as? String != kAXWindowRole,
                                        "Readiness fatal actual ancestry crossed window node=\(node)")
                            ancestors.append(current)
                            guard let actualParent = axElement(try value(current, kAXParentAttribute)) else {
                                throw Failure(description: "Readiness actual parent unavailable node=\(current)")
                            }
                            current = actualParent
                        }
                        try checked(current)
                        // Required content/reader/heading reciprocal paths below
                        // remain strict; enumeration alone never establishes them.
                    }
                    // AXChildren is legitimately absent on terminal controls; required
                    // reader/content ancestry below must still be present in this tree.
                    if let childrenValue = try value(node, kAXChildrenAttribute, parent: parent, optional: true) {
                        guard let children = childrenValue as? [AXUIElement] else { throw Failure(description: "Readiness invalid children type node=\(node)") }
                        try require(tree.count + pending.count + children.count <= 4096, "Readiness fatal traversal cap node=\(node)")
                        pending += children.reversed().map { ($0, node) }
                    }
                }
                var readers: [AXUIElement] = [], headings: [AXUIElement] = []
                for (node, role) in tree {
                    if role == kAXScrollAreaRole,
                       try value(node, kAXIdentifierAttribute, optional: true) as? String == "DocumentReaderScrollView" { readers.append(node) }
                    if role == "AXHeading", try value(node, kAXValueAttribute) as? String == heading { headings.append(node) }
                }
                try require(readers.count <= 1 && headings.count <= 1, "Readiness fatal ambiguous reader/heading")
                guard let reader = readers.first, let headingNode = headings.first else {
                    throw ReaderNotReady(reason: "complete tree nodes=\(tree.count) readerCount=\(readers.count) headingCount=\(headings.count) root=\(window)")
                }
                guard let contents = try value(reader, kAXContentsAttribute) as? [AXUIElement] else {
                    throw Failure(description: "Readiness invalid AXContents type reader=\(reader)")
                }
                try require(contents.count <= 1, "Readiness fatal ambiguous content reader=\(reader)")
                guard let content = contents.first else { throw ReaderNotReady(reason: "empty AXContents reader=\(reader)") }
                try require(tree.contains { CFEqual($0.0, content) }, "Readiness content outside complete tree reader=\(reader) content=\(content)")
                func ancestry(_ node: AXUIElement, through required: AXUIElement) throws {
                    var current = node, seen: [AXUIElement] = [], found = false
                    while seen.count < 32 {
                        try checked(current)
                        try require(!seen.contains { CFEqual($0, current) }, "Readiness fatal ancestry cycle node=\(current)")
                        seen.append(current)
                        if CFEqual(current, required) { found = true }
                        if CFEqual(current, window) {
                            try require(found, "Readiness fatal required ancestry missing node=\(node) required=\(required)")
                            return
                        }
                        guard let parent = axElement(try value(current, kAXParentAttribute)),
                              let children = try value(parent, kAXChildrenAttribute) as? [AXUIElement] else {
                            throw Failure(description: "Readiness invalid reciprocal ancestry node=\(current)")
                        }
                        try require(children.filter { CFEqual($0, current) }.count == 1, "Readiness fatal reciprocal ancestry node=\(current)")
                        current = parent
                    }
                    throw Failure(description: "Readiness fatal ancestry cap node=\(node)")
                }
                try ancestry(content, through: reader)
                try ancestry(headingNode, through: content)
                try consistentMembership()
                try checked(window)
                attempts.append("attempt=\(attempt) READY latency=\(Date().timeIntervalSince(began)) total=\(Date().timeIntervalSince(start)) nodes=\(tree.count) reader=\(reader) content=\(content) heading=\(headingNode); NO geometry/landing sampled")
                return
            } catch let error as ReaderNotReady {
                attempts.append("attempt=\(attempt) NOT READY latency=\(Date().timeIntervalSince(began)) reason=\(error.reason)")
            } catch {
                attempts.append("attempt=\(attempt) FATAL latency=\(Date().timeIntervalSince(began)) error=\(error)")
                throw error
            }
            guard attempt < 60 && deadline.timeIntervalSinceNow > 0.05 else { break }
            // Yield for asynchronous window construction ONLY, never between input
            // and a retried assertion. Geometry is invoked once after this returns.
            try await Task.sleep(for: .milliseconds(50))
        }
        throw Failure(description: "New-reader AX setup exhausted; full attempt/error log attached for \(phase)")
    }

    /// Bind to a retained native identity, never a same-title or indexed window query.
    /// Bounded snapshots; re-prove retained target uniqueness against current membership.
    func resolveWindow(ax: AXUIElement, document: URL) throws -> Window {
        let owner = try verifyCleanupOwner()
        let deadline = Date().addingTimeInterval(3)
        func checked(_ element: AXUIElement) throws {
            var pid: pid_t = 0
            try require(Date() < deadline && AXUIElementGetPid(element, &pid) == .success
                && pid == owner.processIdentifier && AXUIElementSetMessagingTimeout(element, 0.25) == .success,
                "Window binding PID/deadline/timeout guard failed")
        }
        func frame(_ element: AXUIElement) throws -> CGRect {
            try checked(element)
            var point = CGPoint.zero, size = CGSize.zero
            guard let p = attribute(element, kAXPositionAttribute), let s = attribute(element, kAXSizeAttribute),
                  CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID(),
                  AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size),
                  [point.x, point.y, size.width, size.height].allSatisfy(\.isFinite), size.width > 0, size.height > 0 else {
                throw Failure(description: "Window binding requires actual native geometry")
            }
            return CGRect(origin: point, size: size)
        }
        func near(_ a: CGRect, _ b: CGRect) -> Bool {
            abs(a.minX - b.minX) < 2 && abs(a.minY - b.minY) < 2
                && abs(a.width - b.width) < 2 && abs(a.height - b.height) < 2
        }
        let application = AXUIElementCreateApplication(owner.processIdentifier)
        try checked(application)
        let native = try unwrap(attribute(application, kAXWindowsAttribute) as? [AXUIElement])
        try require(native.count <= 32 && native.filter { CFEqual($0, ax) }.count == 1,
                    "Retained window missing/ambiguous or enumeration bound exceeded")
        var mappings: [(AXUIElement, URL?, CGRect)] = []
        for candidate in native {
            try checked(candidate)
            let actual = try frame(candidate)
            if let url = (attribute(candidate, kAXDocumentAttribute) as? String).flatMap(URL.init(string:)) {
                mappings.append((candidate, url.standardizedFileURL, actual))
            }
        }
        try require(mappings.filter { CFEqual($0.0, ax) && $0.1 == document.standardizedFileURL }.count == 1,
                    "Retained window document changed")
        let count = app.windows.count
        try require(count <= 32, "XCUI window enumeration bound exceeded")
        let candidates = app.windows.allElementsBoundByAccessibilityElement
        try require(candidates.count == count, "XCUI membership changed during binding")
        // XCUI snapshots cross processes. Unrelated native windows may disappear
        // meanwhile; only CURRENT full native geometry can prove correspondence.
        let candidateFrames = candidates.map { ($0, $0.frame) }
        try checked(application)
        let after = try unwrap(attribute(application, kAXWindowsAttribute) as? [AXUIElement])
        if after.count != native.count || !native.allSatisfy({ old in after.filter { CFEqual(old, $0) }.count == 1 }) {
            record("before=\(native)\nafter=\(after) retained=\(ax)", name: "window-binding-membership-change")
        }
        try require(after.count <= 32 && after.filter { CFEqual($0, ax) }.count == 1,
                    "Retained window removed/replaced/ambiguous after XCUI snapshots")
        let retainedBefore = try unwrap(mappings.first { CFEqual($0.0, ax) })
        mappings.removeAll()
        for candidate in after {
            try checked(candidate)
            let actual = try frame(candidate)
            // Include non-document windows too: they can geometrically collide.
            let url = (attribute(candidate, kAXDocumentAttribute) as? String).flatMap(URL.init(string:))
            mappings.append((candidate, url?.standardizedFileURL, actual))
        }
        try require(mappings.filter { CFEqual($0.0, ax) && $0.1 == document.standardizedFileURL && near($0.2, retainedBefore.2) }.count == 1,
                    "Retained geometry/document changed during XCUI snapshots")
        var matches: [XCUIElement] = []
        var diagnostics = mappings.map { "native AX=\($0.0) document=\(String(describing: $0.1)) frame=\($0.2) retained=\(CFEqual($0.0, ax))" }
        for (candidate, actual) in candidateFrames {
            try checked(ax)
            let mapped = mappings.filter { near($0.2, actual) }
            diagnostics.append("XCUI frame=\(actual) nativeMatches=\(mapped.map { String(describing: $0.0) })")
            if mapped.count == 1, let match = mapped.first,
               CFEqual(match.0, ax), match.1 == document.standardizedFileURL {
                matches.append(candidate)
            }
        }
        if matches.count != 1 {
            record("retainedAX=\(ax) document=\(document) nativeCount=\(native.count) XCUIcount=\(count) exactMatches=\(matches.count)\n" + diagnostics.joined(separator: "\n"), name: "window-binding-candidate-table")
        }
        try require(matches.count == 1, "Exact retained AX/XCUI correspondence unavailable/ambiguous")
        let element = try unwrap(matches.first)
        _ = try verifyCleanupOwner()
        try require(Date() < deadline, "Window binding deadline exceeded")
        return Window(element: element, ax: ax, document: document)
    }

    func resolveWindow(_ window: Window) throws -> Window {
        try resolveWindow(ax: window.ax, document: window.document)
    }

    func clickTitlebar(_ window: Window) throws {
        let current = try resolveWindow(window)
        current.element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: 0, dy: 12)).click()
        try checkpoint(current, "exact-titlebar-click")
        try require(try isKey(current), "Retained source must be key after normal titlebar click")
    }

    func rect(_ element: AXUIElement) -> CGRect {
        var point = CGPoint.zero, size = CGSize.zero
        if let value = attribute(element, kAXPositionAttribute), CFGetTypeID(value) == AXValueGetTypeID() {
            AXValueGetValue(value as! AXValue, .cgPoint, &point)
        }
        if let value = attribute(element, kAXSizeAttribute), CFGetTypeID(value) == AXValueGetTypeID() {
            AXValueGetValue(value as! AXValue, .cgSize, &size)
        }
        return CGRect(origin: point, size: size)
    }

    func descendants(_ element: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = [], queue = [element]
        while !queue.isEmpty && result.count < 4096 {
            let current = queue.removeLast()
            result.append(current)
            queue += (attribute(current, kAXChildrenAttribute) as? [AXUIElement] ?? []).reversed()
        }
        return result
    }

    func checkpoint(_ window: Window, _ name: String) throws {
        try verifyProcess()
        try require(try windows().contains { CFEqual($0, window.ax) }, "Same AX window must survive")
        try require((attribute(window.ax, kAXDocumentAttribute) as? String).flatMap(URL.init(string:))?.standardizedFileURL ==
                       window.document.standardizedFileURL, "AX window document identity changed")
        let application = AXUIElementCreateApplication(try unwrap(owned).processIdentifier)
        let focused = axElement(attribute(application, kAXFocusedUIElementAttribute))
        lastWindow = window
        record("pid=\(try unwrap(owned).processIdentifier) start=\(String(describing: launched)) executable=\(executable.path) sha256=\(executableHash) document=\(window.document.absoluteString) AX=\(window.ax) title=\(String(describing: attribute(window.ax, kAXTitleAttribute))) frame=\(rect(window.ax)) main=\(String(describing: attribute(window.ax, kAXMainAttribute))) focusedWindow=\(String(describing: attribute(window.ax, kAXFocusedAttribute))) focusedElement=\(String(describing: focused)) nativeWindowNumber=unavailable; AX-object continuity used", name: name)
    }

    func isKey(_ window: Window) throws -> Bool {
        let application = AXUIElementCreateApplication(try unwrap(owned).processIdentifier)
        return axElement(attribute(application, kAXFocusedWindowAttribute)).map { CFEqual($0, window.ax) } ?? false
    }

    func assertReaderFocus(_ window: Window) throws {
        try require(try isKey(window), "Reader window must be key")
        let application = AXUIElementCreateApplication(try unwrap(owned).processIdentifier)
        let focused = try unwrap(axElement(attribute(application, kAXFocusedUIElementAttribute)))
        try require(descendants(window.ax).contains { CFEqual($0, focused) }, "Focus must belong to the reader window")
        try require(attribute(focused, kAXRoleAttribute) as? String == kAXTextAreaRole, "Reader focus must be a native text area")
    }

    func coordinate(_ point: CGPoint, in window: Window) throws -> XCUICoordinate {
        let window = try resolveWindow(window)
        let clip = window.element.scrollViews["DocumentReaderScrollView"].frame
        guard point.x.isFinite, point.y.isFinite, clip.contains(point) else {
            throw XCTSkip("BLOCKED: glyph endpoint outside actual reader clip; no clipped gesture sent")
        }
        return window.element.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: point.x - window.element.frame.minX, dy: point.y - window.element.frame.minY))
    }

    func resize(_ window: Window, to size: CGSize) async throws {
        try checkpoint(window, "before-resize")
        let old = window.element.frame.size
        let corner = window.element.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -2, dy: -2))
        corner.press(forDuration: 0.2, thenDragTo: corner.withOffset(CGVector(dx: size.width - old.width, dy: size.height - old.height)))
        try await wait { abs(window.element.frame.width - size.width) < 3 && abs(window.element.frame.height - size.height) < 3 }
        try checkpoint(window, "resized")
    }

    func wait(seconds: Double = 3, _ condition: () throws -> Bool) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if try condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        try require(try condition(), "Bounded condition did not settle within \(seconds) seconds")
    }

    func oracle() throws -> [Fragment] {
        try JSONDecoder().decode(Oracle.self, from: Data(contentsOf: root.appendingPathComponent(
            "docs/fixtures/m1-priority-e2e/selection-oracles.json"))).fragments
    }

    func leaf(_ text: String, in window: Window) throws -> AXUIElement {
        try leaf(text, in: window.ax)
    }

    func leaf(_ text: String, in window: AXUIElement) throws -> AXUIElement {
        // Authored fixture headings retain their native semantic role. Do not
        // broaden other fragments or substitute AXValue for selected text.
        let expectedRole = text == "Across blocks" ? "AXHeading" : kAXTextAreaRole
        let candidates = descendants(window).filter {
            attribute($0, kAXValueAttribute) as? String == text
                && attribute($0, kAXRoleAttribute) as? String == expectedRole
        }
        guard candidates.count == 1 else { throw XCTSkip("BLOCKED: exact native text leaf unavailable/ambiguous: \(text.debugDescription)") }
        return candidates[0]
    }

    func bounds(_ range: NSRange, leaf: AXUIElement) throws -> CGRect {
        var input = CFRange(location: range.location, length: range.length)
        let value = try unwrap(AXValueCreate(.cfRange, &input))
        var output: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(leaf, kAXBoundsForRangeParameterizedAttribute as CFString, value, &output) == .success,
              let output, CFGetTypeID(output) == AXValueGetTypeID() else { throw XCTSkip("BLOCKED: AXBoundsForRange unavailable") }
        var rect = CGRect.zero
        guard AXValueGetValue(output as! AXValue, .cgRect, &rect), !rect.isEmpty else { throw XCTSkip("BLOCKED: no finite glyph bounds") }
        return rect
    }

    func endpoint(_ id: String, offset: Int, fragments: [Fragment], window: Window) throws -> Point {
        let index = try unwrap(fragments.firstIndex { $0.id == id })
        let literal = fragments[index].text
        let native = try leaf(literal, in: window)
        let length = (literal as NSString).length
        let glyph = try bounds(NSRange(location: min(offset, length - 1), length: 1), leaf: native)
        var point = CGPoint(x: offset == length ? glyph.maxX - 0.1 : glyph.minX + 0.1, y: glyph.midY)
        _ = try coordinate(point, in: window)
        let input = try unwrap(AXValueCreate(.cgPoint, &point))
        var output: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(native, kAXRangeForPositionParameterizedAttribute as CFString, input, &output) == .success,
              let output, CFGetTypeID(output) == AXValueGetTypeID() else { throw XCTSkip("BLOCKED: AXRangeForPosition unavailable") }
        var range = CFRange()
        AXValueGetValue(output as! AXValue, .cfRange, &range)
        // AX reports a glyph range, not necessarily the insertion boundary. The
        // glyph's leading/trailing side establishes that boundary before the action.
        let actual = offset == length ? range.location + range.length : range.location
        var boundaries = Set([0, length]), count = 0
        for character in literal { count += String(character).utf16.count; boundaries.insert(count) }
        guard boundaries.contains(actual) else { throw XCTSkip("BLOCKED: endpoint splits literal grapheme") }
        record("fragment=\(id) requested=\(offset) preActionIndex=\(actual) glyph=\(glyph) point=\(point)", name: "endpoint")
        return Point(fragment: index, offset: actual, screen: point)
    }

    func drag(_ a: Point, _ b: Point, window: Window) throws {
        try coordinate(a.screen, in: window).press(forDuration: 0.2, thenDragTo: coordinate(b.screen, in: window))
        try checkpoint(window, "after-drag")
    }

    func selected(_ leaf: AXUIElement) throws -> (NSRange, String) {
        guard let value = attribute(leaf, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID(),
              let text = attribute(leaf, kAXSelectedTextAttribute) as? String else {
            throw XCTSkip("BLOCKED: nonfocused native selected range/text unavailable; whole AXValue is not selected text")
        }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { throw XCTSkip("BLOCKED: selected range invalid") }
        return (NSRange(location: range.location, length: range.length), text)
    }

    @discardableResult
    func assertSelection(_ a: Point, _ b: Point, fragments: [Fragment], window: Window) throws -> [String] {
        let tree = descendants(window.ax)
        let literalOrder = try fragments.map { fragment in
            let native = try leaf(fragment.text, in: window)
            return try unwrap(tree.firstIndex { CFEqual($0, native) })
        }
        try require(literalOrder == literalOrder.sorted(), "Native AX leaves must retain independently authored metadata/table row-major order")
        let forward = a.fragment < b.fragment || (a.fragment == b.fragment && a.offset <= b.offset)
        let start = forward ? a : b, end = forward ? b : a
        var observed: [String] = []
        defer { record(observed.joined(separator: "\n"), name: "selection-ranges") }
        for (index, fragment) in fragments.enumerated() {
            let (range, text) = try selected(leaf(fragment.text, in: window))
            observed.append("\(fragment.id):\(range):\(text.debugDescription)")
            let inside = index >= start.fragment && index <= end.fragment
            let lower = index == start.fragment ? start.offset : 0
            let upper = index == end.fragment ? end.offset : (fragment.text as NSString).length
            let expected = inside ? NSRange(location: lower, length: upper - lower) : NSRange(location: 0, length: 0)
            try require(range.length == expected.length, "\(fragment.id): selected length \(range.length), expected \(expected.length)")
            if expected.length > 0 {
                try require(range.location == expected.location, "\(fragment.id): selected location \(range.location), expected \(expected.location)")
            }
            try require(text == (inside ? (fragment.text as NSString).substring(with: expected) : ""), "\(fragment.id): selected text differs from authored oracle")
        }
        return observed
    }

    func capture(_ window: Window, name: String) throws -> WindowPixels {
        let window = try resolveWindow(window)
        try checkpoint(window, "identity-" + name)
        let keyBefore = try isKey(window)
        let pixels = try unwrap(WindowPixels(of: window.element))
        let attachment = XCTAttachment(screenshot: window.element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        test.add(attachment)
        guard try isKey(window) == keyBefore else { throw XCTSkip("BLOCKED: screenshot activated window; inactive visual evidence unavailable") }
        return pixels
    }

    func captureFailure(_ window: Window, error: Error) {
        guard !failureCaptured else { return }
        failureCaptured = true
        do {
            _ = try verifyCleanupOwner()
            let window = try resolveWindow(ax: window.ax, document: window.document)
            try checkpoint(window, "failure-owned-window")
            record("error=\(error) retainedAX=\(window.ax)", name: "failure-AX")
            _ = try capture(window, name: "owned-failure-once")
        } catch {
            record("Explicit owned failure capture unavailable: \(error); no substitute window", name: "failure-capture-error")
        }
    }

    private struct CleanupError: Error { let message: String }

    private func verifyCleanupOwner() throws -> NSRunningApplication {
        guard let owned, let live = NSRunningApplication(processIdentifier: owned.processIdentifier),
              live == owned, !owned.isTerminated, !live.isTerminated,
              live.launchDate == launched,
              live.executableURL?.resolvingSymlinksInPath() == executable,
              Self.hash(try Data(contentsOf: executable)) == executableHash else {
            throw CleanupError(message: "Owned PID/object/start/path/hash continuity lost; no action")
        }
        return owned
    }

    private func requestOwnedNormalQuit() throws {
        let owner = try verifyCleanupOwner()
        let pid = owner.processIdentifier
        let application = AXUIElementCreateApplication(pid)
        let deadline = Date().addingTimeInterval(8)
        func checked(_ element: AXUIElement) throws {
            var actual: pid_t = 0
            guard Date() < deadline, AXUIElementGetPid(element, &actual) == .success, actual == pid,
                  AXUIElementSetMessagingTimeout(element, 0.25) == .success else {
                throw CleanupError(message: "Quit AX PID/timeout guard failed")
            }
        }
        try checked(application)
        guard let menu = axElement(attribute(application, kAXMenuBarAttribute)) else {
            record("pid=\(pid) owned menu bar unavailable", name: "quit-menu")
            throw CleanupError(message: "Owned menu bar unavailable")
        }
        var count = 0
        func children(_ parent: AXUIElement) throws -> [AXUIElement] {
            try checked(parent)
            var expected: CFIndex = 0, after: CFIndex = 0
            var value: CFTypeRef?
            guard AXUIElementGetAttributeValueCount(parent, kAXChildrenAttribute as CFString, &expected) == .success,
                  expected >= 0, expected <= 128 - count,
                  AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &value) == .success,
                  let items = value as? [AXUIElement], items.count == expected,
                  AXUIElementGetAttributeValueCount(parent, kAXChildrenAttribute as CFString, &after) == .success,
                  after == expected else {
                throw CleanupError(message: "Quit direct-child enumeration failed/incomplete or exceeded bound")
            }
            count += items.count
            for item in items { try checked(item) }
            record("pid=\(pid) parent=\(parent) directChildren=\(items) count=\(expected)", name: "quit-menu")
            return items
        }
        func string(_ element: AXUIElement, _ name: String) throws -> String {
            try checked(element)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
                  let text = value as? String else {
                throw CleanupError(message: "Quit required AX string unavailable: \(name)")
            }
            return text
        }
        func unique(_ items: [AXUIElement], role: String, title: String? = nil) throws -> AXUIElement {
            var matches: [AXUIElement] = []
            for item in items {
                let actualRole = try string(item, kAXRoleAttribute)
                let actualTitle = try title.map { _ in try string(item, kAXTitleAttribute) }
                record("pid=\(pid) element=\(item) role=\(actualRole) title=\(String(describing: actualTitle))", name: "quit-menu")
                if actualRole == role && (title == nil || actualTitle == title) { matches.append(item) }
            }
            guard matches.count == 1 else {
                throw CleanupError(message: "Quit hierarchy match not unique: role=\(role) title=\(String(describing: title)) count=\(matches.count)")
            }
            return matches[0]
        }
        guard try string(menu, kAXRoleAttribute) == kAXMenuBarRole else {
            throw CleanupError(message: "Owned menu bar role mismatch")
        }
        let applicationItem = try unique(children(menu), role: kAXMenuBarItemRole, title: "NeoMD")
        let applicationMenu = try unique(children(applicationItem), role: kAXMenuRole)
        let target = try unique(children(applicationMenu), role: kAXMenuItemRole, title: "Quit NeoMD")
        do {
            let element = target
            try checked(element)
            let title = attribute(element, kAXTitleAttribute) as? String
            let role = attribute(element, kAXRoleAttribute) as? String
            let enabled = attribute(element, kAXEnabledAttribute) as? Bool
            let key = attribute(element, kAXMenuItemCmdCharAttribute) as? String
            let modifiers = attribute(element, kAXMenuItemCmdModifiersAttribute) as? NSNumber
            var actions: CFArray?
            let actionsResult = AXUIElementCopyActionNames(element, &actions)
            let names = actions as? [String] ?? []
            record("pid=\(pid) element=\(element) title=\(String(describing: title)) role=\(String(describing: role)) enabled=\(String(describing: enabled)) key=\(String(describing: key)) modifiers=\(String(describing: modifiers)) actionsResult=\(actionsResult.rawValue) actions=\(names)", name: "quit-menu")
            guard title == "Quit NeoMD", role == kAXMenuItemRole, enabled == true, key?.lowercased() == "q",
                  modifiers?.intValue == 0, actionsResult == .success, names.contains(kAXPressAction) else {
                throw CleanupError(message: "Quit NeoMD lacks enabled Command-Q press metadata")
            }
        }
        try checked(target)
        let verified = try verifyCleanupOwner()
        record("time=\(Date()) pid=\(verified.processIdentifier) start=\(String(describing: launched)) executable=\(executable.path) sha256=\(executableHash) objectEqual=true target=\(target); AXPress only", name: "cleanup")
        let result = AXUIElementPerformAction(target, kAXPressAction as CFString)
        record("time=\(Date()) pid=\(pid) AXPressResult=\(result.rawValue)", name: "quit-request")
        guard result == .success else { throw CleanupError(message: "AX Quit request rejected: \(result.rawValue)") }
    }

    private func checkCleanupSources(_ phase: String, errors: inout [String]) {
        for source in sources {
            do {
                let bytes = try Data(contentsOf: source.url)
                let date = try source.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                record("url=\(source.url) sha256=\(Self.hash(bytes)) mtime=\(String(describing: date)) bytesUnchanged=\(bytes == source.bytes) mtimeUnchanged=\(date == source.modified)", name: phase)
                if bytes != source.bytes || date != source.modified { errors.append("\(phase): source bytes/mtime changed") }
            } catch { errors.append("\(phase): \(error)") }
        }
    }

    func cleanup() async throws {
        let prior = test.continueAfterFailure
        test.continueAfterFailure = true
        defer { test.continueAfterFailure = prior }
        var errors: [String] = []
        if (test.testRun?.failureCount ?? 0) > 0, let window = lastWindow {
            captureFailure(window, error: Failure(description: "Registered test failure at teardown"))
        }
        checkCleanupSources("source-before-quit", errors: &errors)
        var accepted = false
        if let owned {
            do {
                try requestOwnedNormalQuit()
                accepted = true
            } catch { errors.append("Normal Quit: \(error)") }
            let deadline = Date().addingTimeInterval(3)
            while Date() < deadline {
                if owned.isTerminated && NSRunningApplication(processIdentifier: owned.processIdentifier) == nil { break }
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { errors.append("Exit wait: \(error)"); break }
            }
            let present = NSRunningApplication(processIdentifier: owned.processIdentifier) != nil
            record("time=\(Date()) ownedPID=\(owned.processIdentifier) requestAccepted=\(accepted) terminated=\(owned.isTerminated) freshPIDPresent=\(present); no fallback; fixture/evidence retained", name: "cleanup-outcome")
            if !owned.isTerminated || present { errors.append("Owned process remains or exit uncertain; coordinator reconciliation required") }
        } else {
            record("No owned process; no action", name: "cleanup-outcome")
        }
        checkCleanupSources("source-after-quit", errors: &errors)
        record("errors=\(errors)", name: "cleanup-errors")
        if !errors.isEmpty { throw Failure(description: errors.joined(separator: "\n")) }
    }
}
