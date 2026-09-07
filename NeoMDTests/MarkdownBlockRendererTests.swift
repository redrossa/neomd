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

    @Test func linkLabelProvenancePreservesStylesAndLiteralControls() throws {
        let cases: [(String, String, MarkdownInlineStyle?)] = [
            ("H<sub>2</sub>O", "H2O", .subscriptText),
            ("x<sup>2</sup>", "x2", .superscriptText),
            ("<ins>important</ins>", "important", .underline),
            ("`H<sub>2</sub>O`", "H<sub>2</sub>O", nil),
            (#"H\<sub>2\</sub>O"#, "H<sub>2</sub>O", nil),
            ("before `H<sub>2</sub>O` after", "before H<sub>2</sub>O after", nil),
            ("`H<sub>2</sub>O` after", "H<sub>2</sub>O after", nil),
            ("before `H<sub>2</sub>O`", "before H<sub>2</sub>O", nil),
            ("`` H<sub>2</sub>O ``", "H<sub>2</sub>O", nil),
            ("**H**<sup>2</sup>", "H2", .superscriptText),
            ("<sup>\u{0301}x</sup>", "\u{0301}x", .superscriptText),
            ("<sup><sub>x</sup></sub>", "<sup><sub>x</sup></sub>", nil),
            ("<span>x</span>", "<span>x</span>", nil)
        ]
        for (label, expected, style) in cases {
            let source = "- [\(label)](https://example.com)"
            let text = try #require(MarkdownBlockRenderer.blocks(from: source).flatMap(\.leaves).first).text
            #expect(text.unicodeScalars.elementsEqual(expected.unicodeScalars))
            #expect(text.runs.allSatisfy { $0.link == URL(string: "https://example.com") })
            #expect(text.runs.contains { $0.markdownInlineStyle == style })
            if style == nil { #expect(text.runs.allSatisfy { $0.markdownInlineStyle == nil }) }
        }
    }

    @Test func sourcePositionsHandleRepeatedMultilineAndUnicodeLabels() throws {
        let source = "日本語 👩🏽‍💻\n\n[H<sub>2</sub>O](https://one.example) [H<sub>2</sub>O](https://two.example)\n\n[字\nx<sup>2</sup>][ref]\n\n[ref]: https://three.example"
        let blocks = MarkdownBlockRenderer.blocks(from: source)
        #expect(blocks.map(plainText) == ["日本語 👩🏽‍💻", "H2O H2O", "字 x2"])
        let links = blocks.flatMap { $0.text.runs.compactMap { $0.link?.absoluteString } }
        for url in ["https://one.example", "https://two.example", "https://three.example"] {
            #expect(links.contains(url))
        }
        #expect(blocks[1].text.runs.filter { $0.markdownInlineStyle == .subscriptText }.count == 2)
        let styled = blocks[2].text.runs.filter { $0.markdownInlineStyle == .superscriptText }
            .flatMap { Array(blocks[2].text.unicodeScalars[$0.range]) }
        #expect(styled == Array("2".unicodeScalars))
    }

    @Test func multilineLinkBreaksPreserveHTMLProvenanceAndLiteralControls() throws {
        for (label, expected, styled) in [
            ("字\nx<sup>2</sup>", "字 x2", "2"),
            ("字  \nx<sup>2</sup>", "字\nx2", "2"),
            ("字\\\nx<sup>2</sup>", "字\nx2", "2"),
            ("`字\nx<sup>2</sup>`", "字 x<sup>2</sup>", ""),
            ("字\nx\\<sup>2\\</sup>", "字 x<sup>2</sup>", "")
        ] {
            let blocks = MarkdownBlockRenderer.blocks(from: "[\(label)](https://example.com)")
            #expect(blocks.count == 1)
            let text = try #require(blocks.first).text
            #expect(text.unicodeScalars.elementsEqual(expected.unicodeScalars))
            #expect(text.runs.allSatisfy { $0.link == URL(string: "https://example.com") })
            let scalars = text.runs.filter { $0.markdownInlineStyle == .superscriptText }
                .flatMap { Array(text.unicodeScalars[$0.range]) }
            #expect(scalars == Array(styled.unicodeScalars))
            if styled.isEmpty { #expect(text.runs.allSatisfy { $0.markdownInlineStyle == nil }) }
        }
    }

    @Test func scalarBoundariesPreserveContentAndExactStyleRanges() throws {
        for (source, expected, styled) in [
            ("A<sup>\u{0301}x</sup>Z", "A\u{0301}xZ", "\u{0301}x"),
            ("<sup>x</sup>\u{0301}Z", "x\u{0301}Z", "x"),
            ("<sup>e\u{0301}👩🏽‍💻日本語</sup>", "e\u{0301}👩🏽‍💻日本語", "e\u{0301}👩🏽‍💻日本語")
        ] {
            let text = try #require(MarkdownBlockRenderer.blocks(from: source).first).text
            #expect(text.unicodeScalars.elementsEqual(expected.unicodeScalars))
            let scalars = text.runs.filter { $0.markdownInlineStyle == .superscriptText }
                .flatMap { Array(text.unicodeScalars[$0.range]) }
            #expect(scalars == Array(styled.unicodeScalars))
        }
        let nested = try #require(MarkdownBlockRenderer.blocks(
            from: "<sup><sub>👩🏽‍💻e\u{0301}</sub>外</sup>"
        ).first).text
        #expect(nested.unicodeScalars.elementsEqual("👩🏽‍💻e\u{0301}外".unicodeScalars))
        #expect(nested.runs.contains { $0.markdownInlineStyle == .subscriptText })
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
            ).flatMap(\.leaves).first)
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
            let expected = source.replacingOccurrences(of: "```\n", with: "").replacingOccurrences(of: "\n```", with: "").replacingOccurrences(of: "`", with: "")
            #expect(rendered == expected + (source.hasPrefix("```") ? "\n" : ""))
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
        #expect(loose.map(\.kind) == [.listItem(marker: "•", depth: 1), .listItem(marker: "•", depth: 1)])
        #expect(loose.flatMap(\.leaves).map(plainText) == ["a", "more", "b"])
        #expect(loose[0].children.count == 2)
        let adjacent = MarkdownBlockRenderer.blocks(from: "- a\n\n* b")
        #expect(adjacent.map(\.kind) == Array(repeating: .listItem(marker: "•", depth: 1), count: 2))
        let nested = MarkdownBlockRenderer.blocks(from: "- outer\n\n  5. inner\n     - deep\n\n  after")
        #expect(nested.count == 1)
        #expect(nested[0].children[1].kind == .listItem(marker: "5.", depth: 2))
        #expect(nested[0].children[1].children[1].kind == .listItem(marker: "▪", depth: 3))
        #expect(nested.flatMap(\.leaves).map(plainText) == ["outer", "inner", "deep", "after"])
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
        let text = try #require(block.children.first).text
        #expect(String(text.characters) == "see site now")
        #expect(text.runs.contains { $0.link == URL(string: "https://example.com") })
        #expect(text.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized })
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
        #expect(items[0].leaves.map(plainText) == ["First"])
        #expect(items[1].leaves.map(plainText) == ["Second"])
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
        #expect(code.kind == .codeBlock(language: "swift"))
        #expect(plainText(code).contains("let greeting"))
        #expect(!plainText(code).contains("```"))
    }

    @Test func rendersBlockQuotes() throws {
        let quote = try #require(MarkdownBlockRenderer.blocks(from: "> Quoted aside").first)
        #expect(quote.kind == .blockQuote)
        #expect(quote.children.map(plainText) == ["Quoted aside"])
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
