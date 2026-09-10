import AppKit
import Foundation
import Testing
@testable import NeoMD

struct ColorCueTests {
    private struct Vector: Decodable {
        let id: String
        let normalized_code: String
        let swatch: Bool
        let expected_srgb: [Double]?
    }

    @Test func allApprovedColorVectors() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("docs/fixtures/m1-13-cues/color-cases.json"))
        let vectors = try JSONDecoder().decode([Vector].self, from: data)
        #expect(vectors.count == 49)
        for vector in vectors {
            let color = MarkdownColorReference.parse(vector.normalized_code)
            #expect((color != nil) == vector.swatch, "\(vector.id)")
            if let color, let expected = vector.expected_srgb {
                for (actual, expected) in zip([color.red, color.green, color.blue], expected) {
                    #expect(abs(actual - expected) < 0.000000001, "\(vector.id)")
                }
            }
        }
    }

    @Test func onlyParserOwnedCodeHasColorAndCharactersStayExact() throws {
        let source = "#FFFFFF `#FFFFFF` ` #000000 ` `  #000000  ` ![`#FFFFFF`](image.png)\n\n```\n#FFFFFF\n```"
        let document = MarkdownBlockRenderer.render(from: source)
        let paragraph = try #require(document.roots.first)
        #expect(String(paragraph.text.characters) == "#FFFFFF #FFFFFF #000000  #000000  #FFFFFF")
        #expect(paragraph.text.runs.filter { $0.markdownColorReference != nil }.count == 2)
        #expect(document.roots.last?.text.runs.allSatisfy { $0.markdownColorReference == nil } == true)
    }
}

@MainActor
struct NativeColorCueTests {
    @Test func passiveNativeSwatchesScaleWithoutChangingTextSelectionOrLinks() throws {
        let source = "Before [![Badge](https://example.com/a.png)](#target) `#FFFFFF` next [`rgb(0,0,0)`](#target) end"
        let block = try #require(MarkdownBlockRenderer.render(from: source).roots.first)
        let url = try #require(URL(string: "https://example.com/a.png"))
        let bitmap = NSImage(size: CGSize(width: 16, height: 8))
        let states: [MarkdownImageStore.State] = [.loading, .unavailable(.inaccessible), .loaded(bitmap, natural: CGSize(width: 16, height: 8))]
        for state in states {
            let view = MarkdownLinkedImageTextView(frame: CGRect(x: 0, y: 0, width: 700, height: 200))
            defer { view.detach() }
            var priorString: String?
            for scale in [CGFloat(1), 1.5, 2] {
                let input = MarkdownLinkedImageText.Input(text: ReaderTheme(scale: scale).presentationText(for: block.text),
                    states: [url: state], dark: false, width: 700, scale: scale)
                view.update(input)
                if let priorString { #expect(view.string == priorString) }
                priorString = view.string
                let range = (view.string as NSString).range(of: "#FFFFFF")
                view.setSelectedRange(range)
                let replacements = view.replacementCount
                view.update(input)
                #expect(view.replacementCount == replacements && view.selectedRange() == range)
                let storage = try #require(view.textStorage)
                let font = try #require(storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont)
                #expect(font.pointSize == NSFont.preferredFont(forTextStyle: .body).pointSize * scale)
                #expect(font.isFixedPitch)
                let size = view.measure(width: 700)
                #expect(size.height > 0)
                let bounds = view.swatchBounds()
                #expect(bounds.count == 2)
                #expect(bounds.allSatisfy { $0.0.width == 9 * scale && $0.0.minX >= 0 && $0.0.maxX <= 700 })
                let next = (view.string as NSString).range(of: " next").location
                let layout = try #require(view.layoutManager)
                let container = try #require(view.textContainer)
                let glyphs = layout.glyphRange(forCharacterRange: NSRange(location: next, length: 1), actualCharacterRange: nil)
                let nextBounds = layout.boundingRect(forGlyphRange: glyphs, in: container)
                #expect(bounds[0].0.maxX <= nextBounds.minX + 0.5)
                #expect(storage.attributedSubstring(from: range).string == "#FFFFFF")
                #expect((view.accessibilityChildren() ?? []).count == 2)
                #expect((view.accessibilityChildren() ?? []).compactMap { $0 as? MarkdownImageAccessibilityElement }
                    .contains { $0.alternative == "rgb(0,0,0)" && $0.url?.absoluteString == "#target" })
            }
        }
    }
}
