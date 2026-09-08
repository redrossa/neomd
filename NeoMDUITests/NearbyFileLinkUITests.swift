import AppKit
import XCTest

final class NearbyFileLinkUITests: XCTestCase {
    private var directory: URL!
    private var originals: [URL: (Data, Date)] = [:]

    /// Read the authored durable fixtures, avoiding a second divergent copy of their bytes.
    static func fixtureTree() throws -> [String: Data] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/m1-10-nearby-links")
        // Relative enumeration avoids /tmp versus /private/tmp URL prefix differences.
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(atPath: root.path))
        var files: [String: Data] = [:]
        for case let path as String in enumerator {
            let url = root.appendingPathComponent(path)
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                files[path] = try Data(contentsOf: url)
            }
        }
        XCTAssertEqual(files.count, 13)
        XCTAssertNotNil(files["docs/guide.md"])
        return files
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("NeoMD-Nearby-\(UUID())")
        for (path, data) in try Self.fixtureTree() {
            let url = directory.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)], ofItemAtPath: url.path)
            let date = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
            originals[url] = (data, date)
        }
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
        if let directory { chmod(directory.appendingPathComponent("docs/private.md").path, 0o644) }
        for (url, original) in originals {
            XCTAssertEqual(try Data(contentsOf: url), original.0)
            XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date, original.1)
        }
        if let directory { try FileManager.default.removeItem(at: directory) }
    }

    @MainActor private func open(appearance: String = "Light") async throws -> (XCUIApplication, XCUIElement) {
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
        let source = directory.appendingPathComponent("docs/guide.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        _ = try await NSWorkspace.shared.open([source],
            withApplicationAt: try XCTUnwrap(running.bundleURL), configuration: configuration)
        let window = app.windows["guide.md"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(window.links["Intro second section"].waitForExistence(timeout: 10))
        return (app, window)
    }

    @MainActor private func wait(_ predicate: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(8)
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
        for _ in 0..<12 {
            if link.exists && link.frame.minY >= scroll.frame.minY && link.frame.maxY < scroll.frame.maxY { return link }
            scroll.scroll(byDeltaX: 0, deltaY: -250)
        }
        XCTFail("Link not visible: \(label) — \(window.debugDescription)")
        return link
    }

    @MainActor private func click(_ label: String, in window: XCUIElement) {
        let link = reveal(label, in: window)
        let frame = link.frame
        window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: frame.midX - window.frame.minX, dy: frame.midY - window.frame.minY)).click()
    }

    @MainActor private func assertAtTop(_ heading: String, window: XCUIElement) {
        let element = window.staticTexts[heading]
        let scroll = window.scrollViews["DocumentReaderScrollView"]
        XCTAssertTrue(wait { element.exists && abs(element.frame.minY - scroll.frame.minY) < 10 }, window.debugDescription)
    }

    @MainActor func testRelativePathsOpenNearbyMarkdownAtRequestedSections() async throws {
        for appearance in ["Light", "Dark"] {
            let (app, guide) = try await open(appearance: appearance)
            for (label, file, heading) in [("Intro second section", "intro.md", "Second section"),
                                          ("Parent readme", "README.md", "Parent section"),
                                          ("Deep target", "deep.md", "Deep target")] {
                click(label, in: guide)
                let target = app.windows[file]
                XCTAssertTrue(target.waitForExistence(timeout: 10))
                assertAtTop(heading, window: target)
            }
            for (label, file, marker) in [("Spaces bracketed", "my notes.md", "SPACES TARGET OPENED"),
                ("Spaces encoded", "my notes.md", "SPACES TARGET OPENED"),
                ("Encoded Unicode", "café.md", "UNICODE TARGET OPENED"),
                ("Literal Unicode", "café.md", "UNICODE TARGET OPENED"),
                ("Percent edge", "100%.md", "PERCENT EDGE OPENED"),
                ("Root target", "root-target.md", "ROOT POLICY CORRECT")] {
                click(label, in: guide)
                let target = app.windows[file]
                XCTAssertTrue(target.waitForExistence(timeout: 10))
                XCTAssertTrue(target.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", marker)).firstMatch.waitForExistence(timeout: 5))
                XCTAssertEqual(app.windows.matching(identifier: file).count, 1)
                XCTAssertFalse(target.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "ROOT POLICY WRONG")).firstMatch.exists)
            }
            for key in [XCUIKeyboardKey.return, .space] {
                _ = reveal("Deep target", in: guide)
                let scroll = guide.scrollViews["DocumentReaderScrollView"]
                scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.1)).click()
                var selected = false
                for _ in 0..<12 {
                    app.typeKey(.tab, modifierFlags: [.option])
                    selected = guide.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Link 1 of 1: Deep target")).firstMatch.exists
                    if selected { break }
                }
                XCTAssertTrue(selected, guide.debugDescription)
                app.typeKey(key, modifierFlags: [])
                assertAtTop("Deep target", window: app.windows["deep.md"])
            }
            app.terminate()
        }
    }

    @MainActor func testMissingAndInaccessibleTargetsKeepTheCurrentDocument() async throws {
        chmod(directory.appendingPathComponent("docs/private.md").path, 0)
        for appearance in ["Light", "Dark"] {
            let (app, guide) = try await open(appearance: appearance)
            for (label, name) in [("Missing file", "missing.md"), ("Missing nested", "nowhere.md"), ("Private file", "private.md")] {
                let link = reveal(label, in: guide)
                let before = link.frame.minY
                link.click()
                if label == "Private file" {
                    let cancel = app.windows["open-panel"].buttons["CancelButton"]
                    XCTAssertTrue(cancel.waitForExistence(timeout: 5), app.debugDescription)
                    cancel.click()
                }
                let notice = guide.staticTexts["DocumentLinkNotice"]
                XCTAssertTrue(notice.waitForExistence(timeout: 5))
                XCTAssertTrue((notice.value as? String ?? notice.label).contains(name))
                XCTAssertEqual(link.frame.minY, before, accuracy: 1)
                XCTAssertEqual(app.windows.matching(identifier: "guide.md").count, 1)
                XCTAssertFalse(app.windows[name].exists)
                let attachment = XCTAttachment(screenshot: guide.screenshot())
                attachment.name = "Nearby notice — \(appearance) — \(name)"
                attachment.lifetime = .keepAlways
                add(attachment)
                XCTAssertTrue(wait { !notice.exists })
            }
            click("Missing section", in: guide)
            let target = app.windows["intro.md"]
            XCTAssertTrue(target.staticTexts["DocumentLinkNotice"].waitForExistence(timeout: 10))
            app.terminate()
        }
    }

    @MainActor func testAlreadyOpenTargetRefocusesAndNavigates() async throws {
        let (app, guide) = try await open()
        click("Plain sibling", in: guide)
        let intro = app.windows["intro.md"]
        XCTAssertTrue(intro.staticTexts["Intro"].waitForExistence(timeout: 10))
        click("Intro second section", in: guide)
        assertAtTop("Second section", window: intro)
        XCTAssertEqual(app.windows.matching(identifier: "intro.md").count, 1)
        click("Plain sibling", in: guide)
        // No-fragment reopening preserves the existing reading position (M1-03).
        assertAtTop("Second section", window: intro)
        click("Same document section", in: guide)
        XCTAssertTrue(wait { guide.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "GUIDE END.")).firstMatch.isHittable })
        XCTAssertEqual(app.windows.matching(identifier: "guide.md").count, 1)
    }

    @MainActor func testOtherLocalTypesOpenInTheDefaultApplicationOnlyAfterActivation() async throws {
        let (app, guide) = try await open()
        for (label, path) in [("Plain text notes", "docs/notes.txt"), ("Linked image", "docs/img/diagram.png")] {
            let url = directory.appendingPathComponent(path)
            let applicationURL = try XCTUnwrap(NSWorkspace.shared.urlForApplication(toOpen: url), "Required default app unavailable")
            let bundle = try XCTUnwrap(Bundle(url: applicationURL)?.bundleIdentifier)
            let before = NSRunningApplication.runningApplications(withBundleIdentifier: bundle)
            let other = XCUIApplication(bundleIdentifier: bundle)
            defer {
                // Close only the fixture window; never terminate a pre-existing application.
                let ownedWindow = other.windows[url.lastPathComponent]
                if ownedWindow.exists { ownedWindow.buttons[XCUIIdentifierCloseWindow].click() }
                if before.isEmpty { other.terminate() }
                app.activate()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(3))
            XCTAssertEqual(NSRunningApplication.runningApplications(withBundleIdentifier: bundle).map(\.processIdentifier), before.map(\.processIdentifier))
            click(label, in: guide)
            XCTAssertTrue(wait { NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle })
            XCTAssertTrue(other.windows[url.lastPathComponent].waitForExistence(timeout: 10), other.debugDescription)
            XCTAssertFalse(app.windows[url.lastPathComponent].exists)
        }
    }
}
