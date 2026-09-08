import AppKit
import Testing

@MainActor
struct LinkedImageNativeFeasibilityTests {
    private final class Delegate: NSObject, NSTextViewDelegate {
        var activations: [URL] = []
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL { activations.append(url) }
            return true
        }
    }

    @Test func nativeAttachmentClickSelectionAndWidthConstraint() throws {
        let delegate = Delegate()
        let view = NSTextView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.delegate = delegate
        let target = try #require(URL(string: "https://example.com/badge"))
        let proseTarget = try #require(URL(string: "#section"))
        let text = NSMutableAttributedString(string: "Before ", attributes: [.font: NSFont.boldSystemFont(ofSize: 17)])
        let attachment = NSTextAttachment()
        attachment.image = NSImage(size: CGSize(width: 64, height: 32), flipped: false) { rect in
            NSColor.systemGreen.setFill()
            rect.fill()
            return true
        }
        attachment.bounds = CGRect(x: 0, y: 0, width: 64, height: 32)
        let imageText = NSMutableAttributedString(attachment: attachment)
        imageText.addAttribute(.link, value: target, range: NSRange(location: 0, length: 1))
        let attachmentIndex = text.length
        text.append(imageText)
        text.append(NSAttributedString(string: " after with surrounding prose that wraps at the constrained width. ",
                                       attributes: [.font: NSFont.systemFont(ofSize: 17)]))
        text.append(NSAttributedString(string: "Prose link", attributes: [.link: proseTarget, .font: NSFont.systemFont(ofSize: 17)]))
        view.textStorage?.setAttributedString(text)
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        defer { view.delegate = nil; window.close() }
        let layout = try #require(view.layoutManager)
        let container = try #require(view.textContainer)
        container.containerSize = CGSize(width: 400, height: 10000)
        layout.ensureLayout(for: container)
        let wide = layout.usedRect(for: container)
        container.widthTracksTextView = false
        container.containerSize = CGSize(width: 160, height: 10000)
        layout.ensureLayout(for: container)
        let narrow = layout.usedRect(for: container)
        #expect(narrow.height.isFinite && narrow.height > wide.height)
        #expect(narrow.width <= 160)
        view.setSelectedRange(NSRange(location: 0, length: 6))
        #expect(view.selectedRange() == NSRange(location: 0, length: 6))
        #expect(view.attributedString().attribute(.font, at: 0, effectiveRange: nil) as? NSFont == NSFont.boldSystemFont(ofSize: 17))
        let glyph = layout.glyphRange(forCharacterRange: NSRange(location: attachmentIndex, length: 1), actualCharacterRange: nil)
        let rect = layout.boundingRect(forGlyphRange: glyph, in: container)
        let point = view.convert(CGPoint(x: rect.midX, y: rect.midY), to: nil)
        let up = try #require(NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [], timestamp: 0,
                                               windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
        let down = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                                                 windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        NSApp.postEvent(up, atStart: true)
        view.mouseDown(with: down)
        #expect(delegate.activations == [target])
        #expect(view.string == text.string)
        #expect(!view.isEditable && view.isSelectable)
    }
}
