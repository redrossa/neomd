import CoreGraphics
import CryptoKit
import Foundation
import Testing
@testable import NeoMD

/// Model preparation only: never hosts native text, sends events, or fetches remote assets.
@Suite(.serialized) nonisolated struct MarkdownPerformanceTests {
    private static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/fixtures/m1-18-performance")

    private struct Recipe: Decodable {
        struct Corpus: Decodable {
            let prefix: String
            let suffix: String
            let templateFile: String?
            let line: String?
            let fill: String?
        }
        let targets: [Int]
        let corpora: [String: Corpus]
    }

    private static func source(_ name: String, bytes: Int) throws -> String {
        let recipe = try JSONDecoder().decode(Recipe.self,
            from: Data(contentsOf: fixtures.appendingPathComponent("generator-recipe.json")))
        let corpus = try #require(recipe.corpora[name])
        let budget = bytes - corpus.prefix.utf8.count - corpus.suffix.utf8.count
        let body: String
        if let file = corpus.templateFile {
            let template = try String(contentsOf: fixtures.appendingPathComponent(file), encoding: .utf8)
            let count = (budget - 2) / template.utf8.count
            try #require(count < 1_000_000)
            body = (0..<count).map {
                template.replacingOccurrences(of: "NNNNNN", with: String(format: "%06d", $0))
            }.joined() + "\n\n" + String(repeating: "x", count: (budget - 2) % template.utf8.count)
        } else if let line = corpus.line {
            body = String(repeating: line, count: budget / line.utf8.count)
                + String(repeating: " ", count: budget % line.utf8.count)
        } else {
            body = String(repeating: try #require(corpus.fill), count: budget)
        }
        let result = corpus.prefix + body + corpus.suffix
        #expect(result.utf8.count == bytes)
        return result
    }

    private static func validate(_ document: MarkdownRenderDocument, source: String, corpus: String) throws {
        #expect(document.anchorTargets["start-performance"] != nil)
        #expect(document.anchorTargets["end-performance"] != nil)
        #expect(DocumentFindIndex(document).matches(for: "END-PERFORMANCE").count == 1)
        let roots = Set(document.rootIDs)
        let leaves = Set(document.leafIDs)
        for node in document.nodes {
            #expect(document.nodes.indices.contains(node.id))
            #expect(document.subtreeEnds[node.id] > node.id)
            #expect(document.subtreeEnds[node.id] <= document.nodes.count)
            #expect(roots.contains(document.lazyRootIDs[node.id]))
            for child in node.childIDs {
                #expect(document[child].parentID == node.id)
                #expect(document.subtreeIDs(in: node.id).contains(child))
            }
        }
        let index = DocumentContentIndex(document)
        #expect(index.entries.allSatisfy { leaves.contains($0.id) })
        if corpus == "unbroken" {
            let payload = try #require(document.leaves.first { $0.kind == .paragraph })
            #expect(String(payload.text.characters) == String(repeating: "x", count: source.utf8.count - 41))
        } else if corpus == "code" {
            let code = try #require(document.leaves.first { if case .codeBlock = $0.kind { return true }; return false })
            let body = try #require(source.components(separatedBy: "```swift\n").last?.components(separatedBy: "\n```\n").first)
            #expect(String(code.text.characters) == body + "\n")
            #expect(code.text.runs.allSatisfy { $0.markdownCodeToken == nil })
        } else {
            let sections = document.leaves.filter { $0.kind == .heading(level: 2) }
            let expectedSections = source.components(separatedBy: "## Section ").count - 1
            #expect(sections.count == expectedSections)
            #expect(sections.enumerated().allSatisfy {
                String($0.element.text.characters) == String(format: "Section %06d", $0.offset)
            })
            #expect(document.nodes.filter { if case .table = $0.kind { return true }; return false }.count == expectedSections)
            #expect(document.leaves.filter { if case .codeBlock = $0.kind { return true }; return false }.count == expectedSections)
            #expect(document.nodes.filter { $0.task != nil }.count == expectedSections * 2)
        }
    }

    @Test func generatedCorporaHaveExactBytesAndCompleteContent() async throws {
        try await Task.detached {
            for bytes in [1_000_000, 10_000_000] {
                for corpus in ["report", "unbroken", "code"] {
                    let source = try Self.source(corpus, bytes: bytes)
                    let document = MarkdownBlockRenderer.render(from: source)
                    try Self.validate(document, source: source, corpus: corpus)
                }
            }
        }.value
    }

    @Test func recordsPreparationMeasurements() async throws {
        try await Task.detached {
            let clock = ContinuousClock()
            for bytes in [1_000_000, 10_000_000] {
                for corpus in ["report", "unbroken", "code"] {
                    let source = try Self.source(corpus, bytes: bytes)
                    let hash = SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
                    print("PERF corpus=\(corpus) bytes=\(bytes) scalars=\(source.unicodeScalars.count) sha256=\(hash)")
                    for sample in 0..<6 {
                        let start = clock.now
                        let document = MarkdownBlockRenderer.render(from: source)
                        let rendered = clock.now
                        let content = DocumentContentIndex(document)
                        let indexed = clock.now
                        let matches = DocumentFindIndex(document).matches(for: "END-PERFORMANCE")
                        let found = clock.now
                        #expect(!content.isEmpty)
                        #expect(matches.count == 1)
                        let preparation = start.duration(to: indexed)
                        print("PERF corpus=\(corpus) bytes=\(bytes) sample=\(sample) render=\(start.duration(to: rendered)) contentIndex=\(rendered.duration(to: indexed)) preparation=\(preparation) find=\(indexed.duration(to: found)) budgetSeconds=1 overBudget=\(preparation > .seconds(1)) nodes=\(document.nodes.count) roots=\(document.rootIDs.count) leaves=\(document.leafIDs.count)")
                    }
                }
            }
        }.value
    }

    @Test func noFootnoteFastPathPreservesSemanticControl() throws {
        let url = Self.fixtures.appendingPathComponent("offline-control.md")
        let source = try String(contentsOf: url, encoding: .utf8)
        let document = MarkdownBlockRenderer.render(from: source, documentURL: url)
        let text = document.leaves.map { String($0.text.characters) }.joined(separator: "\n")
        #expect(text.contains("Café, 日本語, and 👩🏽‍💻"))
        #expect(!text.contains("HIDDEN-PERFORMANCE-DECOY"))
        #expect(text.contains("<!-- code stays literal -->"))
        #expect(document.anchorTargets["start-performance"] != nil)
        #expect(document.anchorTargets["end-performance"] != nil)
        #expect(document.leaves.contains { $0.text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true } })
        #expect(document.leaves.contains { $0.text.runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true } })
        #expect(document.nodes.filter { $0.task != nil }.count == 2)
        #expect(document.nodes.contains { if case .metadata = $0.kind { return true }; return false })
        #expect(document.nodes.contains { if case .table = $0.kind { return true }; return false })
        let images = document.leaves.flatMap { $0.text.runs.compactMap(\.markdownImage) }
        #expect(images.count == 5)
        #expect(Set(images.map(\.occurrence)).count == 5)
        #expect(images.filter { $0.source == Self.fixtures.appendingPathComponent("local-diagram.svg") }.count == 3)
        let hidden = MarkdownBlockRenderer.render(from: source + "\n[^unused]: HIDDEN-UNUSED\n\n[^cycle]: HIDDEN-CYCLE[^cycle]\n", documentURL: url)
        #expect(hidden.nodes.map(\.kind) == document.nodes.map(\.kind))
        #expect(hidden.leaves.map { String($0.text.characters) } == document.leaves.map { String($0.text.characters) })
        #expect(hidden.anchorTargets == document.anchorTargets)
        let reachable = MarkdownBlockRenderer.render(from: try String(contentsOf:
            Self.fixtures.appendingPathComponent("reachable-footnotes.md"), encoding: .utf8), documentURL: url)
        #expect(reachable.nodes.filter { if case .footnote = $0.kind { return true }; return false }.count == 2)
        #expect(!reachable.leaves.contains { String($0.text.characters).contains("THIS-UNREACHABLE") })
        for run in reachable.leaves.flatMap({ Array($0.text.runs) }) where run.markdownGeneratedReference != nil {
            let link = try #require(run.link)
            if case .block = DocumentLinkDestination.resolve(url: link, anchors: reachable.anchorTargets) {
                // Both cyclic references and generated returns resolve within this arena.
            } else { Issue.record("Generated footnote link failed to resolve") }
        }
    }

    @Test @MainActor func pendingAssetsDoNotGateTextPreparation() async throws {
        let source = try String(contentsOf: Self.fixtures.appendingPathComponent("offline-control.md"), encoding: .utf8)
        let gate = PerformanceImageGate()
        let store = MarkdownImageStore { _ in await gate.wait() }
        let url = URL(string: "https://assets.invalid/not-present.png")!
        store.load(url)
        await gate.waitUntilStarted()
        defer { store.reset() }
        let document = await Task.detached { MarkdownBlockRenderer.render(from: source) }.value
        #expect(document.anchorTargets["end-performance"] != nil)
        #expect(store.states[url] == .loading)
        await gate.finish()
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while store.states[url] == .loading && ContinuousClock.now < deadline { await Task.yield() }
        #expect(store.states[url] == .unavailable(.unavailable))
        // Reset/stale same-URL completion is additionally covered by the allowlisted image-store regression.
    }

    @Test func localAssetsLoadWithoutChangingOwnedFixtureCopies() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("neomd-18-owned-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = ["offline-control.md", "local-diagram.svg"].map { directory.appendingPathComponent($0) }
        for file in files {
            try FileManager.default.copyItem(at: Self.fixtures.appendingPathComponent(file.lastPathComponent), to: file)
        }
        let before = try files.map { try Data(contentsOf: $0) }
        let times = try files.map { try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
        let document = await Task.detached {
            MarkdownBlockRenderer.render(from: String(decoding: before[0], as: UTF8.self), documentURL: files[0])
        }.value
        #expect(document.anchorTargets["end-performance"] != nil)
        let result = await Task.detached { await MarkdownImageLoader.load(files[1]) }.value
        if case .loaded(let bitmap, let natural) = result {
            #expect(natural.width == 64 && natural.height == 32)
            #expect(bitmap.width > 0 && bitmap.height > 0)
        } else { Issue.record("Owned offline SVG failed to decode") }
        let missing = await Task.detached { await MarkdownImageLoader.load(directory.appendingPathComponent("absent.png")) }.value
        if case .unavailable(.missing) = missing {} else { Issue.record("Missing local image did not retain fallback state") }
        #expect(try files.map { try Data(contentsOf: $0) } == before)
        #expect(try files.map { try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate } == times)
    }

    @Test func largeCodeKeepsEveryScalarAcrossHighlightBudget() {
        let limit = CodeSyntaxHighlighter.maximumHighlightedScalars
        for count in [limit - 1, limit, limit + 1] {
            let source = "let " + String(repeating: "x", count: count - 4)
            let text = CodeSyntaxHighlighter.highlight(AttributedString(source), language: .swift)
            #expect(String(text.characters) == source)
            #expect(text.unicodeScalars.count == count)
            #expect(text.runs.contains { $0.markdownCodeToken == .keyword } == (count <= limit))
        }
    }
}

private actor PerformanceImageGate {
    private var continuation: CheckedContinuation<MarkdownImageLoadResult, Never>?
    func wait() async -> MarkdownImageLoadResult {
        await withCheckedContinuation { continuation = $0 }
    }
    func waitUntilStarted() async {
        while continuation == nil { await Task.yield() }
    }
    func finish() {
        continuation?.resume(returning: .unavailable(.unavailable))
        continuation = nil
    }
}
