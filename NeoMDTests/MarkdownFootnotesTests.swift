import Foundation
import Testing
@testable import NeoMD

struct MarkdownFootnotesTests {
    @Test func generatedLinksResolveByIdentityDespiteAllCollisions() throws {
        let source = """
        # fn-x

        First[^x].

        Again[^x].

        Suffix[^x-2].

        Accent[^É].

        Lower[^é].

        Percent[^p%#].

        <a id="fn-x-1"></a>

        Occupied suffix.

        <a id="fnref-x-2"></a>

        Occupied reference.

        [^x]: Note X.

            # fn-x-3

            <a id="fn-É"></a>

            Later authored anchor.

        [^x-2]: Note suffix.
        [^é]: Note accent.
        [^p%#]: Percent note.
        """
        let blocks = MarkdownBlockRenderer.blocks(from: source)
        let targets = MarkdownBlock.anchorTargets(in: blocks)
        let notes = blocks.filter { if case .footnote = $0.kind { return true }; return false }
        try #require(notes.count == 4)
        let bodies = blocks.filter { $0.text.runs.contains { $0.markdownGeneratedReference == .footnoteReference } }
        try #require(bodies.count == 6)
        let refs = bodies.flatMap { $0.text.runs.filter { $0.markdownGeneratedReference == .footnoteReference } }
        try #require(refs.count == 6)
        for (run, expectedNote) in zip(refs, [notes[0], notes[0], notes[1], notes[2], notes[2], notes[3]]) {
            #expect(DocumentLinkDestination.resolve(url: try #require(run.link), anchors: targets) == .block(expectedNote.id))
        }
        for (note, expectedBodies) in zip(notes, [[bodies[0], bodies[1]], [bodies[2]], [bodies[3], bodies[4]], [bodies[5]]]) {
            let returns = note.leaves.flatMap { $0.text.runs.filter { $0.markdownGeneratedReference == .footnoteReturn } }
            #expect(returns.count == expectedBodies.count)
            for (run, body) in zip(returns, expectedBodies) {
                #expect(DocumentLinkDestination.resolve(url: try #require(run.link), anchors: targets) == .block(body.id))
            }
        }
        #expect(targets["fn-x"] == blocks[0].id)
        #expect(targets["fn-x-3"] != notes[0].id)
        #expect(Set(refs.compactMap(\.link)).count == 4)
    }

    @Test func headingsAcrossNotesAndDefinitionOwnership() throws {
        let blocks = MarkdownBlockRenderer.blocks(from: """
        # **Title** `code`[^N]

        [^n]: First definition.

            # Title code

        [^N]: Duplicate must not appear.
        """)
        #expect(blocks.first?.anchors == ["title-code", "fnref-n"])
        #expect(blocks.count == 2)
        let note = try #require(blocks.last)
        #expect(note.kind == .footnote(ordinal: 1))
        #expect(note.leaves.contains { $0.anchors.contains("title-code-1") })
        #expect(!note.leaves.contains { String($0.text.characters).contains("Duplicate must") })
    }

    @Test(arguments: ["> ", "- "])
    func hoistedDefinitionsLeaveNoEmptyContainers(_ prefix: String) {
        let blocks = MarkdownBlockRenderer.blocks(from: prefix + "[^q]: Quoted note.\n\nBody[^q]")
        #expect(blocks.map(\.kind) == [.paragraph, .footnote(ordinal: 1)])
        #expect(blocks.last?.leaves.first.map { String($0.text.characters) } == "Quoted note. ↩")
    }

    @Test func ineligibleSpellingAndUnreachableCycles() {
        let blocks = MarkdownBlockRenderer.blocks(from: """
        [a[^N] b[^n]](u) ![c[^É] d[^é]](image) \\[^n] `[^n]` [^unknown]

        [^n]: hidden
        [^é]: hidden accent
        [^self]: alone[^self]
        [^a]: cycle[^b]
        [^b]: cycle[^a]
        """)
        #expect(blocks.count == 1)
        #expect(String(blocks[0].text.characters) == "a[^N] b[^n] c[^É] d[^é] [^n] [^n] [^unknown]")
    }

    @Test func reachableCycleKeepsStructureAndReturns() throws {
        let blocks = MarkdownBlockRenderer.blocks(from: """
        Start[^a].

        [^a]: first **bold**[^b]

            - [x] task

            > quote

            ```swift
            let x = 1
            ```

        [^b]: second[^a]
        """)
        let notes = blocks.filter { if case .footnote = $0.kind { return true }; return false }
        try #require(notes.count == 2)
        #expect(notes[0].children.contains { $0.task == .complete })
        #expect(notes[0].children.contains { $0.kind == .blockQuote })
        #expect(notes[0].leaves.contains { String($0.text.characters) == "let x = 1\n" })
        let all = blocks.flatMap(\.leaves)
        #expect(all.flatMap { $0.text.runs }.filter { $0.markdownGeneratedReference == .footnoteReference }.count == 3)
        let targets = MarkdownBlock.anchorTargets(in: blocks)
        for leaf in all {
            for run in leaf.text.runs where run.markdownGeneratedReference != nil {
                if case .block = DocumentLinkDestination.resolve(url: try #require(run.link), anchors: targets) {} else {
                    Issue.record("Generated link has no destination")
                }
            }
        }
    }

    @Test func customAnchorsAttachAndEOFRemainsAddressable() throws {
        let blocks = MarkdownBlockRenderer.blocks(from: "<a id=\"before\"></a>\n\n# **Bold** `code` Café\n\nText <a name='inline'>inside</a>.\n\n<a id=\"end\"></a>")
        try #require(blocks.count == 3)
        #expect(blocks[0].anchors == ["before", "bold-code-café"])
        #expect(blocks[1].anchors == ["inline"])
        #expect(String(blocks[1].text.characters) == "Text inside.")
        #expect(blocks[2].kind == .anchor)
        #expect(blocks[2].anchors == ["end"])
        #expect(MarkdownBlockRenderer.blocks(from: "<a id='only'></a>").first?.kind == .anchor)
    }
}
