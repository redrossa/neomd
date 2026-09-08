import AppKit
import XCTest

final class WebLinkUITests: XCTestCase {
    private var directory: URL!
    private var originals: [URL: (Data, Date)] = [:]

    override func setUpWithError() throws {
        continueAfterFailure = false
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("NeoMD-Web-\(UUID())")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/m1-11-web-links")
        try FileManager.default.copyItem(at: root, to: directory)
        for name in ["web-links.md", "keyboard-links.md", "nearby.md", "README-fixture.md"] {
            let url = directory.appendingPathComponent(name)
            originals[url] = (try Data(contentsOf: url),
                try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date))
        }
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
        for (url, original) in originals {
            XCTAssertEqual(try Data(contentsOf: url), original.0)
            XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date, original.1)
        }
        if let directory { try FileManager.default.removeItem(at: directory) }
    }

    @MainActor private func browserIdentifier() throws -> String {
        let url = try XCTUnwrap(URL(string: "https://example.com/"))
        let application = try XCTUnwrap(NSWorkspace.shared.urlForApplication(toOpen: url))
        return try XCTUnwrap(Bundle(url: application)?.bundleIdentifier)
    }

    @MainActor private func browserPIDs(_ bundle: String) -> Set<pid_t> {
        Set(NSRunningApplication.runningApplications(withBundleIdentifier: bundle).map(\.processIdentifier))
    }

    @MainActor private func open(appearance: String = "Light", filename: String = "web-links.md", firstLink: String = "Example site") async throws -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["NEOMD_UI_TEST_APPEARANCE"] = appearance
        app.launch()
        app.activate()
        let running = try XCTUnwrap(NSWorkspace.shared.frontmostApplication)
        XCTAssertEqual(running.bundleIdentifier, "io.neomd.NeoMD")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.allowsRunningApplicationSubstitution = false
        configuration.createsNewApplicationInstance = false
        configuration.activates = true
        _ = try await NSWorkspace.shared.open([directory.appendingPathComponent(filename)],
            withApplicationAt: try XCTUnwrap(running.bundleURL), configuration: configuration)
        let window = app.windows[filename]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(window.links[firstLink].waitForExistence(timeout: 10))
        return (app, window)
    }

    @MainActor private func wait(_ predicate: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(10)
        repeat {
            if predicate() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return predicate()
    }

    @MainActor private func reveal(_ label: String, in window: XCUIElement) -> XCUIElement {
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.015)).click()
        let scroll = window.scrollViews["DocumentReaderScrollView"]
        scroll.scroll(byDeltaX: 0, deltaY: 10000)
        let link = window.links[label]
        for _ in 0..<30 {
            if link.exists && link.frame.minY >= scroll.frame.minY && link.frame.maxY < scroll.frame.maxY { return link }
            scroll.scroll(byDeltaX: 0, deltaY: -250)
        }
        XCTFail("Link not visible: \(label) — \(window.debugDescription)")
        return link
    }

    @MainActor func testWebLinkFormsAreLinksAndOpeningLaunchesNothing() async throws {
        let browser = try browserIdentifier()
        let before = browserPIDs(browser)
        let (_, window) = try await open()
        for label in ["Example site", "Spec reference", "GFM spec", "CommonMark",
            "https://autolink.example/bare", "https://angle.example/path", "www.plain.example/site",
            "Heading site", "List site", "Quote site"] {
            XCTAssertTrue(window.links[label].exists, label)
        }
        try await Task.sleep(for: .seconds(3))
        XCTAssertEqual(browserPIDs(browser), before)
        XCTAssertEqual(window.toolbars.count, 0)
    }

    @MainActor func testActivatingWebLinkOpensDefaultBrowserAndKeepsReadingPosition() async throws {
        let browser = try browserIdentifier()
        let before = browserPIDs(browser)
        let (app, window) = try await open()
        defer {
            // Never terminate a browser session that predates this test.
            if before.isEmpty {
                for process in NSRunningApplication.runningApplications(withBundleIdentifier: browser) { process.terminate() }
            }
            app.activate()
        }
        let link = reveal("Far link", in: window)
        window.scrollViews["DocumentReaderScrollView"].scroll(byDeltaX: 0, deltaY: -10000)
        let y = link.frame.minY
        let end = window.staticTexts["FAR END."]
        let endY = end.frame.minY
        link.click()
        XCTAssertTrue(wait { NSWorkspace.shared.frontmostApplication?.bundleIdentifier == browser })
        app.activate()
        XCTAssertEqual(link.frame.minY, y, accuracy: 1)
        XCTAssertEqual(end.frame.minY, endY, accuracy: 1)
        XCTAssertEqual(app.windows.count, 1)
        XCTAssertFalse(window.staticTexts["DocumentLinkNotice"].exists)
    }

    @MainActor func testKeyboardWebLinkOpensDefaultBrowserAndKeepsReadingPosition() async throws {
        let browser = try browserIdentifier()
        let before = browserPIDs(browser)
        let (app, window) = try await open(filename: "keyboard-links.md", firstLink: "First web link")
        defer {
            if before.isEmpty {
                for process in NSRunningApplication.runningApplications(withBundleIdentifier: browser) { process.terminate() }
            }
            app.activate()
        }
        let scroll = window.scrollViews["DocumentReaderScrollView"]
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.1)).click()
        let preceding = window.groups["MarkdownLinkBlock-0"]
        XCTAssertEqual(preceding.label, "Link 1 of 2: First web link")
        var selected = false
        for _ in 0..<20 {
            app.typeKey(.tab, modifierFlags: [.option])
            app.typeKey(.rightArrow, modifierFlags: [])
            selected = preceding.label == "Link 2 of 2: Keyboard web link"
            if selected { break }
        }
        XCTAssertTrue(selected, window.debugDescription)
        let focus = XCTAttachment(screenshot: window.screenshot())
        focus.name = "Keyboard web link verified selection"
        focus.lifetime = .keepAlways
        add(focus)
        let link = window.links["Keyboard web link"]
        let keyboardY = link.frame.minY
        let marker = window.staticTexts["KEYBOARD POSITION MARKER."]
        let markerY = marker.frame.minY
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(wait { NSWorkspace.shared.frontmostApplication?.bundleIdentifier == browser })
        app.activate()
        XCTAssertEqual(link.frame.minY, keyboardY, accuracy: 1)
        XCTAssertEqual(marker.frame.minY, markerY, accuracy: 1)
        XCTAssertEqual(app.windows.count, 1)
        XCTAssertFalse(window.staticTexts["DocumentLinkNotice"].exists)
    }

    @MainActor func testNativeSelectionInLinkBearingParagraphStillCopiesText() async throws {
        let browser = try browserIdentifier()
        let before = browserPIDs(browser)
        let (app, window) = try await open()
        let pasteboard = NSPasteboard.general
        let saved = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
        defer {
            pasteboard.clearContents()
            pasteboard.writeObjects(saved.map { representations in
                let item = NSPasteboardItem()
                for (type, data) in representations { item.setData(data, forType: type) }
                return item
            })
        }
        let link = window.links["Example site"]
        XCTAssertTrue(link.isHittable)
        let leading = link.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        leading.withOffset(CGVector(dx: -25, dy: 0)).doubleClick()
        leading.withOffset(CGVector(dx: -50, dy: 0)).press(forDuration: 0.1,
            thenDragTo: leading.withOffset(CGVector(dx: -5, dy: 0)))
        app.typeKey("c", modifierFlags: .command)
        XCTAssertEqual(pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), "Labeled")
        XCTAssertEqual(browserPIDs(browser), before)
        XCTAssertFalse(app.menuItems["Copy Link"].exists)
        XCTAssertTrue(link.isHittable)
    }

    @MainActor func testContextualMenuRevealsDestinationWithoutOpening() async throws {
        let browser = try browserIdentifier()
        let before = browserPIDs(browser)
        let pasteboard = NSPasteboard.general
        // Preserve every original representation, not just plain text.
        let saved = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
        defer {
            pasteboard.clearContents()
            let items = saved.map { representations in
                let item = NSPasteboardItem()
                for (type, data) in representations { item.setData(data, forType: type) }
                return item
            }
            pasteboard.writeObjects(items)
        }
        for appearance in ["Light", "Dark"] {
            let (app, window) = try await open(appearance: appearance)
            if appearance == "Dark" {
                XCUIElement.perform(withKeyModifiers: .control) { window.links["Example site"].click() }
            } else {
                window.links["Example site"].rightClick()
            }
            let destination = app.menuItems["https://example.com/path?q=1"]
            XCTAssertTrue(destination.waitForExistence(timeout: 3), app.debugDescription)
            XCTAssertFalse(destination.isEnabled)
            XCTAssertTrue(app.menuItems["Open Link"].exists)
            XCTAssertTrue(app.menuItems["Copy Link"].exists)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Web link context menu — \(appearance)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.menuItems["Copy Link"].click()
            XCTAssertEqual(pasteboard.string(forType: .string), "https://example.com/path?q=1")
            XCTAssertEqual(browserPIDs(browser), before)
            XCTAssertEqual(app.windows.count, 1)
            window.links["First site"].rightClick()
            XCTAssertTrue(app.menuItems["https://first.example/"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.menuItems["https://second.example/?x=1&y=2"].exists)
            app.typeKey(.escape, modifierFlags: [])
            let plain = window.staticTexts["Plain paragraph without any link for the native text menu check."]
            plain.rightClick()
            XCTAssertTrue(app.menuItems["Copy"].waitForExistence(timeout: 3))
            XCTAssertFalse(app.menuItems["Copy Link"].exists)
            app.typeKey(.escape, modifierFlags: [])
            reveal("Section link", in: window).rightClick()
            XCTAssertTrue(app.menuItems["#far-section"].waitForExistence(timeout: 3))
            app.menuItems.matching(identifier: "Open Link").element(boundBy: 0).click()
            XCTAssertTrue(wait { window.staticTexts["FAR END."].isHittable })
            XCTAssertEqual(browserPIDs(browser), before)
            XCTAssertFalse(window.staticTexts["DocumentLinkNotice"].exists)
            app.terminate()
        }
    }
}
