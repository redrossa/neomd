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

    @Test func allSixHeadingsAndEmphasisRetainTheirIntents() throws {
        let headings = (1...6).map { String(repeating: "#", count: $0) + " Heading \($0)" }
        let blocks = MarkdownBlockRenderer.blocks(from: (headings + ["####### prose"]).joined(separator: "\n\n"))
        #expect(blocks.map(\.kind) == (1...6).map { .heading(level: $0) } + [.paragraph])
        #expect(plainText(blocks[6]) == "####### prose")
        let text = try #require(MarkdownBlockRenderer.blocks(from: "**bold** *italic* ***both*** ~~strike~~").first).text
        for (word, intent): (String, InlinePresentationIntent) in [
            ("bold", .stronglyEmphasized), ("italic", .emphasized),
            ("both", [.stronglyEmphasized, .emphasized]), ("strike", .strikethrough)
        ] {
            let range = try #require(text.range(of: word))
            #expect(text[range].inlinePresentationIntent == intent)
        }
        #expect(String(text.characters) == "bold italic both strike")
    }

    @Test func supportedWrappersBecomeSemanticStylesAcrossBlocks() throws {
        for prefix in ["", "# ", "- ", "> "] {
            let block = try #require(MarkdownBlockRenderer.blocks(
                from: prefix + "H<sub class=\"a\">2</sub>O x<SUP>3</SUP> <ins>under</ins>"
            ).first)
            #expect(plainText(block) == "H2O x3 under")
            for (word, style): (String, MarkdownInlineStyle) in [
                ("2", .subscriptText), ("3", .superscriptText), ("under", .underline)
            ] {
                let range = try #require(block.text.range(of: word))
                #expect(block.text[range].markdownInlineStyle == style)
            }
        }
    }

    @Test func adjacentNestedWrappersAndInlineAttributesSurvive() throws {
        let text = try #require(MarkdownBlockRenderer.blocks(
            from: "<sup><sub>inner</sub> outer</sup> <ins>**bold** [site](https://example.com)</ins>"
        ).first).text
        #expect(String(text.characters) == "inner outer bold site")
        #expect(text[try #require(text.range(of: "inner"))].markdownInlineStyle == .subscriptText)
        #expect(text[try #require(text.range(of: "outer"))].markdownInlineStyle == .superscriptText)
        #expect(text[try #require(text.range(of: "bold"))].inlinePresentationIntent == .stronglyEmphasized)
        #expect(text[try #require(text.range(of: "site"))].link == URL(string: "https://example.com"))
    }

    @Test func malformedUnsupportedEscapedAndCodeWrappersStayLiteral() throws {
        for source in [
            "<sup>x", "x</sup>", "<sup><sub>x</sup></sub>",
            "<sup><sub>x</sub>", "<span>x</span>",
            "<sup><span>x</sup></span>", "<sup/>x</sup>",
            "<span title='<sub>'>x</span></sub>", "<!-- <sup>x</sup> -->",
            "<script>alert('x')</script>", "`<sub>x</sub>`", "```\n<sup>x</sup>\n```"
        ] {
            let blocks = MarkdownBlockRenderer.blocks(from: source)
            let rendered = blocks.map(plainText).joined(separator: "\n")
            #expect(rendered == source.replacingOccurrences(of: "```\n", with: "").replacingOccurrences(of: "\n```", with: "").replacingOccurrences(of: "`", with: ""))
            #expect(blocks.allSatisfy { $0.text.runs.allSatisfy { $0.markdownInlineStyle == nil } })
        }
        let escaped = try #require(MarkdownBlockRenderer.blocks(from: #"\<sub>x\</sub>"#).first)
        #expect(plainText(escaped) == "<sub>x</sub>")
        #expect(escaped.text.runs.allSatisfy { $0.markdownInlineStyle == nil })
        let separate = MarkdownBlockRenderer.blocks(from: "<sup>one\n\ntwo</sup>")
        #expect(separate.map(plainText) == ["<sup>one", "two</sup>"])
    }

    @Test func listIdentityDistinguishesContinuationsAndSeparateLists() {
        let loose = MarkdownBlockRenderer.blocks(from: "- a\n\n  more\n- b")
        #expect(loose.map(\.kind) == [.listItem(marker: "•", depth: 1), .listItem(marker: "", depth: 1), .listItem(marker: "•", depth: 1)])
        #expect(loose.map(plainText) == ["a", "more", "b"])
        let adjacent = MarkdownBlockRenderer.blocks(from: "- a\n\n* b")
        #expect(adjacent.map(\.kind) == Array(repeating: .listItem(marker: "•", depth: 1), count: 2))
        let nested = MarkdownBlockRenderer.blocks(from: "- outer\n\n  5. inner\n     - deep\n\n  after")
        #expect(nested.map(\.kind) == [.listItem(marker: "•", depth: 1), .listItem(marker: "5.", depth: 2), .listItem(marker: "▪", depth: 3), .listItem(marker: "", depth: 1)])
        let ordered = MarkdownBlockRenderer.blocks(from: "9. nine\n10. ten")
        #expect(ordered.map(\.kind) == [.listItem(marker: "9.", depth: 1), .listItem(marker: "10.", depth: 1)])
    }

    @Test func paragraphAndExplicitBreaksSurviveWhileSoftWrapsFlow() {
        #expect(MarkdownBlockRenderer.blocks(from: "line one\nline two").map(plainText) == ["line one line two"])
        for source in ["line one\\\nline two", "line one  \nline two"] {
            #expect(MarkdownBlockRenderer.blocks(from: source).map(plainText) == ["line one\nline two"])
        }
        #expect(MarkdownBlockRenderer.blocks(from: "a\n\nb").map(plainText) == ["a", "b"])
    }

    @Test func mixedListContentRetainsLinkAndEmphasis() throws {
        let block = try #require(MarkdownBlockRenderer.blocks(from: "- see [site](https://example.com) **now**").first)
        #expect(block.kind == .listItem(marker: "•", depth: 1))
        #expect(plainText(block) == "see site now")
        #expect(block.text.runs.contains { $0.link == URL(string: "https://example.com") })
        #expect(block.text.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized })
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
