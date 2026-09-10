import AppKit
import SwiftUI
import Testing
@testable import NeoMD

@MainActor
struct NativeInlineLeafTests {
    @Test func ordinaryLeavesKeepStorageSelectionFontsBaselinesAndDispatch() throws {
        for source in ["Ordinary **bold** *italic* `code` [link](#target) wrapping words wrapping words wrapping words",
                       "# Heading [link](#target)", "> [!NOTE]\n> Alert body [link](#target)"] {
            let block = try #require(MarkdownBlockRenderer.render(from: source).leaves.first(where: { !$0.text.characters.isEmpty }))
            let level: Int? = { if case .heading(let n) = block.kind { return n }; return nil }()
            let view = MarkdownLinkedImageTextView(frame: .zero)
            let storage = try #require(view.textStorage)
            let selected = NSRange(location: 0, length: 8)
            var opened: [URL] = []
            view.open = { opened.append($0) }
            for scale in [CGFloat(1), 1.5, 2] {
                for dark in [false, true, false] {
                    for width in [CGFloat(836), 400] {
                        let input = MarkdownLinkedImageText.Input(text: ReaderTheme(scale: scale).presentationText(for: block.text, headingLevel: level), states: [:], dark: dark, width: width, headingLevel: level, scale: scale)
                        let previouslyUpdated = view.input != nil
                        view.update(input)
                        #expect(view.textStorage === storage)
                        #expect(view.string == String(block.text.characters))
                        if previouslyUpdated { #expect(view.selectedRange() == selected) }
                        view.setSelectedRange(selected)
                        let replacements = view.replacementCount
                        view.update(input)
                        #expect(view.replacementCount == replacements && view.selectedRange() == selected)
                        let size = view.measure(width: width)
                        view.frame.size = size
                        let baseline = MarkdownLinkedImageContent.firstBaseline(input)
                        #expect(size.height > 0 && size.height.isFinite && baseline > 0 && baseline <= size.height)
                        #expect(abs(baseline - view.firstBaselineOffsetFromTop) < 0.01)
                        let font = try #require(storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
                        #expect(font.pointSize == NSFont.preferredFont(forTextStyle: ReaderTheme.textStyle(headingLevel: level)).pointSize * scale)
                        print("INLINE_LEAF level=\(String(describing: level)) scale=\(scale) dark=\(dark) width=\(width) size=\(size) baseline=\(baseline) font=\(font.pointSize) selection=\(view.selectedRange())")
                    }
                }
            }
            let link = try #require((view.accessibilityChildren() as? [MarkdownImageAccessibilityElement])?.first)
            #expect(link.accessibilityPerformPress() && opened.count == 1)
            #expect(view.textView(view, clickedOnLink: URL(string: "#target")!, at: link.range.location))
            #expect(opened.count == 2 && view.isSelectable && !view.isEditable)
            view.detach()
            #expect(view.textStorage === storage && storage.length == 0 && view.input == nil)
            #expect(link.owner == nil && !link.accessibilityPerformPress())
        }
    }
}
