import AppKit
import SwiftUI
import Testing
@testable import NeoMD

@MainActor struct ReadingSizePresentationTests {
    @Test func semanticNativeFontsScriptsAndCodeScaleWithoutChangingText() throws {
        let source = MarkdownBlockRenderer.render(from: "Plain `code` H<sub>2</sub> x<sup>3</sup> [link](https://example.com)").leaves[0].text
        let styles: [(Int?, NSFont.TextStyle)] = [(nil, .body), (1, .largeTitle), (2, .title1),
            (3, .title2), (4, .title3), (5, .headline), (6, .subheadline)]
        for size in ReadingSize.allCases {
            for (level, style) in styles {
                let theme = ReaderTheme(scale: size.rawValue)
                let presented = theme.presentationText(for: source, headingLevel: level)
                let content = MarkdownLinkedImageContent.make(.init(text: presented, states: [:], dark: false,
                    width: 760, headingLevel: level, scale: size.rawValue))
                #expect(content.string == String(source.characters))
                let font = try #require(content.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
                let expectedSize: CGFloat = NSFont.preferredFont(forTextStyle: style).pointSize * CGFloat(size.rawValue)
                #expect(font.pointSize == expectedSize)
                for (token, offset) in [("2", -3.0), ("3", 5.0)] {
                    let index = (content.string as NSString).range(of: token).location
                    #expect((content.attribute(.baselineOffset, at: index, effectiveRange: nil) as? NSNumber)?.doubleValue == offset * size.rawValue)
                }
                #expect(presented.runs.map(\.link) == source.runs.map(\.link))
                #expect(presented.runs.map(\.inlinePresentationIntent) == source.runs.map(\.inlinePresentationIntent))
            }
            let code = "  let x = 1\n\tprint(x)\n"
            let native = MarkdownLinkedImageContent.make(.init(text: AttributedString(code), states: [:], dark: false,
                width: 760, headingLevel: nil, scale: size.rawValue, code: true))
            #expect(native.string == code)
            let font = try #require(native.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
            let expectedCodeSize: CGFloat = NSFont.preferredFont(forTextStyle: .callout).pointSize * CGFloat(size.rawValue)
            #expect(font.pointSize == expectedCodeSize)
        }
    }

    @Test func scaleKeepsSelectionEndpointsFindRangesAndTableSeparators() throws {
        let document = MarkdownBlockRenderer.render(from: "Alpha lantern\n\n```\n  lantern\n```\n\n| Key | Value |\n| --- | --- |\n| lantern | omega |")
        let projection = DocumentTextProjection.rendered(document, presentation: UUID())
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: projection)
        let selection = try #require(projection.entireSelection)
        _ = state.setSelection(selection, scope: state.scope)
        let copied = state.copiedText
        #expect(copied.contains("Key\tValue\nlantern\tomega"))
        #expect(copied.contains("  lantern"))
        let index = DocumentFindIndex(document)
        let matches = index.matches(for: "lantern")
        #expect(matches.count == 3)
        for size in ReadingSize.allCases {
            for leaf in document.leaves {
                let input = MarkdownLinkedImageText.Input(text: ReaderTheme(scale: size.rawValue).presentationText(for: leaf.text),
                    states: [:], dark: false, width: 760, headingLevel: nil, scale: size.rawValue)
                let converted = MarkdownLinkedImageContent.project(input)
                #expect(converted.content.string == String(leaf.text.characters))
                for match in matches where match.leafID == leaf.id {
                    #expect((converted.content.string as NSString).substring(with: match.range).lowercased() == "lantern")
                }
            }
            state.replaceProjection(projection)
            #expect(state.selection == selection && state.copiedText == copied)
            let registered = state.register(selection.anchor.key, scope: state.scope)
            let token = try #require(registered)
            #expect(state.slice(for: token) != nil)
            state.unregister(token)
            #expect(index.matches(for: "lantern") == matches)
        }
    }

    @Test func removedDepthCaptionClearsOnlyAnAffectedEndpoint() throws {
        let id = UUID()
        let body = DocumentTextProjection.Fragment(key: .init(leafID: 0), text: "Body")
        let caption = DocumentTextProjection.Fragment(key: .init(leafID: 0, part: -10), text: "Depth 12")
        let withCaption = DocumentTextProjection(presentation: id, fragments: [caption, body])
        let withoutCaption = DocumentTextProjection(presentation: id, fragments: [body])
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: withCaption)
        _ = state.setSelection(withCaption.entireSelection, scope: state.scope)
        state.replaceProjection(withoutCaption)
        #expect(state.selection == nil)
        _ = state.setSelection(withoutCaption.entireSelection, scope: state.scope)
        let ordinary = state.selection
        state.replaceProjection(withCaption)
        #expect(state.selection == ordinary)
        state.replaceProjection(withoutCaption)
        #expect(state.selection == ordinary && state.copiedText == "Body")
    }

    @Test func listQuoteAndTableGeometryStayFiniteWithinUnscaledColumn() {
        let document = MarkdownBlockRenderer.render(from: "> - [x] Task\n>   - Nested\n\n| H | V |\n| --- | --- |\n| A | B |")
        for size in ReadingSize.allCases {
            let scale = CGFloat(size.rawValue)
            let table = MarkdownTableLayout(viewportWidth: 320, preferredContentWidths: [4000, 4000], scale: scale)
            #expect(table.viewportWidth == 320 && table.overflows)
            #expect(table.padding == MarkdownTableLayout.cellPadding * scale)
            #expect(table.minimumRowHeight == (MarkdownTableLayout.minimumCellHeight + 2 * MarkdownTableLayout.cellPadding) * scale)
            for root in document.rootIDs {
                let geometry = MarkdownContainerGeometry(document: document, rootID: root, width: 320, scale: scale)
                #expect(geometry.viewEntries.allSatisfy { $0.width.isFinite && $0.width >= 0 && $0.width <= 320 })
            }
            #expect(DocumentReaderLayout.columnWidth(for: 400) == 320)
        }
    }
}
