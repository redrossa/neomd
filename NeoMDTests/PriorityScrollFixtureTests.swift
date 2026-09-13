import CryptoKit
import Foundation
import Testing
@testable import NeoMD

struct PriorityScrollFixtureTests {
    @Test func nativeNavigationCorpusPreservesRootsAndFifthTarget() throws {
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("docs/fixtures")
        let data = try Data(contentsOf: fixtures.appendingPathComponent("m1-priority-e2e/priority-scroll-navigation.md"))
        #expect(data.count == 33234)
        #expect(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            == "88f03d5174bff5835947df57964fbad1bffe23c471427520f3bf1ae83adfde09")
        let source = try String(contentsOf: fixtures.appendingPathComponent("m1-p9-scroll/mixed-heights.md"), encoding: .utf8)
        let original = MarkdownBlockRenderer.render(from: Array(repeating: source, count: 8).joined(separator: "\n"))
        let amended = MarkdownBlockRenderer.render(from: try #require(String(data: data, encoding: .utf8)))
        #expect(amended.rootIDs == original.rootIDs)
        #expect(amended.nodes.map(\.kind) == original.nodes.map(\.kind))
        #expect(amended.nodes.map(\.childIDs) == original.nodes.map(\.childIDs))
        #expect(amended.anchorTargets == original.anchorTargets)
        let tops = amended.nodes.filter { String($0.text.characters) == "P9 top" }
        #expect(tops.count == 8)
        let target = try #require(amended.anchorTargets["p9-top-4"])
        #expect(target == tops[4].id)
        let index = try #require(amended.rootIDs.firstIndex(of: target))
        let paragraphID = amended.rootIDs[index + 1]
        let paragraphs = amended.nodes.filter { String($0.text.characters).contains("P9-FIFTH-ONLY") }
        #expect(paragraphs.count == 1)
        #expect(paragraphs.first?.id == paragraphID)
        #expect(paragraphs.first.map { String($0.text.characters) }
            == "AMBER P9-FIFTH-ONLY is the top sentinel. This is a read-only, local, mixed-height scrolling corpus. End sentinel is an explicit navigation control, not a scrolling trigger. The document contains no images or background network activity.")
        let firstParagraph = try #require(amended.nodes.first { String($0.text.characters).hasPrefix("AMBER is") })
        let firstRun = try #require(firstParagraph.text.runs.first)
        #expect(String(firstParagraph.text[firstRun.range].characters) == "AMBER")
        #expect(firstRun.link?.absoluteString == "#p9-top-4")
    }
}
