import AppKit
import XCTest

final class DocumentLinkNavigationUITests: XCTestCase {
    private var directory: URL!
    private var documentURL: URL!
    private var originalData: Data!
    private var originalDate: Date!

    override func setUpWithError() throws {
        continueAfterFailure = false
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("NeoMD-Links-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        documentURL = directory.appendingPathComponent("links.md")
        originalData = Data(Self.fixture.utf8)
        try originalData.write(to: documentURL)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)], ofItemAtPath: documentURL.path)
        originalDate = try FileManager.default.attributesOfItem(atPath: documentURL.path)[.modificationDate] as? Date
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
        if let documentURL {
            XCTAssertEqual(try Data(contentsOf: documentURL), originalData)
            XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: documentURL.path)[.modificationDate] as? Date, originalDate)
        }
        if let directory { try FileManager.default.removeItem(at: directory) }
    }

    static var fixture: String {
        func spacer(_ section: String) -> String {
            (1...18).map { "\(section) spacer \($0). Ordinary reading content with no links." }.joined(separator: "\n\n")
        }
        return """
        [First](#duplicate) [Second](#duplicate-1) [Formatted](#bold-code) [Unicode](#café-日本語) [Custom](#custom) [Inline](#inline) [End](#end) [Missing](#nowhere)

        Reference one[^x] and repeated[^x]. Reference two[^y]. Reference three[^z].

        \\[^x]

        ```
        [^literal]: stays code
        ```

        > - [ ] Quoted pending

        \(spacer("Intro"))

        # Duplicate

        [Back first](#)

        \(spacer("First"))

        # Duplicate

        [Back second](#)

        \(spacer("Second"))

        # **Bold** `code`

        [Back formatted](#)

        \(spacer("Formatted"))

        # Café 日本語

        [Back Unicode](#)

        \(spacer("Unicode"))

        <a id="custom"></a>

        # Custom destination

        [Back custom](#)

        Paragraph <a name="inline">inline destination</a> with [Back inline](#).

        \(spacer("Custom"))

        [^x]: SingleToken
        [^y]: Structured note first paragraph.

            Second note paragraph.

            - Note list item.

        > [^z]: Quoted definition note.

        [^unused]: UNUSED HIDDEN NOTE

        <a id="end"></a>
        """
    }

    @MainActor private func open(appearance: String = "Light", firstLink: String? = "First") async throws -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["NEOMD_UI_TEST_APPEARANCE"] = appearance
        app.launch()
        app.activate()
        let running = try XCTUnwrap(NSWorkspace.shared.frontmostApplication)
        XCTAssertEqual(running.bundleIdentifier, "io.neomd.NeoMD")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.allowsRunningApplicationSubstitution = false
        configuration.createsNewApplicationInstance = false
        _ = try await NSWorkspace.shared.open([documentURL], withApplicationAt: try XCTUnwrap(running.bundleURL), configuration: configuration)
        let window = app.windows["links.md"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        if let firstLink {
            XCTAssertTrue(window.links[firstLink].waitForExistence(timeout: 10), window.debugDescription)
        }
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

    @MainActor private func text(_ value: String, in window: XCUIElement) -> XCUIElement {
        window.staticTexts.matching(NSPredicate(format: "value == %@ OR value == %@", value, value + "\n")).firstMatch
    }

    @MainActor private func assertAtTop(_ element: XCUIElement, window: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let scroll = window.scrollViews["DocumentReaderScrollView"]
        let landed = wait { element.exists && abs(element.frame.minY - scroll.frame.minY) < 10 }
        XCTAssertTrue(landed, window.debugDescription, file: file, line: line)
    }

    @MainActor private func replaceFixture(_ source: String) throws {
        originalData = Data(source.utf8)
        try originalData.write(to: documentURL)
        try FileManager.default.setAttributes([.modificationDate: originalDate!], ofItemAtPath: documentURL.path)
    }

    @MainActor private func resize(_ window: XCUIElement, to size: CGSize) {
        let current = window.frame.size
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
            .withOffset(CGVector(dx: -2, dy: -2))
        corner.press(forDuration: 0.2, thenDragTo: corner.withOffset(
            CGVector(dx: size.width - current.width, dy: size.height - current.height)))
        XCTAssertTrue(wait { abs(window.frame.width - size.width) <= 3 && abs(window.frame.height - size.height) <= 3 })
    }

    @MainActor private func capture(_ window: XCUIElement, name: String) {
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Actual file, actual cmark nesting, normal document opening and native events.
    /// Window-relative coordinates avoid XCUIApplication's nonfinite AX frame.
    @MainActor func testDeepQuoteFileNavigationResizeAndReadOnly() async throws {
        let source = String(repeating: "> ", count: 50000)
            + "<a id='deep'></a>Deep retained [Jump target](#target)\n\n"
            + (1...30).map { "Deep spacer \($0)." }.joined(separator: "\n\n")
            + "\n\n# Target\n\n[Back deep](#deep)\n\n"
            + (1...20).map { "Target spacer \($0)." }.joined(separator: "\n\n")
        try replaceFixture(source)
        for appearance in ["Light", "Dark"] {
            let (app, window) = try await open(appearance: appearance, firstLink: "Jump target")
            for width in [900.0, 480.0, 900.0] {
                resize(window, to: CGSize(width: width, height: 760))
                // Resize restoration preserves a reading fraction, not necessarily
                // the first line. Use a real reader scroll interaction to return
                // to the top; Command-Home can be consumed by native Text focus.
                let scroll = window.scrollViews["DocumentReaderScrollView"]
                scroll.scroll(byDeltaX: 0, deltaY: 10000)
                let link = window.links["Jump target"]
                let leaf = text("Deep retained Jump target", in: window)
                XCTAssertTrue(wait { leaf.exists && link.frame.minY >= scroll.frame.minY - 1
                    && link.frame.maxY < scroll.frame.maxY }, "Deep link must be visible before mouse dispatch: link=\(link.frame), viewport=\(scroll.frame)")
                // AX Text bounds measure glyphs, not the proposed reading column.
                // The hosting/numeric tests assert the >=R column-width contract.
                XCTAssertGreaterThan(leaf.frame.width, 0)
                XCTAssertGreaterThanOrEqual(leaf.frame.minX, scroll.frame.minX)
                XCTAssertLessThanOrEqual(leaf.frame.maxX, scroll.frame.maxX)
                XCTAssertTrue(window.descendants(matching: .any).matching(
                    NSPredicate(format: "label CONTAINS %@", "50000 · quote indentation compressed")).firstMatch.exists,
                    window.debugDescription)
                capture(window, name: "Actual 50000 quotes — \(appearance) — \(Int(width))")
                // Clear focus, then dispatch a real mouse event at the visible link.
                scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.1)).click()
                let frame = link.frame
                window.coordinate(withNormalizedOffset: .zero).withOffset(
                    CGVector(dx: frame.midX - window.frame.minX, dy: frame.midY - window.frame.minY)).click()
                assertAtTop(window.staticTexts["Target"], window: window)
                window.links["Back deep"].click()
                // Native Text's glyph AX rectangle extends one point above its marker.
                XCTAssertTrue(wait { link.frame.minY >= scroll.frame.minY - 1 && link.frame.maxY < scroll.frame.maxY },
                              "Backlink must land on the actual deep paragraph: link=\(link.frame), viewport=\(scroll.frame)")
            }
            for key in [XCUIKeyboardKey.return, .space] {
                let scroll = window.scrollViews["DocumentReaderScrollView"]
                scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.1)).click()
                let block = window.descendants(matching: .any)["MarkdownLinkBlock-50000"]
                var selected = false
                for _ in 0..<5 {
                    app.typeKey(.tab, modifierFlags: [.option])
                    selected = block.label == "Link 1 of 1: Jump target"
                    if selected { break }
                }
                XCTAssertTrue(selected, window.debugDescription)
                app.typeKey(key, modifierFlags: [])
                assertAtTop(window.staticTexts["Target"], window: window)
                app.typeKey(.escape, modifierFlags: [])
                window.links["Back deep"].click()
            }
            XCTAssertEqual(try Data(contentsOf: documentURL), originalData)
            XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: documentURL.path)[.modificationDate] as? Date, originalDate)
            app.terminate()
        }
    }

    /// Mixed cmark input opened from disk, not an injected render arena.
    @MainActor func testMixedContainerFileAXOrderAndNativeActions() async throws {
        let quote = String(repeating: "> ", count: 40)
        let source = [
            quote + "7. [x] Mixed completed [Mixed jump](#mixed-target)",
            quote,
            quote + "   Mixed adjacent continuation.",
            quote,
            quote + "8. [ ] Mixed pending.",
            "", "# Mixed target", "", "Mixed reference[^m].", "",
            "[^m]: Mixed note first.", "",
            "    " + quote + "- [ ] Mixed note task.",
            "    " + quote,
            "    " + quote + "  Mixed note adjacent.",
            "", "    Mixed note last."
        ].joined(separator: "\n")
        try replaceFixture(source)
        for appearance in ["Light", "Dark"] {
            let (app, window) = try await open(appearance: appearance, firstLink: "Mixed jump")
            for width in [900.0, 480.0] {
                resize(window, to: CGSize(width: width, height: 760))
                let scroll = window.scrollViews["DocumentReaderScrollView"]
                scroll.scroll(byDeltaX: 0, deltaY: 10000)
                let orderedText = ["Mixed completed Mixed jump", "Mixed adjacent continuation.", "Mixed pending.",
                                   "Mixed reference1.", "Mixed note first.", "Mixed note task.",
                                   "Mixed note adjacent.", "Mixed note last. ↩"]
                let hierarchy = XCTAttachment(string: window.debugDescription)
                hierarchy.name = "Mixed native AX hierarchy — \(appearance) — \(Int(width))"
                hierarchy.lifetime = .keepAlways
                add(hierarchy)
                // Descendant queries group native link-bearing Text at a deeper
                // AX level. Walk immediate children in tree order instead of
                // treating the flat query's bound indexes as reading order.
                var pending = [window]
                var snapshot: [XCUIElement] = []
                while let element = pending.popLast() {
                    if element.elementType == .staticText { snapshot.append(element) }
                    pending.append(contentsOf: element.children(matching: .any).allElementsBoundByIndex.reversed())
                }
                var previousIndex = -1
                var previousBottom = -CGFloat.infinity
                for value in orderedText {
                    let matches = snapshot.enumerated().filter {
                        ($0.element.value as? String)?.trimmingCharacters(in: .newlines) == value
                    }
                    XCTAssertEqual(matches.count, 1, "Exactly one native AX leaf for \(value): \(window.debugDescription)")
                    let match = try XCTUnwrap(matches.first)
                    XCTAssertGreaterThan(match.offset, previousIndex, "AX source order")
                    guard match.offset > previousIndex else { throw NSError(domain: "MixedAXOrder", code: 1) }
                    XCTAssertGreaterThanOrEqual(match.element.frame.minY, previousBottom, "Spatial source order")
                    XCTAssertGreaterThanOrEqual(match.element.frame.minX, scroll.frame.minX)
                    XCTAssertLessThanOrEqual(match.element.frame.maxX, scroll.frame.maxX)
                    previousIndex = match.offset
                    previousBottom = match.element.frame.maxY
                }
                XCTAssertEqual(window.images.matching(NSPredicate(format: "label == %@", "Completed task")).count, 1)
                XCTAssertEqual(window.images.matching(NSPredicate(format: "label == %@", "Incomplete task")).count, 2)
                for (id, value) in [(40, "Mixed completed Mixed jump"), (43, "Mixed pending."), (89, "Mixed note task.")] {
                    let marker = window.images["MarkdownTaskMarker-\(id)"]
                    XCTAssertEqual(window.images.matching(identifier: "MarkdownTaskMarker-\(id)").count, 1)
                    XCTAssertLessThan(marker.frame.maxY, text(value, in: window).frame.minY)
                }
                let context = window.staticTexts.matching(NSPredicate(
                    format: "value == %@ OR value == %@", "Depth 41 · list item · indentation compressed",
                    "Depth 41 · list item · indentation compressed\n"))
                XCTAssertEqual(context.count, 2, window.debugDescription)
                XCTAssertTrue(window.descendants(matching: .any).matching(NSPredicate(
                    format: "label CONTAINS %@", "–40 · quote indentation compressed")).firstMatch.exists)
                capture(window, name: "Actual mixed source order — \(appearance) — \(Int(width))")
                let link = window.links["Mixed jump"]
                XCTAssertTrue(wait { link.frame.minY >= scroll.frame.minY - 1 && link.frame.maxY < scroll.frame.maxY })
                scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.1)).click()
                let frame = link.frame
                window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: frame.midX - window.frame.minX, dy: frame.midY - window.frame.minY)).click()
                XCTAssertTrue(wait { self.text("Mixed reference1.", in: window).isHittable })
                window.links["1"].click()
                XCTAssertTrue(wait { window.links["↩"].exists })
                let noteValues = ["Mixed note first.", "Mixed note task.", "Mixed note adjacent.", "Mixed note last. ↩"]
                for value in noteValues { XCTAssertTrue(text(value, in: window).exists, window.debugDescription) }
                XCTAssertTrue(window.descendants(matching: .any).matching(NSPredicate(
                    format: "label == %@", "Footnote 1")).firstMatch.exists)
                capture(window, name: "Actual mixed footnote — \(appearance) — \(Int(width))")
                window.links["↩"].click()
                XCTAssertTrue(wait { self.text("Mixed reference1.", in: window).isHittable })
            }
            XCTAssertEqual(try Data(contentsOf: documentURL), originalData)
            XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: documentURL.path)[.modificationDate] as? Date, originalDate)
            app.terminate()
        }
    }

    @MainActor func testHeadingLinksReachDuplicateFormattedAndUnicodeSections() async throws {
        let (_, window) = try await open()
        for (link, heading, back) in [("First", "Duplicate", "Back first"), ("Second", "Duplicate", "Back second"), ("Formatted", "Bold code", "Back formatted"), ("Unicode", "Café 日本語", "Back Unicode")] {
            window.links[link].click()
            if heading == "Duplicate" {
                let duplicates = window.staticTexts.matching(NSPredicate(format: "value == %@ OR value == %@ OR label == %@", heading, heading + "\n", heading))
                let scroll = window.scrollViews["DocumentReaderScrollView"]
                let landed = wait { duplicates.allElementsBoundByIndex.contains { abs($0.frame.minY - scroll.frame.minY) < 10 } }
                XCTAssertTrue(landed, window.debugDescription)
                XCTAssertTrue(window.links[back].isHittable)
            } else { assertAtTop(window.staticTexts[heading], window: window) }
            window.links[back].click()
            XCTAssertTrue(wait { window.links["First"].isHittable })
        }
    }

    @MainActor func testCustomAnchorsNavigateWithoutVisibleMarkup() async throws {
        let (_, window) = try await open()
        window.links["Custom"].click()
        assertAtTop(window.staticTexts["Custom destination"], window: window)
        XCTAssertFalse(window.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "<a ")).firstMatch.exists)
        window.links["Back custom"].click()
        XCTAssertTrue(wait { window.links["Inline"].isHittable })
        window.links["Inline"].click()
        assertAtTop(text("Paragraph inline destination with Back inline.", in: window), window: window)
        window.links["Back inline"].click()
        XCTAssertTrue(wait { window.links["End"].isHittable })
        window.links["End"].click()
        XCTAssertTrue(wait { self.text("SingleToken ↩ ↩ 2", in: window).isHittable }, window.debugDescription)
    }

    @MainActor func testEOFAnchorAndAnchorOnlyDocument() async throws {
        func replaceFixture(_ source: String) throws {
            originalData = Data(source.utf8)
            try originalData.write(to: documentURL)
            try FileManager.default.setAttributes([.modificationDate: originalDate!], ofItemAtPath: documentURL.path)
        }
        try replaceFixture("[Jump end](#end)\n\n" + (1...50).map { "EOF spacer \($0)." }.joined(separator: "\n\n") + "\n\nFinal paragraph.\n\n<a id='end'></a>")
        let (app, window) = try await open(firstLink: "Jump end")
        window.links["Jump end"].click()
        let final = text("Final paragraph.", in: window)
        let scroll = window.scrollViews["DocumentReaderScrollView"]
        XCTAssertTrue(wait { final.isHittable && final.frame.maxY <= scroll.frame.maxY })
        XCTAssertFalse(window.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "<a ")).firstMatch.exists)
        XCTAssertEqual(try Data(contentsOf: documentURL), originalData)
        app.terminate()
        try replaceFixture("<a id='only'></a>")
        let (_, emptyWindow) = try await open(firstLink: nil)
        XCTAssertTrue(emptyWindow.staticTexts["This document is empty."].waitForExistence(timeout: 5))
        XCTAssertFalse(emptyWindow.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "<a ")).firstMatch.exists)
    }

    @MainActor func testFootnoteReferencesAndReturnLinks() async throws {
        let (_, window) = try await open()
        let references = window.links.matching(identifier: "1")
        XCTAssertTrue(references.firstMatch.exists, window.debugDescription)
        references.firstMatch.click()
        XCTAssertTrue(wait { window.links["↩ 2"].isHittable }, window.debugDescription)
        XCTAssertTrue(text("SingleToken ↩ ↩ 2", in: window).exists)
        XCTAssertTrue(text("Structured note first paragraph.", in: window).exists)
        XCTAssertTrue(text("Note list item.", in: window).exists)
        XCTAssertFalse(text("UNUSED HIDDEN NOTE", in: window).exists)
        window.links["↩ 2"].click()
        assertAtTop(text("Reference one1 and repeated1. Reference two2. Reference three3.", in: window), window: window)
    }

    @MainActor func testMissingDestinationKeepsDocumentUsable() async throws {
        let (app, window) = try await open()
        let before = window.links["First"].frame
        let prose = text("Intro spacer 1. Ordinary reading content with no links.", in: window)
        let beforeProse = prose.frame
        window.links["Missing"].click()
        let notice = window.staticTexts["DocumentLinkNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 3))
        XCTAssertEqual(prose.frame, beforeProse)
        // Native focus changes an attributed link's AX bounds by one point, not scroll position.
        XCTAssertEqual(window.links["First"].frame.minY, before.minY, accuracy: 1)
        XCTAssertEqual(window.sheets.count, 0)
        XCTAssertEqual(app.dialogs.count, 0)
        app.typeKey(.pageDown, modifierFlags: [])
        XCTAssertTrue(wait { prose.frame != beforeProse })
        XCTAssertTrue(wait { !notice.exists })
    }

    @MainActor func testKeyboardFocusAndActivationOfInternalLinks() async throws {
        for appearance in ["Light", "Dark"] {
            let (app, window) = try await open(appearance: appearance)
            let scroll = window.scrollViews["DocumentReaderScrollView"]
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.1)).click()
            let index = window.descendants(matching: .any)["MarkdownLinkBlock-0"]
            var selected = false
            for _ in 0..<5 {
                app.typeKey(.tab, modifierFlags: [.option])
                app.typeKey(.rightArrow, modifierFlags: [])
                selected = wait { index.label.hasPrefix("Link 2 of 8:") || (index.value as? String)?.hasPrefix("Link 2 of 8:") == true }
                if selected { break }
            }
            XCTAssertTrue(selected, window.debugDescription)
            let attachment = XCTAttachment(screenshot: window.screenshot())
            attachment.name = "Link keyboard focus — \(appearance)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.typeKey(.return, modifierFlags: [])
            XCTAssertTrue(wait { window.links["Back second"].isHittable })
            app.typeKey(.escape, modifierFlags: [])
            window.links["Back second"].click()
            XCTAssertTrue(wait { window.links["First"].isHittable })
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.1)).click()
            let referenceBlock = window.descendants(matching: .any)["MarkdownLinkBlock-1"]
            var referenceSelected = false
            for _ in 0..<6 {
                app.typeKey(.tab, modifierFlags: [.option])
                app.typeKey(.rightArrow, modifierFlags: [])
                referenceSelected = referenceBlock.label.hasPrefix("Link 2 of 4:")
                if referenceSelected { break }
            }
            XCTAssertTrue(referenceSelected, window.debugDescription)
            app.typeKey(.space, modifierFlags: [])
            XCTAssertTrue(wait { window.links["↩ 2"].isHittable })
            var returnSelected = false
            for _ in 0..<12 {
                app.typeKey(.tab, modifierFlags: [.option])
                app.typeKey(.rightArrow, modifierFlags: [])
                returnSelected = window.groups.matching(NSPredicate(format: "label == %@", "Link 2 of 2: ↩ 2")).firstMatch.exists
                if returnSelected { break }
            }
            XCTAssertTrue(returnSelected, window.debugDescription)
            app.typeKey(.space, modifierFlags: [])
            let expected = "Reference one1 and repeated1. Reference two2. Reference three3."
            var matches: [XCUIElement] = []
            XCTAssertTrue(wait {
                matches = window.textViews.allElementsBoundByIndex.filter { ($0.value as? String) == expected }
                return matches.count == 1
            }, window.debugDescription)
            XCTAssertEqual(matches.count, 1)
            let reference = try XCTUnwrap(matches.first)
            XCTAssertEqual(reference.value as? String, expected)
            assertAtTop(reference, window: window)
            app.terminate()
        }
    }
}
