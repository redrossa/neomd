import AppKit
import Testing
@testable import NeoMD

@MainActor
struct MarkdownLinkAttachmentTests {
    private func window() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        return window
    }

    private func event(_ window: NSWindow, point: NSPoint = NSPoint(x: 30, y: 30),
                       type: NSEvent.EventType = .rightMouseDown,
                       flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: flags,
            timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 1,
            clickCount: 1, pressure: 1))
    }

    @Test func ownershipRejectsOtherWindowsControlsAndNonSecondaryEvents() throws {
        let host = window()
        let other = window()
        defer { host.close(); other.close() }
        let view = MarkdownLinkContextMenuView(frame: NSRect(x: 10, y: 10, width: 100, height: 80))
        view.entries = [.destination(URL(string: "https://example.com/")!)]
        host.contentView!.addSubview(view)
        #expect(view.owns(try event(host)))
        #expect(view.owns(try event(host, type: .leftMouseDown, flags: .control)))
        #expect(!view.owns(try event(host, type: .leftMouseDown)))
        #expect(!view.owns(try event(host, type: .rightMouseUp)))
        #expect(!view.owns(try event(other)))
        #expect(!view.owns(try event(host, point: NSPoint(x: 150, y: 30))))
        #expect(view.hitTest(NSPoint(x: 30, y: 30)) == nil)
        #expect(!view.acceptsFirstResponder)
        #expect(!view.isAccessibilityElement())
        let button = NSButton(frame: NSRect(x: 10, y: 10, width: 100, height: 80))
        host.contentView!.addSubview(button)
        #expect(!view.owns(try event(host)))
        button.removeFromSuperview()
        let field = NSTextField(frame: view.frame)
        host.contentView!.addSubview(field)
        field.isEditable = true
        #expect(!view.owns(try event(host)))
        field.isEditable = false
        #expect(view.owns(try event(host)))
        field.removeFromSuperview()
        let scroller = NSScroller(frame: view.frame)
        host.contentView!.addSubview(scroller)
        #expect(!view.owns(try event(host)))
        scroller.removeFromSuperview()
        #expect(view.owns(try event(host)))
        view.isHidden = true
        #expect(!view.owns(try event(host)))
        view.isHidden = false
        host.contentView!.isHidden = true
        #expect(!view.owns(try event(host)))
        host.contentView!.isHidden = false
        view.removeFromSuperview()
        #expect(!view.owns(try event(host)))
    }

    @Test func clippedAreaDoesNotOwnAnOtherwiseInBoundsEvent() throws {
        let host = window()
        defer { host.close() }
        let clip = NSClipView(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        host.contentView!.addSubview(clip)
        let view = MarkdownLinkContextMenuView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        view.entries = [.destination(URL(string: "https://example.com/")!)]
        clip.documentView = view
        #expect(view.owns(try event(host)))
        let outside = NSPoint(x: 120, y: 30)
        #expect(view.bounds.contains(view.convert(outside, from: nil)))
        #expect(!view.visibleRect.contains(view.convert(outside, from: nil)))
        #expect(!view.owns(try event(host, point: outside)))
    }

    @Test func monitorOwnershipIsIdempotentAndReleasedOnDetachTransitionAndDeallocation() throws {
        let host = window()
        let other = window()
        defer { host.close(); other.close() }
        weak var weakView: MarkdownLinkContextMenuView?
        autoreleasepool {
            var view: MarkdownLinkContextMenuView? = MarkdownLinkContextMenuView(frame: .zero)
            weakView = view
            host.contentView!.addSubview(view!)
            weak var first = view!.monitor
            #expect(first != nil)
            view!.viewDidMoveToWindow()
            #expect(view!.monitor === first)
            view!.removeFromSuperview()
            #expect(first == nil)
            #expect(view!.monitor == nil)
            other.contentView!.addSubview(view!)
            weak var second = view!.monitor
            #expect(second != nil)
            final class Captured {}
            var captured: Captured? = Captured()
            weak var weakCaptured = captured
            view!.open = { [captured] _ in _ = captured }
            captured = nil
            #expect(weakCaptured != nil)
            view!.detach()
            view!.detach()
            #expect(second == nil)
            #expect(weakCaptured == nil)
            #expect(view!.entries.isEmpty)
            view!.removeFromSuperview()
            host.contentView!.addSubview(view!)
            weak var third = view!.monitor
            #expect(third != nil)
            view!.removeFromSuperview()
            view = nil
            #expect(third == nil)
        }
        #expect(weakView == nil)
        // The token owner also cleans up without a view/window transition.
        var owner: MarkdownLinkMenuMonitor? = MarkdownLinkMenuMonitor { $0 }
        weak var weakOwner = owner
        owner = nil
        #expect(weakOwner == nil)
    }
}
