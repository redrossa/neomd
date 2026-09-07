import Foundation
import Testing
@testable import NeoMD

struct DocumentLinkResolverTests {
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
