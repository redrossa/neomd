import Foundation
import Testing
@testable import NeoMD

struct MarkdownMetadataTests {
    @Test func bodySemanticsAndArenaAreUnaffectedByMetadata() throws {
        let body = """
        > [!NOTE]
        > Body alert

        # Dup

        # Dup

        <a id='fn-x'></a>

        ![same](absent.png)![same](absent.png)

        - [x] done :smile: `#ff0000`

        note[^x] [unknown][ref] [raw [^MiXeD]](nearby.md)

        [^x]: Body footnote
        """
        let payload = """
        title: Dup
        fake: |-
          [ref]: evil.md
          [^x]: Wrong footnote
          # Dup
          <a id='fn-x'></a>
          :smile: `#ff0000`
        """ + "\n"
        let prefix = "---\n" + payload + "---\n"
        let original = MarkdownBlockRenderer.render(from: body)
        let rendered = MarkdownBlockRenderer.render(from: prefix + body)
        #expect(rendered.nodes.count == original.nodes.count + 1)
        #expect(rendered.nodes.map(\.id) == Array(rendered.nodes.indices))
        #expect(rendered.rootIDs == [0] + original.rootIDs.map { $0 + 1 })
        #expect(rendered.leafIDs == [0] + original.leafIDs.map { $0 + 1 })
        #expect(rendered.subtreeEnds == [1] + original.subtreeEnds.map { $0 + 1 })
        #expect(rendered.firstLeafIDs == [0] + original.firstLeafIDs.map { $0 + 1 })
        #expect(rendered.lastLeafIDs == [0] + original.lastLeafIDs.map { $0 + 1 })
        #expect(rendered.lazyRootIDs == [0] + original.lazyRootIDs.map { $0 + 1 })
        #expect(rendered.anchorTargets == original.anchorTargets.mapValues { $0 + 1 })
        for (before, after) in zip(original.nodes, rendered.nodes.dropFirst()) {
            #expect(before.kind == after.kind)
            #expect(before.task == after.task)
            #expect(before.anchors == after.anchors)
            #expect(after.parentID == before.parentID.map { $0 + 1 })
            #expect(after.childIDs == before.childIDs.map { $0 + 1 })
            #expect(normalized(before.text) == normalized(after.text))
        }
        #expect(rendered.nodes.contains { $0.kind.alert == .note })
        #expect(rendered.anchorTargets["dup"] != nil && rendered.anchorTargets["dup-1"] != nil)
        #expect(rendered.anchorTargets["fn-x-1"] != nil)
        let text = rendered.leaves.dropFirst().map { String($0.text.characters) }.joined(separator: "\n")
        #expect(text.contains("[unknown][ref]"))
        #expect(text.contains("[^MiXeD]"))
        #expect(!text.contains("Wrong footnote"))
        let images = rendered.nodes.flatMap { $0.text.runs[\.markdownImage].compactMap { $0.0 } }
        try #require(images.count == 2)
        let prefixLines = prefix.utf8.filter { $0 == 10 }.count
        #expect(images.map(\.occurrence) == ["\(prefixLines + 10):1", "\(prefixLines + 10):20"])
    }

    @Test func oversizeRecoveryKeepsBodyAlertAndExactCandidate() throws {
        let prefix = "\u{FEFF}---\r\nvalue: " + String(repeating: "x", count: 262145) + "\r\n...\r\n"
        let body = "> [!NOTE]\r\n> BODY ALERT\r\n\r\n# BODY\r\n"
        let document = MarkdownBlockRenderer.render(from: prefix + body)
        let first = try #require(document.nodes.first)
        guard case .metadata(.literal(let source)) = first.kind else { Issue.record("Expected literal recovery"); return }
        #expect(Array(source.utf8) == Array(prefix.utf8))
        #expect(document.nodes.contains { $0.kind.alert == .note })
        #expect(document.nodes.contains { $0.kind == .heading(level: 1) && String($0.text.characters) == "BODY" })
    }

    @Test func rowLabelsAndDescriptorsShareTheOutputBudget() throws {
        // a › b (7 UTF-8 bytes) + x (1) = 8, including the three-byte ›.
        for cap in [7, 8, 9] {
            var limits = YAMLMetadataLimits(); limits.outputBytes = cap
            let value = try? YAMLMetadataParser.parse("a: {b: x}\n", limits: limits)
            #expect((value != nil) == (cap >= 8))
        }
        let metadata = try YAMLMetadataParser.parse("? !key [a, b]\n: !value [c]\n")
        #expect(metadata.rows.map(\.accessibilityLabel) == [
            "Entry 1 › Key › Tag: !key", "Entry 1 › Key › Item 1: a", "Entry 1 › Key › Item 2: b",
            "Entry 1 › Value › Tag: !value", "Entry 1 › Value › Item 1: c"
        ])
        #expect(metadata.nodes.contains { $0.tag == "!key" })
        #expect(metadata.nodes.contains { $0.tag == "!value" })
    }

    @Test func physicalFixturesRenderConcurrentlyWithoutContextLeakage() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/m1-15-content")
        let names = ["metadata.md", "aliases-tags.md", "recovery.md", "bom-crlf.md", "cr-only.md", "comments.md"]
        let sources = try names.map { name in
            (name, String(decoding: try Data(contentsOf: root.appendingPathComponent(name)), as: UTF8.self))
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                for (name, source) in sources {
                    let serial = MarkdownBlockRenderer.render(from: source)
                    group.addTask {
                        let document = MarkdownBlockRenderer.render(from: source)
                        #expect(document.nodes.map(\.text) == serial.nodes.map(\.text))
                        #expect(document.anchorTargets == serial.anchorTargets)
                        let first = try #require(document.nodes.first)
                        if name == "comments.md" {
                            let text = document.nodes.map { String($0.text.characters) }.joined()
                            #expect(!text.contains("HIDDEN"))
                            #expect(text.contains("<!--RAWTEXT-LITERAL-->"))
                            #expect(text.contains("<!--UNCLOSED-LITERAL"))
                        } else if name == "recovery.md" {
                            guard case .metadata(.literal(let candidate)) = first.kind else { Issue.record("Recovery missing"); return }
                            #expect(candidate.contains("<!--FALLBACK COMMENT DATA-->"))
                            #expect(document.nodes.contains { $0.kind == .heading(level: 1) && String($0.text.characters) == "Recovery body" })
                        } else {
                            guard case .metadata(.formatted(let metadata)) = first.kind else { Issue.record("Table missing: \(name)"); return }
                            let expected: String
                            switch name {
                            case "metadata.md": expected = "Finished café report"
                            case "aliases-tags.md": expected = "structured key value"
                            case "bom-crlf.md": expected = "BOM CRLF"
                            default: expected = "CR only"
                            }
                            #expect(metadata.rows.contains { $0.value == expected })
                            if name == "metadata.md" {
                                #expect(document.nodes.contains { $0.kind.alert == .note })
                                #expect(document.anchorTargets["body-destination-1"] != nil)
                                #expect(metadata.rows.filter { $0.key == "duplicate" }.map(\.value) == ["first", "second"])
                            }
                        }
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    private func normalized(_ source: AttributedString) -> AttributedString {
        var result = source
        for run in source.runs {
            if var image = run.markdownImage {
                image.occurrence = nil
                result[run.range].markdownImage = image
            }
        }
        return result
    }
}
