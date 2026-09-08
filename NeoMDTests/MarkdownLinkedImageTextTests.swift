import AppKit
import Testing
@testable import NeoMD

@MainActor
struct MarkdownLinkedImageTextTests {
    @Test func headingFormattingAndAdjacentImageOccurrencesSurviveNativeConversion() throws {
        let document = MarkdownBlockRenderer.render(from: "# [![**same** alt](https://example.com/a.png)](#target)[![same](https://example.com/a.png)](#other) **bold** *italic* `code` <sup>up</sup>")
        let block = try #require(document.roots.first)
        let url = try #require(URL(string: "https://example.com/a.png"))
        let bitmap = NSImage(size: CGSize(width: 64, height: 32))
        let input = MarkdownLinkedImageText.Input(text: ReaderTheme().presentationText(for: block.text, headingLevel: 1),
            states: [url: .loaded(bitmap, natural: CGSize(width: 64, height: 32))], dark: false, width: 40, headingLevel: 1)
        let native = MarkdownLinkedImageContent.make(input)
        var attachments: [NSTextAttachment] = []
        native.enumerateAttribute(.attachment, in: NSRange(location: 0, length: native.length)) { value, _, _ in
            if let attachment = value as? NSTextAttachment { attachments.append(attachment) }
        }
        #expect(attachments.count == 2)
        #expect(attachments.allSatisfy { $0.bounds.size == CGSize(width: 40, height: 20) })
        let string = native.string as NSString
        let bold = try #require(native.attribute(.font, at: string.range(of: "bold").location, effectiveRange: nil) as? NSFont)
        let italic = try #require(native.attribute(.font, at: string.range(of: "italic").location, effectiveRange: nil) as? NSFont)
        let code = try #require(native.attribute(.font, at: string.range(of: "code").location, effectiveRange: nil) as? NSFont)
        #expect(bold.pointSize == NSFont.preferredFont(forTextStyle: .largeTitle).pointSize)
        #expect(NSFontManager.shared.traits(of: bold).contains(.boldFontMask))
        #expect(NSFontManager.shared.traits(of: italic).contains(.italicFontMask))
        #expect(code.isFixedPitch)
        var quote = input
        quote.headingLevel = nil
        quote.quoted = true
        let quoted = MarkdownLinkedImageContent.make(quote)
        #expect(quoted.attribute(.foregroundColor, at: string.range(of: "bold").location, effectiveRange: nil) as? NSColor == .secondaryLabelColor)
        #expect(native.attribute(.baselineOffset, at: string.range(of: "up").location, effectiveRange: nil) as? Int == 5)
    }

    @Test func dismantlingReleasesOwnedStateAndDisablesRetainedAccessibilityActions() throws {
        final class CapturedPolicy {
            var destinations: [URL] = []
            func open(_ url: URL) { destinations.append(url) }
        }
        let document = MarkdownBlockRenderer.render(from: "[![Badge](https://example.com/a.png)](#target)")
        let text = try #require(document.roots.first?.text)
        // Intentionally retain the view: cleanup must work independently of when
        // AppKit releases NSTextView (a stock NSTextView is retained on this host).
        let view = MarkdownLinkedImageTextView(frame: .zero)
        view.update(.init(text: text, states: [:], dark: false, width: 300))
        let child = try #require(view.accessibilityChildren()?.first as? MarkdownImageAccessibilityElement)
        weak var releasedPolicy: CapturedPolicy?
        do {
            let policy = CapturedPolicy()
            releasedPolicy = policy
            view.open = { policy.open($0) }
        }
        #expect(releasedPolicy != nil)
        view.detach()
        #expect(releasedPolicy == nil)
        #expect(view.input == nil && view.delegate == nil && view.textStorage?.length == 0)
        #expect(view.accessibilityChildren()?.isEmpty == true)
        #expect(child.owner == nil && child.accessibilityParent() == nil)
        #expect(!child.accessibilityPerformPress())
    }

    @Test func textSystemMeasuresAndPreservesSelectionOnUnchangedUpdates() throws {
        let document = MarkdownBlockRenderer.render(from: "Before [![Badge](https://example.com/a.png)](#target) after with **bold** and *italic* and `code` and [prose](https://example.com).")
        let block = try #require(document.roots.first)
        let input = MarkdownLinkedImageText.Input(text: ReaderTheme().presentationText(for: block.text), states: [:], dark: false, width: 400)
        let view = MarkdownLinkedImageTextView(frame: .zero)
        #expect(view.textStorage != nil && view.layoutManager != nil && view.textContainer != nil)
        view.update(input)
        #expect(view.string.contains("Badge (Image loading)"))
        view.setSelectedRange(NSRange(location: 0, length: 6))
        view.update(input)
        #expect(view.replacementCount == 1)
        #expect(view.selectedRange() == NSRange(location: 0, length: 6))
        let wide = view.measure(width: 400)
        let narrow = view.measure(width: 160)
        #expect(wide.height > 0 && narrow.height > wide.height)
        #expect(view.measure(width: .infinity).height.isFinite)
        #expect(!view.isEditable && view.isSelectable && !view.importsGraphics)
        #expect(!view.isAutomaticLinkDetectionEnabled && !view.isAutomaticDataDetectionEnabled)
        var dispatched: [URL] = []
        view.open = { dispatched.append($0) }
        let target = try #require(URL(string: "#target"))
        #expect(view.textView(view, clickedOnLink: target, at: 7))
        #expect(dispatched == [target])
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 400, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        let links = (view.accessibilityChildren() ?? []).compactMap { $0 as? any NSAccessibilityProtocol }
            .filter { $0.accessibilityRole() == .link }
        let first = try #require(links.first)
        #expect(first.accessibilityLabel()?.contains("Badge") == true)
        #expect(first.accessibilityPerformPress())
        #expect(dispatched == [target, target])
        view.detach()
        #expect(view.delegate == nil && view.input == nil)
        #expect(view.textView(view, clickedOnLink: target, at: 7))
        #expect(dispatched == [target, target])
    }
}
