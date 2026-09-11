import Foundation
import Testing
@testable import NeoMD

struct MarkdownFrontMatterTests {
    @Test func boundaryFixturesPreserveExactPhysicalLines() throws {
        for item in try metadataFixtureCases("boundary-cases.json") {
            let source = item["source"] as! String
            let result = MarkdownFrontMatter.extract(source)
            if let file = item["file"] as? String {
                let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                let data = try Data(contentsOf: root.appendingPathComponent("docs/fixtures/m1-15-content/" + file))
                #expect(Array(data) == Array(source.utf8))
            }
            #expect((result != nil) == item["recognized"] as! Bool, "\(item["id"]!)")
            if item["id"] as? String == "double-bom" {
                #expect(Array(source.utf8.prefix(9)) == [239, 187, 191, 239, 187, 191, 45, 45, 45])
                #expect(MarkdownFrontMatter.extract("\u{FEFF}\u{FEFF}---\na: one\n---\nBody") == nil)
            }
            guard let result, let expectedBody = item["body"] as? String else { continue }
            #expect(String(result.body) == expectedBody)
            #expect(String(result.candidate) + result.body == source)
            #expect(result.parserSource.utf8.filter { $0 == 10 || $0 == 13 } == source.utf8.filter { $0 == 10 || $0 == 13 })
            #expect(result.parserSource.hasSuffix(result.body))
            guard case .formatted = result.content else { Issue.record("Valid envelope failed: \(item["id"]!)"); continue }
            if let line = item["bodyLine"] as? Int {
                let document = CMarkDocument(markdown: source, parserSource: result.parserSource)
                let originalLine = document.sourceLine(line).map { String(decoding: $0, as: UTF8.self) }
                #expect(originalLine == result.body.split(whereSeparator: \.isNewline).first.map(String.init))
            }
        }
    }

    @Test func metadataAndRecoveryArePlainNonemptyLeadingLeaves() {
        for source in ["---\na: '**bold** [link](nearby.md) <!--data--> :smile:'\n---\n", "\u{FEFF}---\r\na: [bad\r\n---\r\n"] {
            let document = MarkdownBlockRenderer.render(from: source)
            #expect(document.nodes.count == 1)
            let block = document.nodes[0]
            guard case .metadata = block.kind else { Issue.record("Expected metadata leaf"); continue }
            #expect(block.id == 0 && block.parentID == nil && block.childIDs.isEmpty)
            #expect(!block.text.characters.isEmpty)
            #expect(block.anchors.isEmpty)
            for run in block.text.runs {
                #expect(run.link == nil && run.markdownImage == nil && run.markdownInlineStyle == nil)
                #expect(run.markdownColorReference == nil && run.markdownGeneratedReference == nil)
                #expect(run.inlinePresentationIntent == nil)
            }
            if case .metadata(.literal(let candidate)) = block.kind {
                #expect(String(candidate) == source)
                #expect(String(block.text.characters) == source)
            }
        }
    }
}
