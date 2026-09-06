//
//  DocumentReaderLayoutUITests.swift
//  NeoMDUITests
//

import AppKit
import XCTest

/// End-to-end coverage for the viewport-constrained reading surface.
final class DocumentReaderLayoutUITests: XCTestCase {
    private var testDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeoMD-Layout-\(UUID().uuidString)", isDirectory: true)
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

    @MainActor
    func testReadingColumnReflowsAndKeepsCodeOverflowLocal() async throws {
        let prose = "PROSE START " + String(
            repeating: "ordinary spaced words make this paragraph reflow naturally ",
            count: 18
        ) + "PROSE END"
        let unbroken = "TOKEN_START_" + String(repeating: "abcdefghij", count: 90) + "_TOKEN_END"
        let heading = "Heading " + String(repeating: "unbroken", count: 12) + " end"
        let quote = "QUOTE START " + String(repeating: "quoted wrapping words ", count: 20) + "QUOTE END"
        let list = "LIST START " + String(repeating: "listed wrapping words ", count: 20) + "LIST END"
        let code = "CODE_START_" + String(repeating: "0123456789", count: 140) + "_CODE_END"
        let source = """
            # Layout checks

            \(prose)

            \(unbroken)

            ## \(heading)

            > \(quote)

            - \(list)

            CODE NEIGHBOR

            ```
            \(code)
            ```
            """
        let url = try makeDocument(named: "layout.md", content: source)
        let before = try snapshot(of: url)
        let app = configuredApplication(appearance: "Light")

        app.launch()
        try await openWhileRunning(url, in: app)
        let window = app.windows[url.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let outerScrollView = window.scrollViews["DocumentReaderScrollView"]
        XCTAssertTrue(outerScrollView.waitForExistence(timeout: 10))
        let title = app.staticTexts["Layout checks"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let proseElement = staticText(prose, in: window)
        XCTAssertTrue(proseElement.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(title.frame.minY - outerScrollView.frame.minY, 30)
        assertInsideReadingMargins(title.frame, scrollView: outerScrollView)

        resize(window, to: CGSize(width: 1_200, height: 760))
        let wideProseFrame = proseElement.frame
        XCTAssertGreaterThanOrEqual(
            wideProseFrame.minX - outerScrollView.frame.minX,
            190,
            "A wide window should center a readable-width column."
        )
        XCTAssertLessThanOrEqual(wideProseFrame.width, 760)
        XCTAssertTrue(title.isHittable, "Resizing at the top should preserve the top of the document.")

        resize(window, to: CGSize(width: 520, height: 620))
        XCTAssertTrue(waitUntil { proseElement.isHittable })
        let narrowProseFrame = proseElement.frame
        assertInsideReadingMargins(narrowProseFrame, scrollView: outerScrollView)
        XCTAssertGreaterThan(
            wideProseFrame.width,
            narrowProseFrame.width + 250,
            "The reading column should use substantially more of a wide viewport."
        )
        XCTAssertGreaterThan(
            narrowProseFrame.height,
            wideProseFrame.height,
            "Ordinary prose should gain lines rather than truncate in a narrow window."
        )

        let unbrokenElement = staticText(unbroken, in: window)
        let headingElement = window.staticTexts[heading]
        let wideTextElements = [
            unbrokenElement,
            headingElement,
            staticText(quote, in: window),
            staticText(list, in: window)
        ]
        for element in wideTextElements {
            scrollToElement(element, in: outerScrollView)
            assertInsideReadingMargins(element.frame, scrollView: outerScrollView)
        }
        XCTAssertGreaterThan(
            unbrokenElement.frame.height,
            20,
            "A long token should wrap instead of widening or clipping the page."
        )
        XCTAssertGreaterThan(
            headingElement.frame.height,
            30,
            "A long heading should wrap inside the reading column."
        )

        let neighbor = window.staticTexts["CODE NEIGHBOR"]
        scrollToElement(neighbor, in: outerScrollView)
        let codeScrollView = window.scrollViews["MarkdownCodeBlock-7"]
        XCTAssertTrue(codeScrollView.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(codeScrollView.frame.width, outerScrollView.frame.width - 78)
        let codeElement = staticText(code, in: window)
        XCTAssertTrue(codeElement.waitForExistence(timeout: 5))
        let neighborX = neighbor.frame.minX
        let outerFrame = outerScrollView.frame
        let codeFrameBefore = codeElement.frame

        for _ in 0..<12 {
            if codeElement.frame.maxX <= codeScrollView.frame.maxX + 2 { break }
            codeScrollView.scroll(byDeltaX: -2_000, deltaY: 0)
        }
        XCTAssertTrue(waitUntil {
            codeElement.frame.maxX <= codeScrollView.frame.maxX + 2
        }, "The trailing end of a long code line should be reachable in its own scroller.")
        XCTAssertLessThan(codeElement.frame.minX, codeFrameBefore.minX)
        XCTAssertEqual(neighbor.frame.minX, neighborX, accuracy: 1)
        XCTAssertEqual(outerScrollView.frame, outerFrame)

        let buttonCount = window.buttons.count
        proseElement.hover()
        staticText(quote, in: window).hover()
        staticText(list, in: window).hover()
        codeScrollView.hover()
        XCTAssertEqual(window.buttons.count, buttonCount)
        assertNoEditingControls(in: window)

        let neighborY = neighbor.frame.minY
        outerScrollView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        ).click()
        app.typeKey(.pageUp, modifierFlags: [])
        XCTAssertTrue(waitUntil {
            !neighbor.exists || neighbor.frame.minY > neighborY + 100
        }, "Keyboard paging should continue to scroll the reading surface.")

        attachScreenshot(of: window, named: "Reader layout — Light")
        let after = try snapshot(of: url)
        XCTAssertEqual(after.data, before.data)
        XCTAssertEqual(after.modificationDate, before.modificationDate)
    }

    @MainActor
    func testCodeOverflowSupportsKeyboardScrollingAndTextSelection() async throws {
        let code = "KEYBOARD_CODE_START_"
            + String(repeating: "abcdefghij", count: 100)
            + "_KEYBOARD_CODE_END"
        let source = """
            # Keyboard code

            ADJACENT PROSE STAYS PUT

            ```
            \(code)
            ```
            """
        let url = try makeDocument(named: "keyboard-code.md", content: source)
        let before = try snapshot(of: url)
        let app = configuredApplication(appearance: "Light")

        app.launch()
        try await openWhileRunning(url, in: app)
        let window = app.windows[url.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        resize(window, to: CGSize(width: 480, height: 620))

        let outerScrollView = window.scrollViews["DocumentReaderScrollView"]
        let codeScrollView = window.scrollViews["MarkdownCodeBlock-2"]
        XCTAssertTrue(outerScrollView.waitForExistence(timeout: 10))
        XCTAssertTrue(codeScrollView.waitForExistence(timeout: 10))
        let codeElement = staticText(code, in: window)
        let neighbor = window.staticTexts["ADJACENT PROSE STAYS PUT"]
        XCTAssertTrue(codeElement.waitForExistence(timeout: 5))
        XCTAssertTrue(neighbor.waitForExistence(timeout: 5))

        let leadingCodeX = codeElement.frame.minX
        let neighborX = neighbor.frame.minX
        let outerFrame = outerScrollView.frame
        outerScrollView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)
        ).click()

        var keyboardMovedCode = false
        for _ in 0..<4 {
            app.typeKey(.tab, modifierFlags: [.option])
            app.typeKey(.rightArrow, modifierFlags: [])
            app.typeKey(.rightArrow, modifierFlags: [])
            keyboardMovedCode = waitUntil(timeout: 0.75) {
                codeElement.frame.minX < leadingCodeX - 2
            }
            if keyboardMovedCode { break }
        }
        XCTAssertTrue(
            keyboardMovedCode,
            "Option-Tab should focus wide code so Right Arrow scrolls its local viewport."
        )
        XCTAssertEqual(neighbor.frame.minX, neighborX, accuracy: 1)
        XCTAssertEqual(outerScrollView.frame, outerFrame)
        attachScreenshot(of: window, named: "Reader code keyboard focus — Light")

        app.typeKey(.rightArrow, modifierFlags: [.command])
        XCTAssertTrue(
            waitUntil {
                codeElement.frame.maxX <= codeScrollView.frame.maxX + 2
            },
            "Command-Right Arrow should reach the trailing code without pointer scrolling."
        )
        XCTAssertLessThan(codeElement.frame.minX, leadingCodeX)
        XCTAssertEqual(neighbor.frame.minX, neighborX, accuracy: 1)
        XCTAssertEqual(outerScrollView.frame, outerFrame)

        app.typeKey(.leftArrow, modifierFlags: [.command])
        XCTAssertTrue(
            waitUntil {
                abs(codeElement.frame.minX - leadingCodeX) <= 2
            },
            "Command-Left Arrow should return the focused code viewport to its leading edge."
        )
        XCTAssertEqual(neighbor.frame.minX, neighborX, accuracy: 1)
        XCTAssertEqual(outerScrollView.frame, outerFrame)

        codeScrollView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.18, dy: 0.5)
        ).doubleClick()
        app.typeKey(.rightArrow, modifierFlags: [.command, .shift])
        let editMenu = app.menuBars.menuBarItems["Edit"]
        XCTAssertTrue(editMenu.waitForExistence(timeout: 5))
        editMenu.click()
        let copyItem = app.menuBars.menuItems["Copy"]
        XCTAssertTrue(copyItem.waitForExistence(timeout: 5))
        XCTAssertTrue(copyItem.isEnabled, "Keyboard scrolling must preserve native code selection and Copy.")
        app.typeKey(.escape, modifierFlags: [])

        let after = try snapshot(of: url)
        XCTAssertEqual(after.data, before.data)
        XCTAssertEqual(after.modificationDate, before.modificationDate)
    }

