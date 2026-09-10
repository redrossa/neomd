import AppKit
import XCTest

/// Clipboard-free real-app cue validation. Each matrix selector is a bounded batch.
final class DocumentCueUITests: XCTestCase {
    private var directory: URL!
    private var originals: [URL: (Data, Date)] = [:]
    private var application: XCUIApplication?
    private var originalAppearance: Bool?

    override func setUpWithError() throws {
        continueAfterFailure = false
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("NeoMD-Cues-\(UUID())")
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/m1-13-cues")
        try FileManager.default.copyItem(at: fixtures, to: directory)
        let files = try XCTUnwrap(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]))
        for case let url as URL in files where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            originals[url] = (try Data(contentsOf: url), try XCTUnwrap(url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate))
        }
    }

    override func tearDownWithError() throws {
        application?.terminate()
        if let originalAppearance { try SystemAppearance.restore(to: originalAppearance) }
        for (url, original) in originals {
            XCTAssertEqual(try Data(contentsOf: url), original.0)
            XCTAssertEqual(try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, original.1)
        }
        if let directory { try FileManager.default.removeItem(at: directory) }
    }

    @MainActor func testScaleOneLight() async throws { try await matrix(scale: 1, appearance: "Light") }
    @MainActor func testScaleOneDark() async throws { try await matrix(scale: 1, appearance: "Dark") }
    @MainActor func testScaleOneAndHalfLight() async throws { try await matrix(scale: 1.5, appearance: "Light") }
    @MainActor func testScaleOneAndHalfDark() async throws { try await matrix(scale: 1.5, appearance: "Dark") }
    @MainActor func testScaleTwoLight() async throws { try await matrix(scale: 2, appearance: "Light") }
    @MainActor func testScaleTwoDark() async throws { try await matrix(scale: 2, appearance: "Dark") }

    @MainActor private func launch(scale: Double, appearance: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["NEOMD_TEST_READING_SCALE"] = String(scale)
        if let appearance { app.launchEnvironment["NEOMD_UI_TEST_APPEARANCE"] = appearance }
        application = app
        app.launch()
        return app
    }

    @MainActor private func open(_ name: String, app: XCUIApplication) async throws -> XCUIElement {
        app.activate()
        let running = try XCTUnwrap(NSWorkspace.shared.frontmostApplication)
        XCTAssertEqual(running.bundleIdentifier, "io.neomd.NeoMD")
        let config = NSWorkspace.OpenConfiguration()
        config.allowsRunningApplicationSubstitution = false
        _ = try await NSWorkspace.shared.open([directory.appendingPathComponent(name)],
            withApplicationAt: try XCTUnwrap(running.bundleURL), configuration: config)
        let window = app.windows[name]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(window.scrollViews["DocumentReaderScrollView"].waitForExistence(timeout: 10))
        return window
    }

    @MainActor private func matrix(scale: Double, appearance: String) async throws {
        let app = launch(scale: scale, appearance: appearance)
        let alerts = try await open("alerts.md", app: app)
        for width in [CGFloat(900), 480] {
            resize(alerts, width: width)
            for kind in ["NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION"] {
                let label = alerts.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "MarkdownAlert-\(kind)-")).firstMatch
                try show(label, window: alerts)
                XCTAssertEqual(label.label, kind.capitalized)
                let pixels = try XCTUnwrap(WindowPixels(of: alerts))
                let page = try XCTUnwrap(pixels.medianSample(in: label.frame.insetBy(dx: -5, dy: -5)))
                XCTAssertEqual(page.gray > 0.5, appearance == "Light")
                XCTAssertGreaterThanOrEqual(pixels.inkContrast(in: label.frame, against: page), 4.5)
                XCTAssertGreaterThanOrEqual(label.frame.height, 12 * scale)
                record(alerts, "Alerts-\(kind)-\(appearance)-\(scale)x-\(Int(width))")
            }
        }
        app.typeKey("w", modifierFlags: .command)
        let mixed = try await open("mixed-cues.md", app: app)
        for width in [CGFloat(900), 480] {
            resize(mixed, width: width)
            for prefix in ["MIXED START.", "Unlinked image path before", "Linked image native path before", "Native heading", "Missing unlinked path before", "Missing linked native path before", "ALERT MIXED BODY.", "Nested pending", "Ordinary quote", "Footnote"] {
                let predicate = NSPredicate(format: "value BEGINSWITH %@ OR label BEGINSWITH %@", prefix, prefix)
                let native = mixed.textViews.matching(predicate).firstMatch
                let element = prefix == "Native heading" ? mixed.groups["MarkdownLinkBlock-4"] : native
                try show(element, window: mixed)
                XCTAssertGreaterThan(element.frame.height, 10 * scale)
                if prefix == "Nested pending" {
                    let marker = mixed.images["MarkdownTaskMarker-12"]
                    XCTAssertTrue(marker.exists)
                    XCTAssertEqual(marker.frame.midY, element.frame.minY + 8 * scale, accuracy: 5 * scale)
                }
                record(mixed, "Mixed-\(prefix)-\(appearance)-\(scale)x-\(Int(width))")
            }
        }
        XCTAssertFalse(mixed.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'swatch'")).firstMatch.exists)
        app.typeKey("w", modifierFlags: .command)
    }

    @MainActor func testScaleOneAndHalfNarrowAlertScrollRemainsResponsive() async throws {
        let app = launch(scale: 1.5, appearance: "Light")
        let window = try await open("alerts.md", app: app)
        resize(window, width: 480)
        let scroll = window.scrollViews["DocumentReaderScrollView"]
        for _ in 0..<8 {
            scroll.scroll(byDeltaX: 0, deltaY: -600)
            scroll.scroll(byDeltaX: 0, deltaY: 10000)
            XCTAssertTrue(window.exists)
        }
        record(window, "Narrow-1.5x-alert-scroll-regression")
        app.typeKey("w", modifierFlags: .command)
    }

    /// Paired pre-migration/production probe. Selection is inspected visually, never via pasteboard.
    @MainActor func testCrossParagraphDragWithoutClipboard() async throws {
        let app = launch(scale: 1, appearance: "Light")
        let window = try await open("mixed-cues.md", app: app)
        resize(window, width: 900)
        func paragraph(_ prefix: String) -> XCUIElement {
            window.descendants(matching: .any).matching(NSPredicate(
                format: "(elementType == %d OR elementType == %d) AND (value BEGINSWITH %@ OR label BEGINSWITH %@)",
                XCUIElement.ElementType.textView.rawValue, XCUIElement.ElementType.staticText.rawValue,
                prefix, prefix)).firstMatch
        }
        let first = paragraph("Mixed spacer 01.")
        let second = paragraph("Mixed spacer 02.")
        try show(first, window: window)
        XCTAssertTrue(second.exists)
        XCTAssertLessThan(second.frame.maxY, window.scrollViews["DocumentReaderScrollView"].frame.maxY)
        let start = first.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 2, dy: 8))
        let end = second.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 95, dy: 8))
        start.press(forDuration: 0.1, thenDragTo: end)
        record(window, "Cross-paragraph-selection-no-clipboard")
        app.typeKey("w", modifierFlags: .command)
    }

    @MainActor func testRealSystemSwitchPreservesOpenAlertDocument() async throws {
        XCTAssertTrue(SystemAppearance.isAssisted, "Run through the authorized appearance host controller")
        originalAppearance = SystemAppearance.isDarkMode()
        try SystemAppearance.setDarkMode(false)
        let app = launch(scale: 1.5, appearance: nil)
        let window = try await open("alerts.md", app: app)
        resize(window, width: 900)
        let label = window.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'MarkdownAlert-IMPORTANT-'")).firstMatch
        try show(label, window: window)
        let before = label.frame
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        for dark in [false, true, false] {
            try SystemAppearance.setDarkMode(dark)
            XCTAssertTrue(wait {
                guard let pixels = WindowPixels(of: window), let page = pixels.medianSample(in: label.frame.insetBy(dx: -5, dy: -5)) else { return false }
                return (page.gray < 0.5) == dark
            })
            XCTAssertEqual(label.frame.minY, before.minY, accuracy: 8)
            XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, pid)
            XCTAssertEqual(app.windows.count, 1)
            record(window, "Live-alert-system-\(dark ? "Dark" : "Light")")
        }
        app.typeKey("w", modifierFlags: .command)
    }

    /// C2 only: retain the separate 1.5× gate above; use the public default font here.
    /// Each real alert stays at its reading point for a complete system Light→Dark→Light.
    @MainActor func testDefaultSizeAllAlertsFollowLiveSystemAppearance() async throws {
        XCTAssertTrue(SystemAppearance.isHostControlled, "Use the owned appearance host controller")
        originalAppearance = SystemAppearance.isDarkMode()
        try SystemAppearance.setDarkMode(false)
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        // Empty test inputs select the ordinary defaults, without writing preferences.
        app.launchEnvironment["NEOMD_TEST_READING_SCALE"] = ""
        app.launchEnvironment["NEOMD_UI_TEST_APPEARANCE"] = ""
        app.launchEnvironment["NEOMD_UI_TEST_APPEARANCE_CHANNEL"] = ""
        application = app
        app.launch()
        let window = try await open("alerts.md", app: app)
        resize(window, width: 900)
        let scroll = window.scrollViews["DocumentReaderScrollView"]
        let pid = try XCTUnwrap(NSWorkspace.shared.frontmostApplication?.processIdentifier)
        let windowFrame = window.frame
        for kind in ["NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION"] {
            let labels = window.descendants(matching: .any).matching(NSPredicate(
                format: "identifier BEGINSWITH %@", "MarkdownAlert-\(kind)-"))
            let label = labels.firstMatch
            try show(label, window: window)
            let body = window.textViews.matching(NSPredicate(
                format: "value BEGINSWITH %@", "\(kind) BODY.")).firstMatch
            XCTAssertTrue(body.exists)
            // Keep both label and first body paragraph completely inside the viewport.
            if body.frame.maxY >= scroll.frame.maxY - 4 {
                scroll.scroll(byDeltaX: 0, deltaY: scroll.frame.midY - label.frame.midY)
            }
            let before = label.frame
            let bodyBefore = body.frame
            let identifier = label.identifier
            for (phase, dark) in [false, true, false].enumerated() {
                try SystemAppearance.setDarkMode(dark)
                XCTAssertEqual(SystemAppearance.isDarkMode(), dark)
                let background = CGRect(x: scroll.frame.minX + 4,
                    y: scroll.frame.minY + 30, width: 20, height: 80)
                XCTAssertTrue(wait {
                    guard let page = WindowPixels(of: window)?.medianSample(in: background)
                    else { return false }
                    return (page.gray < 0.5) == dark
                })
                let name = "C2-\(kind)-\(phase)-\(dark ? "Dark" : "Light")-default1x"
                record(window, name)
                XCTAssertEqual(labels.count, 1)
                XCTAssertEqual(label.label, kind.capitalized)
                XCTAssertEqual(label.identifier, identifier)
                XCTAssertEqual(label.frame.minY, before.minY, accuracy: 8)
                XCTAssertEqual(body.frame.minY, bodyBefore.minY, accuracy: 8)
                XCTAssertGreaterThanOrEqual(label.frame.minY, scroll.frame.minY + 4)
                XCTAssertLessThan(body.frame.maxY, scroll.frame.maxY - 4)
                XCTAssertGreaterThanOrEqual(body.frame.minY, label.frame.maxY)
                XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, pid)
                XCTAssertEqual(app.windows.count, 1)
                XCTAssertEqual(window.frame, windowFrame)
                XCTAssertTrue(window.exists)
                let pixels = try XCTUnwrap(WindowPixels(of: window))
                let page = try XCTUnwrap(pixels.medianSample(in: background))
                let labelContrast = pixels.inkContrast(in: label.frame, against: page)
                let bodyContrast = pixels.inkContrast(in: body.frame, against: page)
                // Known AX limit found in the first C2 run: label.frame starts at the
                // symbol, not the rule. This retained sample includes glyphs; it is NOT
                // independent rule proof. See m1-13-validation.md for screenshot evidence.
                let ruleRect = CGRect(x: label.frame.minX, y: label.frame.minY,
                    width: 3, height: body.frame.maxY - label.frame.minY)
                let ruleContrast = pixels.inkContrast(in: ruleRect, against: page)
                let evidence = "\(name): systemDark=\(SystemAppearance.isDarkMode()) page=\(page.gray) labelContrast=\(labelContrast) bodyContrast=\(bodyContrast) ruleContrast=\(ruleContrast) label=\(label.frame) body=\(body.frame) rule=\(ruleRect) pid=\(pid)"
                print(evidence)
                fflush(stdout)
                let measurement = XCTAttachment(string: evidence)
                measurement.name = name + "-measurements"
                measurement.lifetime = .keepAlways
                add(measurement)
                XCTAssertGreaterThanOrEqual(labelContrast, 4.5)
                XCTAssertGreaterThanOrEqual(bodyContrast, 4.5)
                XCTAssertGreaterThanOrEqual(ruleContrast, 3)
            }
        }
        app.typeKey("w", modifierFlags: .command)
    }

    @MainActor private func resize(_ window: XCUIElement, width: CGFloat) {
        let current = window.frame.size
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -2, dy: -2))
        corner.press(forDuration: 0.2, thenDragTo: corner.withOffset(CGVector(dx: width - current.width, dy: 760 - current.height)))
        XCTAssertTrue(wait { abs(window.frame.width - width) < 4 && abs(window.frame.height - 760) < 4 })
    }

    @MainActor private func show(_ element: XCUIElement, window: XCUIElement) throws {
        let scroll = window.scrollViews["DocumentReaderScrollView"]
        scroll.scroll(byDeltaX: 0, deltaY: 10000)
        for _ in 0..<40 {
            if element.exists, element.frame.minY >= scroll.frame.minY + 4, element.frame.maxY < scroll.frame.maxY - 4 { return }
            if element.exists {
                let delta = scroll.frame.midY - element.frame.midY
                scroll.scroll(byDeltaX: 0, deltaY: max(-600, min(600, delta)))
            } else {
                scroll.scroll(byDeltaX: 0, deltaY: -400)
            }
        }
        XCTFail("Cue not visible: \(element)\n\(window.debugDescription)")
        throw NSError(domain: "DocumentCueUITests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cue not visible"])
    }

    @MainActor private func wait(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(10)
        repeat {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return condition()
    }

    @MainActor private func record(_ window: XCUIElement, _ name: String) {
        let image = XCTAttachment(screenshot: window.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let geometry = XCTAttachment(string: "window=\(window.frame)\n\(window.debugDescription)")
        geometry.name = name + "-AX-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
    }
}
