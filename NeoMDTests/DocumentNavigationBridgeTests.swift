import AppKit
import Testing
@testable import NeoMD

@MainActor
struct DocumentNavigationBridgeTests {
    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    private func fixture() -> (NSWindow, NSScrollView, NSView, NSView, DocumentNavigationBridge) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        scroll.hasVerticalScroller = true
        let document = FlippedView(frame: NSRect(x: 0, y: 0, width: 480, height: 2000))
        scroll.documentView = document
        window.contentView = scroll
        let root = NSView(frame: document.bounds)
        document.addSubview(root)
        let target = NSView(frame: NSRect(x: 10, y: 1200, width: 200, height: 40))
        document.addSubview(target)
        let bridge = DocumentNavigationBridge()
        bridge.register(root, id: nil, generation: 0)
        bridge.register(target, id: 1, generation: 0)
        return (window, scroll, root, target, bridge)
    }

    @Test func independentWindowsNativeCoordinatesAndNestedOwnerRejection() {
        let (window, scroll, root, target, bridge) = fixture()
        let (otherWindow, otherScroll, otherRoot, otherTarget, other) = fixture()
        defer { window.close(); otherWindow.close() }
        withExtendedLifetime((root, otherRoot, otherTarget)) {
            #expect(bridge.owner === scroll)
            #expect(other.owner === otherScroll)
            #expect(bridge.position(id: 1, request: 0) != nil)
            #expect(abs(target.convert(target.bounds, to: scroll.contentView).minY - scroll.contentView.bounds.minY) < 1)
            #expect(otherScroll.contentView.bounds.minY == 0)
            let nested = NSScrollView(frame: NSRect(x: 0, y: 500, width: 200, height: 100))
            nested.hasHorizontalScroller = true
            let code = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 80))
            nested.documentView = code
            scroll.documentView!.addSubview(nested)
            bridge.register(code, id: 2, generation: 0)
            #expect(bridge.destination(2) == nil)
            #expect(bridge.position(id: 2, request: 0) == nil)
            bridge.register(otherTarget, id: 3, generation: 0)
            #expect(bridge.destination(3) == nil)
        }
    }

    @Test func cancellationReplacementAndWeakCleanup() {
        let (window, scroll, root, target, bridge) = fixture()
        defer { window.close() }
        withExtendedLifetime(root) {
            bridge.cancel()
            #expect(bridge.position(id: 1, request: 0) == nil)
            #expect(scroll.contentView.bounds.minY == 0)
            let replacement = NSView(frame: target.frame)
            scroll.documentView!.addSubview(replacement)
            bridge.register(replacement, id: 1, generation: 0)
            bridge.unregister(target, id: 1)
            #expect(bridge.destination(1) === replacement)
            bridge.replaceDocument()
            #expect(bridge.owner == nil)
            bridge.register(root, id: nil, generation: 0)
            #expect(bridge.owner == nil)
            bridge.register(root, id: nil, generation: 1)
            bridge.register(target, id: 1, generation: 0)
            #expect(bridge.destination(1) == nil)
            bridge.register(replacement, id: 1, generation: 1)
            #expect(bridge.destination(1) === replacement)
            weak var weakMarker: NSView?
            autoreleasepool {
                let marker = NSView()
                weakMarker = marker
                bridge.register(marker, id: 4, generation: 1)
            }
            #expect(weakMarker == nil)
            #expect(bridge.destination(4) == nil)
        }
    }
}
