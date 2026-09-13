import AppKit
import XCTest

final class PrioritySelectionUITests: XCTestCase {
    @MainActor
    private func prepare(_ appearance: String = "Light", linkFixture: Bool = false) async throws -> (PriorityInteractionSupport, PriorityInteractionSupport.Window, [PriorityInteractionSupport.Fragment]) {
        continueAfterFailure = false
        let support = try PriorityInteractionSupport(test: self)
        addTeardownBlock { @MainActor in try await support.cleanup() }
        let url = try linkFixture
            ? support.fixture("m1-priority-e2e/selection-links.md", name: "selection.md")
            : support.fixture("m1-priority-e2e/selection.md")
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
        enum SetupFailure: Error {
            case missingNewWindowPicker
            case missingSecondReader
            case unexpectedWindowGeometry
        }
        let (support, window, fragments) = try await prepare(appearance)
        func requirePlacement(_ condition: Bool, _ message: String) throws {
            guard condition else { throw PriorityInteractionSupport.Failure(description: message) }
        }
        var placementFrames: [String] = []
        var secondOwned: PriorityInteractionSupport.Window?
        do {
        // AX uses the primary display's top-left origin, not a desktop union.
        let screens = NSScreen.screens
        guard let primary = screens.first else { throw XCTSkip("BLOCKED: no actual display") }
        let initial = support.rect(window.ax)
        let secondSize = CGSize(width: 480, height: 400)
        let minimumGap: CGFloat = 10
        // Native titlebar drags may round their landing point. Only these setup
        // moves allow 2pt per axis; dimensions and measured safety remain exact.
        func nearOrigin(_ actual: CGPoint, _ target: CGPoint) -> Bool {
            abs(actual.x - target.x) <= 2 && abs(actual.y - target.y) <= 2
        }
        let visibleFrames = screens.map { screen in
            let visible = screen.visibleFrame
            return CGRect(x: visible.minX, y: primary.frame.maxY - visible.maxY,
                          width: visible.width, height: visible.height)
        }
        let fittingDisplays = visibleFrames.filter {
            $0.width >= initial.width + minimumGap + secondSize.width + 20
                && $0.height >= max(initial.height, secondSize.height) + 20
        }
        guard let visible = fittingDisplays.first(where: { $0.contains(initial) }) ?? fittingDisplays.first else {
            throw XCTSkip("BLOCKED: one actual display cannot fit both owned readers with margins")
        }
        let usable = visible.insetBy(dx: 10, dy: 10)
        let reserve: CGFloat = visible.width >= initial.width + secondSize.width + 60
            && visible.height >= max(initial.height, secondSize.height) + 40 ? 20 : 10
        let gap = reserve
        let plannedUsable = visible.insetBy(dx: reserve, dy: reserve)
        let origin = CGPoint(x: min(max(initial.minX, plannedUsable.minX), plannedUsable.maxX - initial.width - gap - secondSize.width),
                             y: min(max(initial.minY, plannedUsable.minY), plannedUsable.maxY - max(initial.height, secondSize.height)))
        try support.checkpoint(window, "before-display-placement")
        placementFrames.append("first pre=\(initial) targetOrigin=\(origin)")
        let firstCurrent = try support.resolveWindow(window)
        try requirePlacement(try support.isKey(firstCurrent), "First placement requires normal key identity")
        let firstInput = support.rect(firstCurrent.ax)
        try requirePlacement(firstInput == initial, "First placement geometry changed before input")
        placementFrames.append("first input=\(firstInput)")
        let firstTitle = firstCurrent.element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 12))
        firstTitle.press(forDuration: 0.2, thenDragTo: firstTitle.withOffset(
            CGVector(dx: origin.x - initial.minX, dy: origin.y - initial.minY)))
        try await support.wait { nearOrigin(support.rect(window.ax).origin, origin) }
        try support.checkpoint(window, "first-display-placement")
        let placed = support.rect(window.ax)
        guard nearOrigin(placed.origin, origin), placed.size == initial.size, usable.contains(placed) else {
            throw SetupFailure.unexpectedWindowGeometry
        }
        support.record("actualDisplayVisibleAX=\(visible) usableWithMargin=\(usable) initial=\(initial) placed=\(placed)", name: "display-placement")
        // All screen-space endpoints and pixel references are collected AFTER the verified move.
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
        guard panel.waitForExistence(timeout: 5) else {
            throw SetupFailure.missingNewWindowPicker
        }
        support.app.typeKey("g", modifierFlags: [.command, .shift])
        support.app.typeText(secondURL.path)
        support.app.typeKey(.return, modifierFlags: [])
        support.app.typeKey(.return, modifierFlags: [])
        let secondElement = support.app.windows[secondURL.lastPathComponent]
        guard secondElement.waitForExistence(timeout: 5) else {
            throw SetupFailure.missingSecondReader
        }
        let second = PriorityInteractionSupport.Window(element: secondElement,
            ax: try support.axWindow(document: secondURL, frame: secondElement.frame), document: secondURL)
        secondOwned = second
        try support.checkpoint(second, "second-owned-reader")
        placementFrames.append("second preResize=\(support.rect(second.ax))")
        try await support.resize(second, to: CGSize(width: 480, height: 400))
        let secondCurrent = try support.resolveWindow(second)
        try requirePlacement(try support.isKey(secondCurrent), "Second placement requires normal key identity")
        let secondBefore = support.rect(secondCurrent.ax)
        let titlePoint = CGPoint(x: secondBefore.midX, y: secondBefore.minY + 12)
        try requirePlacement(secondBefore.size == secondSize && usable.contains(titlePoint)
            && secondBefore.contains(titlePoint) && titlePoint.x > secondBefore.minX + 100
            && titlePoint.x < secondBefore.maxX - 100, "Second titlebar safe input point unavailable")
        // Setup oracle is safe nonocclusion, not native drag pixel accuracy.
        // Declare the complete admissible origin region before the single input.
        let validOrigins = CGRect(x: placed.maxX + minimumGap, y: usable.minY,
            width: usable.maxX - secondSize.width - placed.maxX - minimumGap,
            height: usable.height - secondSize.height)
        func validSecondPlacement(_ frame: CGRect) -> Bool {
            frame.size == secondSize && usable.contains(frame)
                && !placed.intersects(frame) && frame.minX - placed.maxX >= minimumGap
                && support.rect(window.ax) == placed
        }
        let target = CGRect(x: validOrigins.midX, y: min(max(placed.minY, validOrigins.minY + 10), validOrigins.maxY - 10),
                            width: secondSize.width, height: secondSize.height)
        placementFrames.append("predeclared validOriginRegion=\(validOrigins) minimumGap=\(minimumGap) exactSize=\(secondSize) unchangedSource=\(placed)")
        guard usable.contains(target) else {
            throw XCTSkip("BLOCKED: actual second reader cannot fit on the same display")
        }
        placementFrames.append("second input=\(secondBefore) titlePoint=\(titlePoint) target=\(target)")
        support.record(placementFrames.joined(separator: "\n"), name: "placement-before-input")
        let title = secondCurrent.element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 12))
        title.press(forDuration: 0.2, thenDragTo: title.withOffset(
            CGVector(dx: target.minX - secondBefore.minX, dy: target.minY - secondBefore.minY)))
        try await support.wait { validSecondPlacement(support.rect(second.ax)) }
        try support.checkpoint(window, "first-after-second-placement")
        try support.checkpoint(second, "second-display-placement")
        let actualFirst = support.rect(window.ax)
        let actualSecond = support.rect(second.ax)
        support.record("actualDisplayVisibleAX=\(visible) first=\(actualFirst) second=\(actualSecond)", name: "common-display-containment")
        guard actualFirst == placed, validSecondPlacement(actualSecond), actualSecond.size == secondSize,
              usable.contains(actualFirst), usable.contains(actualSecond),
              !actualFirst.intersects(actualSecond), actualSecond.minX - actualFirst.maxX >= minimumGap else {
            throw SetupFailure.unexpectedWindowGeometry
        }
        XCTAssertFalse(try support.isKey(window))
        XCTAssertTrue(try support.isKey(second))
        XCTAssertEqual(try support.assertSelection(first, last, fragments: fragments, window: window), ranges)
        let inactive = try support.capture(window, name: "shared-inactive-\(appearance)")
        try assertPixels(inactive, references: references, support: support, active: false)
        window.element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 12)).click()
        try support.assertReaderFocus(window)
        XCTAssertEqual(try support.assertSelection(first, last, fragments: fragments, window: window), ranges)
        try assertPixels(support.capture(window, name: "shared-reactivated-\(appearance)"), references: references, support: support, active: true)
        placementFrames.append("SUCCESS firstFinal=\(support.rect(window.ax)) secondFinal=\(String(describing: secondOwned.map { support.rect($0.ax) }))")
        support.record(placementFrames.joined(separator: "\n"), name: "placement-final")
        } catch {
            placementFrames.append("FAIL error=\(error) firstFinal=\(support.rect(window.ax)) secondFinal=\(String(describing: secondOwned.map { support.rect($0.ax) }))")
            support.record(placementFrames.joined(separator: "\n"), name: "placement-final")
            support.captureFailure(window, error: error)
            throw error
        }
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
        let (support, window, fragments) = try await prepare(linkFixture: true)
        do {
        func check(_ condition: Bool, _ message: String) throws {
            guard condition else { throw PriorityInteractionSupport.Failure(description: "Link: \(message)") }
        }
        let linkStart = try support.endpoint("links", offset: 2, fragments: fragments, window: window)
        let omega = try support.endpoint("omega", offset: 2, fragments: fragments, window: window)
        let count = support.app.windows.count
        let headingText = try XCTUnwrap(fragments.first { $0.id == "heading" }).text
        let headingBefore = support.rect(try support.leaf(headingText, in: window)).minY
        var suffixWitness: (AXUIElement, String, CGRect, CGRect)?
        func geometry(_ readerAX: AXUIElement, phase: String, requireTravel: Bool) throws {
            try support.verifyRetainedWindow(ax: readerAX, document: window.document, phase: phase)
            var notes: [String] = []
            defer { support.record(notes.joined(separator: "\n"), name: "link-geometry-" + phase) }
            func check(_ condition: Bool, _ message: String) throws {
                guard condition else { throw PriorityInteractionSupport.Failure(description: "Link geometry \(phase): \(message)") }
            }
            func rect(_ element: AXUIElement) throws -> CGRect {
                var point = CGPoint.zero, size = CGSize.zero
                guard let p = support.attribute(element, kAXPositionAttribute), let s = support.attribute(element, kAXSizeAttribute),
                      CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID(),
                      AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size),
                      [point.x, point.y, size.width, size.height].allSatisfy(\.isFinite), size.width > 0, size.height > 0 else {
                    throw PriorityInteractionSupport.Failure(description: "Link required AX rectangle unavailable; no zero fallback")
                }
                return CGRect(origin: point, size: size)
            }
            func near(_ a: CGRect, _ b: CGRect) -> Bool {
                abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2
                    && abs(a.width - b.width) <= 2 && abs(a.height - b.height) <= 2
            }
            var pid: pid_t = 0
            try check(AXUIElementGetPid(readerAX, &pid) == .success && pid > 0, "Owned window PID unavailable")
            func owned(_ element: AXUIElement) throws {
                var actual: pid_t = 0
                try check(AXUIElementGetPid(element, &actual) == .success && actual == pid, "AX escaped owned PID")
            }
            func ancestry(_ element: AXUIElement, through required: AXUIElement) throws {
                var current = element, seen: [AXUIElement] = [], found = false
                while seen.count < 32 {
                    try owned(current)
                    try check(!seen.contains { CFEqual($0, current) }, "Cyclic ancestry")
                    seen.append(current)
                    if CFEqual(current, required) { found = true }
                    if CFEqual(current, readerAX) { try check(found, "Required content/reader ancestry missing"); return }
                    guard let parent = support.axElement(support.attribute(current, kAXParentAttribute)),
                          let children = support.attribute(parent, kAXChildrenAttribute) as? [AXUIElement] else {
                        throw PriorityInteractionSupport.Failure(description: "Link reciprocal ancestry unavailable")
                    }
                    try check(children.filter { CFEqual($0, current) }.count == 1, "Nonreciprocal ancestry")
                    current = parent
                }
                throw PriorityInteractionSupport.Failure(description: "Link ancestry bound exceeded")
            }
            var pending: [(AXUIElement, AXUIElement?)] = [(readerAX, nil)], tree: [AXUIElement] = []
            while tree.count < 4096, let (element, parent) = pending.popLast() {
                try owned(element)
                tree.append(element)
                var value: CFTypeRef?
                let error = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
                if error != .success {
                    notes.append(support.axFailure(element, parent: parent, attribute: kAXChildrenAttribute, error: error))
                }
                if error == .noValue { try check(support.attribute(element, kAXRoleAttribute) as? String != nil, "Childless role unavailable"); continue }
                if error == .attributeUnsupported {
                    var names: CFArray?
                    try check(AXUIElementCopyAttributeNames(element, &names) == .success, "Childless attributes unavailable")
                    guard let attributes = names as? [String], !attributes.contains(kAXChildrenAttribute),
                          support.attribute(element, kAXRoleAttribute) as? String != nil else {
                        throw PriorityInteractionSupport.Failure(description: "Unproven childless AX node")
                    }
                    continue
                }
                guard error == .success, let children = value as? [AXUIElement] else {
                    throw PriorityInteractionSupport.Failure(description: "Incomplete link AX traversal error=\(error.rawValue)")
                }
                pending += children.reversed().map { ($0, element) }
            }
            try check(pending.isEmpty, "Link AX traversal cap exceeded")
            let areas = tree.filter {
                support.attribute($0, kAXRoleAttribute) as? String == kAXScrollAreaRole &&
                support.attribute($0, kAXIdentifierAttribute) as? String == "DocumentReaderScrollView"
            }
            try check(areas.count == 1, "Unique reader unavailable")
            let area = areas[0]
            try ancestry(area, through: area)
            guard let contents = support.attribute(area, kAXContentsAttribute) as? [AXUIElement], contents.count == 1 else {
                throw PriorityInteractionSupport.Failure(description: "Unique scroll-carried AXContents unavailable")
            }
            let document = contents[0]
            try ancestry(document, through: area)
            let clip = try rect(area), bounds = try rect(document)
            if requireTravel {
                let reader = try support.resolveWindow(ax: readerAX, document: window.document)
                let query = reader.element.scrollViews.matching(identifier: "DocumentReaderScrollView")
                try check(query.count == 1 && near(clip, query.element.frame), "AX/XCUI clip disagreement")
            }
            let headingElement = try support.leaf(headingText, in: readerAX)
            try ancestry(headingElement, through: document)
            let heading = try rect(headingElement)
            func nativeGlyph(_ element: AXUIElement, text: String) throws -> CGRect {
                try check(support.attribute(element, kAXValueAttribute) as? String == text, "Exact text changed")
                var range = CFRange(location: 0, length: text.utf16.count)
                guard let input = AXValueCreate(.cfRange, &range) else { throw PriorityInteractionSupport.Failure(description: "Link range unavailable") }
                var output: CFTypeRef?
                let error = AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString, input, &output)
                try check(error == .success && output as? String == text, "Native exact string-for-range unavailable")
                let glyph = try support.bounds(NSRange(location: 0, length: text.utf16.count), leaf: element)
                try check([glyph.minX, glyph.minY, glyph.width, glyph.height].allSatisfy(\.isFinite) && glyph.width > 0 && glyph.height > 0,
                          "Native glyph bounds invalid")
                try check(try rect(element).insetBy(dx: -2, dy: -2).contains(glyph), "Glyph outside actual leaf")
                return glyph
            }
            let headingGlyph = try nativeGlyph(headingElement, text: headingText)
            try check(clip.contains(headingGlyph), "Heading glyph clipped")
            // AXContents is scroll-carried content, NOT an exact documentView or
            // zero-origin offset interval. R is only a sufficient remaining bound.
            let displacement = heading.minY - clip.minY
            let remaining = bounds.maxY - clip.maxY
            notes.append("pid=\(pid) area=\(area) content=\(document) clip=\(clip) AXContents=\(bounds) heading=\(heading) headingGlyph=\(headingGlyph) d=\(displacement) R=\(remaining); no exact offset interval inferred")
            if requireTravel {
                try check(remaining > 0 && displacement > 35 && remaining >= displacement + 35, "Original35pt sufficient remaining-travel gate failed")
                let authored = try String(contentsOf: support.root.appendingPathComponent("docs/fixtures/m1-priority-e2e/selection-links.md"), encoding: .utf8)
                    .components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .newlines) }.filter { $0.hasPrefix("Trailing passage ") }
                var witnesses: [(AXUIElement, String, CGRect)] = []
                for element in tree where support.attribute(element, kAXRoleAttribute) as? String == kAXTextAreaRole {
                    guard let text = support.attribute(element, kAXValueAttribute) as? String, authored.contains(text) else { continue }
                    let leaf = try rect(element)
                    notes.append("realizedSuffixCandidate AX=\(element) text=\(text.debugDescription) leaf=\(leaf)")
                    if leaf.maxY > clip.maxY + displacement + 35 { witnesses.append((element, text, leaf)) }
                }
                // Lowest sufficient realized leaf, not an estimated paragraph count.
                witnesses.sort { $0.2.maxY < $1.2.maxY }
                let chosen: (AXUIElement, String, CGRect)
                if let prior = suffixWitness {
                    guard let same = witnesses.first(where: { CFEqual($0.0, prior.0) && $0.1 == prior.1 }) else {
                        throw PriorityInteractionSupport.Failure(description: "Retained realized suffix witness lost; no rematch")
                    }
                    chosen = same
                } else {
                    guard let first = witnesses.first else { throw PriorityInteractionSupport.Failure(description: "No realized authored suffix witness beyond target+35; no measured-scroll fallback") }
                    chosen = first
                }
                try ancestry(chosen.0, through: document)
                let glyph = try nativeGlyph(chosen.0, text: chosen.1)
                notes.append("witnessAX=\(chosen.0) exactText=\(chosen.1.debugDescription) range=[0,\(chosen.1.utf16.count)) leaf=\(chosen.2) glyph=\(glyph) realizedRemaining=\(glyph.maxY - clip.maxY); native offclip evidence, no unclipping action")
                try check(bounds.insetBy(dx: -2, dy: -2).contains(glyph) && glyph.maxY > clip.maxY + displacement + 35,
                          "Realized native glyph does not establish sufficient suffix; no fallback")
                if let prior = suffixWitness { try check(near(prior.2, chosen.2) && near(prior.3, glyph), "Retained suffix layout changed before click") }
                suffixWitness = (chosen.0, chosen.1, chosen.2, glyph)
            }
            if !requireTravel { try check(abs(displacement) <= 35, "Additional/original reader missed heading; original35pt gate") }
            try support.verifyRetainedWindow(ax: readerAX, document: window.document, phase: phase + "-after-geometry")
            // Landing is retained native observation. A screenshot still requires
            // an exact XCUI mapping; never label another same-frame reader as it.
            let captureWindow: PriorityInteractionSupport.Window?
            do {
                captureWindow = try support.resolveWindow(ax: readerAX, document: window.document)
            } catch {
                try support.verifyRetainedWindow(ax: readerAX, document: window.document, phase: phase + "-capture-unavailable")
                notes.append("Exact landing-window screenshot unavailable: \(error); no XCUI substitute. Required visual evidence uses separately verified owned SOURCE frame; may be occluded, not a landing-window pixel assertion.")
                captureWindow = nil
            }
            if let captureWindow {
                _ = try support.capture(captureWindow, name: "link-owned-" + phase)
            } else {
                _ = try support.capture(window, name: "link-owned-source-frame-" + phase)
            }
            notes.append("Owned visual capture: inspect stable heading/content correspondence and occlusion honestly; no new pixel-difference tolerance or automated pixel proof")
        }
        try geometry(window.ax, phase: "before-drag", requireTravel: true)
        try support.drag(linkStart, omega, window: window)
        try support.assertSelection(linkStart, omega, fragments: fragments, window: window)
        try check(support.app.windows.count == count, "Drag added a window")
        try check(abs(support.rect(try support.leaf(headingText, in: window)).minY - headingBefore) <= 2, "Drag navigated")
        try geometry(window.ax, phase: "before-fragment-click", requireTravel: true)
        let fragmentClick = try support.endpoint("links", offset: 2, fragments: fragments, window: window)
        try support.coordinate(fragmentClick.screen, in: window).click()
        try await support.wait { abs(support.rect(try support.leaf(headingText, in: window)).minY - window.element.scrollViews["DocumentReaderScrollView"].frame.minY) <= 35 }
        try check(support.app.windows.count == count, "Ordinary fragment added a window")
        try support.checkpoint(window, "ordinary-fragment")
        try geometry(window.ax, phase: "after-fragment-click", requireTravel: false)
        let additional = try support.endpoint("links", offset: 20, fragments: fragments, window: window)
        func selectionSnapshot() throws -> [String] {
            let snapshot = try fragments.map {
                let (range, text) = try support.selected(support.leaf($0.text, in: window))
                return "\(range):\(text.debugDescription)"
            }
            support.record(zip(fragments, snapshot).map { "\($0.0.id):\($0.1)" }.joined(separator: "\n"),
                           name: "link-raw-selection-snapshot")
            return snapshot
        }
        let beforeSelection = try selectionSnapshot()
        let beforeY = support.rect(try support.leaf(headingText, in: window)).minY
        let target = try support.coordinate(additional.screen, in: window)
        XCUIElement.perform(withKeyModifiers: [.command]) { target.click() }
        try await support.wait { support.app.windows.count == count + 1 }
        try check(try selectionSnapshot() == beforeSelection, "Command-click changed exact collapsed source ranges")
        try check(abs(support.rect(try support.leaf(headingText, in: window)).minY - beforeY) <= 2, "Command-click moved source")
        try support.checkpoint(window, "command-click-source-preserved")
        let added = try support.windows().filter { !CFEqual($0, window.ax) }
        try check(added.count == 1, "Expected exactly one additional owned reader")
        guard let addedAX = added.first else { throw PriorityInteractionSupport.Failure(description: "Missing additional reader") }
        try check((support.attribute(addedAX, kAXDocumentAttribute) as? String).flatMap(URL.init(string:))?.standardizedFileURL == window.document.standardizedFileURL, "Additional document URL changed")
        try await support.waitForNewReaderAX(addedAX, document: window.document, heading: headingText, phase: "command-click-added")
        try geometry(addedAX, phase: "command-click-added", requireTravel: false)
        try support.clickTitlebar(window)
        // One bounded nonempty cross-block subcase, using existing literal endpoints.
        let alpha = try support.endpoint("alpha", offset: 2, fragments: fragments, window: window)
        let four = try support.endpoint("table-row-two-right", offset: 2, fragments: fragments, window: window)
        try support.drag(alpha, four, window: window)
        let nonempty = try support.assertSelection(alpha, four, fragments: fragments, window: window)
        let exactNonempty = try selectionSnapshot()
        let nonemptyY = support.rect(try support.leaf(headingText, in: window)).minY
        let ownedBefore = try support.windows()
        try check(ownedBefore.count == count + 1, "Nonempty subcase initial window count changed")
        let nonemptyLink = try support.endpoint("links", offset: 20, fragments: fragments, window: window)
        let nonemptyTarget = try support.coordinate(nonemptyLink.screen, in: window)
        XCUIElement.perform(withKeyModifiers: [.command]) { nonemptyTarget.click() }
        try await support.wait { support.app.windows.count == count + 2 }
        try support.checkpoint(window, "nonempty-command-source")
        try check(!(try support.isKey(window)), "Source did not lose key status")
        try check(try selectionSnapshot() == exactNonempty, "Nonempty exact native source ranges changed")
        try check(try support.assertSelection(alpha, four, fragments: fragments, window: window) == nonempty, "Nonempty literal slices changed")
        try check(abs(support.rect(try support.leaf(headingText, in: window)).minY - nonemptyY) <= 2, "Nonempty source scrolled")
        let ownedAfter = try support.windows()
        let newlyAdded = ownedAfter.filter { candidate in !ownedBefore.contains { CFEqual($0, candidate) } }
        try check(newlyAdded.count == 1 && ownedBefore.allSatisfy { old in ownedAfter.contains { CFEqual(old, $0) } }, "Nonempty subcase did not add exactly one reader preserving identities")
        try check(newlyAdded.allSatisfy { (support.attribute($0, kAXDocumentAttribute) as? String).flatMap(URL.init(string:))?.standardizedFileURL == window.document.standardizedFileURL }, "Nonempty added document URL changed")
        guard let nonemptyAddedAX = newlyAdded.first else { throw PriorityInteractionSupport.Failure(description: "Missing nonempty additional reader") }
        try await support.waitForNewReaderAX(nonemptyAddedAX, document: window.document, heading: headingText, phase: "nonempty-command-added")
        try geometry(nonemptyAddedAX, phase: "nonempty-command-added", requireTravel: false)
        _ = try support.capture(window, name: "nonempty-source-inactive")
        try support.clickTitlebar(window)
        try support.assertReaderFocus(window)
        try check(try selectionSnapshot() == exactNonempty, "Source reactivation changed selection")
        let continuation = try support.endpoint("omega", offset: 2, fragments: fragments, window: window)
        let continuationTarget = try support.coordinate(continuation.screen, in: window)
        XCUIElement.perform(withKeyModifiers: [.shift]) { continuationTarget.click() }
        try support.assertSelection(alpha, continuation, fragments: fragments, window: window)
        let ordinary = try support.endpoint("links", offset: 20, fragments: fragments, window: window)
        try support.coordinate(ordinary.screen, in: window).click()
        try check(support.app.windows.count == count + 2, "Ordinary path added another reader")
        try support.checkpoint(window, "ordinary-path-same-reader")
        } catch {
            support.captureFailure(window, error: error)
            throw error
        }
    }
}
