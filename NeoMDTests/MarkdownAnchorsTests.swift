import Foundation
import Testing
@testable import NeoMD

struct MarkdownAnchorsTests {
    @Test func headingSlugs() {
        var slugger = MarkdownAnchorSlugger()
        #expect(slugger.slug(for: AttributedString("Dup")) == "dup")
        #expect(slugger.slug(for: AttributedString("dup-1")) == "dup-1")
        #expect(slugger.slug(for: AttributedString("DUP")) == "dup-2")
        #expect(slugger.slug(for: AttributedString("Café 日本語 🚀 Title!")) == "café-日本語--title")
        var heading = AttributedString("User")
        var ordinal = AttributedString("1")
        ordinal.markdownGeneratedReference = .footnoteReference
        heading.append(ordinal)
        #expect(slugger.slug(for: heading) == "user")
        var userSup = AttributedString("sup")
        userSup.markdownInlineStyle = .superscriptText
        #expect(slugger.slug(for: userSup) == "sup")
    }

    @Test func allocationReservesLaterPreferredAndAuthoredNames() {
        let preferred = ["fn-x", "fnref-x", "fnref-x-2", "fn-x-2", "fnref-x-2", "fn-é% #", "fn-É% #"]
        let authored = ["fn-x", "fn-x-1", "fn-x-3", "fnref-x-2", "fn-é% #"]
        var allocator = MarkdownGeneratedAnchorAllocator(authored: authored, preferred: preferred)
        let allocated = preferred.map { allocator.allocate($0) }
        #expect(allocated == ["fn-x-4", "fnref-x", "fnref-x-2-1", "fn-x-2", "fnref-x-2-2", "fn-é% #-1", "fn-É% #"])
        #expect(Set(allocated).count == preferred.count)
        #expect(Set(allocated).isDisjoint(with: authored))
        for anchor in allocated {
            let url = MarkdownGeneratedAnchorAllocator.url(for: anchor)
            #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment == anchor)
        }
    }

    @Test func authoredDestinationsKeepPreorderFirstWins() {
        let document = MarkdownRenderDocument(nodes: [
            MarkdownBlock(id: 0, kind: .blockQuote, text: AttributedString(), childIDs: [1]),
            MarkdownBlock(id: 1, kind: .paragraph, text: AttributedString("first"), parentID: 0, anchors: ["same"]),
            MarkdownBlock(id: 2, kind: .paragraph, text: AttributedString("second"), anchors: ["same"])
        ], rootIDs: [0, 2])
        #expect(document.anchorTargets["same"] == 1)
        #expect(document.lazyRootIDs[1] == 0)
    }
}
