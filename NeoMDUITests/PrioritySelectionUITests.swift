import AppKit
import XCTest

final class PrioritySelectionUITests: XCTestCase {
    @MainActor
    private func prepare(_ appearance: String = "Light") async throws -> (PriorityInteractionSupport, PriorityInteractionSupport.Window, [PriorityInteractionSupport.Fragment]) {
        continueAfterFailure = false
        let support = try PriorityInteractionSupport(test: self)
        addTeardownBlock { @MainActor in try await support.cleanup() }
        let url = try support.fixture("m1-priority-e2e/selection.md")
        try support.launch(appearance: appearance)
        let window = try await support.open(url)
        try await support.resize(window, to: CGSize(width: 900, height: 900))
        try await Task.sleep(for: .milliseconds(500))
        return (support, window, try support.oracle())
    }

    @MainActor
    private func fullSpan(_ support: PriorityInteractionSupport, _ window: PriorityInteractionSupport.Window,
                          _ fragments: [PriorityInteractionSupport.Fragment]) throws -> (PriorityInteractionSupport.Point, PriorityInteractionSupport.Point) {
        let first = try support.endpoint("metadata-title-value", offset: 0, fragments: fragments, window: window)
        let last = try support.endpoint("omega", offset: try XCTUnwrap(fragments.last).text.utf16.count, fragments: fragments, window: window)
        // Both pre-action indices are independently established from AX glyphs.
        try support.drag(first, last, window: window)
        try support.assertSelection(first, last, fragments: fragments, window: window)
        return (first, last)
    }

    @MainActor
    func testCrossBlockForwardReverseAndShiftSelection() async throws {
        let (support, window, fragments) = try await prepare()
        let (first, last) = try fullSpan(support, window, fragments)
        try support.drag(last, first, window: window)
        try support.assertSelection(first, last, fragments: fragments, window: window)
        let alpha = try support.endpoint("alpha", offset: 2, fragments: fragments, window: window)
        let four = try support.endpoint("table-row-two-right", offset: 2, fragments: fragments, window: window)
        let heading = try support.endpoint("heading", offset: 7, fragments: fragments, window: window)
        try support.coordinate(alpha.screen, in: window).click()
        try support.assertSelection(alpha, alpha, fragments: fragments, window: window)
        for extent in [four, last, heading] {
            let target = try support.coordinate(extent.screen, in: window)
            XCUIElement.perform(withKeyModifiers: [.shift]) { target.click() }
            try support.assertSelection(alpha, extent, fragments: fragments, window: window)
        }
        _ = try support.capture(window, name: "forward-reverse-shift")
    }

    @MainActor
    func testSharedSelectionActiveAndInactiveLight() async throws { try await sharedActivity("Light") }

    @MainActor
    func testSharedSelectionActiveAndInactiveDark() async throws { try await sharedActivity("Dark") }