    @MainActor
    func testKeyboardPagingReturnsToReaderWhenFocusedCodeStopsOverflowing() async throws {
        let code = "COPY_START "
            + String(repeating: "abcdefghij ", count: 100)
            + "COPY_END"
        let mediumCode = "MEDIUM_"
            + String(repeating: "abcdefghij", count: 5)
            + "_END"
        let paragraphs = (1...40).map {
            "Paragraph \($0) ordinary words to keep vertical paging available."
        }.joined(separator: "\n\n")
        let source = """
            # Keyboard focus transition

            NEIGHBOR

            ```
            \(code)
            ```

            ```
            \(mediumCode)
            ```

            \(paragraphs)
            """

        for appearance in ["Light", "Dark"] {
            let url = try makeDocument(
                named: "keyboard-focus-\(appearance).md",
                content: source
            )
            let before = try snapshot(of: url)
            let app = configuredApplication(appearance: appearance)

            app.launch()
            try await openWhileRunning(url, in: app)
            let window = app.windows[url.lastPathComponent]
            XCTAssertTrue(window.waitForExistence(timeout: 10))
            resize(window, to: CGSize(width: 480, height: 620))

            let outerScrollView = window.scrollViews["DocumentReaderScrollView"]
            let mediumScrollView = window.scrollViews["MarkdownCodeBlock-3"]
            let mediumElement = staticText(mediumCode, in: window)
            XCTAssertTrue(outerScrollView.waitForExistence(timeout: 10))
            XCTAssertTrue(mediumScrollView.waitForExistence(timeout: 10))
            XCTAssertTrue(mediumElement.waitForExistence(timeout: 10))

            let mediumLeadingX = mediumElement.frame.minX
            var focusedMediumCode = false
            for _ in 0..<8 {
                app.typeKey(.tab, modifierFlags: [.option])
                app.typeKey(.rightArrow, modifierFlags: [])
                focusedMediumCode = waitUntil(timeout: 0.75) {
                    mediumElement.frame.minX < mediumLeadingX - 2
                }
                if focusedMediumCode { break }
            }
            XCTAssertTrue(
                focusedMediumCode,
                "Option-Tab should focus the medium overflowing code viewport."
            )
            attachScreenshot(
                of: window,
                named: "Reader medium code focus — \(appearance)"
            )

            resize(window, to: CGSize(width: 1_200, height: 760))
            XCTAssertTrue(
                waitUntil {
                    mediumElement.frame.minX >= mediumScrollView.frame.minX
                        && mediumElement.frame.maxX <= mediumScrollView.frame.maxX
                },
                "The medium code line should stop overflowing at the wide size."
            )
            let fittedX = mediumElement.frame.minX
            app.typeKey(.rightArrow, modifierFlags: [])
            XCTAssertEqual(mediumElement.frame.minX, fittedX, accuracy: 1)

            let firstParagraph = window.staticTexts[
                "Paragraph 1 ordinary words to keep vertical paging available."
            ]
            XCTAssertTrue(firstParagraph.waitForExistence(timeout: 5))
            let paragraphY = firstParagraph.frame.minY
            app.typeKey(.pageDown, modifierFlags: [])
            XCTAssertTrue(
                waitUntil {
                    !firstParagraph.exists
                        || firstParagraph.frame.minY < paragraphY - 100
                },
                "Page Down should return to vertical reading after code overflow disappears."
            )
            attachScreenshot(
                of: window,
                named: "Reader paging after code fits — \(appearance)"
            )

            let after = try snapshot(of: url)
            XCTAssertEqual(after.data, before.data)
            XCTAssertEqual(after.modificationDate, before.modificationDate)
            app.terminate()
        }
    }

