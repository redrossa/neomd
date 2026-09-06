//
//  MarkdownBlockRendererTests.swift
//  NeoMDTests
//

import Foundation
import Testing
@testable import NeoMD

struct MarkdownBlockRendererTests {

    /// The plain characters of a block, for asserting that syntax was consumed.
    private func plainText(_ block: MarkdownBlock) -> String {
        String(block.text.characters)
    }

    @Test func rendersNothingForEmptySource() {
        #expect(MarkdownBlockRenderer.blocks(from: "").isEmpty)
        #expect(MarkdownBlockRenderer.blocks(from: "\n\n   \n").isEmpty)
    }

    @Test func rendersHeadingsWithoutTheirMarkers() throws {
        let blocks = MarkdownBlockRenderer.blocks(from: "# Release notes\n\nBody text.")
        let heading = try #require(blocks.first)
        #expect(heading.kind == .heading(level: 1))
        #expect(plainText(heading) == "Release notes")
        #expect(!plainText(heading).contains("#"))
    }

    @Test func rendersDeeperHeadingLevels() throws {
        let blocks = MarkdownBlockRenderer.blocks(from: "### Details")
        #expect(try #require(blocks.first).kind == .heading(level: 3))
    }

    @Test func rendersParagraphsWithoutEmphasisSyntax() throws {
        let blocks = MarkdownBlockRenderer.blocks(from: "A **bold** and *italic* line.")
        let paragraph = try #require(blocks.first)
        #expect(paragraph.kind == .paragraph)
        #expect(plainText(paragraph) == "A bold and italic line.")
    }

    @Test func rendersUnorderedListItems() {
        let blocks = MarkdownBlockRenderer.blocks(from: "- First\n- Second")
        let items = blocks.filter { if case .listItem = $0.kind { true } else { false } }
        #expect(items.count == 2)
        #expect(plainText(items[0]) == "First")
        #expect(plainText(items[1]) == "Second")
        if case .listItem(let marker, let depth) = items[0].kind {
            #expect(marker == "\u{2022}")
            #expect(depth == 1)
        }
    }

    @Test func numbersOrderedListItems() {
        let blocks = MarkdownBlockRenderer.blocks(from: "1. First\n2. Second")
        let markers = blocks.compactMap { block -> String? in
            if case .listItem(let marker, _) = block.kind { marker } else { nil }
        }
        #expect(markers == ["1.", "2."])
    }

    @Test func rendersFencedCodeWithoutFences() throws {
        let source = """
            ```swift
            let greeting = "hello"
            ```
            """
        let code = try #require(MarkdownBlockRenderer.blocks(from: source).first)
        #expect(code.kind == .codeBlock)
        #expect(plainText(code).contains("let greeting"))
        #expect(!plainText(code).contains("```"))
    }

    @Test func rendersBlockQuotes() throws {
        let quote = try #require(MarkdownBlockRenderer.blocks(from: "> Quoted aside").first)
        #expect(quote.kind == .blockQuote)
        #expect(plainText(quote) == "Quoted aside")
    }

    @Test func assignsStableIdentifiersInDocumentOrder() {
        let blocks = MarkdownBlockRenderer.blocks(from: "# One\n\nTwo\n\nThree")
        #expect(blocks.map(\.id) == Array(0..<blocks.count))
    }

    @Test func neverSurfacesRawSourceForOrdinaryDocuments() {
        let source = """
            # Title

            Some *emphasis* and a [link](https://example.com).

            - item
            """
        let rendered = MarkdownBlockRenderer.blocks(from: source).map(plainText).joined(separator: "\n")
        #expect(!rendered.contains("#"))
        #expect(!rendered.contains("*"))
        #expect(!rendered.contains("](" ))
    }
}
