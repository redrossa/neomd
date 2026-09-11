import Foundation
import Testing
@testable import NeoMD

struct MarkdownHTMLCommentsTests {
    @Test func tokenProvenanceFixtures() throws {
        for item in try metadataFixtureCases("comment-cases.json") {
            let id = item["id"] as! String
            let document = MarkdownBlockRenderer.render(from: item["source"] as! String)
            let visible = document.leaves.map { String($0.text.characters) }.joined(separator: "\n")
            if let text = item["visibleText"] as? String { #expect(visible == text, "\(id)") }
            for text in item["present"] as? [String] ?? [] { #expect(visible.contains(text), "\(id)") }
            for text in item["absent"] as? [String] ?? [] {
                #expect(!visible.contains(text), "\(id)")
                #expect(!document.nodes.flatMap(\.anchors).contains { $0.contains(text.lowercased()) }, "\(id)")
            }
            if let count = item["visibleLeafCount"] as? Int { #expect(document.leaves.count == count, "\(id)") }
            if let text = item["codeText"] as? String { #expect(visible == text, "\(id)") }
            if let alt = item["imageAlt"] as? String {
                #expect(visible == alt)
                #expect(document.leaves.first?.text.runs.contains { $0.markdownImage != nil } == true)
            }
            if let anchor = item["customAnchor"] as? String { #expect(document.nodes.flatMap(\.anchors).contains(anchor)) }
            if let anchor = item["headingFragment"] as? String { #expect(document.nodes.flatMap(\.anchors).contains(anchor)) }
            for anchor in item["absentAnchors"] as? [String] ?? [] { #expect(!document.nodes.flatMap(\.anchors).contains(anchor)) }
            if let link = item["linkDestination"] as? String {
                #expect(document.leaves.first?.text.runs.contains { $0.link == URL(string: link) } == true)
            }
            if item["noSuperscript"] as? Bool == true {
                #expect(document.nodes.allSatisfy { $0.text.runs.allSatisfy { $0.markdownInlineStyle == nil } })
            }
            if item["task"] != nil {
                #expect(document.nodes.contains { $0.task == .incomplete })
                #expect(document.leaves.contains { $0.text.characters.isEmpty })
            }
            if let styles = item["styles"] as? [[String]] {
                let text = try #require(document.leaves.first?.text)
                for style in styles {
                    let range = try #require(text.range(of: style[0]))
                    let expected: MarkdownInlineStyle = style[1] == "superscript" ? .superscriptText : style[1] == "subscript" ? .subscriptText : .underline
                    #expect(text[range].markdownInlineStyle == expected)
                }
            }
        }
    }

    @Test func contextsAndNoNewSyntaxAuthority() {
        for source in [
            "<code>\n\n<!--KEEP-->\n\n</code>\n\n<!--HIDDEN-->\n",
            "before <SCRIPT data-x='</script>'><!--KEEP--></SCRIPT> after<!--HIDDEN-->",
            "before <textarea><!--KEEP--></textarea> after<!--HIDDEN-->",
            "before <style><!--KEEP--></style> after<!--HIDDEN-->",
            "before <title><!--KEEP--></title> after<!--HIDDEN-->"
        ] {
            let text = MarkdownBlockRenderer.render(from: source).leaves.map { String($0.text.characters) }.joined()
            #expect(text.contains("<!--KEEP-->"), "\(source)")
            #expect(!text.contains("HIDDEN"), "\(source)")
        }
        for source in ["&lt;su<!--HIDDEN-->p&gt;x&lt;/sup&gt;", ":smi<!--HIDDEN-->le:", "[la<!--HIDDEN-->bel]", "`#ff<!--HIDDEN-->0000`"] {
            let document = MarkdownBlockRenderer.render(from: source)
            #expect(document.nodes.allSatisfy { $0.text.runs.allSatisfy { $0.markdownInlineStyle == nil && $0.link == nil && $0.markdownColorReference == nil } })
        }
        #expect(MarkdownBlockRenderer.render(from: "<!-- <sup>x</sup> -->").nodes.isEmpty)
        let separateContainer = MarkdownBlockRenderer.render(from: "<code>\n\n> <!--HIDDEN-->\n")
        #expect(separateContainer.nodes.allSatisfy { !String($0.text.characters).contains("HIDDEN") })
    }

    @Test func otherHTMLTokensAreNotComments() {
        for source in [
            "before <![CDATA[<!--KEEP-->]]> after<!--HIDDEN-->",
            "<![CDATA[<!--KEEP-->]]>\n\n<!--HIDDEN-->",
            "before <?data <!--KEEP--> ?> after<!--HIDDEN-->",
            "<?data <!--KEEP--> ?>\n\n<!--HIDDEN-->",
            "<!DOCTYPE x ' <!--KEEP--> '>\n\n<!--HIDDEN-->"
        ] {
            let visible = MarkdownBlockRenderer.render(from: source).leaves.map { String($0.text.characters) }.joined()
            #expect(visible.contains("<!--KEEP-->"), "\(source)")
            #expect(!visible.contains("HIDDEN"), "\(source)")
        }
        let block = MarkdownBlockRenderer.render(from: "<!--HIDDEN--!>Visible\n").leaves
        #expect(block.map { String($0.text.characters) }.joined() == "Visible")
        let picture = MarkdownBlockRenderer.render(from: "<picture><!--HIDDEN--><img src='absent.png'></picture>")
        #expect(picture.nodes.allSatisfy { $0.text.runs.allSatisfy { $0.markdownImage == nil } })
        #expect(picture.leaves.map { String($0.text.characters) }.joined() == "<picture><img src='absent.png'></picture>")
    }

    @Test func commentsInContainersFootnotesAndEmptyImages() throws {
        let source = "# café<!--HIDDEN-->😀\n\n- a<!--HIDDEN-->b\n\n> q<!--HIDDEN-->r\n\nnote[^x]\n\n[^x]: f<!--HIDDEN-->n\n\n![<!--HIDDEN-->](absent.png)"
        let document = MarkdownBlockRenderer.render(from: source)
        #expect(document.nodes.allSatisfy { !String($0.text.characters).contains("HIDDEN") })
        #expect(document.nodes.contains { String($0.text.characters) == "ab" })
        #expect(document.nodes.contains { String($0.text.characters) == "qr" })
        let image = try #require(document.leaves.first { $0.text.runs.contains { $0.markdownImage != nil } })
        #expect(image.text.runs.contains { $0.markdownImage != nil })
        #expect(String(image.text.characters) == MarkdownPictureParser.emptyAltCarrier)
    }
}