    @MainActor
    func testResizeAndFullScreenPreserveMiddleAndTallReadingPositions() async throws {
        let beforePassage = (1...18).map {
            "Before paragraph \($0): " + String(
                repeating: "spaced prose changes height when the reading column reflows ",
                count: 4
            )
        }.joined(separator: "\n\n")
        let afterPassage = (1...16).map {
            "After paragraph \($0): " + String(
                repeating: "more prose keeps this passage in the middle of the document ",
                count: 4
            )
        }.joined(separator: "\n\n")
        let tallPassage = "TALL PASSAGE START " + String(
            repeating: "this tall paragraph retains a proportional place through major reflow ",
            count: 130
        ) + "TALL PASSAGE END"
        let source = """
            # Position checks

            \(beforePassage)

            MIDDLE READING PASSAGE

            \(tallPassage)

            AFTER TALL PASSAGE

            \(afterPassage)
            """
        let url = try makeDocument(named: "position-layout.md", content: source)
        let before = try snapshot(of: url)
        let app = configuredApplication()

        app.launch()
        try await openWhileRunning(url, in: app)
        let window = app.windows[url.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let scrollView = window.scrollViews["DocumentReaderScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10))
        let middle = window.staticTexts["MIDDLE READING PASSAGE"]
        centerElement(middle, in: scrollView)

        resize(window, to: CGSize(width: 520, height: 620))
        assertNearReadingLine(middle, in: scrollView, tolerance: 130)
        XCTAssertTrue(window.exists)
        XCTAssertTrue(window.staticTexts[url.lastPathComponent].exists)

        resize(window, to: CGSize(width: 1_200, height: 760))
        assertNearReadingLine(middle, in: scrollView, tolerance: 130)

        resize(window, to: CGSize(width: 520, height: 620))
        let tallElement = staticText(tallPassage, in: window)
        scrollToElement(tallElement, in: scrollView)
        place(fraction: 0.68, of: tallElement, atReadingLineIn: scrollView)
        let fractionBeforeFullScreen = fractionAtReadingLine(of: tallElement, in: scrollView)
        XCTAssertEqual(fractionBeforeFullScreen, 0.68, accuracy: 0.05)

        let fullScreenButton = window.buttons.matching(
            identifier: "_XCUI:FullScreenWindow"
        ).firstMatch
        XCTAssertTrue(fullScreenButton.waitForExistence(timeout: 5))
        let windowedSize = window.frame.size
        fullScreenButton.click()
        XCTAssertTrue(waitUntil(timeout: 10) {
            window.frame.width > windowedSize.width + 500
        }, "The test must exercise an actual native full-screen transition.")
        assertReadingFraction(
            fractionBeforeFullScreen,
            of: tallElement,
            atReadingLineIn: scrollView,
            tolerance: 0.1
        )
        XCTAssertTrue(window.staticTexts[url.lastPathComponent].exists)

        exitFullScreen(in: app)
        XCTAssertTrue(waitUntil(timeout: 10) {
            abs(window.frame.width - windowedSize.width) <= 3
        }, "The native full-screen exit should restore the windowed size.")
        assertReadingFraction(
            fractionBeforeFullScreen,
            of: tallElement,
            atReadingLineIn: scrollView,
            tolerance: 0.1
        )
        XCTAssertTrue(window.staticTexts[url.lastPathComponent].exists)
        attachScreenshot(of: window, named: "Reader position — Full-screen round trip")

        let after = try snapshot(of: url)
        XCTAssertEqual(after.data, before.data)
        XCTAssertEqual(after.modificationDate, before.modificationDate)
    }

    @MainActor
    func testLargeLazyDocumentResizeRoundTripPreservesExactMiddlePassage() async throws {
        let passages = (1...160).map {
            "Independent passage \($0): "
                + String(
                    repeating: "ordinary wrapping prose remains readable ",
                    count: 12
                )
                + "end."
        }
        let url = try makeDocument(
            named: "large-resize-position.md",
            content: passages.joined(separator: "\n\n")
        )
        let before = try snapshot(of: url)
        let app = configuredApplication()

        app.launch()
        try await openWhileRunning(url, in: app)
        let window = app.windows[url.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertEqual(window.frame.width, 900, accuracy: 3)
        XCTAssertEqual(window.frame.height, 720, accuracy: 3)

        let scrollView = window.scrollViews["DocumentReaderScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10))
        let passage = staticText(passages[75], in: window)
        centerElement(passage, in: scrollView)
        try await Task.sleep(for: .seconds(2))
        assertNearReadingLine(passage, in: scrollView, tolerance: 20)

        for width: CGFloat in [480, 1_200, 480] {
            resize(window, to: CGSize(width: width, height: 620))
            try await Task.sleep(for: .seconds(2))
            assertNearReadingLine(passage, in: scrollView, tolerance: 90)
        }
        attachScreenshot(of: window, named: "Reader large-document resize round trip")

        let after = try snapshot(of: url)
        XCTAssertEqual(after.data, before.data)
        XCTAssertEqual(after.modificationDate, before.modificationDate)
    }

    @MainActor
    func testIntentionalKeyboardAndWheelScrollingInterruptResizeRestoration() async throws {
        let passages = (1...160).map {
            "Independent passage \($0): "
                + String(
                    repeating: "ordinary wrapping prose remains readable ",
                    count: 12
                )
                + "end."
        }
        let url = try makeDocument(
            named: "resize-interruption.md",
            content: passages.joined(separator: "\n\n")
        )
        let before = try snapshot(of: url)
        let app = configuredApplication(
            resizeRestorationDelayMilliseconds: 4_000
        )

        app.launch()
        try await openWhileRunning(url, in: app)
        let window = app.windows[url.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let scrollView = window.scrollViews["DocumentReaderScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10))
        let passage = staticText(passages[75], in: window)
        centerElement(passage, in: scrollView)
        try await Task.sleep(for: .seconds(1))

        scrollView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)
        ).click()
        app.typeKey(.tab, modifierFlags: [.option])
        let controlY = passage.frame.midY
        app.typeKey(.pageDown, modifierFlags: [])
        XCTAssertTrue(
            waitUntil { passage.frame.midY < controlY - 100 },
            "The fixture must establish reader focus before testing interruption."
        )
        app.typeKey(.pageUp, modifierFlags: [])
        centerElement(passage, in: scrollView)
        try await Task.sleep(for: .seconds(1))

        let keyboardBaseline = passage.frame.midY - scrollView.frame.midY
        resize(window, to: CGSize(width: 900, height: 700))
        app.typeKey(.pageDown, modifierFlags: [])
        XCTAssertTrue(
            waitUntil(timeout: 1) {
                passage.frame.midY - scrollView.frame.midY
                    < keyboardBaseline - 300
            },
            "Page Down must move while resize restoration is still pending."
        )
        let keyboardPosition = passage.frame.midY - scrollView.frame.midY
        try await Task.sleep(for: .milliseconds(5_500))
        let settledKeyboardPosition = passage.frame.midY - scrollView.frame.midY
        XCTAssertLessThan(
            settledKeyboardPosition,
            keyboardBaseline - 100,
            "Delayed restoration must not undo intentional keyboard paging."
        )
        XCTAssertEqual(
            settledKeyboardPosition,
            keyboardPosition,
            accuracy: 100,
            "The reader should remain at the keyboard-selected position."
        )

        let keyboardSelectedPassage = try passageNearestReadingLine(
            among: passages[70...90],
            in: window,
            scrollView: scrollView
        )
        let keyboardSelectedFraction = semanticFractionAtReadingLine(
            of: keyboardSelectedPassage,
            in: scrollView
        )
        resize(window, to: CGSize(width: 480, height: 700))
        try await Task.sleep(for: .milliseconds(5_500))
        assertSemanticReadingPoint(
            keyboardSelectedFraction,
            of: keyboardSelectedPassage,
            in: scrollView,
            tolerance: 90,
            message: "A later width reflow should preserve the keyboard-selected reading point."
        )
        attachScreenshot(
            of: window,
            named: "Reader keyboard-selected position — follow-up resize"
        )

        resize(window, to: CGSize(width: 480, height: 620))
        centerElement(passage, in: scrollView)
        try await Task.sleep(for: .seconds(1))
        let wheelBaseline = passage.frame.midY - scrollView.frame.midY
        resize(window, to: CGSize(width: 480, height: 640))
        scrollView.scroll(byDeltaX: 0, deltaY: -400)
        XCTAssertTrue(
            waitUntil(timeout: 1) {
                passage.frame.midY - scrollView.frame.midY
                    < wheelBaseline - 200
            },
            "Wheel input must move while resize restoration is still pending."
        )
        let wheelPosition = passage.frame.midY - scrollView.frame.midY
        try await Task.sleep(for: .milliseconds(5_500))
        let settledWheelPosition = passage.frame.midY - scrollView.frame.midY
        XCTAssertLessThan(
            settledWheelPosition,
            wheelBaseline - 100,
            "Delayed restoration must not undo intentional pointer scrolling."
        )
        XCTAssertEqual(
            settledWheelPosition,
            wheelPosition,
            accuracy: 100,
            "The reader should remain at the wheel-selected position."
        )

        let wheelSelectedPassage = staticText(passages[78], in: window)
        XCTAssertTrue(
            wheelSelectedPassage.waitForExistence(timeout: 5),
            "The exact fixture should place passage 79 at the new reading point."
        )
        XCTAssertLessThanOrEqual(
            abs(wheelSelectedPassage.frame.minY - scrollView.frame.midY),
            90,
            "Wheel input should select the reading point near the start of passage 79."
        )
        let wheelSelectedFraction = semanticFractionAtReadingLine(
            of: wheelSelectedPassage,
            in: scrollView
        )
        resize(window, to: CGSize(width: 1_200, height: 620))
        try await Task.sleep(for: .milliseconds(5_500))
        assertSemanticReadingPoint(
            wheelSelectedFraction,
            of: wheelSelectedPassage,
            in: scrollView,
            tolerance: 90,
            message: "A later width reflow should preserve the wheel-selected reading point."
        )
        attachScreenshot(
            of: window,
            named: "Reader wheel-selected position — follow-up resize"
        )

        let after = try snapshot(of: url)
        XCTAssertEqual(after.data, before.data)
        XCTAssertEqual(after.modificationDate, before.modificationDate)
    }

    @MainActor
    func testDarkReaderRemainsUnclutteredAtNarrowWidth() async throws {
        let prose = "DARK PROSE "
            + String(repeating: "readable wrapping words ", count: 35)
            + "DARK PROSE END"
        let source = """
            # Dark layout

            \(prose)

            > DARK QUOTE CONTENT

            - DARK LIST CONTENT

            ```
            DARK_CODE_CONTENT
            ```
            """
        let url = try makeDocument(named: "dark-layout.md", content: source)
        let before = try snapshot(of: url)
        let app = configuredApplication(appearance: "Dark")

        app.launch()
        try await openWhileRunning(url, in: app)
        let window = app.windows[url.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let scrollView = window.scrollViews["DocumentReaderScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10))
        let proseElement = staticText(prose, in: window)
        XCTAssertTrue(proseElement.waitForExistence(timeout: 10))
        resize(window, to: CGSize(width: 480, height: 620))

        assertInsideReadingMargins(proseElement.frame, scrollView: scrollView)
        proseElement.hover()
        window.staticTexts["DARK QUOTE CONTENT"].hover()
        assertNoEditingControls(in: window)
        attachScreenshot(of: window, named: "Reader layout — Dark")

        let after = try snapshot(of: url)
        XCTAssertEqual(after.data, before.data)
        XCTAssertEqual(after.modificationDate, before.modificationDate)
    }

    @MainActor
    private func configuredApplication(
        appearance: String? = nil,
        resizeRestorationDelayMilliseconds: Int? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        if let appearance {
            app.launchEnvironment["NEOMD_UI_TEST_APPEARANCE"] = appearance
        }
        if let resizeRestorationDelayMilliseconds {
            app.launchEnvironment[
                "NEOMD_UI_TEST_RESIZE_RESTORATION_DELAY_MILLISECONDS"
            ] = String(resizeRestorationDelayMilliseconds)
        }
        return app
    }

    /// Delivers a native open-document event without relaunching, so the test-only
    /// appearance override remains in effect for the visual regressions.
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
    private func staticText(_ value: String, in container: XCUIElement) -> XCUIElement {
        container.staticTexts.matching(
            NSPredicate(format: "value == %@", value)
        ).firstMatch
    }

    @MainActor
    private func resize(_ window: XCUIElement, to size: CGSize) {
        let currentSize = window.frame.size
        let corner = window.coordinate(
            withNormalizedOffset: CGVector(dx: 1, dy: 1)
        ).withOffset(CGVector(dx: -2, dy: -2))
        corner.press(
            forDuration: 0.2,
            thenDragTo: corner.withOffset(
                CGVector(
                    dx: size.width - currentSize.width,
                    dy: size.height - currentSize.height
                )
            )
        )
        XCTAssertTrue(waitUntil(timeout: 8) {
            abs(window.frame.width - size.width) <= 3
                && abs(window.frame.height - size.height) <= 3
        }, "The reader window should reach the requested regression-test size.")
    }

    @MainActor
    private func exitFullScreen(in app: XCUIApplication) {
        app.activate()
        let viewMenu = app.menuBars.menuBarItems["View"]
        XCTAssertTrue(viewMenu.waitForExistence(timeout: 5))
        viewMenu.click()

        let toggleFullScreen = app.menuBars.menuItems.matching(
            identifier: "toggleFullScreen:"
        ).firstMatch
        XCTAssertTrue(toggleFullScreen.waitForExistence(timeout: 5))
        XCTAssertTrue(toggleFullScreen.isEnabled)
        toggleFullScreen.click()
    }

    @MainActor
    private func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement) {
        for _ in 0..<35 where !element.exists {
            scrollView.scroll(byDeltaX: 0, deltaY: -350)
        }
        XCTAssertTrue(element.exists, "Expected document content should be reachable.")
        if !element.isHittable {
            let adjustment = element.frame.midY - scrollView.frame.midY
            scrollView.scroll(byDeltaX: 0, deltaY: -adjustment)
        }
        XCTAssertTrue(waitUntil { element.isHittable })
    }

    @MainActor
    private func centerElement(_ element: XCUIElement, in scrollView: XCUIElement) {
        scrollToElement(element, in: scrollView)
        for _ in 0..<3 {
            let adjustment = element.frame.midY - scrollView.frame.midY
            if abs(adjustment) <= 4 { break }
            scrollView.scroll(byDeltaX: 0, deltaY: -adjustment)
        }
        assertNearReadingLine(element, in: scrollView, tolerance: 20)
    }

    @MainActor
    private func place(
        fraction: CGFloat,
        of element: XCUIElement,
        atReadingLineIn scrollView: XCUIElement
    ) {
        for _ in 0..<3 {
            let frame = element.frame
            let targetY = frame.minY + (frame.height * fraction)
            let adjustment = targetY - scrollView.frame.midY
            if abs(adjustment) <= 4 { break }
            scrollView.scroll(byDeltaX: 0, deltaY: -adjustment)
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func fractionAtReadingLine(
        of element: XCUIElement,
        in scrollView: XCUIElement
    ) -> CGFloat {
        let frame = element.frame
        XCTAssertGreaterThan(frame.height, 0)
        return (scrollView.frame.midY - frame.minY) / frame.height
    }

    @MainActor
    private func passageNearestReadingLine(
        among passages: ArraySlice<String>,
        in window: XCUIElement,
        scrollView: XCUIElement
    ) throws -> XCUIElement {
        let visiblePassages = passages
            .map { staticText($0, in: window) }
            .filter { $0.exists && scrollView.frame.intersects($0.frame) }
        return try XCTUnwrap(
            visiblePassages.min {
                abs($0.frame.midY - scrollView.frame.midY)
                    < abs($1.frame.midY - scrollView.frame.midY)
            },
            "Expected a visible passage near the current reading line."
        )
    }

    @MainActor
    private func semanticFractionAtReadingLine(
        of element: XCUIElement,
        in scrollView: XCUIElement
    ) -> CGFloat {
        let frame = element.frame
        XCTAssertGreaterThan(frame.height, 0)
        return min(
            1,
            max(0, (scrollView.frame.midY - frame.minY) / frame.height)
        )
    }

    @MainActor
    private func assertSemanticReadingPoint(
        _ fraction: CGFloat,
        of element: XCUIElement,
        in scrollView: XCUIElement,
        tolerance: CGFloat,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitUntil {
                guard element.exists else { return false }
                let frame = element.frame
                let semanticY = frame.minY + (frame.height * fraction)
                return abs(semanticY - scrollView.frame.midY) <= tolerance
            },
            message,
            file: file,
            line: line
        )
        XCTAssertTrue(
            scrollView.frame.intersects(element.frame),
            "The user-selected passage should remain inside the viewport.",
            file: file,
            line: line
        )
    }

    @MainActor
    private func assertNearReadingLine(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        tolerance: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitUntil {
                element.exists
                    && abs(element.frame.midY - scrollView.frame.midY) <= tolerance
            },
            "The same reading passage should remain near the viewport reading line.",
            file: file,
            line: line
        )
        XCTAssertTrue(
            scrollView.frame.intersects(element.frame),
            "The preserved passage should remain inside the viewport.",
            file: file,
            line: line
        )
    }

    @MainActor
    private func assertReadingFraction(
        _ expectedFraction: CGFloat,
        of element: XCUIElement,
        atReadingLineIn scrollView: XCUIElement,
        tolerance: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitUntil {
                element.exists
                    && abs(
                        fractionAtReadingLine(of: element, in: scrollView)
                            - expectedFraction
                    ) <= tolerance
            },
            "The same place within the tall passage should remain at the reading line.",
            file: file,
            line: line
        )
        XCTAssertTrue(
            scrollView.frame.intersects(element.frame),
            "The preserved part of the tall passage should remain visible.",
            file: file,
            line: line
        )
    }

    private func assertInsideReadingMargins(
        _ frame: CGRect,
        scrollView: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(
            frame.minX,
            scrollView.frame.minX + 34,
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(
            frame.maxX,
            scrollView.frame.maxX - 34,
            file: file,
            line: line
        )
    }

    @MainActor
    private func assertNoEditingControls(
        in window: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for title in ["Edit", "Copy", "Format", "Bold", "Italic"] {
            XCTAssertFalse(
                window.buttons[title].exists,
                "Hovering document content must not reveal a \(title) button.",
                file: file,
                line: line
            )
        }
    }

    @MainActor
    private func attachScreenshot(of window: XCUIElement, named name: String) {
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 5,
        condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return condition()
    }
}
