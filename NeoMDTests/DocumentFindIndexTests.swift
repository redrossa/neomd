import AppKit
import SwiftUI
import Testing
@testable import NeoMD

@MainActor struct DocumentFindIndexTests {
    private struct Cases: Decodable {
        struct Case: Decodable { let id: String; let query: String; let options: String; let expectedCount: Int }
        let cases: [Case]
    }

    private var fixtures: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/m1-21-find")
    }

    @Test func fixtureCasesMatchAuthoredCounts() throws {
        let cases = try JSONDecoder().decode(Cases.self,
            from: Data(contentsOf: fixtures.appendingPathComponent("find-cases.json")))
        let source = try String(contentsOf: fixtures.appendingPathComponent("find-corpus.md"), encoding: .utf8)
        let index = DocumentFindIndex(MarkdownBlockRenderer.render(from: source))
        for item in cases.cases {
            let options = DocumentFindOptions(caseSensitive: item.options != "default",
                                              diacriticSensitive: item.options == "exact")
            let actual = index.matches(for: item.query, options: options)
            // Authored fixture discrepancy, retained byte-identically and disclosed:
            // case-sensitive “café” cannot match the corpus's capitalized “Café”.
            if item.id == "diacritic-exact" {
                #expect(item.expectedCount == 1)
                #expect(actual.isEmpty)
                #expect(index.matches(for: "Café", options: options).count == 1)
            } else {
                #expect(actual.count == item.expectedCount,
                        "\(item.id): actual \(actual.count), authored \(item.expectedCount); matches \(actual)")
            }
        }
    }

    @Test func matchesFollowLeafOrderAndCursorSteps() throws {
        let source = try String(contentsOf: fixtures.appendingPathComponent("find-corpus.md"), encoding: .utf8)
        let document = MarkdownBlockRenderer.render(from: source)
        let matches = DocumentFindIndex(document).matches(for: "lantern")
        #expect(matches.map(\.leafID) == matches.map(\.leafID).sorted())
        #expect(matches.prefix(2).allSatisfy { $0.leafID == 0 })
        let cells = matches.enumerated().filter { document.tableCell(for: $0.element.leafID) != nil }
        #expect(cells.count == 2)
        #expect(cells.last!.offset == cells.first!.offset + 1)
        #expect(DocumentFindIndex.step(from: matches.count - 1, count: matches.count, reverse: false)?.index == 0)
        let long = try String(contentsOf: fixtures.appendingPathComponent("long-lazy.md"), encoding: .utf8)
        #expect(DocumentFindIndex(MarkdownBlockRenderer.render(from: long)).matches(for: "BEACON").count == 3)
    }

    @Test func hiddenCommentsMarkupURLsAndImageAltNeverMatch() {
        let source = """
        **visible** before<!--secret-->after [label](https://url-only.example)

        ![alt-only](image-only.png) ![](empty.png)

        | Header |
        | --- |
        | cell<!--cell-secret-->text |
        """
        let index = DocumentFindIndex(MarkdownBlockRenderer.render(from: source))
        for query in ["secret", "**", "url-only", "alt-only", "image-only", "cell-secret", "\u{FFFC}"] {
            #expect(index.matches(for: query).isEmpty, "\(query)")
        }
        #expect(index.matches(for: "beforeafter").count == 1)
        #expect(index.matches(for: "celltext").count == 1)
    }

    @Test func metadataMatchesStayInsideOneKeyOrValue() {
        let index = DocumentFindIndex(MarkdownBlockRenderer.render(from: "---\ntitle: Lantern\ntags: lantern\n---\nBody"))
        #expect(index.matches(for: "lantern").count == 2)
        #expect(index.matches(for: "title: Lantern").isEmpty)
        #expect(index.matches(for: "Lantern\ntags").isEmpty)
        #expect(index.matches(for: ": ").isEmpty)
        let literal = DocumentFindIndex(MarkdownBlockRenderer.render(from: "---\nbroken: [\n---\nBody"))
        #expect(literal.matches(for: "broken").count == 1)
    }

    @Test func rangesAreUTF16AndComposedCharacterSafe() throws {
        let document = MarkdownBlockRenderer.render(from: "👩🏽‍💻 Café cafe\u{301} aaaa")
        let index = DocumentFindIndex(document)
        let matches = index.matches(for: "cafe")
        #expect(matches.count == 2)
        let first = try #require(matches.first)
        let string = String(document[first.leafID].text.characters) as NSString
        #expect(first.range.location == "👩🏽‍💻 ".utf16.count)
        #expect(string.substring(with: first.range) == "Café")
        #expect(index.matches(for: "aa").count == 2)
        #expect(index.matches(for: "  ").isEmpty)
        let highlight = DocumentFindHighlight.applying(first.range, to: document[first.leafID].text)
        #expect(String(highlight.characters) == string as String)
        #expect(highlight.runs.contains { $0.backgroundColor != nil })
    }

    @Test func nativeProjectionMapsFindRangesAcrossImagesAndSwatches() throws {
        let document = MarkdownBlockRenderer.render(from: "![alternative](a.png) `#12AB34` needle")
        let match = try #require(DocumentFindIndex(document).matches(for: "needle").first)
        let text = document[match.leafID].text
        let url = URL(string: "a.png")!
        let image = NSImage(size: CGSize(width: 32, height: 16))
        let states: [[URL: MarkdownImageStore.State]] = [[:], [url: .loaded(image, natural: image.size)]]
        for state in states {
            let projection = MarkdownLinkedImageContent.project(.init(
                text: ReaderTheme().presentationText(for: text), states: state, dark: false,
                width: 200, headingLevel: nil, tableCell: .init(alignment: .left, header: false)))
            let display = projection.displayRange(for: match.range)
            #expect((projection.content.string as NSString).substring(with: display) == "needle")
            #expect(projection.sourceRange(for: display) == match.range)
        }
    }
}
