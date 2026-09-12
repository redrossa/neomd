import Foundation
import Testing
@testable import NeoMD

struct DocumentRecoveryFixtureTests {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/fixtures/m1-17-recovery")
    static let files = ["empty.md", "bom-only.md", "whitespace-only.md", "utf8-emoji-endings.md",
                        "invalid-utf8.md", "truncated-utf8.md", "binary-junk.md", "deep-nesting.md"]

    @Test func emptyBOMAndWhitespaceDecodeToEmptyRendering() throws {
        for (name, expected) in [("empty.md", ""), ("bom-only.md", ""),
                                 ("whitespace-only.md", "\n\n   \n\t\n \n")] {
            let text = try MarkdownTextDecoder.text(from: Data(contentsOf: Self.folder.appendingPathComponent(name)))
            #expect(text == expected)
            #expect(MarkdownBlockRenderer.render(from: text).roots.isEmpty)
        }
    }

    @Test func mixedEndingsPreserveUnicodeScalarsCodeAndTableText() throws {
        let bytes = try Data(contentsOf: Self.folder.appendingPathComponent("utf8-emoji-endings.md"))
        let source = try #require(String(data: bytes, encoding: .utf8))
        let text = try MarkdownTextDecoder.text(from: bytes)
        let expected = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        #expect(Array(text.unicodeScalars) == Array(expected.unicodeScalars))
        #expect(!text.contains("\r") && text.hasSuffix("🏁"))
        let rendered = MarkdownBlockRenderer.render(from: text)
        let leaves = rendered.leaves.map { String($0.text.characters) }
        let visible = leaves.joined(separator: "\n")
        for scalarSequence in ["👨‍👩‍👧‍👦", "🇯🇵", "👍🏽", "1️⃣", "é", "é", "नमस्ते", "مرحبا بالعالم", "日本語のメモ", "🏁"] {
            #expect(text.unicodeScalars.elementsEqual(expected.unicodeScalars))
            #expect(visible.range(of: scalarSequence, options: .literal) != nil)
        }
        #expect(leaves.contains("let greeting = \"héllo 🌍\" // CRLF code line\nlet tab = \"\\t\"\nprint(greeting)\n"))
        let table = try #require(rendered.nodes.first { $0.isTable })
        let cells = rendered.tableCells(in: table.id).map { String(rendered.nodes[$0.leafID].text.characters) }
        #expect(cells == ["Emoji", "Meaning", "✅", "done", "❌", "not done"])
    }

    @Test func permissiveCompatibilityFixturesAreNotInventedEncodingRejections() throws {
        for (name, sentinels) in [("invalid-utf8.md", ["Invalid UTF-8 fixture", "Valid tail:", "caf"]),
                                   ("truncated-utf8.md", ["Truncated fixture", "cut mid-character:"]),
                                   ("binary-junk.md", [])] {
            let bytes = try Data(contentsOf: Self.folder.appendingPathComponent(name))
            #expect(String(data: bytes, encoding: .utf8) == nil)
            let text = try MarkdownTextDecoder.text(from: bytes)
            #expect(!text.isEmpty)
            for sentinel in sentinels { #expect(text.contains(sentinel)) }
            #expect(!MarkdownBlockRenderer.render(from: text).roots.isEmpty)
        }
    }

    @Test func boundedMalformedFixtureRetainsSentinelsAndReleasesFlatRendering() throws {
        let text = try MarkdownTextDecoder.text(from: Data(contentsOf: Self.folder.appendingPathComponent("deep-nesting.md")))
        let rendered = MarkdownBlockRenderer.render(from: text)
        let visible = rendered.leaves.map { String($0.text.characters) }.joined(separator: "\n")
        for sentinel in ["deepest quote leaf DEEP-Q-3000", "level 200", "inner", "code never closed", "still code"] {
            #expect(visible.contains(sentinel))
        }
        #expect(rendered.nodes.contains { $0.kind == .thematicBreak })
    }
}
