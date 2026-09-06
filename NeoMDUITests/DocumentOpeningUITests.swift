//
//  DocumentOpeningUITests.swift
//  NeoMDUITests
//

import XCTest

/// Covers the parts of opening a document that can be driven from a UI test.
///
/// Finder's Open With menu and double-click launching are Launch Services behavior and
/// are verified by inspecting the built app's `Info.plist` rather than by automation.
final class DocumentOpeningUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The item title uses a real ellipsis in some macOS versions and three periods in
    /// others, so match on the leading word instead of the exact string.
    private func openCommand(in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(
            format: "title BEGINSWITH 'Open' AND NOT title BEGINSWITH 'Open Recent'"
        )
        return app.menuBars.menuItems.matching(predicate).firstMatch
    }

    @MainActor
    func testAppExposesTheDocumentOpenCommand() throws {
        let app = XCUIApplication()
        app.launch()

        let fileMenu = app.menuBars.menuBarItems["File"]
        XCTAssertTrue(fileMenu.waitForExistence(timeout: 10), "The File menu should exist.")
        fileMenu.click()

        let open = openCommand(in: app)
        XCTAssertTrue(open.waitForExistence(timeout: 5), "A document app should offer File > Open.")
        XCTAssertTrue(open.isEnabled, "File > Open should be available.")

        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testSavingCommandsAreUnavailable() throws {
        // AppKit always builds the standard File menu, so the read-only guarantee shows
        // up as disabled commands rather than missing ones.
        let app = XCUIApplication()
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
