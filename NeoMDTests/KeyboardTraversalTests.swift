import AppKit
import SwiftUI
import Testing
@testable import NeoMD

@MainActor struct KeyboardTraversalTests {
    @Test func lazyOriginDetachDoesNotCancelAnotherTargetAcquisition() {
        let bridge = DocumentNavigationBridge()
        let origin = NSView(), target = NSView()
        bridge.registerText(origin, id: 1, generation: 0)
        bridge.registerText(target, id: 2, generation: 0)
        bridge.prepareTraversal(to: .text(2))
        let request = bridge.request
        bridge.unregisterText(origin, id: 1)
        #expect(bridge.request == request)
        #expect(bridge.traversalTarget == .text(2))
        bridge.unregisterText(target, id: 2)
        #expect(bridge.request != request)
        #expect(bridge.traversalTarget == nil)

        bridge.registerCode(origin, id: 1, generation: 0, overflow: true)
        bridge.registerCode(target, id: 2, generation: 0, overflow: true)
        bridge.prepareTraversal(to: .codeBlock(2))
        let codeRequest = bridge.request
        bridge.unregisterCode(origin, id: 1)
        #expect(bridge.request == codeRequest)
        bridge.unregisterCode(target, id: 2)
        #expect(bridge.request != codeRequest)
        #expect(bridge.traversalTarget == nil)
    }

    @Test func semanticCandidatesKeepSeparateTextAndActionStops() {
        let document = MarkdownBlockRenderer.render(from: "Plain\n\n[One](#end) and [Two](#end)\n\n```\nwide code\n```\n\n# End")
        #expect(DocumentReaderTraversal.candidates(in: document) == [.text(0), .text(1), .links(1), .codeBlock(2), .text(3)])
        #expect(Array(DocumentReaderTraversal.candidates(in: document).reversed()) == [.text(3), .codeBlock(2), .links(1), .text(1), .text(0)])
    }

    @Test func exactNativeChordAndClipboardFreeSelection() throws {
        let view = MarkdownLinkedImageTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
        view.update(.init(text: AttributedString("Selectable ordinary text"), states: [:], dark: false, width: 300))
        func event(_ modifiers: NSEvent.ModifierFlags, key: UInt16 = 48) throws -> NSEvent {
            try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                timestamp: 0, windowNumber: 0, context: nil, characters: "\t", charactersIgnoringModifiers: "\t",
                isARepeat: false, keyCode: key))
        }
        #expect(MarkdownLinkedImageTextView.traversalDirection(try event(.option)) == false)
        #expect(MarkdownLinkedImageTextView.traversalDirection(try event([.option, .shift])) == true)
        for flags: NSEvent.ModifierFlags in [[], .shift, .command, .control, [.option, .command], [.option, .control]] {
            #expect(MarkdownLinkedImageTextView.traversalDirection(try event(flags)) == nil)
        }
        #expect(MarkdownLinkedImageTextView.traversalDirection(try event(.option, key: 124)) == nil)
        view.setSelectedRange(NSRange(location: 3, length: 0))
        view.moveRightAndModifySelection(nil)
        #expect(view.selectedRange() == NSRange(location: 3, length: 1))
        view.moveLeftAndModifySelection(nil)
        #expect(view.selectedRange() == NSRange(location: 3, length: 0))
        #expect(view.string == "Selectable ordinary text")
        #expect(view.isSelectable && !view.isEditable)
        view.detach()
    }

    @Test func weakIdentityGenerationDetachAndTwoOwnerIsolation() async throws {
        func host() -> (NSWindow, NSScrollView, NSView, NSView, DocumentNavigationBridge) {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
            scroll.hasVerticalScroller = true
            let document = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 400))
            let marker = NSView(frame: .zero)
            document.addSubview(marker)
            scroll.documentView = document
            window.contentView = scroll
            let bridge = DocumentNavigationBridge()
            bridge.register(marker, id: nil, generation: 0)
            return (window, scroll, document, marker, bridge)
        }
        weak var weakView: MarkdownLinkedImageTextView?
        weak var baseline: MarkdownLinkedImageTextView?
        weak var weakOwner: DocumentNavigationBridge?
        try autoreleasepool {
        let first = host(), second = host()
        weakOwner = first.4
        defer { first.0.close(); second.0.close() }
        var view: MarkdownLinkedImageTextView? = MarkdownLinkedImageTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 40))
        weakView = view
        first.2.addSubview(try #require(view))
        view?.bindTraversal(bridge: first.4, id: 7, generation: 0)
        // Same class, host, frame and detach path, without traversal registration.
        var plain: MarkdownLinkedImageTextView? = MarkdownLinkedImageTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 40))
        baseline = plain
        first.2.addSubview(try #require(plain))
        plain?.detach()
        plain?.removeFromSuperview()
        plain = nil
        let other = MarkdownLinkedImageTextView(frame: .zero)
        second.2.addSubview(other)
        other.bindTraversal(bridge: second.4, id: 7, generation: 0)
        #expect(first.4.textLeaf(7) === view)
        #expect(second.4.textLeaf(7) === other)
        #expect(!second.4.traverseText(try #require(view), id: 7, generation: 0, reverse: false))
        let replacement = MarkdownLinkedImageTextView(frame: .zero)
        first.2.addSubview(replacement)
        replacement.bindTraversal(bridge: first.4, id: 7, generation: 0)
        view?.detach()
        #expect(first.4.textLeaf(7) === replacement)
        view?.removeFromSuperview()
        view = nil
        first.4.registerCode(first.3, id: 9, generation: 0, overflow: true)
        first.4.registerCode(replacement, id: 9, generation: 0, overflow: false)
        first.4.unregisterCode(first.3, id: 9)
        #expect(first.4.codeOverflow(9) == false)
        first.4.unregisterCode(replacement, id: 9)
        #expect(first.4.codeOverflow(9) == nil)
        final class Payload {}
        var payload: Payload? = Payload()
        weak var capturedPayload = payload
        first.4.traverse = { [payload] _, _ in _ = payload }
        payload = nil
        #expect(capturedPayload != nil)
        first.4.replaceDocument()
        #expect(capturedPayload == nil)
        #expect(first.4.traverse == nil)
        #expect(first.4.textLeaf(7) == nil)
        #expect(!first.4.traverseText(replacement, id: 7, generation: 0, reverse: false))
        #expect(second.4.textLeaf(7) === other)
        replacement.detach()
        other.detach()
        }
        // The captured native owner graph includes a dispatch-timer block retaining
        // each view. Counted quick turns do not advance that deadline. Drain real
        // AppKit turns until release, bounded by elapsed time; never sleep.
        let releaseStart = Date()
        let releaseDeadline = releaseStart.addingTimeInterval(2)
        while (weakView != nil || baseline != nil), Date() < releaseDeadline {
            // A queued perform block can resume before AppKit's end-of-turn cleanup.
            // Observe the actual before-waiting phase, after framework observers.
            await withCheckedContinuation { continuation in
                let observer = CFRunLoopObserverCreateWithHandler(nil,
                    CFRunLoopActivity.beforeWaiting.rawValue, false, CFIndex.max) { _, _ in
                    continuation.resume()
                }
                CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
            }

        }
        #expect(baseline == nil)
        #expect(weakView == nil)
        #expect(weakOwner == nil)
    }
}
