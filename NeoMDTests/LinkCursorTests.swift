import AppKit
import Testing
@testable import NeoMD

@MainActor
struct LinkCursorTests {
    @Test func nativePolicyPreservesAuthoredAndGeneratedLinkRanges() throws {
        let document = MarkdownBlockRenderer.render(from: """
        Plain [external **bold** *italic*](https://example.com) [local](nearby.md) [section](#target) note[^n].

        Again[^n].

        # Target

        [^n]: Note body.
        """)
        let view = MarkdownLinkedImageTextView(frame: .zero)
        defer { view.detach() }
        #expect(view.linkTextAttributes?[.cursor] as? NSCursor === NSCursor.pointingHand)
        #expect(view.linkTextAttributes?[.foregroundColor] as? NSColor == NSColor.linkColor)
        #expect(view.linkTextAttributes?[.underlineStyle] as? Int == NSUnderlineStyle.single.rawValue)
        var destinations = Set<URL>()
        var references = 0
        var returns = 0
        var dispatched = false
        view.open = { _ in dispatched = true }
        for leaf in document.roots.flatMap({ document.leaves(in: $0.id) }) where !leaf.text.characters.isEmpty {
            let input = MarkdownLinkedImageText.Input(text: leaf.text, states: [:], dark: false, width: 400)
            view.update(input)
            let storage = try #require(view.textStorage)
            // No attachments in this source: native UTF-16 offsets map directly to each rendered run.
            var offset = 0
            for run in leaf.text.runs {
                let text = String(leaf.text.characters[run.range])
                let length = text.utf16.count
                if run.markdownGeneratedReference == .footnoteReference { references += 1 }
                if run.markdownGeneratedReference == .footnoteReturn { returns += 1 }
                for index in offset..<(offset + length) {
                    #expect(storage.attribute(.link, at: index, effectiveRange: nil) as? URL == run.link)
                    #expect(storage.attribute(.cursor, at: index, effectiveRange: nil) == nil)
                }
                if let link = run.link { destinations.insert(link) }
                offset += length
            }
            #expect(offset == storage.length)
            view.setSelectedRange(NSRange(location: 0, length: min(5, storage.length)))
            let selection = view.selectedRange()
            var changed = input
            changed.dark = true
            changed.width = 180
            changed.scale = 1.5
            view.update(changed)
            #expect(view.measure(width: 180).height > 0)
            #expect(view.selectedRange() == selection)
            #expect(!view.isEditable && view.isSelectable)
        }
        #expect(references == 2 && returns == 2)
        for target in ["https://example.com", "nearby.md", "#target"] {
            #expect(destinations.contains(try #require(URL(string: target))))
        }
        #expect(!dispatched)
    }

    @Test func linkedImageAndFallbackRangesRetainLinkOnlyCursorPolicy() throws {
        let document = MarkdownBlockRenderer.render(from: "Plain [![Badge](https://example.com/a.png)](#target) ordinary ![Unlinked](https://example.com/a.png)")
        let text = try #require(document.roots.first?.text)
        let imageURL = try #require(URL(string: "https://example.com/a.png"))
        let target = try #require(URL(string: "#target"))
        let bitmap = NSImage(size: CGSize(width: 64, height: 32))
        let states: [MarkdownImageStore.State] = [.loading, .unavailable(.missing), .loaded(bitmap, natural: bitmap.size)]
        let view = MarkdownLinkedImageTextView(frame: .zero)
        defer { view.detach() }
        for state in states {
            view.update(.init(text: text, states: [imageURL: state], dark: false, width: 300))
            let storage = try #require(view.textStorage)
            var linkedLength = 0
            var linkedAttachments = 0
            var unlinkedAttachments = 0
            for index in 0..<storage.length {
                let link = storage.attribute(.link, at: index, effectiveRange: nil) as? URL
                #expect(storage.attribute(.cursor, at: index, effectiveRange: nil) == nil)
                if let link { #expect(link == target); linkedLength += 1 }
                if storage.attribute(.attachment, at: index, effectiveRange: nil) != nil {
                    if link == nil { unlinkedAttachments += 1 } else { linkedAttachments += 1 }
                }
            }
            if case .loaded = state {
                #expect(linkedLength == 1 && linkedAttachments == 1 && unlinkedAttachments == 1)
            } else {
                let status = state == .loading ? "Image loading" : "Image unavailable"
                #expect(linkedLength == "Badge (\(status))".utf16.count)
                #expect(view.string.contains("Unlinked (\(status))"))
                #expect(linkedAttachments == 0 && unlinkedAttachments == 0)
            }
            #expect(storage.attribute(.link, at: 0, effectiveRange: nil) == nil)
            #expect(view.linkTextAttributes?[.cursor] as? NSCursor === NSCursor.pointingHand)
        }
    }
}
