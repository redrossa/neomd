import Foundation
import Testing
@testable import NeoMD

struct CMarkParityTests {
    @Test func supportedExtensionsAndFlattenedPresentation() throws {
        let blocks = MarkdownBlockRenderer.blocks(from: """
        https://example.com www.example.com user@example.com ~single~ &amp; \\*

        | A | B |
        | - | - |
        | C | D |

        ![image **alt**](photo.png)

        [empty]()

        <div>literal</div>
        """)
        #expect(blocks.map { String($0.text.characters) } == [
            "https://example.com www.example.com user@example.com single & *", "A", "B", "C", "D", "image alt", "empty", "<div>literal</div>"
        ])
        #expect(Set(blocks[0].text.runs.compactMap { $0.link?.absoluteString }) == ["https://example.com", "http://www.example.com", "mailto:user@example.com"])
        #expect(blocks[0].text.runs.contains { $0.inlinePresentationIntent == .strikethrough })
        #expect(blocks[5].text.runs.allSatisfy { $0.imageURL == URL(string: "photo.png") })
        #expect(blocks[5].text.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized })
        #expect(blocks[6].text.runs.allSatisfy { $0.link == nil })
        #expect(blocks[7].text.inlinePresentationIntent == .blockHTML)
    }

    @Test nonisolated func concurrentParsingPreservesExtensions() async {
        let source = Array(repeating: "~single~", count: 200).joined(separator: "\n\n")
        let mismatches = await withTaskGroup(of: Int.self, returning: Int.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    await Task.detached {
                        var mismatches = 0
                        for _ in 0..<40 {
                            let blocks = MarkdownBlockRenderer.blocks(from: source)
                            if blocks.count != 200 || blocks.contains(where: {
                                String($0.text.characters) != "single"
                                    || $0.text.inlinePresentationIntent != .strikethrough
                            }) { mismatches += 1 }
                        }
                        return mismatches
                    }.value
                }
            }
            var total = 0
            for await count in group { total += count }
            return total
        }
        #expect(mismatches == 0)
    }

    @Test func emptyContainersAndCodeBoundaries() throws {
        #expect(MarkdownBlockRenderer.blocks(from: ">\n\n- \n\n```\n```\n\n> [^unused]: hidden").isEmpty)
        let code = try #require(MarkdownBlockRenderer.blocks(from: "```python extra\r\n\r\n\tx  =  1\r\n```").first)
        #expect(code.kind == .codeBlock(language: "python"))
        #expect(String(code.text.characters) == "\n\tx  =  1\n")
    }

    @Test func deeplyNestedInputUsesIterativeTraversal() throws {
        let source = String(repeating: "> ", count: 1000) + "deep **text**[^x]\n\n[^x]: note"
        let blocks = MarkdownBlockRenderer.blocks(from: source)
        #expect(blocks.first?.leaves.first.map { String($0.text.characters) } == "deep text1")
        let ancestors = MarkdownBlock.lazyAncestors(in: blocks)
        #expect(ancestors.count >= 1002)
        #expect(MarkdownBlock.anchorTargets(in: blocks).count == 2)
    }

    @Test(arguments: ["<a href id='x'>text</a>", "<a href='u' id='x'>text</a>", "<a id='x'>", "`<a id='x'></a>`", "\\<a id='x'>\\</a>"])
    func nonAnchorMarkupRemainsLiteral(_ source: String) {
        let blocks = MarkdownBlockRenderer.blocks(from: source)
        #expect(MarkdownBlock.anchorTargets(in: blocks).isEmpty)
        #expect(blocks.flatMap(\.leaves).contains { String($0.text.characters).contains("<a") })
    }
}
