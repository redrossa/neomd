import Foundation
import Testing
@testable import NeoMD

struct EmojiCueTests {
    private struct Vector: Decodable {
        let id: String
        let markdown: String
        let expected_text: String
    }

    @Test func approvedProvenanceVectors() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("docs/fixtures/m1-13-cues/emoji-cases.json"))
        let vectors = try JSONDecoder().decode([Vector].self, from: data)
        #expect(vectors.count == 22)
        for vector in vectors {
            #expect(text(vector.markdown) == vector.expected_text, "\(vector.id)")
        }
    }

    @Test func everyPinnedAliasPreservesUnicodeScalars() {
        #expect(CMarkEmojiExtension.aliases.count == 1913)
        for (alias, expected) in CMarkEmojiExtension.aliases {
            #expect(Array(text(":" + alias + ":").unicodeScalars) == Array(expected.unicodeScalars), "\(alias)")
        }
    }

    @Test func imageAlternativesAndReferenceLabelsRetainContext() {
        #expect(text("![:smile:](badge.png)") == ":smile:")
        #expect(text("[![:smile:](badge.png)](#target)") == ":smile:")
        #expect(text("[:smile:][ref]\n\n[ref]: https://example.com/:heart:") == "😄")
        #expect(text("![:smile:][ref]\n\n[ref]: badge.png") == ":smile:")
        let document = CMarkBlockAdapter(document: CMarkDocument(markdown: "[**:smile:**](https://example.com/:heart:)")).render()
        let runs = document.nodes.flatMap { Array($0.text.runs) }
        #expect(runs.contains { $0.link?.absoluteString == "https://example.com/:heart:" &&
            $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    }

    @Test nonisolated func concurrentCandidatesKeepTheirOwnPayloads() async {
        let mismatches = await withTaskGroup(of: Int.self, returning: Int.self) { group in
            for worker in 0..<16 {
                group.addTask {
                    await Task.detached {
                        var failures = 0
                        for iteration in 0..<40 {
                            let prefix = "\(worker)-\(iteration) "
                            let source = prefix + "\\:smile: :heart: ![:smile:](image.png) [:smile:](#target)"
                            let document = MarkdownBlockRenderer.render(from: source)
                            let actual = document.nodes.map { String($0.text.characters) }.joined()
                            if actual != prefix + ":smile: ❤️ :smile: 😄" { failures += 1 }
                        }
                        return failures
                    }.value
                }
            }
            var total = 0
            for await count in group { total += count }
            return total
        }
        #expect(mismatches == 0)
    }

    @Test func rawMarkupAndDestinationsAreNotRewritten() {
        #expect(text("<script>:smile:</script>") == "<script>:smile:</script>")
        #expect(text("before <span title=':smile:'>after</span>") == "before <span title=':smile:'>after</span>")
        #expect(text("<user@example.com> www.example.com/:smile:") == "user@example.com www.example.com/:smile:")
    }

    private func text(_ source: String) -> String {
        let document = CMarkBlockAdapter(document: CMarkDocument(markdown: source)).render()
        return document.nodes.map { String($0.text.characters) }.joined()
    }
}
