import Foundation
import SwiftUI
import Testing
@testable import NeoMD

struct QuotationsAndCodeTests {
    @Test func nestedBoundariesAndSeparateQuotes() {
        let document = MarkdownBlockRenderer.render(from: "> outer\n>\n> > inner\n>\n> back")
        let blocks = document.roots
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .blockQuote)
        #expect(document.children(of: blocks[0].id).map(\.kind) == [.paragraph, .blockQuote, .paragraph])
        #expect(document.leaves(in: blocks[0].id).map { String($0.text.characters) } == ["outer", "inner", "back"])
        #expect(MarkdownBlockRenderer.render(from: "> a\n\n> b").roots.count == 2)
    }

    @Test func ancestryOrderAndMarkerOwnership() {
        let quoted = MarkdownBlockRenderer.render(from: "5. > quote\n   >\n   > ```swift\n   > let x = 1\n   > ```\n\n   continuation")
        let quoteInList = quoted.roots
        #expect(quoteInList[0].kind == .listItem(marker: "5.", depth: 1))
        #expect(quoted[quoteInList[0].childIDs[0]].kind == .blockQuote)
        #expect(quoted.children(of: quoteInList[0].childIDs[0]).map(\.kind) == [.paragraph, .codeBlock(language: "swift")])
        #expect(quoted[quoteInList[0].childIDs[1]].kind == .paragraph)
        let listed = MarkdownBlockRenderer.render(from: "> - item\n>\n>   ```swift\n>   let x = 1\n>   ```\n>\n>   continuation")
        let listInQuote = listed.roots
        #expect(listInQuote[0].kind == .blockQuote)
        let item = listed[listInQuote[0].childIDs[0]]
        #expect(item.kind == .listItem(marker: "•", depth: 1))
        #expect(listed.children(of: item.id).map(\.kind) == [.paragraph, .codeBlock(language: "swift"), .paragraph])
        #expect(String(listed[item.childIDs[1]].text.characters) == "let x = 1\n")
    }

    @Test func descendantsHaveUniqueOrderedIDsAndLazyAncestors() {
        let document = MarkdownBlockRenderer.render(from: "before\n\n> outer\n>\n> - inner\n>\n>   ```\n>   code\n>   ```\n\nafter")
        let blocks = document.roots
        let all = document.nodes.map(\.id)
        #expect(all == Array(0..<all.count))
        let lookup = document.lazyRootIDs
        for leaf in document.leaves(in: blocks[1].id) { #expect(lookup[leaf.id] == blocks[1].id) }
        #expect(lookup[blocks[2].id] == blocks[2].id)
        let leaf = document.leaves(in: blocks[1].id).last!
        let frame = CGRect(x: 0, y: 1000, width: 300, height: 200)
        let anchor = DocumentReaderLayout.readingAnchor(in: [leaf.id: frame],
            visibleRect: CGRect(x: 0, y: 1000, width: 400, height: 200), isAtTop: false, isAtBottom: false)
        #expect(anchor == .block(id: leaf.id, fraction: 0.5))
        #expect(DocumentReaderLayout.verticalOffset(for: anchor!, targetFrame: frame, viewportHeight: 200) == 1000)
    }

    @Test func codePreservesExactParserScalarsAndBoundaryBlankLines() throws {
        let expected = "\n    let  x = 1  \n\tprint(x)\n\n"
        let source = "```Swift\n" + expected + "```"
        let block = try #require(MarkdownBlockRenderer.render(from: source).roots.first)
        #expect(block.kind == .codeBlock(language: "swift"))
        #expect(block.text.unicodeScalars.elementsEqual(expected.unicodeScalars))
        for prefix in ["", "# ", "> ", "- "] {
            let text = try #require(MarkdownBlockRenderer.render(from: prefix + "`x  =   1`").leaves.first).text
            #expect(String(text.characters) == "x  =   1")
            #expect(text.runs.allSatisfy { $0.inlinePresentationIntent?.contains(.code) == true })
        }
    }

    @Test func inlineCodeBoundaryScalarsSurviveInEveryLeafContext() throws {
        for prefix in ["", "# ", "> ", "- "] {
            for (source, expected) in [
                ("`  x  `", " x "), ("`   `", "   "),
                ("`  x  ` after", " x  after"), ("before `  x  `", "before  x "),
                ("before `  x  ` after", "before  x  after"),
                ("ordinary prose   ", "ordinary prose")
            ] {
                let leaves = MarkdownBlockRenderer.render(from: prefix + source).leaves
                #expect(leaves.count == 1)
                let leaf = try #require(leaves.first)
                #expect(leaf.text.unicodeScalars.elementsEqual(expected.unicodeScalars))
                if source == "`   `" {
                    #expect(leaf.text.runs.allSatisfy { $0.inlinePresentationIntent?.contains(.code) == true })
                }
            }
        }
    }

    @Test func fencesAndLanguageHintsAreNotDocumentSyntax() throws {
        for (source, hint, expected): (String, String?, String) in [
            ("~~~python extra info\nx = 1\n~~~", "python", "x = 1\n"),
            ("```swift\nlet x = 1", "swift", "let x = 1\n"),
            ("````md\n```\ninside\n```\n````", "md", "```\ninside\n```\n"),
            ("    code\n", nil, "code\n"),
            ("```{.swift}\ncode\n```", "{.swift}", "code\n")
        ] {
            let block = try #require(MarkdownBlockRenderer.render(from: source).roots.first)
            #expect(block.kind == .codeBlock(language: hint))
            #expect(String(block.text.characters) == expected)
        }
        #expect(MarkdownBlockRenderer.render(from: "```\n```").roots.isEmpty)
    }

    @Test func semanticTokensAndInlineCodeArePresentedWithoutRewriting() throws {
        var text = AttributedString("code plain keyword")
        text[text.range(of: "code")!].inlinePresentationIntent = .code
        text[text.range(of: "keyword")!].markdownCodeToken = .keyword
        let presented = ReaderTheme().presentationText(for: text)
        #expect(presented.unicodeScalars.elementsEqual(text.unicodeScalars))
        let code = try #require(presented.range(of: "code"))
        let context = EnvironmentValues().fontResolutionContext
        let actual = try #require(presented[code].font).resolve(in: context)
        let baseline = Font.system(.body, design: .monospaced).resolve(in: context)
        #expect(actual.pointSize == baseline.pointSize)
        #expect(actual.weight == baseline.weight)
        #expect(actual.isMonospaced == baseline.isMonospaced)
        #expect(presented[code].backgroundColor != nil)
        #expect(presented[presented.range(of: "keyword")!].foregroundColor != nil)
        #expect(presented[presented.range(of: "plain")!].foregroundColor == nil)
    }

    @Test func everyTokenMeetsContrastInBothAppearances() {
        func luminance(_ rgb: UInt32) -> Double {
            let channels = [16, 8, 0].map { shift -> Double in
                let value = Double((rgb >> shift) & 255) / 255
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        }
        for dark in [false, true] {
            let background = luminance(ReaderTheme.codeBackgroundRGB(dark: dark))
            for token in MarkdownCodeToken.allCases {
                let foreground = luminance(ReaderTheme.tokenRGB(token, dark: dark))
                let ratio = (max(background, foreground) + 0.05) / (min(background, foreground) + 0.05)
                #expect(ratio >= 4.5, "\(token) dark=\(dark): \(ratio)")
            }
        }
    }
}
