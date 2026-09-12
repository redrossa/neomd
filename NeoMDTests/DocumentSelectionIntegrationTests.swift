import AppKit
import Testing
@testable import NeoMD

@MainActor struct DocumentSelectionIntegrationTests {
    @Test func renderedTableMetadataAndCodeUseIndependentPlainTextOracle() throws {
        let source = "---\ntitle: Selection café\nowner: Reader\n---\n\n| H1 | H2 | H3 |\n|---|---|---|\n| A1 | A2 | A3 |\n| B1 | | B3 |\n\n```\n\n    let  x = 1  \n\tprint(x)\n\n```"
        let rendered = MarkdownBlockRenderer.render(from: source)
        let projection = DocumentTextProjection.rendered(rendered, presentation: UUID())
        #expect(projection.copiedText(for: try #require(projection.entireSelection)) ==
            "title\tSelection café\nowner\tReader\n\nH1\tH2\tH3\nA1\tA2\tA3\nB1\t\tB3\n\n\n    let  x = 1  \n\tprint(x)\n\n")
        let candidates = DocumentReaderTraversal.candidates(in: rendered)
        let code = try #require(rendered.leaves.last)
        #expect(candidates.suffix(2) == [.text(code.id), .codeBlock(code.id)])
        #expect(candidates.contains(.text(0)))
        #expect(rendered.tableCells(in: 1).count == 9)
    }

    @Test func injectedWriterReceivesOnlyExtractionWithoutAnyPasteboard() throws {
        let rendered = MarkdownBlockRenderer.render(from: "**Alpha**\n\n    code")
        let projection = DocumentTextProjection.rendered(rendered, presentation: UUID())
        var writes: [String] = []
        let owner = DocumentSelectionController(reader: UUID(), projection: projection, write: { writes.append($0) })
        owner.select(projection.entireSelection)
        owner.copy()
        #expect(writes == ["Alpha\n\ncode\n"])
        owner.select(nil)
        owner.copy()
        #expect(writes.count == 1)
    }

    @Test func finalArenaListIdentitiesDistinguishAdjacentAndNestedTasks() throws {
        let document = MarkdownBlockRenderer.render(from: "<!--hidden-->\n\n- [ ] pending\n  - [x] nested\n\n1. ordered\n2. [x] done\n\n## Heading")
        let items = document.nodes.filter { $0.listID != nil }
        #expect(items.count == 4)
        #expect(Set(items.compactMap(\.listID)).count == 3)
        #expect(items[0].task == .incomplete)
        #expect(items[1].task == .complete)
        #expect(items[2].listID == items[3].listID)
        for item in items { #expect(document.nodes.indices.contains(try #require(item.listID))) }
        #expect(document.leaves.last?.kind == .heading(level: 2))
    }

    @Test func sessionRefreshTransfersSelectionOnceWithoutConsumingFind() throws {
        let session = DocumentReadSession()
        let before = MarkdownBlockRenderer.render(from: "Start\n\nEnd")
        let input = PreparedReadingDocument(text: "Start\n\nEnd", fileURL: URL(fileURLWithPath: "/tmp/pure-selection.md"), rendered: before)
        #expect(session.commit(input, fragment: nil, token: session.begin()))
        session.binding = UUID()
        let projection = DocumentTextProjection.rendered(before, presentation: input.id)
        let entire = try #require(projection.entireSelection)
        let descriptor = try #require(projection.refreshDescriptor(for: entire))
        session.recordSelection(descriptor, presentation: input.id)
        session.isFindPresented = true; session.findQuery = "Start"; session.requestFind(.next)
        let binding = try #require(session.binding)
        let ticket = try #require(session.refreshTicket(binding: binding, revision: 1))
        let after = MarkdownBlockRenderer.render(from: "Prefix\n\nStart\n\nInserted\n\nEnd")
        let next = PreparedReadingDocument(text: "Prefix\n\nStart\n\nInserted\n\nEnd", fileURL: input.fileURL, rendered: after)
        #expect(session.commitRefresh(next, ticket: ticket, restoration: nil))
        #expect(session.takeSelection(for: input.id) == nil)
        let transfer = try #require(session.takeSelection(for: next.id))
        let updated = DocumentTextProjection.rendered(after, presentation: next.id)
        #expect(updated.copiedText(for: try #require(updated.resolve(transfer))) == "Start\n\nInserted\n\nEnd")
        #expect(session.takeSelection(for: next.id) == nil)
        #expect(session.isFindPresented && session.findQuery == "Start")
        #expect(session.takeFindCommand()?.kind == .next)
    }

    @Test func focusedLinkAttributesAndUnavailableImageProjectionRemainIndependent() throws {
        var link = AttributedString("Link")
        link.link = URL(string: "https://example.com")
        link.underlineStyle = .thick
        let content = MarkdownLinkedImageContent.project(.init(text: link, states: [:], dark: false, width: 300, headingLevel: nil))
        #expect(content.content.string == "Link")
        #expect(content.content.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int == NSUnderlineStyle.thick.rawValue)
        let document = MarkdownBlockRenderer.render(from: "![alt](javascript:blocked)")
        let leaf = try #require(document.leaves.first)
        let nativeValue = MarkdownLinkedImageContent.project(.init(text: leaf.text, states: [:], dark: false, width: 300, headingLevel: nil))
        let logical = DocumentTextProjection.rendered(document, presentation: UUID())
        #expect(nativeValue.content.string == logical.fragments.first?.text)
        #expect(nativeValue.content.string == "alt (Image unavailable)")
    }

    @Test func keyboardExtentValuesRetainAnchorAcrossFragmentsAndReverse() throws {
        let projection = DocumentTextProjection.rendered(MarkdownBlockRenderer.render(from: "Alpha\n\nBeta\n\nGamma"), presentation: UUID())
        let owner = DocumentSelectionController(reader: UUID(), projection: projection, write: { _ in })
        let keys = projection.fragments.map(\.key)
        owner.select(.init(anchor: .init(key: keys[0], offset: 2), extent: .init(key: keys[1], offset: 2)))
        owner.extendNative(NSRange(location: 1, length: 1), key: keys[1], forward: false)
        #expect(owner.state.copiedText == "pha\n\nB")
        owner.extendNative(NSRange(location: 0, length: 2), key: keys[0], forward: false)
        #expect(owner.state.copiedText == "Al")
        owner.extendDocument(forward: true)
        #expect(owner.state.copiedText == "pha\n\nBeta\n\nGamma")
        #expect(owner.state.registrations.isEmpty)
    }

    @Test func imageStateUpdatesOffscreenProjectionWithoutNativeHosts() throws {
        let rendered = MarkdownBlockRenderer.render(from: "before ![alt](missing.png) after", documentURL: URL(fileURLWithPath: "/tmp/doc.md"))
        let projection = DocumentTextProjection.rendered(rendered, presentation: UUID())
        let owner = DocumentSelectionController(reader: UUID(), projection: projection, write: { _ in })
        owner.select(projection.entireSelection)
        owner.updateImages(rendered, states: [:], dark: false)
        let image = try #require(rendered.leaves[0].text.runs.compactMap(\.markdownImage).first)
        let url = try #require(image.url(preferringDark: false))
        owner.updateImages(rendered, states: [url: .unavailable(.inaccessible)], dark: false)
        #expect(owner.state.copiedText == "before alt (Image unavailable) after")
        #expect(owner.state.registrations.isEmpty)
    }
}
