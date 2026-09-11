import AppKit
import Testing
@testable import NeoMD

/// Source-to-display correspondence for one cell's attributed payload.
///
/// Only in-memory attributed conversion is exercised: no loader, text view,
/// window, selection or layout host is created, so live selection behaviour stays
/// unverified.
@MainActor
struct MarkdownCellDisplayProjectionTests {
    private let url = URL(string: "a.png")!

    private func input(_ source: String, states: [URL: MarkdownImageStore.State] = [:],
                       cell: MarkdownTableCellPresentation? = nil,
                       width: CGFloat = 200) throws -> MarkdownLinkedImageText.Input {
        let document = MarkdownBlockRenderer.render(from: source)
        let block = try #require(document.roots.first)
        return .init(text: ReaderTheme().presentationText(for: block.text), states: states,
                     dark: false, width: width, headingLevel: nil, tableCell: cell)
    }

    private func loaded() -> [URL: MarkdownImageStore.State] {
        let bitmap = NSImage(size: CGSize(width: 64, height: 32))
        return [url: .loaded(bitmap, natural: CGSize(width: 64, height: 32))]
    }

    @Test func plainTextSegmentsMapPositionForPosition() throws {
        let projection = MarkdownLinkedImageContent.project(try input("alpha **beta** gamma"))
        #expect(projection.content.string == "alpha beta gamma")
        #expect(projection.source == "alpha beta gamma")
        #expect(projection.segments.allSatisfy { $0.kind == .text })
        #expect(projection.segments.allSatisfy { $0.source == $0.display })
        for location in 0...projection.content.length {
            let range = NSRange(location: location, length: 0)
            #expect(projection.sourceRange(for: range).location == location)
        }
        let beta = (projection.content.string as NSString).range(of: "beta")
        #expect(projection.sourceRange(for: beta) == beta)
        #expect(projection.displayRange(for: beta) == beta)
        // Out-of-range input is clamped rather than trapping.
        let past = NSRange(location: 999, length: 40)
        #expect(NSMaxRange(projection.sourceRange(for: past)) <= projection.source.utf16.count)
        #expect(NSMaxRange(projection.displayRange(for: past)) <= projection.content.length)
    }

    @Test func unicodeScalarsKeepComposedCharacterBoundaries() throws {
        let projection = MarkdownLinkedImageContent.project(try input("e\u{301} 日本語 👩🏽‍💻 tail"))
        #expect(projection.content.string == projection.source)
        let text = projection.content.string as NSString
        let emoji = text.range(of: "👩🏽‍💻")
        #expect(emoji.location != NSNotFound)
        // A boundary inside a surrogate pair expands to the whole sequence.
        let split = NSRange(location: emoji.location, length: 1)
        let mapped = projection.sourceRange(for: split)
        #expect(mapped.location <= emoji.location)
        #expect(NSMaxRange(mapped) >= emoji.location + 2)
        let combining = text.range(of: "e\u{301}")
        #expect(projection.sourceRange(for: combining) == combining)
    }

    @Test func aReplacedImageMapsAtomicallyToItsWholeSpan() throws {
        let projection = MarkdownLinkedImageContent.project(try input("before ![alt](a.png) after",
                                                                      states: loaded()))
        let image = try #require(projection.segments.first { $0.kind == .attachment })
        #expect(image.occurrence != nil)
        #expect(image.display.length == 1, "A loaded image becomes one attachment character")
        #expect(image.source.length == 3, "The alt text keeps its own source length")
        // Any partial display range inside the image covers the whole span, and
        // never pretends the replacement is one to one.
        for location in image.display.location...NSMaxRange(image.display) {
            let mapped = projection.sourceRange(for: NSRange(location: location, length: 0))
            #expect(mapped.length == 0)
            #expect(mapped.location >= image.source.location)
            #expect(mapped.location <= NSMaxRange(image.source))
        }
        let whole = projection.sourceRange(for: image.display)
        #expect(whole.location <= image.source.location)
        #expect(NSMaxRange(whole) >= NSMaxRange(image.source))
        // Plain neighbours still map exactly.
        let before = try #require(projection.segments.first)
        #expect(before.kind == .text && before.source == before.display)
    }

    @Test func fallbackAndStatusTextIsDescribedAsItsOwnSegment() throws {
        let loading = MarkdownLinkedImageContent.project(try input("![alt](a.png)"))
        let unavailable = MarkdownLinkedImageContent.project(
            try input("![alt](a.png)", states: [url: .unavailable(.inaccessible)]))
        #expect(loading.content.string == "alt (Image loading)")
        #expect(unavailable.content.string == "alt (Image unavailable)")
        for projection in [loading, unavailable] {
            let segment = try #require(projection.segments.first { $0.kind == .fallback })
            #expect(segment.occurrence != nil)
            #expect(segment.display.length == projection.content.length)
            #expect(segment.source.length == 3)
            // The displayed status text is described, not silently mapped as text.
            #expect(projection.segments.allSatisfy { $0.kind != .text } || projection.segments.count > 1)
        }
        // The empty-alt carrier is not user text and keeps the Image fallback label.
        let empty = MarkdownLinkedImageContent.project(try input("![](a.png)"))
        #expect(empty.content.string == "Image (Image loading)")
        #expect(empty.source == MarkdownPictureParser.emptyAltCarrier)
        let carrier = try #require(empty.segments.first)
        #expect(carrier.kind == .fallback && carrier.source.length == 1)
    }

