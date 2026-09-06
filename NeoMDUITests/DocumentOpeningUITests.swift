//
//  DocumentOpeningUITests.swift
//  NeoMDUITests
//

import AppKit
import XCTest

/// End-to-end coverage for native opening commands, no-file lifecycle, and file drops.
final class DocumentOpeningUITests: XCTestCase {
    private var testDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeoMD-Opening-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
        if let testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
    }

    /// The item title uses a real ellipsis in some macOS versions and three periods in
    /// others, so match on the leading word instead of the exact string.
    @MainActor
    private func openCommand(in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(
            format: "title BEGINSWITH 'Open' AND NOT title BEGINSWITH 'Open Recent'"
        )
        return app.menuBars.menuItems.matching(predicate).firstMatch
    }

    @MainActor
    private func configuredApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        return app
    }

    @MainActor
    private func openPanel(in app: XCUIApplication) -> XCUIElement {
        app.windows.matching(identifier: "open-panel").firstMatch
    }

    /// Sends an Open Documents event to the already-running test application without
    /// relaunching it, matching Finder and Dock behavior for a running app.
    @MainActor
    private func openWhileRunning(_ url: URL, in app: XCUIApplication) async throws {
        app.activate()
        let runningApplication = try XCTUnwrap(NSWorkspace.shared.frontmostApplication)
        XCTAssertEqual(runningApplication.bundleIdentifier, "io.neomd.NeoMD")
        let applicationURL = try XCTUnwrap(runningApplication.bundleURL)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.allowsRunningApplicationSubstitution = false
        configuration.createsNewApplicationInstance = false
        _ = try await NSWorkspace.shared.open(
            [url],
            withApplicationAt: applicationURL,
            configuration: configuration
        )
    }

    @MainActor
    private func noDocumentWindow(in app: XCUIApplication) -> XCUIElement {
        app.windows.containing(
            .staticText,
            identifier: "NoDocumentInstruction"
        ).firstMatch
    }

    @MainActor
    private func invokeMenuOpen(in app: XCUIApplication) {
        let fileMenu = app.menuBars.menuBarItems["File"]
        XCTAssertTrue(fileMenu.waitForExistence(timeout: 10), "The File menu should exist.")
        fileMenu.click()

        let open = openCommand(in: app)
        XCTAssertTrue(open.waitForExistence(timeout: 5), "File > Open should exist.")
        XCTAssertTrue(open.isEnabled, "File > Open should be available.")
        open.click()
    }

    @MainActor
    private func cancelOpenPanel(in app: XCUIApplication) {
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            openPanel(in: app).waitForNonExistence(timeout: 5),
            "Escape should cancel the native Open panel."
        )
    }

    @MainActor
    private func closeWindow(_ window: XCUIElement) {
        let closeButton = window.buttons.matching(identifier: "_XCUI:CloseWindow").firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.click()
    }

    @discardableResult
    private func makeDocument(named name: String, content: String) throws -> URL {
        let url = testDirectory.appendingPathComponent(name)
        try Data(content.utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)],
            ofItemAtPath: url.path
        )
        return url
    }

    private func snapshot(of url: URL) throws -> (data: Data, modificationDate: Date) {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (
            try Data(contentsOf: url),
            try XCTUnwrap(attributes[.modificationDate] as? Date)
        )
    }

    @MainActor
    private func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement) {
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10), "The reader should scroll.")
        scrollView.scroll(byDeltaX: 0, deltaY: -10_000)
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(element.isHittable, "Expected content should be visible after scrolling.")
    }

    /// Finder is brought forward with the test file selected, then its file row is
    /// dragged into an exposed area near the reader's right edge.
    @MainActor
    private func dragFromFinder(_ url: URL, to targetWindow: XCUIElement) {
        XCTAssertTrue(targetWindow.waitForExistence(timeout: 10))

        // Move NeoMD far enough right that Finder's centered window cannot cover the
        // destination point while it is frontmost.
        let titleBar = targetWindow.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.02))
        titleBar.press(
            forDuration: 0.2,
            thenDragTo: titleBar.withOffset(CGVector(dx: 380, dy: 0))
        )

        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        let generatedWindowPredicate = NSPredicate(
            format: "title BEGINSWITH 'NeoMD-Opening-'"
        )
        for window in finder.windows.matching(generatedWindowPredicate).allElementsBoundByIndex {
            let closeButton = window.buttons.matching(identifier: "_XCUI:CloseWindow").firstMatch
            if closeButton.exists {
                closeButton.click()
            }
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
        finder.activate()
        XCTAssertTrue(finder.windows.firstMatch.waitForExistence(timeout: 10))

        let filePredicate = NSPredicate(format: "value == %@", url.lastPathComponent)
        let file = finder.textFields.matching(filePredicate).firstMatch
        XCTAssertTrue(
            file.waitForExistence(timeout: 10),
            "Finder should expose the selected file for a real drag."
        )

        let destination = targetWindow.coordinate(
            withNormalizedOffset: CGVector(dx: 0.9, dy: 0.55)
        )
        file.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.8, thenDragTo: destination)

        finder.activate()
        finder.typeKey("w", modifierFlags: .command)
        XCUIApplication().activate()
    }

    @MainActor
    func testMenuAndCommandOInvokeTheNativeOpenPanel() throws {
        let app = configuredApplication()
        app.launch()

        XCTAssertTrue(noDocumentWindow(in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(openPanel(in: app).exists, "Launch should not force an Open panel.")

        invokeMenuOpen(in: app)
        XCTAssertTrue(
            openPanel(in: app).waitForExistence(timeout: 5),
            "File > Open should present the native Open panel."
        )
        cancelOpenPanel(in: app)

        app.typeKey("o", modifierFlags: .command)
        XCTAssertTrue(
            openPanel(in: app).waitForExistence(timeout: 5),
            "Command-O should present the native Open panel."
        )
        cancelOpenPanel(in: app)
    }

    @MainActor
    func testNoFileLifecycleAndEmptyDocumentStayDistinct() async throws {
        let emptyDocument = try makeDocument(named: "empty.md", content: "")
        let app = configuredApplication()
        app.launch()

        let instruction = app.staticTexts["NoDocumentInstruction"]
        XCTAssertTrue(instruction.waitForExistence(timeout: 10))

        app.typeKey("o", modifierFlags: .command)
        XCTAssertTrue(openPanel(in: app).waitForExistence(timeout: 5))
        cancelOpenPanel(in: app)
        XCTAssertTrue(instruction.exists, "Canceling without a document keeps the instruction.")

        try await openWhileRunning(emptyDocument, in: app)
        let emptyMessage = app.staticTexts["This document is empty."]
        XCTAssertTrue(emptyMessage.waitForExistence(timeout: 10))
        XCTAssertTrue(instruction.waitForNonExistence(timeout: 5))

        closeWindow(app.windows[emptyDocument.lastPathComponent])
        XCTAssertTrue(
            app.staticTexts["NoDocumentInstruction"].waitForExistence(timeout: 10),
            "Closing the final document should return to the no-file instruction."
        )
        XCTAssertFalse(emptyMessage.exists)
    }

    @MainActor
    func testPickerCancellationPreservesScrolledReaderAndSourceFile() throws {
        let paragraphs = (1...90)
            .map { "Paragraph \($0): enough text to create a substantial reading surface." }
            .joined(separator: "\n\n")
        let url = try makeDocument(
            named: "position.md",
            content: "# Start\n\n\(paragraphs)\n\nSCROLL POSITION MARKER"
        )
        let before = try snapshot(of: url)
        let app = configuredApplication()

        // Opening a URL while stopped exercises the cold native open-document path.
        app.open(url)
        XCTAssertTrue(app.staticTexts["Start"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["NoDocumentInstruction"].waitForNonExistence(timeout: 5))
        let marker = app.staticTexts["SCROLL POSITION MARKER"]
        scrollToElement(marker, in: app.scrollViews.firstMatch)
        let markerFrameBeforeCancellation = marker.frame

        app.typeKey("o", modifierFlags: .command)
        XCTAssertTrue(openPanel(in: app).waitForExistence(timeout: 5))
        cancelOpenPanel(in: app)

        XCTAssertTrue(marker.isHittable, "Cancellation should keep the scrolled content visible.")
        XCTAssertEqual(marker.frame, markerFrameBeforeCancellation)

        let after = try snapshot(of: url)
        XCTAssertEqual(after.data, before.data)
        XCTAssertEqual(after.modificationDate, before.modificationDate)
    }

    @MainActor
    func testClosingOneOfMultipleDocumentsKeepsTheOtherReader() async throws {
        let firstURL = try makeDocument(named: "first.md", content: "FIRST WINDOW CONTENT")
        let secondURL = try makeDocument(named: "second.md", content: "SECOND WINDOW CONTENT")
        let app = configuredApplication()

        app.open(firstURL)
        XCTAssertTrue(app.staticTexts["FIRST WINDOW CONTENT"].waitForExistence(timeout: 10))
        try await openWhileRunning(secondURL, in: app)
        XCTAssertTrue(app.staticTexts["SECOND WINDOW CONTENT"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.windows[firstURL.lastPathComponent].exists)
        XCTAssertTrue(app.windows[secondURL.lastPathComponent].exists)

        closeWindow(app.windows[secondURL.lastPathComponent])
        XCTAssertTrue(app.staticTexts["SECOND WINDOW CONTENT"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["FIRST WINDOW CONTENT"].exists)
        XCTAssertFalse(app.staticTexts["NoDocumentInstruction"].exists)

        closeWindow(app.windows[firstURL.lastPathComponent])
        XCTAssertTrue(app.staticTexts["NoDocumentInstruction"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testDroppingOnNoFileWindowOpensTheDocument() throws {
        let url = try makeDocument(named: "drop-empty.md", content: "EMPTY DROP CONTENT")
        let before = try snapshot(of: url)
        let app = configuredApplication()
        app.launch()

        dragFromFinder(url, to: noDocumentWindow(in: app))

        XCTAssertTrue(app.staticTexts["EMPTY DROP CONTENT"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["NoDocumentInstruction"].waitForNonExistence(timeout: 5))
        let after = try snapshot(of: url)
        XCTAssertEqual(after.data, before.data)
        XCTAssertEqual(after.modificationDate, before.modificationDate)
    }

    @MainActor
    func testDroppingDistinctFileOnReaderOpensAnotherWindowAndPreservesOriginal() throws {
        let paragraphs = (1...60)
            .map { "Original paragraph \($0) keeps the first window scrollable." }
            .joined(separator: "\n\n")
        let firstURL = try makeDocument(
            named: "drop-first.md",
            content: "FIRST DROP WINDOW\n\n\(paragraphs)\n\nFIRST DROP POSITION"
        )
        let secondURL = try makeDocument(
            named: "drop-second.md",
            content: "SECOND DROP WINDOW"
        )
        let firstBefore = try snapshot(of: firstURL)
        let secondBefore = try snapshot(of: secondURL)
        let app = configuredApplication()

        app.open(firstURL)
        XCTAssertTrue(app.staticTexts["FIRST DROP WINDOW"].waitForExistence(timeout: 10))
        let position = app.staticTexts["FIRST DROP POSITION"]
        scrollToElement(position, in: app.scrollViews.firstMatch)
        let positionYBeforeDrop = position.frame.minY
        let firstWindow = app.windows[firstURL.lastPathComponent]

        dragFromFinder(secondURL, to: firstWindow)

        XCTAssertTrue(app.staticTexts["SECOND DROP WINDOW"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.windows[firstURL.lastPathComponent].exists)
        XCTAssertTrue(app.windows[secondURL.lastPathComponent].exists)

        app.activate()
        firstWindow.click()
        XCTAssertTrue(position.isHittable)
        XCTAssertEqual(position.frame.minY, positionYBeforeDrop)
        XCTAssertFalse(app.staticTexts["NoDocumentInstruction"].exists)

        let firstAfter = try snapshot(of: firstURL)
        let secondAfter = try snapshot(of: secondURL)
        XCTAssertEqual(firstAfter.data, firstBefore.data)
        XCTAssertEqual(firstAfter.modificationDate, firstBefore.modificationDate)
        XCTAssertEqual(secondAfter.data, secondBefore.data)
        XCTAssertEqual(secondAfter.modificationDate, secondBefore.modificationDate)
    }

    @MainActor
    func testSavingCommandsAreUnavailable() throws {
        // AppKit always builds the standard File menu, so the read-only guarantee shows
        // up as disabled commands rather than missing ones.
        let app = configuredApplication()
        app.launch()

        let fileMenu = app.menuBars.menuBarItems["File"]
        XCTAssertTrue(fileMenu.waitForExistence(timeout: 10))
        fileMenu.click()

        for title in ["Save", "Save As…", "Save As...", "Duplicate", "Revert To"] {
            let item = app.menuBars.menuItems[title]
            if item.exists {
                XCTAssertFalse(item.isEnabled, "\(title) must stay disabled in a reading app.")
            }
        }

        app.typeKey(.escape, modifierFlags: [])
    }
}
