import AppKit
import ApplicationServices
import CryptoKit
import XCTest

/// Only the seven priority selectors use this support. No clipboard, event monitor,
/// permission changes, first-bundle-match adoption, or unchecked XCUI termination.
@MainActor
final class PriorityInteractionSupport {
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
        let date = try XCTUnwrap(url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
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
        let returned = try await NSWorkspace.shared.open([try XCTUnwrap(components.url)], withApplicationAt: product, configuration: config)
        XCTAssertEqual(returned.processIdentifier, owned?.processIdentifier)
        try verifyProcess()
        let element = app.windows[url.lastPathComponent].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 8))
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
        return AXUIElementCreateApplication(try XCTUnwrap(owned).processIdentifier)
    }

    func windows() throws -> [AXUIElement] {
        try verifyProcess()
        let application = AXUIElementCreateApplication(try XCTUnwrap(owned).processIdentifier)
        return try XCTUnwrap(attribute(application, kAXWindowsAttribute) as? [AXUIElement])
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
        XCTAssertTrue(try windows().contains { CFEqual($0, window.ax) }, "Same AX window must survive")
        XCTAssertEqual((attribute(window.ax, kAXDocumentAttribute) as? String).flatMap(URL.init(string:))?.standardizedFileURL,
                       window.document.standardizedFileURL)
        let application = AXUIElementCreateApplication(try XCTUnwrap(owned).processIdentifier)
        let focused = axElement(attribute(application, kAXFocusedUIElementAttribute))
        record("pid=\(try XCTUnwrap(owned).processIdentifier) start=\(String(describing: launched)) executable=\(executable.path) sha256=\(executableHash) document=\(window.document.absoluteString) AX=\(window.ax) title=\(String(describing: attribute(window.ax, kAXTitleAttribute))) frame=\(rect(window.ax)) main=\(String(describing: attribute(window.ax, kAXMainAttribute))) focusedWindow=\(String(describing: attribute(window.ax, kAXFocusedAttribute))) focusedElement=\(String(describing: focused)) nativeWindowNumber=unavailable; AX-object continuity used", name: name)
    }

    func isKey(_ window: Window) throws -> Bool {
        let application = AXUIElementCreateApplication(try XCTUnwrap(owned).processIdentifier)
        return axElement(attribute(application, kAXFocusedWindowAttribute)).map { CFEqual($0, window.ax) } ?? false
    }

    func assertReaderFocus(_ window: Window) throws {
        XCTAssertTrue(try isKey(window))
        let application = AXUIElementCreateApplication(try XCTUnwrap(owned).processIdentifier)
        let focused = try XCTUnwrap(axElement(attribute(application, kAXFocusedUIElementAttribute)))
        XCTAssertTrue(descendants(window.ax).contains { CFEqual($0, focused) })
        XCTAssertEqual(attribute(focused, kAXRoleAttribute) as? String, kAXTextAreaRole)
    }

    func coordinate(_ point: CGPoint, in window: Window) throws -> XCUICoordinate {
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
        XCTAssertTrue(try condition(), "Bounded condition did not settle")
    }

    func oracle() throws -> [Fragment] {
        try JSONDecoder().decode(Oracle.self, from: Data(contentsOf: root.appendingPathComponent(
            "docs/fixtures/m1-priority-e2e/selection-oracles.json"))).fragments
    }

    func leaf(_ text: String, in window: Window) throws -> AXUIElement {
        let candidates = descendants(window.ax).filter {
            attribute($0, kAXValueAttribute) as? String == text
                && attribute($0, kAXRoleAttribute) as? String == kAXTextAreaRole
        }
        guard candidates.count == 1 else { throw XCTSkip("BLOCKED: exact native text leaf unavailable/ambiguous: \(text.debugDescription)") }
        return candidates[0]
    }

    func bounds(_ range: NSRange, leaf: AXUIElement) throws -> CGRect {
        var input = CFRange(location: range.location, length: range.length)
        let value = try XCTUnwrap(AXValueCreate(.cfRange, &input))
        var output: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(leaf, kAXBoundsForRangeParameterizedAttribute as CFString, value, &output) == .success,
              let output, CFGetTypeID(output) == AXValueGetTypeID() else { throw XCTSkip("BLOCKED: AXBoundsForRange unavailable") }
        var rect = CGRect.zero
        guard AXValueGetValue(output as! AXValue, .cgRect, &rect), !rect.isEmpty else { throw XCTSkip("BLOCKED: no finite glyph bounds") }
        return rect
    }

    func endpoint(_ id: String, offset: Int, fragments: [Fragment], window: Window) throws -> Point {
        let index = try XCTUnwrap(fragments.firstIndex { $0.id == id })
        let literal = fragments[index].text
        let native = try leaf(literal, in: window)
        let length = (literal as NSString).length
        let glyph = try bounds(NSRange(location: min(offset, length - 1), length: 1), leaf: native)
        var point = CGPoint(x: offset == length ? glyph.maxX - 0.1 : glyph.minX + 0.1, y: glyph.midY)
        _ = try coordinate(point, in: window)
        let input = try XCTUnwrap(AXValueCreate(.cgPoint, &point))
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
            return try XCTUnwrap(tree.firstIndex { CFEqual($0, native) })
        }
        XCTAssertEqual(literalOrder, literalOrder.sorted(), "Native AX leaves must retain independently authored metadata/table row-major order")
        let forward = a.fragment < b.fragment || (a.fragment == b.fragment && a.offset <= b.offset)
        let start = forward ? a : b, end = forward ? b : a
        var observed: [String] = []
        for (index, fragment) in fragments.enumerated() {
            let (range, text) = try selected(leaf(fragment.text, in: window))
            let inside = index >= start.fragment && index <= end.fragment
            let lower = index == start.fragment ? start.offset : 0
            let upper = index == end.fragment ? end.offset : (fragment.text as NSString).length
            let expected = inside ? NSRange(location: lower, length: upper - lower) : NSRange(location: 0, length: 0)
            XCTAssertEqual(range.length, expected.length, fragment.id)
            if expected.length > 0 { XCTAssertEqual(range.location, expected.location, fragment.id) }
            XCTAssertEqual(text, inside ? (fragment.text as NSString).substring(with: expected) : "", fragment.id)
            observed.append("\(fragment.id):\(range):\(text.debugDescription)")
        }
        record(observed.joined(separator: "\n"), name: "selection-ranges")
        return observed
    }

    func capture(_ window: Window, name: String) throws -> WindowPixels {
        try checkpoint(window, "identity-" + name)
        let keyBefore = try isKey(window)
        let pixels = try XCTUnwrap(WindowPixels(of: window.element))
        let attachment = XCTAttachment(screenshot: window.element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        test.add(attachment)
        guard try isKey(window) == keyBefore else { throw XCTSkip("BLOCKED: screenshot activated window; inactive visual evidence unavailable") }
        return pixels
    }

    func cleanup() async throws {
        if (test.testRun?.failureCount ?? 0) > 0, owned != nil {
            // One failure capture only, after verifying the captured PID identity.
            try verifyProcess()
            record("failure capture: \(try windows())", name: "failure-AX")
            if let element = app.windows.allElementsBoundByIndex.first(where: { candidate in
                sources.contains { $0.url.lastPathComponent == candidate.title }
            }) {
                let attachment = XCTAttachment(screenshot: element.screenshot())
                attachment.name = "owned-failure-once"
                attachment.lifetime = .keepAlways
                test.add(attachment)
            }
        }
        var changed = false
        for source in sources {
            let bytes = try Data(contentsOf: source.url)
            let date = try source.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            record("url=\(source.url) sha256=\(Self.hash(bytes)) mtime=\(String(describing: date)) bytesUnchanged=\(bytes == source.bytes) mtimeUnchanged=\(date == source.modified)", name: "source-after")
            changed = changed || bytes != source.bytes || date != source.modified
        }
        XCTAssertFalse(changed, "Source bytes/mtime changed, including failure cleanup")
        if let owned, !owned.isTerminated {
            try verifyProcess()
            record("graceful terminate owned pid=\(owned.processIdentifier) start=\(String(describing: launched)); fixture/evidence directory retained", name: "cleanup")
            XCTAssertTrue(owned.terminate(), "Owned process refused graceful termination; coordinator cleanup required")
            let deadline = Date().addingTimeInterval(3)
            while !owned.isTerminated && Date() < deadline { try await Task.sleep(for: .milliseconds(100)) }
            record("ownedPID=\(owned.processIdentifier) terminated=\(owned.isTerminated); no force termination", name: "cleanup-outcome")
            XCTAssertTrue(owned.isTerminated, "Coordinator must reconcile owned process still running; do not relaunch")
        }
        // Keep owned fixture copies and evidence on failure AND success. Coordinator
        // may remove them only after copying attachments; no global recents cleanup.
    }
}