    @MainActor
    private func sharedActivity(_ appearance: String) async throws {
        let (support, window, fragments) = try await prepare(appearance)
        let probes = ["metadata-title-value", "alpha", "code", "table-row-one-right"]
        var references: [(String, CGRect, PixelSample, PixelSample)] = []
        for id in probes {
            let fragment = try XCTUnwrap(fragments.first { $0.id == id })
            // First-line range only: avoid line breaks, borders and find attributes.
            let startOffset = id == "code" ? 4 : 0
            let endOffset = min(startOffset + 6, fragment.text.utf16.count)
            let start = try support.endpoint(id, offset: startOffset, fragments: fragments, window: window)
            let end = try support.endpoint(id, offset: endOffset, fragments: fragments, window: window)
            try support.coordinate(start.screen, in: window).click()
            let region = try support.bounds(NSRange(location: start.offset, length: end.offset - start.offset),
                leaf: support.leaf(fragment.text, in: window))
            let before = try support.capture(window, name: "unselected-\(id)")
            try support.drag(start, end, window: window)
            try support.assertSelection(start, end, fragments: fragments, window: window)
            try support.assertReaderFocus(window)
            let after = try support.capture(window, name: "single-leaf-\(id)")
            let plain = try XCTUnwrap(before.medianSample(in: region))
            let selected = try XCTUnwrap(after.medianSample(in: region))
            XCTAssertGreaterThan(selected.distance(to: plain), 0.05, "Nonempty highlight must change this leaf's own background")
            XCTAssertGreaterThanOrEqual(after.inkContrast(in: region, against: selected), 3)
            references.append((id, region, plain, selected))
        }
        let (first, last) = try fullSpan(support, window, fragments)
        try support.assertReaderFocus(window)
        let active = try support.capture(window, name: "shared-active-\(appearance)")
        try assertPixels(active, references: references, support: support, active: true)
        let ranges = try support.assertSelection(first, last, fragments: fragments, window: window)

        // Command-N is the app's normal additional-reader picker. Typing a path is
        // not pasting; never click document text merely to change key-window state.
        let secondURL = try support.fixture("m1-priority-e2e/selection.md", name: "inactive-control.md")
        support.app.typeKey("n", modifierFlags: [.command])
        let panel = support.app.windows["open-panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        support.app.typeKey("g", modifierFlags: [.command, .shift])
        support.app.typeText(secondURL.path)
        support.app.typeKey(.return, modifierFlags: [])
        support.app.typeKey(.return, modifierFlags: [])
        let secondElement = support.app.windows[secondURL.lastPathComponent]
        XCTAssertTrue(secondElement.waitForExistence(timeout: 5))
        let second = PriorityInteractionSupport.Window(element: secondElement,
            ax: try support.axWindow(document: secondURL, frame: secondElement.frame), document: secondURL)
        try support.checkpoint(second, "second-owned-reader")
        try await support.resize(second, to: CGSize(width: 480, height: 400))
        let targetX = window.element.frame.maxX + 10
        let desktopWidth = NSScreen.screens.map { $0.frame.maxX }.max() ?? 0
        guard targetX + second.element.frame.width <= desktopWidth else {
            throw XCTSkip("BLOCKED: display cannot keep first selected regions unobscured beside second owned reader")
        }
        let title = second.element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 12))
        title.press(forDuration: 0.2, thenDragTo: title.withOffset(CGVector(dx: targetX - second.element.frame.minX, dy: 0)))
        XCTAssertFalse(try support.isKey(window))
        XCTAssertTrue(try support.isKey(second))
        XCTAssertEqual(try support.assertSelection(first, last, fragments: fragments, window: window), ranges)
        let inactive = try support.capture(window, name: "shared-inactive-\(appearance)")
        try assertPixels(inactive, references: references, support: support, active: false)
        window.element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 12)).click()
        try support.assertReaderFocus(window)
        XCTAssertEqual(try support.assertSelection(first, last, fragments: fragments, window: window), ranges)
        try assertPixels(support.capture(window, name: "shared-reactivated-\(appearance)"), references: references, support: support, active: true)
    }

    @MainActor
    private func assertPixels(_ pixels: WindowPixels, references: [(String, CGRect, PixelSample, PixelSample)],
                              support: PriorityInteractionSupport, active: Bool) throws {
        var inactiveColors: [PixelSample] = []
        for (id, rect, plain, reference) in references {
            let current = try XCTUnwrap(pixels.medianSample(in: rect))
            support.record("leaf=\(id) rect=\(rect) rgb=\(current) activeReference=\(reference) plain=\(plain) activeDistance=\(current.distance(to: reference)) changed=\(current.distance(to: plain))", name: "pixels")
            XCTAssertGreaterThan(current.distance(to: plain), 0.05)
            XCTAssertGreaterThanOrEqual(pixels.inkContrast(in: rect, against: current), 3)
            if active { XCTAssertLessThanOrEqual(current.distance(to: reference), 0.10) }
            else {
                XCTAssertGreaterThan(current.distance(to: reference), 0.05, "Non-key native selection must visibly become inactive")
                inactiveColors.append(current)
            }
        }
        if let first = inactiveColors.first {
            for color in inactiveColors.dropFirst() { XCTAssertLessThanOrEqual(color.distance(to: first), 0.10) }
        }
    }

    @MainActor
    func testFindHighlightCoexistsWithCrossBlockSelection() async throws {
        let (support, window, fragments) = try await prepare()
        var selectionReferences: [(String, NSRange, PixelSample)] = []
        for (id, lower, upper) in [("alpha", 2, 8), ("code", 22, 28), ("table-row-one-right", 0, 3)] {
            let a = try support.endpoint(id, offset: lower, fragments: fragments, window: window)
            let b = try support.endpoint(id, offset: upper, fragments: fragments, window: window)
            try support.drag(a, b, window: window)
            try support.assertSelection(a, b, fragments: fragments, window: window)
            let literal = try XCTUnwrap(fragments.first { $0.id == id }).text
            let range = NSRange(location: a.offset, length: b.offset - a.offset)
            let rect = try support.bounds(range, leaf: support.leaf(literal, in: window))
            let sample = try XCTUnwrap(support.capture(window, name: "find-active-reference-\(id)").medianSample(in: rect))
            selectionReferences.append((id, range, sample))
            try support.coordinate(a.screen, in: window).click()
        }
        let code = try support.leaf(try XCTUnwrap(fragments.first { $0.id == "code" }).text, in: window)
        let matchRange = NSRange(location: 13, length: 7) // Literal "lantern" in authored code, independent of app search.
        let beforeRegion = try support.bounds(matchRange, leaf: code)
        let plain = try XCTUnwrap(support.capture(window, name: "before-find").medianSample(in: beforeRegion))
        support.app.typeKey("f", modifierFlags: [.command])
        let field = window.element.textFields["DocumentFindField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("lantern")
        let status = window.element.staticTexts["DocumentFindStatus"]
        try await support.wait { status.label == "1 of 2" || status.value as? String == "1 of 2" }
        try await Task.sleep(for: .milliseconds(700))
        let region = try support.bounds(matchRange, leaf: support.leaf(try XCTUnwrap(fragments.first { $0.id == "code" }).text, in: window))
        let highlighted = try XCTUnwrap(support.capture(window, name: "find-before-selection").medianSample(in: region))
        XCTAssertGreaterThan(highlighted.distance(to: plain), 0.05)
        let alpha = try support.endpoint("alpha", offset: 2, fragments: fragments, window: window)
        let four = try support.endpoint("table-row-two-right", offset: 2, fragments: fragments, window: window)
        try support.drag(alpha, four, window: window)
        try support.assertSelection(alpha, four, fragments: fragments, window: window)
        try support.assertReaderFocus(window)
        let shared = try support.capture(window, name: "selection-with-find")
        for (id, range, reference) in selectionReferences {
            let literal = try XCTUnwrap(fragments.first { $0.id == id }).text
            let rect = try support.bounds(range, leaf: support.leaf(literal, in: window))
            let current = try XCTUnwrap(shared.medianSample(in: rect))
            support.record("leaf=\(id) rect=\(rect) activeReference=\(reference) sharedWithFind=\(current) distance=\(current.distance(to: reference))", name: "find-selection-pixels")
            XCTAssertLessThanOrEqual(current.distance(to: reference), 0.10)
            XCTAssertGreaterThanOrEqual(shared.inkContrast(in: rect, against: current), 3)
        }
        let omega = try support.endpoint("omega", offset: 2, fragments: fragments, window: window)
        try support.coordinate(omega.screen, in: window).click()
        let collapsed = try support.assertSelection(omega, omega, fragments: fragments, window: window)
        let after = try XCTUnwrap(support.capture(window, name: "find-after-collapse").medianSample(in: region))
        XCTAssertLessThanOrEqual(after.distance(to: highlighted), 0.10)
        XCTAssertTrue(status.label == "1 of 2" || status.value as? String == "1 of 2")
        field.click()
        support.app.typeKey("a", modifierFlags: [.command])
        XCTAssertEqual(try support.assertSelection(omega, omega, fragments: fragments, window: window), collapsed)
        let application = try support.applicationAX()
        let focused = try XCTUnwrap(support.axElement(support.attribute(application, kAXFocusedUIElementAttribute)))
        XCTAssertEqual(try support.selected(focused).1, "lantern")
    }

    @MainActor
    func testLinkClickVersusDragAndCommandClick() async throws {
        let (support, window, fragments) = try await prepare()
        let linkStart = try support.endpoint("links", offset: 2, fragments: fragments, window: window)
        let omega = try support.endpoint("omega", offset: 2, fragments: fragments, window: window)
        let count = support.app.windows.count
        let headingText = try XCTUnwrap(fragments.first { $0.id == "heading" }).text
        let headingBefore = support.rect(try support.leaf(headingText, in: window)).minY
        try support.drag(linkStart, omega, window: window)
        try support.assertSelection(linkStart, omega, fragments: fragments, window: window)
        XCTAssertEqual(support.app.windows.count, count)
        XCTAssertEqual(support.rect(try support.leaf(headingText, in: window)).minY, headingBefore, accuracy: 2)
        try support.coordinate(linkStart.screen, in: window).click()
        try await support.wait { abs(support.rect(try support.leaf(headingText, in: window)).minY - window.element.scrollViews["DocumentReaderScrollView"].frame.minY) <= 35 }
        XCTAssertEqual(support.app.windows.count, count)
        try support.checkpoint(window, "ordinary-fragment")
        let additional = try support.endpoint("links", offset: 20, fragments: fragments, window: window)
        let beforeSelection = try fragments.map { try support.selected(support.leaf($0.text, in: window)).1 }
        let beforeY = support.rect(try support.leaf(headingText, in: window)).minY
        let target = try support.coordinate(additional.screen, in: window)
        XCUIElement.perform(withKeyModifiers: [.command]) { target.click() }
        try await support.wait { support.app.windows.count == count + 1 }
        XCTAssertEqual(try fragments.map { try support.selected(support.leaf($0.text, in: window)).1 }, beforeSelection)
        XCTAssertEqual(support.rect(try support.leaf(headingText, in: window)).minY, beforeY, accuracy: 2)
        try support.checkpoint(window, "command-click-source-preserved")
        let added = try support.windows().filter { !CFEqual($0, window.ax) }
        XCTAssertEqual(added.count, 1)
        let addedAX = try XCTUnwrap(added.first)
        XCTAssertEqual((support.attribute(addedAX, kAXDocumentAttribute) as? String).flatMap(URL.init(string:))?.standardizedFileURL, window.document.standardizedFileURL)
        let addedElement = try XCTUnwrap(support.app.windows.allElementsBoundByIndex.first { abs($0.frame.minX - support.rect(addedAX).minX) < 2 && abs($0.frame.minY - support.rect(addedAX).minY) < 2 })
        let addedWindow = PriorityInteractionSupport.Window(element: addedElement, ax: addedAX, document: window.document)
        try support.checkpoint(addedWindow, "command-click-added")
        XCTAssertLessThanOrEqual(abs(support.rect(try support.leaf(headingText, in: addedWindow)).minY - addedElement.scrollViews["DocumentReaderScrollView"].frame.minY), 35)
        window.element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 12)).click()
        let ordinary = try support.endpoint("links", offset: 20, fragments: fragments, window: window)
        try support.coordinate(ordinary.screen, in: window).click()
        XCTAssertEqual(support.app.windows.count, count + 1)
        try support.checkpoint(window, "ordinary-path-same-reader")
    }
}
