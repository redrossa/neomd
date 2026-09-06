//
//  AppearanceUITests.swift
//  NeoMDUITests
//

import AppKit
import XCTest

/// End-to-end coverage for following the Mac's light and dark appearance.
///
/// Appearance cannot be verified from element trees alone, so these tests sample the
/// pixels of real window screenshots: a surface is only "coherent" if its rendered
/// text actually contrasts with its rendered background.
///
/// Two contrast bars are used. Content the reader presents at full emphasis — prose,
/// list text, code — must reach 4.5:1, the WCAG AA ratio for body text. Text the reader
/// deliberately de-emphasizes with the system `secondary` label style — quotations, the
/// empty-document message, the no-file instruction — must reach 3:1, the AA ratio for
/// large text and interface elements. The second bar records what the platform's own
/// semantic color provides; raising de-emphasized text further is typography work, not
/// part of this appearance foundation.
final class AppearanceUITests: XCTestCase {
    private var testDirectory: URL!
    private var originalSystemDarkMode: Bool?

    override func setUpWithError() throws {
        continueAfterFailure = false
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeoMD-Appearance-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()

        // A test that changed the real system appearance must always put it back,
        // including when it failed part way through. Restoration uses every path the
        // test was allowed to use in the first place — a machine that needed a host
        // controller or a person to make the change needs the same help to undo it —
        // and it is only believed once the real setting has been read back. A
        // restoration that could not be verified is reported, never swallowed.
        var restorationFailure: (any Error)?
        if let originalSystemDarkMode {
            do {
                try SystemAppearance.restore(to: originalSystemDarkMode)
                self.originalSystemDarkMode = nil
            } catch {
                restorationFailure = error
            }
        }

        if let testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
            for url in unreadableFixtures {
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o644],
                    ofItemAtPath: url.path
                )
                try? FileManager.default.removeItem(at: url)
            }
        }

        if let restorationFailure {
            // Throwing alone is not enough to reach the tester. XCTest stops recording
            // failures for a test that has already failed with `continueAfterFailure`
            // off, and a restoration can only fail on a run that failed already — a run
            // whose own switches all worked leaves nothing to restore. So the
            // instruction is printed and attached, which always surfaces, and the throw
            // is what would still turn an otherwise-passing run red. Recording a failure
            // here as well would only make XCTest run this teardown a second time and
            // wait out the same restoration timeout again.
            let message = """
                [NeoMD appearance test] \(restorationFailure.localizedDescription)
                """
            print(message)
            fflush(stdout)
            let attachment = XCTAttachment(string: message)
            attachment.name = "System appearance restoration failed"
            attachment.lifetime = .keepAlways
            add(attachment)
            throw restorationFailure
        }
    }

    private var unreadableFixtures: [URL] = []

    // MARK: - Criterion 1: a coherent page in either appearance

    @MainActor
    func testOpeningInLightAndDarkRendersCoherentDocumentContent() async throws {
        for appearance in Appearance.allCases {
            let url = try makeDocument(
                named: "content-\(appearance.rawValue).md",
                content: Self.coherenceFixture
            )
            let before = try snapshot(of: url)
            let app = configuredApplication(appearance: appearance)

            app.launch()
            try await openWhileRunning(url, in: app)
            let window = app.windows[url.lastPathComponent]
            XCTAssertTrue(window.waitForExistence(timeout: 10))
            let scrollView = window.scrollViews["DocumentReaderScrollView"]
            XCTAssertTrue(scrollView.waitForExistence(timeout: 10))

            let heading = window.staticTexts["Appearance checks"]
            let singleLine = staticText("SINGLE LINE PROSE", in: window)
            let body = staticText(Self.bodyProse, in: window)
            let link = try element(containing: Self.linkLabel, in: window)
            let quote = staticText("QUOTED ASIDE CONTENT", in: window)
            let list = staticText("LIST ITEM CONTENT", in: window)
            let code = staticText("CODE_BLOCK_CONTENT", in: window)
            let codeContainer = window.scrollViews.matching(
                NSPredicate(format: "identifier BEGINSWITH 'MarkdownCodeBlock-'")
            ).firstMatch
            for element in [heading, singleLine, body, link, quote, list, code] {
                XCTAssertTrue(
                    element.waitForExistence(timeout: 10),
                    "\(appearance.rawValue): every fixture block should render."
                )
            }
            XCTAssertTrue(codeContainer.waitForExistence(timeout: 10))

            let pixels = try XCTUnwrap(
                WindowPixels(of: window),
                "\(appearance.rawValue): the reader window should be capturable."
            )
            let page = try XCTUnwrap(
                pixels.medianSample(in: pageBackgroundRect(of: scrollView, avoiding: body)),
                "\(appearance.rawValue): the page background should be samplable."
            )

            switch appearance {
            case .light:
                XCTAssertGreaterThan(
                    page.gray,
                    0.6,
                    "Light mode should draw the page on a light background."
                )
            case .dark:
                XCTAssertLessThan(
                    page.gray,
                    0.4,
                    "Dark mode should draw the page on a dark background."
                )
            }

            // Prose, quotations, and code all have to stay readable on that page.
            var measurements: [String] = ["\(appearance.rawValue) page gray: \(page.gray)"]
            for (name, element, minimum) in [
                ("body prose", body, 4.5),
                ("list item", list, 4.5),
                ("quotation (secondary)", quote, 3.0)
            ] {
                let contrast = pixels.inkContrast(in: element.frame, against: page)
                measurements.append("\(name) contrast: \(contrast)")
                XCTAssertGreaterThanOrEqual(
                    contrast,
                    minimum,
                    "\(appearance.rawValue): \(name) should keep readable contrast, not \(contrast)."
                )
            }

            let codeSurface = try XCTUnwrap(
                pixels.medianSample(in: codeContainer.frame),
                "\(appearance.rawValue): the code container should be samplable."
            )
            let codeContrast = pixels.inkContrast(in: code.frame, against: codeSurface)
            measurements.append("code surface gray: \(codeSurface.gray)")
            measurements.append("code contrast: \(codeContrast)")
            XCTAssertGreaterThanOrEqual(
                abs(codeSurface.gray - page.gray),
                0.015,
                "\(appearance.rawValue): code should sit on its own visible surface."
            )
            XCTAssertGreaterThanOrEqual(
                codeContrast,
                4.5,
                "\(appearance.rawValue): code text should stay readable on that surface."
            )

            // A link has to be visibly distinct from the prose around it.
            let bodyInk = try XCTUnwrap(pixels.ink(in: body.frame, against: page))
            let linkInk = try XCTUnwrap(pixels.ink(in: link.frame, against: page))
            measurements.append("link contrast: \(PixelSample.contrastRatio(linkInk, page))")
            measurements.append("link/prose color distance: \(linkInk.distance(to: bodyInk))")
            XCTAssertGreaterThanOrEqual(
                PixelSample.contrastRatio(linkInk, page),
                3.0,
                "\(appearance.rawValue): link text should stay legible on the page."
            )
            XCTAssertGreaterThanOrEqual(
                linkInk.distance(to: bodyInk),
                0.08,
                "\(appearance.rawValue): a link should not render as ordinary prose."
            )

            // Structure, not only color: a quotation rule, list markers, a heading
            // scale, and a thematic break all survive in both appearances.
            XCTAssertGreaterThanOrEqual(
                pixels.maximumGrayDelta(in: gutterRect(leftOf: quote, width: 22), from: page),
                0.05,
                "\(appearance.rawValue): a quotation should keep its leading rule."
            )
            XCTAssertGreaterThanOrEqual(
                pixels.maximumGrayDelta(in: gutterRect(leftOf: list, width: 30), from: page),
                0.10,
                "\(appearance.rawValue): a list item should keep its marker."
            )
            XCTAssertGreaterThan(
                heading.frame.height,
                singleLine.frame.height * 1.4,
                "\(appearance.rawValue): a heading should stay larger than body prose."
            )
            let breakBand = CGRect(
                x: body.frame.minX,
                y: list.frame.maxY,
                width: body.frame.width,
                height: max(1, codeContainer.frame.minY - list.frame.maxY)
            )
            XCTAssertGreaterThanOrEqual(
                pixels.maximumRowGrayDelta(in: breakBand, from: page),
                0.02,
                "\(appearance.rawValue): the thematic break should draw a visible rule."
            )

            attachScreenshot(of: window, named: "Reader content — \(appearance.rawValue)")
            attachMeasurements(measurements, named: "Reader contrast — \(appearance.rawValue)")

            let after = try snapshot(of: url)
            XCTAssertEqual(after.data, before.data)
            XCTAssertEqual(after.modificationDate, before.modificationDate)
            app.terminate()
        }
    }

    @MainActor
    func testSelectionStaysLegibleInLightAndDark() async throws {
        for appearance in Appearance.allCases {
            let url = try makeDocument(
                named: "selection-\(appearance.rawValue).md",
                content: Self.coherenceFixture
            )
            let before = try snapshot(of: url)
            let app = configuredApplication(appearance: appearance)

            app.launch()
            try await openWhileRunning(url, in: app)
            let window = app.windows[url.lastPathComponent]
            XCTAssertTrue(window.waitForExistence(timeout: 10))
            let body = staticText(Self.bodyProse, in: window)
            XCTAssertTrue(body.waitForExistence(timeout: 10))

            let unselected = try XCTUnwrap(WindowPixels(of: window))
            body.doubleClick()
            let selected = try XCTUnwrap(WindowPixels(of: window))

            let editMenu = app.menuBars.menuBarItems["Edit"]
            XCTAssertTrue(editMenu.waitForExistence(timeout: 5))
            editMenu.click()
            let copyItem = app.menuBars.menuItems["Copy"]
            XCTAssertTrue(copyItem.waitForExistence(timeout: 5))
            XCTAssertTrue(
                copyItem.isEnabled,
                "\(appearance.rawValue): double-clicking prose should select a word."
            )
            app.typeKey(.escape, modifierFlags: [])

            let changed = try XCTUnwrap(
                selected.changedRegion(from: unselected, in: body.frame),
                "\(appearance.rawValue): selecting a word should change the rendered page."
            )
            let highlight = try XCTUnwrap(selected.medianSample(in: changed))
            let selectedInk = try XCTUnwrap(selected.ink(in: changed, against: highlight))
            XCTAssertGreaterThanOrEqual(
                PixelSample.contrastRatio(selectedInk, highlight),
                3.0,
                "\(appearance.rawValue): selected text should stay readable on its highlight."
            )
            attachScreenshot(of: window, named: "Reader selection — \(appearance.rawValue)")

            let after = try snapshot(of: url)
            XCTAssertEqual(after.data, before.data)
            XCTAssertEqual(after.modificationDate, before.modificationDate)
            app.terminate()
        }
    }

    @MainActor
    func testEmptyDocumentAndNoFileWindowStayLegibleInLightAndDark() async throws {
        for appearance in Appearance.allCases {
            let url = try makeDocument(named: "empty-\(appearance.rawValue).md", content: "")
            let before = try snapshot(of: url)
            let app = configuredApplication(appearance: appearance)

            app.launch()
            let instructionWindow = app.windows.containing(
                .staticText,
                identifier: "NoDocumentInstruction"
            ).firstMatch
            XCTAssertTrue(instructionWindow.waitForExistence(timeout: 10))
            let instruction = app.staticTexts["NoDocumentInstruction"]
            XCTAssertTrue(instruction.waitForExistence(timeout: 10))
            try assertLegible(
                instruction,
                in: instructionWindow,
                appearance: appearance,
                description: "the no-file instruction",
                minimumContrast: 3.0
            )
            attachScreenshot(
                of: instructionWindow,
                named: "No-file window — \(appearance.rawValue)"
            )

            try await openWhileRunning(url, in: app)
            let window = app.windows[url.lastPathComponent]
            XCTAssertTrue(window.waitForExistence(timeout: 10))
            let emptyMessage = app.staticTexts["This document is empty."]
            XCTAssertTrue(emptyMessage.waitForExistence(timeout: 10))
            try assertLegible(
                emptyMessage,
                in: window,
                appearance: appearance,
                description: "the empty-document message",
                minimumContrast: 3.0
            )
            attachScreenshot(of: window, named: "Empty document — \(appearance.rawValue)")

            let after = try snapshot(of: url)
            XCTAssertEqual(after.data, before.data)
            XCTAssertEqual(after.modificationDate, before.modificationDate)
            app.terminate()
        }
    }

    @MainActor
    func testDropErrorStaysLegibleInLightAndDark() throws {
        for appearance in Appearance.allCases {
            let unreadable = try makeUnreadableDocument(
                named: "unreadable-\(appearance.rawValue).md"
            )
            let app = configuredApplication(appearance: appearance)

            app.launch()
            let instructionWindow = app.windows.containing(
                .staticText,
                identifier: "NoDocumentInstruction"
            ).firstMatch
            XCTAssertTrue(instructionWindow.waitForExistence(timeout: 10))

            dragFromFinder(unreadable, to: instructionWindow)

            let alertTitle = app.staticTexts["Couldn’t Open Document"]
            XCTAssertTrue(
                alertTitle.waitForExistence(timeout: 15),
                "\(appearance.rawValue): a failed drop should explain itself."
            )
            // An alert is presented in its own window, so it has to be sampled there
            // rather than in the window it belongs to.
            let alert = try alertContainer(titled: "Couldn’t Open Document", in: app)
            try assertLegible(
                alertTitle,
                in: alert,
                appearance: appearance,
                description: "the drop error",
                minimumContrast: 3.0
            )
            attachScreenshot(of: alert, named: "Drop error — \(appearance.rawValue)")

            let okButton = alert.buttons["OK"].firstMatch
            XCTAssertTrue(okButton.waitForExistence(timeout: 5))
            okButton.click()
            XCTAssertTrue(alertTitle.waitForNonExistence(timeout: 5))
            XCTAssertTrue(
                app.staticTexts["NoDocumentInstruction"].exists,
                "\(appearance.rawValue): dismissing the error should leave the app usable."
            )
            app.terminate()
        }
    }

    // MARK: - Criterion 2: an appearance change while a document is open

    /// The criterion's own scenario: a real macOS light/dark change, with no appearance
    /// pin, while a document is open.
    ///
    /// The test runner has to be able to change the real setting for this, either
    /// directly or through the host controller described in
    /// `docs/appearance-ui-tests.md`. When it cannot, the test reports that limitation
    /// and skips rather than passing, and the criterion has to be verified by hand.
    ///
    /// Whatever happens after the first switch — including a failure before the
    /// switch-back below — `tearDownWithError` restores the appearance this test found
    /// and fails the test if it cannot verify that it did.
    @MainActor
    func testSystemAppearanceChangeUpdatesTheOpenDocumentInPlace() async throws {
        let startedDark = try requireSystemAppearanceControl()
        originalSystemDarkMode = startedDark

        try await assertAppearanceChangePreservesReading(
            app: configuredApplication(),
            fixtureName: "live-system-appearance.md",
            startsDark: startedDark,
            label: "system"
        ) { dark in
            try SystemAppearance.setDarkMode(dark)
            try Self.failEarlyIfRehearsingCleanup(afterSwitchingTo: dark, from: startedDark)
        }
    }

    /// A deliberate failure immediately after the first real appearance switch.
    ///
    /// The cleanup guarantee is itself testable this way: a run started with
    /// `NEOMD_UI_TEST_APPEARANCE_REHEARSE_CLEANUP=1` stops here, with the Mac already
    /// switched and the test's own switch-back never reached, so the only thing that
    /// can restore the appearance is teardown. Ordinary runs never reach it.
    private static func failEarlyIfRehearsingCleanup(
        afterSwitchingTo dark: Bool,
        from original: Bool
    ) throws {
        guard dark != original,
              ProcessInfo.processInfo.environment[
                "NEOMD_UI_TEST_APPEARANCE_REHEARSE_CLEANUP"
              ] == "1"
        else { return }

        XCTFail(
            """
            Intentional failure after the first real appearance switch, rehearsing the \
            restoration this test owes the tester.
            """
        )
        throw RehearsedCleanupFailure()
    }

    private struct RehearsedCleanupFailure: Error, CustomStringConvertible {
        var description: String {
            "Intentional failure after the first real appearance switch."
        }
    }

    /// A repeatable regression for the same repaint on any machine.
    ///
    /// This changes only this app's appearance, through a debug-only test channel, so
    /// it cannot show that NeoMD follows the system setting. What it does show, without
    /// touching the tester's machine, is that an appearance change repaints the open
    /// document in place: the same process, window, and document, at the same place.
    @MainActor
    func testAppearanceChangeRepaintsTheOpenDocumentInPlace() async throws {
        try await assertAppearanceChangePreservesReading(
            app: configuredApplication(appearance: .light, appearanceChannel: true),
            fixtureName: "in-place-appearance.md",
            startsDark: false,
            label: "in-place"
        ) { dark in
            DistributedNotificationCenter.default().postNotificationName(
                Notification.Name("io.neomd.uitest.setAppearance"),
                object: dark ? "Dark" : "Light",
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }

    /// Puts a passage at the reading line, changes the appearance, and requires the
    /// same process, window, document, and reading position afterwards — with the
    /// rendered page actually repainted, not merely reported as changed.
    @MainActor
    private func assertAppearanceChangePreservesReading(
        app: XCUIApplication,
        fixtureName: String,
        startsDark: Bool,
        label: String,
        applyAppearance: (_ dark: Bool) throws -> Void
    ) async throws {
        let passages = (1...120).map {
            "Independent passage \($0): "
                + String(repeating: "ordinary wrapping prose remains readable ", count: 10)
                + "end."
        }
        let url = try makeDocument(
            named: fixtureName,
            content: "# Live appearance\n\n" + passages.joined(separator: "\n\n")
        )
        let before = try snapshot(of: url)

        app.launch()
        try await openWhileRunning(url, in: app)
        let window = app.windows[url.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let scrollView = window.scrollViews["DocumentReaderScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10))

        let passage = staticText(passages[60], in: window)
        centerElement(passage, in: scrollView)
        try await Task.sleep(for: .seconds(1))

        let processIdentifier = try XCTUnwrap(runningProcessIdentifier())
        let windowCount = app.windows.count
        let windowFrame = window.frame
        let offsetBefore = passage.frame.midY - scrollView.frame.midY
        let backgroundRect = pageBackgroundRect(of: scrollView, avoiding: passage)
        let pageBefore = try XCTUnwrap(
            WindowPixels(of: window)?.medianSample(in: backgroundRect)
        )
        XCTAssertEqual(
            pageBefore.gray > 0.5,
            !startsDark,
            "\(label): the reader should already match the appearance it launched under."
        )
        attachScreenshot(
            of: window,
            named: "Appearance change (\(label)) — before, \(startsDark ? "Dark" : "Light")"
        )

        try applyAppearance(!startsDark)

        // The proof is the rendered page changing, not a signal from the app.
        var pageAfter: PixelSample?
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                guard let page = WindowPixels(of: window)?.medianSample(in: backgroundRect)
                else { return false }
                pageAfter = page
                return abs(page.gray - pageBefore.gray) > 0.25
            },
            "\(label): the open document should repaint for the new appearance."
        )
        let repainted = try XCTUnwrap(pageAfter)
        XCTAssertEqual(
            repainted.gray > 0.5,
            startsDark,
            "\(label): the page should now match the newly selected appearance."
        )

        // Same process, same window, same document, same place.
        XCTAssertEqual(
            runningProcessIdentifier(),
            processIdentifier,
            "\(label): an appearance change must not relaunch the app."
        )
        XCTAssertEqual(app.windows.count, windowCount, "\(label): no window should be replaced.")
        XCTAssertTrue(window.exists)
        XCTAssertEqual(window.frame, windowFrame)
        XCTAssertTrue(
            window.staticTexts[url.lastPathComponent].exists,
            "\(label): the same document should still be open."
        )
        XCTAssertTrue(passage.exists, "\(label): the reading passage should still be on screen.")
        XCTAssertEqual(
            passage.frame.midY - scrollView.frame.midY,
            offsetBefore,
            accuracy: 8,
            "\(label): an appearance change must not move the reading position."
        )
        let contrastAfter = try XCTUnwrap(
            WindowPixels(of: window)?.inkContrast(in: passage.frame, against: repainted)
        )
        attachMeasurements(
            [
                "page gray before: \(pageBefore.gray)",
                "page gray after: \(repainted.gray)",
                "reading offset before: \(offsetBefore)",
                "reading offset after: \(passage.frame.midY - scrollView.frame.midY)",
                "prose contrast after: \(contrastAfter)"
            ],
            named: "Appearance change (\(label))"
        )
        XCTAssertGreaterThanOrEqual(
            contrastAfter,
            4.5,
            "\(label): the repainted page should keep readable text contrast."
        )
        attachScreenshot(
            of: window,
            named: "Appearance change (\(label)) — after, \(startsDark ? "Light" : "Dark")"
        )

        // Switching back has to be equally uneventful.
        try applyAppearance(startsDark)
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                guard let page = WindowPixels(of: window)?.medianSample(in: backgroundRect)
                else { return false }
                return abs(page.gray - pageBefore.gray) < 0.1
            },
            "\(label): restoring the appearance should repaint the same document again."
        )
        XCTAssertEqual(
            passage.frame.midY - scrollView.frame.midY,
            offsetBefore,
            accuracy: 8,
            "\(label): switching back must also preserve the reading position."
        )
        XCTAssertTrue(window.staticTexts[url.lastPathComponent].exists)

        let after = try snapshot(of: url)
        XCTAssertEqual(after.data, before.data)
        XCTAssertEqual(after.modificationDate, before.modificationDate)
    }

    // MARK: - Criterion 4: distinctions that do not rely on color

    /// A link has to be recognizable without color on an ordinary launch, in both
    /// appearances: no accessibility setting, no launch environment, nothing the reader
    /// has to find and switch on first.
    ///
    /// Color cannot be argued away from a screenshot, so the underline is measured
    /// instead: an unbroken horizontal run of marked pixels spanning a whole label,
    /// including the spaces between its words, is a rule. Letterforms always break, so
    /// ordinary prose measured the same way scores far lower, and a link inside a
    /// sentence marks its label without underlining the sentence.
    @MainActor
    func testLinksAreUnderlinedByDefaultInLightAndDark() async throws {
        for appearance in Appearance.allCases {
            let url = try makeDocument(
                named: "link-underline-\(appearance.rawValue).md",
                content: Self.linkFixture
            )
            let app = configuredApplication(appearance: appearance)
            app.launch()
            try await openWhileRunning(url, in: app)
            let window = app.windows[url.lastPathComponent]
            XCTAssertTrue(window.waitForExistence(timeout: 10))
            let scrollView = window.scrollViews["DocumentReaderScrollView"]
            XCTAssertTrue(scrollView.waitForExistence(timeout: 10))

            let link = try element(containing: Self.linkLabel, in: window)
            let mixed = try element(containing: Self.mixedLinkLabel, in: window)
            let control = staticText(Self.controlProse, in: window)
            for element in [link, mixed, control] {
                XCTAssertTrue(
                    element.waitForExistence(timeout: 10),
                    "\(appearance.rawValue): every fixture line should render."
                )
            }

            let pixels = try XCTUnwrap(WindowPixels(of: window))
            let page = try XCTUnwrap(
                pixels.medianSample(in: pageBackgroundRect(of: scrollView, avoiding: control)),
                "\(appearance.rawValue): the page background should be samplable."
            )
            func longestRun(across element: XCUIElement) -> CGFloat {
                pixels.maximumContiguousRunFraction(
                    in: element.frame.insetBy(dx: 0, dy: -3),
                    differingFrom: page,
                    byAtLeast: 0.15
                )
            }
            let linkRun = longestRun(across: link)
            let mixedRun = longestRun(across: mixed)
            let controlRun = longestRun(across: control)

            attachScreenshot(of: window, named: "Link presentation — \(appearance.rawValue)")
            attachMeasurements(
                [
                    "page gray: \(page.gray)",
                    "longest unbroken run, link label: \(linkRun)",
                    "longest unbroken run, link inside a sentence: \(mixedRun)",
                    "longest unbroken run, ordinary prose: \(controlRun)"
                ],
                named: "Link underline evidence — \(appearance.rawValue)"
            )

            XCTAssertGreaterThan(
                linkRun,
                0.9,
                "\(appearance.rawValue): a link should draw an unbroken rule under its label."
            )
            XCTAssertLessThan(
                controlRun,
                0.5,
                "\(appearance.rawValue): ordinary prose should stay unmarked letterforms."
            )
            XCTAssertGreaterThan(
                mixedRun,
                max(0.1, controlRun * 3),
                """
                \(appearance.rawValue): a link inside a sentence should be underlined too, \
                not \(mixedRun) against prose at \(controlRun).
                """
            )
            XCTAssertLessThan(
                mixedRun,
                0.9,
                "\(appearance.rawValue): the underline should mark the link, not the sentence."
            )

            // The tint is still there; it is simply no longer the only cue.
            let linkInk = try XCTUnwrap(pixels.ink(in: link.frame, against: page))
            let controlInk = try XCTUnwrap(pixels.ink(in: control.frame, against: page))
            XCTAssertGreaterThanOrEqual(
                linkInk.distance(to: controlInk),
                0.08,
                "\(appearance.rawValue): a link should not render as ordinary prose."
            )
            app.terminate()
        }
    }

    // MARK: - Fixtures

    private static let bodyProse =
        "Ordinary paragraph with inline code and BODY PROSE MARKER at the end."
    private static let linkLabel = "RELEASE CHECKLIST LINK"
    private static let mixedLinkLabel = "MIXED CHECKLIST LINK"
    private static let controlProse =
        "Ordinary sentence around plain words and ordinary prose written after them."

    /// Links on their own and inside a sentence, next to prose of the same shape, so an
    /// underline can be told apart from letterforms and from the line around it.
    private static let linkFixture = """
        # Link checks

        [\(linkLabel)](https://example.com/checklist)

        \(controlProse)

        Ordinary sentence around a [\(mixedLinkLabel)](https://example.com/mixed) and \
        ordinary prose written after it.
        """

    private static let coherenceFixture = """
        # Appearance checks

        SINGLE LINE PROSE

        [\(linkLabel)](https://example.com/checklist)

        Ordinary paragraph with `inline code` and BODY PROSE MARKER at the end.

        > QUOTED ASIDE CONTENT

        - LIST ITEM CONTENT

        ***

        ```
        CODE_BLOCK_CONTENT
        ```
        """

    private enum Appearance: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
    }

    // MARK: - Application helpers

    @MainActor
    private func configuredApplication(
        appearance: Appearance? = nil,
        appearanceChannel: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        if let appearance {
            app.launchEnvironment["NEOMD_UI_TEST_APPEARANCE"] = appearance.rawValue
        }
        if appearanceChannel {
            app.launchEnvironment["NEOMD_UI_TEST_APPEARANCE_CHANNEL"] = "1"
        }
        return app
    }

    /// Opens a document in the already-running app, so a test-only appearance pin and
    /// the live system appearance both stay in effect.
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

    private func runningProcessIdentifier() -> pid_t? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == "io.neomd.NeoMD"
        }?.processIdentifier
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

    /// A Markdown file the app is allowed to claim but not allowed to read, so a drop
    /// reaches the reader's own error state.
    private func makeUnreadableDocument(named name: String) throws -> URL {
        let url = try makeDocument(named: name, content: "UNREADABLE DROP CONTENT")
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: url.path
        )
        unreadableFixtures.append(url)
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

    /// Finds a rendered run of text whether the accessibility tree exposes it as static
    /// text or as a link.
    @MainActor
    private func element(
        containing text: String,
        in window: XCUIElement
    ) throws -> XCUIElement {
        let predicate = NSPredicate(
            format: "value CONTAINS %@ OR label CONTAINS %@",
            text,
            text
        )
        for query in [window.staticTexts, window.links, window.descendants(matching: .any)] {
            let match = query.matching(predicate).firstMatch
            if match.waitForExistence(timeout: 5) { return match }
        }
        XCTFail("The reader did not render \(text).")
        throw MissingRenderedText(text: text)
    }

    private struct MissingRenderedText: Error, CustomStringConvertible {
        let text: String
        var description: String { "The reader did not render \(text)." }
    }

    /// The window an alert is drawn in, whichever element kind macOS presents it as.
    @MainActor
    private func alertContainer(
        titled title: String,
        in app: XCUIApplication
    ) throws -> XCUIElement {
        let candidates = [
            app.sheets.containing(.staticText, identifier: title).firstMatch,
            app.dialogs.containing(.staticText, identifier: title).firstMatch,
            app.windows.containing(.staticText, identifier: title).firstMatch,
            app.sheets.firstMatch,
            app.dialogs.firstMatch
        ]
        for candidate in candidates where candidate.exists && candidate.frame.height > 1 {
            return candidate
        }
        XCTFail("The alert titled \(title) was not presented in a container.")
        throw MissingRenderedText(text: title)
    }

    @MainActor
    private func centerElement(_ element: XCUIElement, in scrollView: XCUIElement) {
        for _ in 0..<40 where !element.exists {
            scrollView.scroll(byDeltaX: 0, deltaY: -350)
        }
        XCTAssertTrue(element.exists, "The reading passage should be reachable.")
        for _ in 0..<4 {
            let adjustment = element.frame.midY - scrollView.frame.midY
            if abs(adjustment) <= 4 { break }
            scrollView.scroll(byDeltaX: 0, deltaY: -adjustment)
        }
    }

    /// Finder is brought forward with the fixture selected, then its row is dragged
    /// onto the target window. This mirrors the drag coverage in the opening tests.
    @MainActor
    private func dragFromFinder(_ url: URL, to targetWindow: XCUIElement) {
        XCTAssertTrue(targetWindow.waitForExistence(timeout: 10))

        let titleBar = targetWindow.coordinate(
            withNormalizedOffset: CGVector(dx: 0.55, dy: 0.02)
        )
        titleBar.press(
            forDuration: 0.2,
            thenDragTo: titleBar.withOffset(CGVector(dx: 380, dy: 0))
        )

        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        let generatedWindowPredicate = NSPredicate(
            format: "title BEGINSWITH 'NeoMD-Appearance-'"
        )
        for window in finder.windows.matching(generatedWindowPredicate)
            .allElementsBoundByIndex {
            let closeButton = window.buttons.matching(
                identifier: "_XCUI:CloseWindow"
            ).firstMatch
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

    // MARK: - Appearance assertions

    /// A strip of page that carries no text, used as the background reference.
    @MainActor
    private func pageBackgroundRect(
        of scrollView: XCUIElement,
        avoiding element: XCUIElement
    ) -> CGRect {
        let frame = scrollView.frame
        let width = max(8, min(24, element.frame.minX - frame.minX - 6))
        return CGRect(
            x: frame.minX + 4,
            y: frame.minY + 30,
            width: width,
            height: max(20, frame.height - 60)
        )
    }

    @MainActor
    private func gutterRect(leftOf element: XCUIElement, width: CGFloat) -> CGRect {
        let frame = element.frame
        return CGRect(
            x: frame.minX - width,
            y: frame.minY,
            width: width - 2,
            height: max(4, frame.height)
        )
    }

    @MainActor
    private func assertLegible(
        _ element: XCUIElement,
        in window: XCUIElement,
        appearance: Appearance,
        description: String,
        minimumContrast: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let pixels = try XCTUnwrap(WindowPixels(of: window), file: file, line: line)
        let surrounding = element.frame.insetBy(dx: -12, dy: -12)
        let background = try XCTUnwrap(
            pixels.medianSample(in: surrounding),
            file: file,
            line: line
        )

        switch appearance {
        case .light:
            XCTAssertGreaterThan(
                background.gray,
                0.5,
                "\(appearance.rawValue): \(description) should sit on a light surface.",
                file: file,
                line: line
            )
        case .dark:
            XCTAssertLessThan(
                background.gray,
                0.5,
                "\(appearance.rawValue): \(description) should sit on a dark surface.",
                file: file,
                line: line
            )
        }
        let contrast = pixels.inkContrast(in: element.frame, against: background)
        attachMeasurements(
            ["surface gray: \(background.gray)", "contrast: \(contrast)"],
            named: "\(description) — \(appearance.rawValue)"
        )
        XCTAssertGreaterThanOrEqual(
            contrast,
            minimumContrast,
            "\(appearance.rawValue): \(description) should stay readable.",
            file: file,
            line: line
        )
    }

    /// Records the measured values a criterion was judged on, so a reviewer can see the
    /// evidence rather than only a pass or a failure.
    private func attachMeasurements(_ measurements: [String], named name: String) {
        let attachment = XCTAttachment(string: measurements.joined(separator: "\n"))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Reads the current system appearance and confirms the test can be driven.
    ///
    /// The test runner needs Automation access to change the setting by itself. Where
    /// that is unavailable, the criterion stays verifiable through assistance:
    /// `Scripts/appearance-test-host.sh` runs the suite from a terminal that already
    /// has that access and answers the test's requests, and a person can also make the
    /// change when prompted. Without either, the test reports the limitation and skips,
    /// which is a recorded gap, never a pass.
    private func requireSystemAppearanceControl() throws -> Bool {
        if SystemAppearance.canChangeAppearanceDirectly() || SystemAppearance.isAssisted {
            return SystemAppearance.isDarkMode()
        }
        throw XCTSkip(
            """
            This machine did not allow the test runner to change the system appearance, \
            so the real light/dark switch could not be exercised automatically: \
            \(SystemAppearance.lastFailureDescription ?? "Automation was refused"). \
            Run the suite through Scripts/appearance-test-host.sh, which drives the \
            switches from a terminal that already has Automation access and always \
            restores the setting, grant the test runner Automation access, or re-run \
            with TEST_RUNNER_NEOMD_UI_TEST_ASSISTED_APPEARANCE=1 and switch appearance \
            in System Settings when prompted. Until then this criterion has to be \
            verified by hand.
            """
        )
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

// MARK: - System appearance control

/// Reads and writes the real macOS light/dark setting.
///
/// A test runner is usually not allowed to send Apple events to System Events, so the
/// change can also be delegated. `Scripts/appearance-test-host.sh` runs the suite from a
/// terminal that already has Automation access and answers this runner's requests;
/// without a host controller, a person can make the change when prompted.
///
/// The handshake is deliberately asymmetric, because the UI test runner is sandboxed: it
/// carries a read-only exception for the file system and can write only inside its own
/// container, so it *asks* on standard output with a marker line the controller greps
/// for, and the controller *answers* with a file this side only has to read. Neither
/// side has to guess what was asked for or whether it happened, and no path is trusted
/// until the real setting has been read back.
private enum SystemAppearance {
    enum Failure: LocalizedError {
        case notPermitted(String)
        case notObserved(String)
        case notRestored(String)

        var errorDescription: String? {
            switch self {
            case .notPermitted(let message):
                "the system appearance could not be changed: \(message)"
            case .notObserved(let message):
                message
            case .notRestored(let message):
                message
            }
        }
    }

    static nonisolated(unsafe) private(set) var lastFailureDescription: String?
    static nonisolated(unsafe) private var requestCount = 0

    /// The line a host controller greps its build output for, followed by the request
    /// number, `Dark` or `Light`, and a terminator so a half-flushed line cannot match.
    static let requestMarker = "NEOMD-APPEARANCE-REQUEST"

    /// The directory a host controller leaves its answers in.
    static var controlDirectory: URL? {
        guard let path = ProcessInfo.processInfo.environment[
            "NEOMD_UI_TEST_APPEARANCE_CONTROL_DIR"
        ], !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Whether a host controller is answering this run's requests.
    static var isHostControlled: Bool { controlDirectory != nil }

    static var isAssisted: Bool {
        ProcessInfo.processInfo.environment["NEOMD_UI_TEST_ASSISTED_APPEARANCE"] == "1"
            || isHostControlled
    }

    /// How long assistance is waited for: a host controller answers in moments, a
    /// person needs time to find the setting.
    private static var assistanceTimeout: TimeInterval { isHostControlled ? 120 : 180 }

    /// Reading the setting needs no permission: the global domain records it, and an
    /// unset value is the light appearance. The value is re-synchronized on every read
    /// so a change made while the test waits is seen.
    static func isDarkMode() -> Bool {
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        let style = CFPreferencesCopyAppValue(
            "AppleInterfaceStyle" as CFString,
            kCFPreferencesAnyApplication
        ) as? String
        return style?.lowercased().hasPrefix("dark") ?? false
    }

    static func canChangeAppearanceDirectly() -> Bool {
        do {
            _ = try run(
                "tell application \"System Events\" to tell appearance preferences to get dark mode"
            )
            return true
        } catch {
            lastFailureDescription = "\(error)"
            return false
        }
    }

    /// Changes the real setting, and returns only once the change has been read back.
    static func setDarkMode(_ isDark: Bool) throws {
        guard isDarkMode() != isDark else { return }

        do {
            _ = try run(
                "tell application \"System Events\" to tell appearance preferences to set dark mode to \(isDark)"
            )
            if waitForDarkMode(isDark, timeout: 10) { return }
            lastFailureDescription = """
                the setting was accepted but never became \(Self.name(isDark))
                """
        } catch {
            lastFailureDescription = "\(error)"
        }

        guard isAssisted else {
            throw Failure.notPermitted(lastFailureDescription ?? "Automation was refused")
        }

        if let controlDirectory {
            try requestFromHost(isDark, in: controlDirectory, timeout: assistanceTimeout)
        } else {
            // Wait for a person to make the change in System Settings.
            print(
                """
                [NeoMD appearance test] Switch macOS appearance to \
                \(Self.name(isDark)) in System Settings now.
                """
            )
            _ = waitForDarkMode(isDark, timeout: assistanceTimeout)
        }

        guard isDarkMode() == isDark else {
            throw Failure.notObserved(
                "No system appearance change to \(Self.name(isDark)) was observed."
            )
        }
    }

    /// Puts the setting back to what a test found, and insists on seeing it happen.
    ///
    /// A restoration is not optional cleanup: leaving a tester's Mac in the appearance a
    /// failed test switched it to is a defect of the test. Every path the run was
    /// allowed to use is tried again here, and an unverified result is an error the
    /// caller has to surface.
    static func restore(to original: Bool) throws {
        guard isDarkMode() != original else { return }

        var underlyingDescription: String?
        do {
            try setDarkMode(original)
        } catch {
            underlyingDescription = error.localizedDescription
                .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        }

        guard isDarkMode() != original else { return }
        throw Failure.notRestored(
            """
            This test changed the Mac's appearance to \(name(!original)) and could not \
            put it back to \(name(original))\(underlyingDescription.map { ": \($0)" } ?? ""). \
            Set it in System Settings > Appearance.
            """
        )
    }

    private static func name(_ isDark: Bool) -> String { isDark ? "Dark" : "Light" }

    /// Polls the real setting until it matches, so a change is never assumed.
    private static func waitForDarkMode(_ isDark: Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if isDarkMode() == isDark { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return isDarkMode() == isDark
    }

    /// Asks the host controller for a change and waits for its explicit answer.
    ///
    /// The request is a single marker line on standard output, because this runner is
    /// sandboxed and cannot write into the controller's directory. It is not free-form
    /// prose: the controller matches the marker, a request number and a terminator, so a
    /// partially flushed line is never acted on and the wording of the surrounding log
    /// does not matter. The answer comes back as a file, which the runner is allowed to
    /// read, so a controller that reports a failure fails the test immediately instead
    /// of timing out.
    private static func requestFromHost(
        _ isDark: Bool,
        in directory: URL,
        timeout: TimeInterval
    ) throws {
        requestCount += 1
        let identifier = requestCount
        let response = directory.appendingPathComponent("response-\(identifier)")

        print(
            """
            [NeoMD appearance test] Asking the host controller for \(name(isDark)) \
            (request-\(identifier)).
            \(requestMarker) \(identifier) \(name(isDark)) END
            """
        )
        fflush(stdout)

        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let answer = try? String(contentsOf: response, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines) {
                guard answer.hasPrefix("ok") else {
                    throw Failure.notPermitted(
                        "the host controller could not switch to \(name(isDark)): \(answer)"
                    )
                }
                guard waitForDarkMode(isDark, timeout: 10) else {
                    throw Failure.notObserved(
                        """
                        The host controller answered \(answer) for request-\(identifier), \
                        but the setting is still \(name(isDarkMode())).
                        """
                    )
                }
                return
            }
            if isDarkMode() == isDark { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        throw Failure.notObserved(
            """
            The host controller did not answer request-\(identifier) for \
            \(name(isDark)) within \(Int(timeout))s.
            """
        )
    }

    @discardableResult
    private static func run(_ script: String) throws -> String {
        do {
            return try runInProcess(script)
        } catch {
            do {
                return try runThroughOsascript(script)
            } catch let fallbackError {
                throw Failure.notPermitted(
                    "NSAppleScript: \(error); osascript: \(fallbackError)"
                )
            }
        }
    }

    private static func runInProcess(_ source: String) throws -> String {
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw Failure.notPermitted("the script could not be compiled")
        }
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            throw Failure.notPermitted("\(errorInfo)")
        }
        return result.stringValue ?? ""
    }

    private static func runThroughOsascript(_ script: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let output = Pipe()
        let errorOutput = Pipe()
        process.standardOutput = output
        process.standardError = errorOutput
        try process.run()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorOutput.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw Failure.notPermitted(
                String(decoding: errorData, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return String(decoding: outputData, as: UTF8.self)
    }
}

// MARK: - Pixel sampling

/// One sampled sRGB pixel.
private struct PixelSample {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    /// Mean component value, used to compare how light two surfaces are.
    var gray: CGFloat { (red + green + blue) / 3 }

    /// WCAG relative luminance, used for contrast ratios.
    var relativeLuminance: CGFloat {
        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    func distance(to other: PixelSample) -> CGFloat {
        let deltaRed = red - other.red
        let deltaGreen = green - other.green
        let deltaBlue = blue - other.blue
        return sqrt(
            (deltaRed * deltaRed) + (deltaGreen * deltaGreen) + (deltaBlue * deltaBlue)
        )
    }

    static func contrastRatio(_ first: PixelSample, _ second: PixelSample) -> CGFloat {
        let lighter = max(first.relativeLuminance, second.relativeLuminance)
        let darker = min(first.relativeLuminance, second.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

/// A window screenshot addressable in the screen-point coordinates XCUITest reports.
///
/// Every pixel of a requested region is read. Text strokes are thin, so a sampled
/// subset can miss the glyph cores entirely and make a legible page look blank.
private struct WindowPixels {
    private let width: Int
    private let height: Int
    private let pixels: [UInt8]
    private let isTopDown: Bool
    private let windowFrame: CGRect
    private let scaleX: CGFloat
    private let scaleY: CGFloat

    @MainActor
    init?(of window: XCUIElement) {
        let frame = window.frame
        guard frame.width > 1, frame.height > 1 else { return nil }
        guard let cgImage = window.screenshot().image.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else { return nil }

        // Redraw into a buffer whose color space and channel order are known, rather
        // than guessing at the screenshot's native layout.
        width = cgImage.width
        height = cgImage.height
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drew = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: cgImage.width,
                height: cgImage.height,
                bitsPerComponent: 8,
                bytesPerRow: cgImage.width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            context.draw(
                cgImage,
                in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
            )
            return true
        }
        guard drew else { return nil }
        pixels = buffer

        windowFrame = frame
        scaleX = CGFloat(width) / frame.width
        scaleY = CGFloat(height) / frame.height

        // The redrawn buffer's channel order is fixed by the context's format, but
        // which end of it holds the top of the window is not, so it is measured: the
        // orientation whose row brightness profile matches the always-correct accessor
        // is the right one. A window's rows differ strongly from top to bottom, so the
        // comparison is decisive without depending on exact color values.
        let reference = NSBitmapImageRep(cgImage: cgImage)
        isTopDown = Self.mismatch(buffer, width: width, height: height, against: reference, topDown: true)
            <= Self.mismatch(buffer, width: width, height: height, against: reference, topDown: false)
    }

    /// Mean difference between a redrawn buffer's row brightness and the screenshot's.
    private static func mismatch(
        _ pixels: [UInt8],
        width: Int,
        height: Int,
        against reference: NSBitmapImageRep,
        topDown: Bool
    ) -> CGFloat {
        let stepX = max(1, width / 24)
        let stepY = max(1, height / 24)
        var total: CGFloat = 0
        var rows = 0

        for y in stride(from: 0, to: height, by: stepY) {
            var referenceTotal: CGFloat = 0
            var bufferTotal: CGFloat = 0
            var count = 0
            for x in stride(from: 0, to: width, by: stepX) {
                guard let color = reference.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)
                else { continue }
                referenceTotal += (color.redComponent + color.greenComponent + color.blueComponent) / 3

                let row = topDown ? y : (height - 1 - y)
                let offset = (row * width * 4) + (x * 4)
                bufferTotal += CGFloat(
                    Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])
                ) / (3 * 255)
                count += 1
            }
            guard count > 0 else { continue }
            total += abs((referenceTotal - bufferTotal) / CGFloat(count))
            rows += 1
        }
        return rows > 0 ? total / CGFloat(rows) : .greatestFiniteMagnitude
    }

    private func sample(x: Int, y: Int) -> PixelSample? {
        let row = isTopDown ? y : (height - 1 - y)
        guard row >= 0, row < height, x >= 0, x < width else { return nil }
        let offset = (row * width * 4) + (x * 4)
        return PixelSample(
            red: CGFloat(pixels[offset]) / 255,
            green: CGFloat(pixels[offset + 1]) / 255,
            blue: CGFloat(pixels[offset + 2]) / 255
        )
    }

    private func pixelBounds(for rect: CGRect) -> (x: Range<Int>, y: Range<Int>)? {
        let minX = Int(((rect.minX - windowFrame.minX) * scaleX).rounded(.down))
        let maxX = Int(((rect.maxX - windowFrame.minX) * scaleX).rounded(.up))
        let minY = Int(((rect.minY - windowFrame.minY) * scaleY).rounded(.down))
        let maxY = Int(((rect.maxY - windowFrame.minY) * scaleY).rounded(.up))
        let clampedX = max(0, minX)..<min(width, max(0, maxX))
        let clampedY = max(0, minY)..<min(height, max(0, maxY))
        guard !clampedX.isEmpty, !clampedY.isEmpty else { return nil }
        return (clampedX, clampedY)
    }

    private func forEachPixel(in rect: CGRect, _ body: (PixelSample) -> Void) {
        guard let bounds = pixelBounds(for: rect) else { return }
        for y in bounds.y {
            for x in bounds.x {
                guard let sample = sample(x: x, y: y) else { continue }
                body(sample)
            }
        }
    }

    /// The median-brightness color of a region, a stable estimate of its surface.
    func medianSample(in rect: CGRect) -> PixelSample? {
        var histogram = [Int](repeating: 0, count: 256)
        var total = 0
        forEachPixel(in: rect) { sample in
            histogram[Self.bucket(for: sample.gray)] += 1
            total += 1
        }
        guard total > 0 else { return nil }

        var seen = 0
        var medianBucket = 0
        for (bucket, count) in histogram.enumerated() {
            seen += count
            if seen >= total / 2 {
                medianBucket = bucket
                break
            }
        }
        return averageColor(in: rect) { Self.bucket(for: $0.gray) == medianBucket }
    }

    /// The color of the pixels that depart most from a surface: the rendered ink.
    ///
    /// The cutoff is relative to the strongest departure in the region rather than a
    /// fixed share of it, so a short message inside a large window measures the same as
    /// a dense paragraph, and antialiased edges do not dilute the result. A region with
    /// nothing drawn on it reports the surface itself, which scores no contrast.
    func ink(in rect: CGRect, against background: PixelSample) -> PixelSample? {
        var histogram = [Int](repeating: 0, count: 256)
        var total = 0
        forEachPixel(in: rect) { sample in
            histogram[Self.bucket(for: sample.distance(to: background) / Self.maximumDistance)] += 1
            total += 1
        }
        guard total > 0 else { return nil }

        // Ignore a few extreme pixels so a stray artifact cannot define ink, but keep
        // the allowance absolute: a short message covers well under a percent of a
        // large window, and a proportional allowance would discard all of its ink.
        let outliers = min(max(0, total / 200), 64)
        var seen = 0
        var referenceBucket = 0
        for bucket in stride(from: 255, through: 0, by: -1) {
            seen += histogram[bucket]
            if seen > outliers {
                referenceBucket = bucket
                break
            }
        }
        let reference = (CGFloat(referenceBucket) / 255) * Self.maximumDistance
        let cutoff = reference * 0.9
        guard cutoff > 0.02 else { return background }
        return averageColor(in: rect) { $0.distance(to: background) >= cutoff } ?? background
    }

    /// The contrast ratio between a region's ink and the surface behind it.
    func inkContrast(in rect: CGRect, against background: PixelSample) -> CGFloat {
        guard let ink = ink(in: rect, against: background) else { return 0 }
        return PixelSample.contrastRatio(ink, background)
    }

    /// How far the most distinct pixel of a region departs from a surface.
    func maximumGrayDelta(in rect: CGRect, from background: PixelSample) -> CGFloat {
        var strongest: CGFloat = 0
        forEachPixel(in: rect) { sample in
            strongest = max(strongest, abs(sample.gray - background.gray))
        }
        return strongest
    }

    /// The strongest row-average departure from a surface, which finds thin rules.
    func maximumRowGrayDelta(in rect: CGRect, from background: PixelSample) -> CGFloat {
        guard let bounds = pixelBounds(for: rect) else { return 0 }
        var strongest: CGFloat = 0
        for y in bounds.y {
            var total: CGFloat = 0
            var count = 0
            for x in bounds.x {
                guard let sample = sample(x: x, y: y) else { continue }
                total += sample.gray
                count += 1
            }
            guard count > 0 else { continue }
            strongest = max(strongest, abs((total / CGFloat(count)) - background.gray))
        }
        return strongest
    }

    /// The longest unbroken horizontal run of marked pixels in any row, as a fraction
    /// of the marked content's own width.
    ///
    /// This separates a continuous rule, such as an underline that spans a whole label
    /// including the spaces between its words, from letterforms, which always leave
    /// gaps. Measuring against the marked extent rather than the requested rectangle
    /// keeps the result independent of how wide a view's layout frame happens to be.
    func maximumContiguousRunFraction(
        in rect: CGRect,
        differingFrom background: PixelSample,
        byAtLeast threshold: CGFloat
    ) -> CGFloat {
        guard let bounds = pixelBounds(for: rect) else { return 0 }

        var markedMinX = Int.max
        var markedMaxX = Int.min
        var longestRun = 0
        for y in bounds.y {
            var run = 0
            for x in bounds.x {
                guard let sample = sample(x: x, y: y),
                      sample.distance(to: background) >= threshold else {
                    run = 0
                    continue
                }
                run += 1
                longestRun = max(longestRun, run)
                markedMinX = min(markedMinX, x)
                markedMaxX = max(markedMaxX, x)
            }
        }

        let markedWidth = markedMaxX - markedMinX + 1
        guard markedWidth > 1 else { return 0 }
        return min(1, CGFloat(longestRun) / CGFloat(markedWidth))
    }

    /// The bounding rectangle, in screen points, of the pixels that changed between two
    /// captures of the same region.
    func changedRegion(
        from other: WindowPixels,
        in rect: CGRect,
        threshold: CGFloat = 0.08
    ) -> CGRect? {
        guard let bounds = pixelBounds(for: rect) else { return nil }
        var minX = Int.max, maxX = Int.min, minY = Int.max, maxY = Int.min
        for y in bounds.y {
            for x in bounds.x {
                guard let new = sample(x: x, y: y),
                      let old = other.sample(x: x, y: y),
                      new.distance(to: old) >= threshold else { continue }
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard minX <= maxX, minY <= maxY else { return nil }
        return CGRect(
            x: windowFrame.minX + (CGFloat(minX) / scaleX),
            y: windowFrame.minY + (CGFloat(minY) / scaleY),
            width: max(1, CGFloat(maxX - minX) / scaleX),
            height: max(1, CGFloat(maxY - minY) / scaleY)
        )
    }

    private func averageColor(
        in rect: CGRect,
        where isIncluded: (PixelSample) -> Bool
    ) -> PixelSample? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var count = 0
        forEachPixel(in: rect) { sample in
            guard isIncluded(sample) else { return }
            red += sample.red
            green += sample.green
            blue += sample.blue
            count += 1
        }
        guard count > 0 else { return nil }
        return PixelSample(
            red: red / CGFloat(count),
            green: green / CGFloat(count),
            blue: blue / CGFloat(count)
        )
    }

    private static let maximumDistance = sqrt(3.0) as CGFloat

    private static func bucket(for value: CGFloat) -> Int {
        min(255, max(0, Int((value * 255).rounded())))
    }
}
