import AppKit
import XCTest

/// Generic XCUI scrolling only. Neither method claims physical trackpad momentum.
final class PriorityScrollUITests: XCTestCase {
    @MainActor
    private func prepare(delay: Int? = nil) async throws -> (PriorityInteractionSupport, PriorityInteractionSupport.Window) {
        continueAfterFailure = false
        let support = try PriorityInteractionSupport(test: self)
        addTeardownBlock { @MainActor in try await support.cleanup() }
        let url = try support.fixture("m1-p9-scroll/mixed-heights.md", name: "priority-scroll.md", copies: 8)
        XCTAssertEqual(try Data(contentsOf: url).count, 33207)
        XCTAssertEqual(PriorityInteractionSupport.hash(try Data(contentsOf: url)), "09c556b41d3dafdf4d2bf1f6f5dcf48e45993ccff29903a35ca1a7138236e1f8")
        try support.launch(delay: delay)
        let window = try await support.open(url, fragment: "p9-top-4")
        try await support.resize(window, to: CGSize(width: 900, height: 720))
        // Opening again is explicit fragment navigation, not measured wheel setup.
        _ = try await support.open(url, fragment: "p9-top-4")
        try await Task.sleep(for: .milliseconds(700))
        _ = try middleSentinel(support, window)
        support.record("eventKind=XCUI generic scroll; native phase/momentumPhase/content-height/NSClipView-offset and pending-generation channels unavailable; instrumentation=off. AX scrollbar fraction and same AX sentinel geometry are limited native position evidence, not momentum physics.", name: "scroll-evidence-limits")
        return (support, window)
    }

    @MainActor
    private func fraction(_ support: PriorityInteractionSupport, _ window: PriorityInteractionSupport.Window) throws -> Double {
        let scrolls = support.descendants(window.ax).filter {
            support.attribute($0, kAXIdentifierAttribute) as? String == "DocumentReaderScrollView"
        }
        for scroll in scrolls {
            if let bar = support.axElement(support.attribute(scroll, kAXVerticalScrollBarAttribute)),
               let value = support.attribute(bar, kAXValueAttribute) as? NSNumber {
                return value.doubleValue
            }
        }
        throw XCTSkip("BLOCKED: reader-scoped AX vertical scrollbar offset evidence unavailable; no guessed content offset")
    }

    @MainActor
    private func middleSentinel(_ support: PriorityInteractionSupport, _ window: PriorityInteractionSupport.Window) throws -> AXUIElement {
        let clip = window.element.scrollViews["DocumentReaderScrollView"].frame
        let candidates = support.descendants(window.ax).filter {
            support.attribute($0, kAXValueAttribute) as? String == "P9 top"
                && clip.intersects(support.rect($0)) && support.rect($0).height > 0
        }
        let sentinel = try XCTUnwrap(candidates.first { abs(support.rect($0).minY - clip.minY) < 40 }, "Requested fifth-copy heading must land at viewport top")
        let value = try fraction(support, window)
        XCTAssertGreaterThan(value, 0.3)
        XCTAssertLessThan(value, 0.7)
        support.record("requestedFragment=p9-top-4 visibleSentinelAX=\(sentinel) rect=\(support.rect(sentinel)) scrollbarFraction=\(value); repeated authored heading text is not itself a unique-copy identifier", name: "middle-setup")
        return sentinel
    }

    @MainActor
    func testGenericUpwardScrollDoesNotSnapBack() async throws {
        let (support, window) = try await prepare()
        let reader = window.element.scrollViews["DocumentReaderScrollView"]
        for trial in 0..<2 {
            if trial == 1 {
                _ = try await support.open(window.document, fragment: "p9-top-4")
                try await Task.sleep(for: .milliseconds(700))
            }
            let sentinel = try middleSentinel(support, window)
            let beforeY = support.rect(sentinel).minY
            let before = try fraction(support, window)
            _ = try support.capture(window, name: "generic-before-\(trial)")
            reader.scroll(byDeltaX: 0, deltaY: 240)
            let firstY = support.rect(sentinel).minY
            XCTAssertGreaterThan(firstY - beforeY, 20, "First visible sentinel must move down: wrong sign or no input is setup failure")
            XCTAssertLessThan(try fraction(support, window), before)
            for _ in 0..<2 {
                try await Task.sleep(for: .milliseconds(100))
                reader.scroll(byDeltaX: 0, deltaY: 240)
            }
            let after = try fraction(support, window)
            XCTAssertLessThan(after, before)
            // Capture a currently visible native leaf, then keep that same AX object
            // through the settle; do not match a same-text leaf in another copy.
            let clip = reader.frame
            let surviving = try XCTUnwrap(support.descendants(window.ax).first {
                support.attribute($0, kAXRoleAttribute) as? String == kAXTextAreaRole
                    && support.rect($0).height > 0 && clip.contains(CGPoint(x: support.rect($0).midX, y: support.rect($0).midY))
            })
            let settledY = support.rect(surviving).minY
            try await Task.sleep(for: .seconds(2))
            XCTAssertEqual(support.rect(surviving).minY, settledY, accuracy: 20)
            XCTAssertLessThan(try fraction(support, window), before)
            support.record("trial=\(trial) scrollbar before=\(before) after=\(after) settled=\(try fraction(support, window)) firstSentinelDisplacement=\(firstY - beforeY) survivingAX=\(surviving) settledDisplacement=\(support.rect(surviving).minY - settledY)", name: "generic-scroll")
            _ = try support.capture(window, name: "generic-after-\(trial)")
        }
    }

    @MainActor
    func testGenericScrollCancelsPendingRestoration() async throws {
        let (support, window) = try await prepare(delay: 1500)
        let sentinel = try middleSentinel(support, window)
        let reader = window.element.scrollViews["DocumentReaderScrollView"]
        let oldPoint = support.rect(sentinel).minY - reader.frame.minY
        _ = try support.capture(window, name: "restoration-before")
        // Only height changes by 20; no width/fullscreen/history/refresh permutations.
        let size = window.element.frame.size
        let corner = window.element.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -2, dy: -2))
        corner.press(forDuration: 0.1, thenDragTo: corner.withOffset(CGVector(dx: 0, dy: 20)))
        let started = Date()
        XCTAssertEqual(window.element.frame.height, size.height + 20, accuracy: 3)
        reader.scroll(byDeltaX: 0, deltaY: 240)
        let newPoint = support.rect(sentinel).minY - reader.frame.minY
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.5, "Input must arrive inside configured delayed-restoration window")
        XCTAssertGreaterThanOrEqual(newPoint - oldPoint, 80, "Observed input movement is required")
        try await Task.sleep(for: .milliseconds(2500))
        let finalPoint = support.rect(sentinel).minY - reader.frame.minY
        XCTAssertEqual(finalPoint, newPoint, accuracy: 20)
        XCTAssertGreaterThanOrEqual(finalPoint - oldPoint, 60)
        support.record("oldSemanticPoint=\(oldPoint) new=\(newPoint) final=\(finalPoint) pending/cancel-generation=unavailable; configured 1500ms delay and observed timing only, not direct pending-state proof", name: "restoration-cancellation")
        _ = try support.capture(window, name: "restoration-after")
    }
}
