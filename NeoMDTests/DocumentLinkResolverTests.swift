import Foundation
import Testing
@testable import NeoMD

struct DocumentLinkResolverTests {
    @Test func localPathsResolveFromTheDocumentFolder() throws {
        let base = URL(fileURLWithPath: "/base/docs/guide.md")
        for (source, path) in [
            ("./intro.md", "/base/docs/intro.md"), ("../README.md", "/base/README.md"),
            ("sub/deep.md#section", "/base/docs/sub/deep.md"),
            ("my notes.md", "/base/docs/my notes.md"), ("my%20notes.md", "/base/docs/my notes.md"),
            ("caf%C3%A9.md", "/base/docs/café.md"), ("café.md", "/base/docs/café.md"),
            ("100%.md", "/base/docs/100%.md"), ("/root-target.md", "/base/docs/root-target.md"),
            ("/nested/x.md", "/base/docs/nested/x.md"), ("notes.md?x=1#frag", "/base/docs/notes.md"),
            ("../../../../etc/hosts", "/etc/hosts"), ("a%23b%3Fc.md", "/base/docs/a#b?c.md")
        ] {
            let url = try #require(URL(string: source))
            let target = try #require(DocumentLocalPath.resolve(url, relativeTo: base))
            #expect(target.fileURL.path == path)
            #expect(DocumentLinkDestination.resolve(url: url, anchors: [:], documentURL: base) == .local(target))
        }
        for source in ["https://example.com/a", "//example.com/a.md", "mailto:a@b.com", "file:///etc/hosts", "#x"] {
            #expect(DocumentLocalPath.resolve(try #require(URL(string: source)), relativeTo: base) == nil)
        }
        for (encoded, decoded) in [("", ""), ("caf%C3%A9", "café"), ("literal%2520", "literal%20"),
                                   ("a%23b%3Fc%26d", "a#b?c&d"), ("100%25", "100%") ] {
            let url = try #require(URL(string: "x.md#" + encoded))
            let target = try #require(DocumentLocalPath.resolve(url, relativeTo: base))
            #expect(target.fragment == decoded)
            #expect(DocumentLinkDestination.resolve(fragment: decoded, anchors: [decoded: 9]) == (decoded.isEmpty ? .top : .block(9)))
        }
    }

    @Test func fragmentClassificationAndDecoding() throws {
        let anchors = ["Café 日本語": 4, "CASE": 2, "case": 7, "literal%20": 8]
        for (source, expected): (String, DocumentLinkDestination) in [
            ("#Caf%C3%A9%20%E6%97%A5%E6%9C%AC%E8%AA%9E", .block(4)),
            ("#case", .block(7)), ("#Case", .block(2)), ("#", .top),
            ("#missing", .missing("missing")), ("#literal%2520", .block(8)),
            ("other.md#case", .external), ("https://example.com/#case", .external),
            ("mailto:user@example.com", .external), ("//example.com/#case", .external)
        ] {
            #expect(DocumentLinkDestination.resolve(url: try #require(URL(string: source)), anchors: anchors) == expected)
        }
    }
}
