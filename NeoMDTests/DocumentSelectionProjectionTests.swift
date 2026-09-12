import Foundation
import Testing
@testable import NeoMD

@MainActor struct DocumentSelectionProjectionTests {
    private typealias Projection = DocumentTextProjection

    private func projection(_ text: [String], separators: [String] = []) -> Projection {
        Projection(presentation: UUID(), fragments: text.enumerated().map { index, text in
            .init(key: .init(leafID: index), text: text,
                  separator: index > 0 && separators.indices.contains(index - 1) ? separators[index - 1] : "\n\n")
        })
    }

    private func selection(_ a: Int, _ offsetA: Int, _ b: Int, _ offsetB: Int) -> Projection.Selection {
        .init(anchor: .init(key: .init(leafID: a), offset: offsetA),
              extent: .init(key: .init(leafID: b), offset: offsetB))
    }

    @Test func authoredPartialOracleAndReverseAreExact() throws {
        struct Cases: Decodable {
            struct Case: Decodable {
                let id: String
                let fragments: [String]?
                let separators: [String]?
                let anchor: [Int]?
                let extent: [Int]?
                let expected: String?
            }
            let cases: [Case]
        }
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/m1-16-selection/projection-cases.json")
        let cases = try JSONDecoder().decode(Cases.self, from: Data(contentsOf: url))
        let item = try #require(cases.cases.first { $0.id == "three-fragment-partial" })
        let text = try #require(item.fragments), separators = try #require(item.separators)
        let anchor = try #require(item.anchor), extent = try #require(item.extent)
        let expected = try #require(item.expected)
        let model = projection(text, separators: separators)
        #expect(model.copiedText(for: selection(anchor[0], anchor[1], extent[0], extent[1])) == expected)
        #expect(model.copiedText(for: selection(extent[0], extent[1], anchor[0], anchor[1])) == expected)
    }

    @Test func tableAndMetadataJoinsKeepEmptyCells() throws {
        let table = projection(["H1", "H2", "H3", "A1", "A2", "A3", "B1", "", "B3"],
                               separators: ["\t", "\t", "\n", "\t", "\t", "\n", "\t", "\t"])
        #expect(table.copiedText(for: try #require(table.entireSelection)) == "H1\tH2\tH3\nA1\tA2\tA3\nB1\t\tB3")
        #expect(table.copiedText(for: selection(8, 1, 4, 1)) == "2\tA3\nB1\t\tB")
        let empty = projection(["", "", ""], separators: ["\t", "\n"])
        #expect(empty.copiedText(for: try #require(empty.entireSelection)) == "\t\n")
        let metadata = projection(["title", "Selection café", "owner", "Reader"], separators: ["\t", "\n", "\t"])
        #expect(metadata.copiedText(for: try #require(metadata.entireSelection)) == "title\tSelection café\nowner\tReader")
    }

    @Test func literalWhitespaceAndSeparatorsAreNeverTrimmed() throws {
        let code = "\n    let  x = 1  \n\tprint(x)\n\n"
        let model = projection(["*stars*", code, "<!--LITERAL-CODE-COMMENT-->", "   "])
        #expect(model.copiedText(for: selection(1, 0, 1, code.utf16.count)) == code)
        #expect(model.copiedText(for: try #require(model.entireSelection)) ==
                "*stars*\n\n" + code + "\n\n<!--LITERAL-CODE-COMMENT-->\n\n   ")
    }

    @Test func attachmentsKeepSelectablePositionsButEmitNoCopyCharacters() throws {
        let text = "before \u{FFFC} after"
        let fragment = Projection.Fragment(key: .init(leafID: 0), text: text,
                                           attachments: [NSRange(location: 7, length: 1)])
        let model = Projection(presentation: UUID(), fragments: [fragment])
        #expect(model.copiedText(for: try #require(model.entireSelection)) == "before  after")
        #expect(model.slices(for: selection(0, 7, 0, 8)).first?.range == NSRange(location: 7, length: 1))
        #expect(model.copiedText(for: selection(0, 7, 0, 8)).isEmpty)
        let fallback = model.replacing(.init(key: fragment.key, text: "before alt (Image loading) after"))
        #expect(fallback.copiedText(for: try #require(fallback.entireSelection)) == "before alt (Image loading) after")
        // Input validation also makes repeated/overlapping removal descriptors safe.
        let overlapping = Projection.Fragment(key: fragment.key, text: text,
            attachments: [NSRange(location: 7, length: 1), NSRange(location: 7, length: 1), NSRange(location: Int.max, length: Int.max)])
        #expect(overlapping.copiedText(in: NSRange(location: 0, length: Int.max)) == "before  after")
    }

    @Test func utf16BoundsExpandGraphemesAndSnapCollapsedCaretsBackward() {
        let text = "e\u{301} 日本語 👩🏽‍💻 tail"
        #expect(Projection.normalized(NSRange(location: 1, length: 1), in: text) == NSRange(location: 0, length: 2))
        #expect(Projection.normalized(NSRange(location: 1, length: 0), in: text) == NSRange(location: 0, length: 0))
        let emojiStart = "e\u{301} 日本語 ".utf16.count
        let emojiLength = "👩🏽‍💻".utf16.count
        for offset in emojiStart..<(emojiStart + emojiLength) {
            #expect(Projection.normalized(NSRange(location: offset, length: 1), in: text) ==
                    NSRange(location: emojiStart, length: emojiLength))
        }
        #expect(Projection.normalized(NSRange(location: Int.max, length: Int.max), in: text) ==
                NSRange(location: text.utf16.count, length: 0))
    }

    @Test func collapsedInvalidAndEndpointOnlySelectionsDoNotInventSeparators() {
        let model = projection(["Alpha", "Beta", "Gamma"])
        #expect(model.copiedText(for: selection(0, 2, 0, 2)).isEmpty)
        #expect(model.copiedText(for: selection(0, 5, 1, 0)).isEmpty)
        #expect(model.copiedText(for: selection(0, 5, 2, 0)) == "Beta")
        #expect(model.copiedText(for: selection(0, 0, 999, 1)).isEmpty)
        #expect(projection([]).entireSelection == nil)
    }
}