    @Test func adjacentSameURLOccurrencesStayDistinctSegments() throws {
        let projection = MarkdownLinkedImageContent.project(
            try input("![one](a.png)![two](a.png)", states: loaded()))
        let images = projection.segments.filter { $0.kind == .attachment }
        #expect(images.count == 2)
        #expect(Set(images.compactMap(\.occurrence)).count == 2)
        #expect(images[0].display.location != images[1].display.location)
        #expect(images[0].source.location != images[1].source.location)
    }

    @Test func rangesRemapAcrossImageStateWidthAndThemeChanges() throws {
        let loadingInput = try input("before ![alt](a.png) after")
        var loadedInput = loadingInput
        loadedInput.states = loaded()
        let loading = MarkdownLinkedImageContent.project(loadingInput)
        let displayed = MarkdownLinkedImageContent.project(loadedInput)
        #expect(loading.content.length != displayed.content.length)
        #expect(loading.source == displayed.source, "The immutable source is retained")

        let text = loading.content.string as NSString
        let before = text.range(of: "before")
        let remapped = displayed.remap(before, from: loading)
        #expect((displayed.content.string as NSString).substring(with: remapped) == "before")
        let after = text.range(of: "after")
        let remappedAfter = displayed.remap(after, from: loading)
        #expect((displayed.content.string as NSString).substring(with: remappedAfter) == "after")
        // A stale range that spanned the longer fallback text is clamped, never
        // allowed past the end of the new payload.
        let stale = NSRange(location: 0, length: loading.content.length)
        let clamped = displayed.remap(stale, from: loading)
        #expect(NSMaxRange(clamped) <= displayed.content.length)
        // Width and theme changes do not move plain-text positions.
        var wide = loadedInput
        wide.width = 640
        let wider = MarkdownLinkedImageContent.project(wide)
        #expect(wider.remap(remapped, from: displayed) == remapped)
        var dark = loadedInput
        dark.dark = true
        let darkened = MarkdownLinkedImageContent.project(dark)
        #expect(darkened.remap(remapped, from: displayed) == remapped)
    }

    @Test func headerWeightAndAlignmentCombineWithInlineStyles() throws {
        let source = "**bold** *slant* `code` <sub>2</sub> [link](https://example.com)"
        let plain = MarkdownLinkedImageContent.project(
            try input(source, cell: .init(alignment: .left, header: false)))
        let header = MarkdownLinkedImageContent.project(
            try input(source, cell: .init(alignment: .center, header: true)))
        let text = plain.content.string as NSString
        #expect(plain.content.string == header.content.string, "Header weight adds no characters")

        func font(_ content: NSAttributedString, _ needle: String) throws -> NSFont {
            try #require(content.attribute(.font, at: text.range(of: needle).location,
                                           effectiveRange: nil) as? NSFont)
        }
        // Every run keeps its own distinction and additionally gains header weight.
        #expect(NSFontManager.shared.traits(of: try font(header.content, "slant")).contains(.italicFontMask))
        #expect(NSFontManager.shared.traits(of: try font(header.content, "slant")).contains(.boldFontMask))
        #expect(!NSFontManager.shared.traits(of: try font(plain.content, "slant")).contains(.boldFontMask))
        #expect(try font(header.content, "code").isFixedPitch)
        #expect(NSFontManager.shared.traits(of: try font(header.content, "code")).contains(.boldFontMask))
        #expect(NSFontManager.shared.traits(of: try font(header.content, "bold")).contains(.boldFontMask))
        #expect(header.content.attribute(.link, at: text.range(of: "link").location,
                                         effectiveRange: nil) != nil)
        #expect((header.content.attribute(.baselineOffset, at: text.range(of: "2").location,
                                          effectiveRange: nil) as? NSNumber)?.doubleValue == -3)

        func alignment(_ content: NSAttributedString) throws -> NSTextAlignment {
            let style = try #require(content.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                as? NSParagraphStyle)
            return style.alignment
        }
        #expect(try alignment(plain.content) == .left)
        #expect(try alignment(header.content) == .center)
        for (value, expected) in [(MarkdownTableStructure.Alignment.unspecified, NSTextAlignment.left),
                                  (.left, .left), (.center, .center), (.right, .right)] {
            let projection = MarkdownLinkedImageContent.project(
                try input("value", cell: .init(alignment: value, header: false)))
            #expect(try alignment(projection.content) == expected)
        }
        // Ordinary prose keeps its existing behaviour: no cell paragraph style.
        let prose = MarkdownLinkedImageContent.project(try input(source))
        #expect(prose.content.attribute(.paragraphStyle, at: 0, effectiveRange: nil) == nil)
    }

    @Test func hiddenCommentsAndSwatchesAddNoDisplayIndexes() throws {
        let hidden = MarkdownLinkedImageContent.project(
            try input("before<!--SECRET-->after", cell: .init(alignment: .left, header: false)))
        #expect(hidden.content.string == "beforeafter")
        #expect(!hidden.content.string.contains("SECRET"))
        #expect(hidden.segments.allSatisfy { $0.kind == .text })
        #expect(hidden.segments.reduce(0) { $0 + $1.display.length } == hidden.content.length)

        let swatch = MarkdownLinkedImageContent.project(
            try input("`#12AB34`", cell: .init(alignment: .left, header: true)))
        #expect(swatch.content.string == "#12AB34", "A swatch consumes no text index")
        #expect(swatch.content.attribute(MarkdownColorSwatch.attribute,
                                         at: swatch.content.length - 1, effectiveRange: nil) != nil)
        #expect(swatch.segments.reduce(0) { $0 + $1.source.length } == swatch.source.utf16.count)
    }
}
