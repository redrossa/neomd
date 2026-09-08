import Foundation
import Testing
@testable import NeoMD

struct MarkdownWebLinksTests {
    @Test func labeledReferencesAndAutolinksRetainLabelsAndDestinations() {
        let document = MarkdownBlockRenderer.render(from: """
        [Example site](https://example.com/path?q=1)

        [Full][ref] [Collapsed][] [Shortcut]

        <https://angle.example/path> https://autolink.example/bare www.plain.example/site

        [ref]: https://full.example/
        [Collapsed]: https://collapsed.example/
        [Shortcut]: https://shortcut.example/
        """)
        let links = document.leaves.flatMap { MarkdownLinkMenu.links(in: $0.text) }
        #expect(links.map(\.label) == ["Example site", "Full", "Collapsed", "Shortcut",
            "https://angle.example/path", "https://autolink.example/bare", "www.plain.example/site"])
        #expect(links.map { $0.url.absoluteString } == ["https://example.com/path?q=1",
            "https://full.example/", "https://collapsed.example/", "https://shortcut.example/",
            "https://angle.example/path", "https://autolink.example/bare", "http://www.plain.example/site"])
    }

    @Test func webLinksRemainExternalEvenWithLocalDocumentAndMatchingAnchor() throws {
        for source in ["https://example.com/", "http://example.com/", "https://example.com/#frag"] {
            #expect(DocumentLinkDestination.resolve(url: try #require(URL(string: source)),
                anchors: ["frag": 1], documentURL: URL(fileURLWithPath: "/base/guide.md")) == .external)
        }
    }

    @Test func menuEntriesPreserveAuthoredOrderAndTitles() throws {
        let first = try #require(URL(string: "https://example.com/?x=1&y=2"))
        let second = try #require(URL(string: "#section"))
        let single = MarkdownLinkMenu(links: [("First", first)])
        #expect(single.entries == [.destination(first), .openLink(first), .copyLink(first)])
        #expect(single.entries.map(\.title) == [first.absoluteString, "Open Link", "Copy Link"])
        #expect(MarkdownLinkMenu(links: [("First", first), ("Second", second)]).entries ==
            single.entries + [.separator, .destination(second), .openLink(second), .copyLink(second)])
        #expect(MarkdownLinkMenu(links: []).entries.isEmpty)
    }

    @Test func styledLabelHasOneMenuGroupAndSeparateAuthoredLinksStaySeparate() {
        let document = MarkdownBlockRenderer.render(from: """
        [A **bold** and *emphasized* label](https://example.com/) [Separate](https://example.com/) note[^n].

        [^n]: Footnote.
        """)
        let links = document.leaves.flatMap { MarkdownLinkMenu.links(in: $0.text) }
        #expect(links.map(\.label) == ["A bold and emphasized label", "Separate"])
        #expect(MarkdownLinkMenu(links: links).entries.count == 7)
    }

    @Test func generatedFootnoteLinksDoNotReceiveMenus() {
        let document = MarkdownBlockRenderer.render(from: """
        Note[^note] and [authored](#section).

        [^note]: Footnote text.
        """)
        let links = document.leaves.flatMap { MarkdownLinkMenu.links(in: $0.text) }
        #expect(links.map(\.label) == ["authored"])
        #expect(links.map { $0.url.absoluteString } == ["#section"])
    }
}
