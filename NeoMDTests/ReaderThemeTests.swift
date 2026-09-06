//
//  ReaderThemeTests.swift
//  NeoMDTests
//

import SwiftUI
import Testing
@testable import NeoMD

/// Covers the appearance policy the reader applies to inline text.
///
/// The policy is the same in light and dark appearance and on every Mac: it adds a
/// non-color affordance to links and changes nothing else, so these tests can assert it
/// on the rendered text itself rather than through a view.
struct ReaderThemeTests {

    /// A rendered paragraph that mixes a link with ordinary and emphasized prose.
    private func linkedParagraph() -> AttributedString {
        let blocks = MarkdownBlockRenderer.blocks(
            from: "Read the [release checklist](https://example.com/checklist) before **shipping**."
        )
        return blocks[0].text
    }

    @Test func linksAreUnderlinedWithoutAnyAccessibilitySettingOrAppearance() throws {
        let text = linkedParagraph()
        let presented = ReaderTheme().presentationText(for: text)

        var underlinedLinkRuns = 0
        for run in presented.runs {
            if run.link == nil {
                #expect(
                    run.underlineStyle == nil,
                    "Ordinary prose must not gain a link's underline."
                )
            } else {
                #expect(
                    run.underlineStyle == .single,
                    "A link must carry its own non-color affordance by default."
                )
                underlinedLinkRuns += 1
            }
        }
        #expect(underlinedLinkRuns == 1)
        #expect(
            presented.runs.contains { $0.link?.absoluteString == "https://example.com/checklist" }
        )
        #expect(presented != text, "The default presentation must add the underline.")
    }

    @Test func everyLinkInMixedInlineContentIsUnderlined() {
        let text = MarkdownBlockRenderer.blocks(
            from: """
                Compare the [first report](https://example.com/first) with `inline code`, \
                *emphasis*, the [**second report**](https://example.com/second), and \
                <https://example.com/third> at the end.
                """
        )[0].text
        let presented = ReaderTheme().presentationText(for: text)

        let linkRuns = presented.runs.filter { $0.link != nil }
        #expect(linkRuns.count >= 3, "The fixture should render three separate links.")
        #expect(linkRuns.allSatisfy { $0.underlineStyle == .single })
        #expect(presented.runs.allSatisfy { $0.link != nil || $0.underlineStyle == nil })
    }

    @Test func linksInEveryBlockKindKeepTheirUnderline() {
        let blocks = MarkdownBlockRenderer.blocks(
            from: """
                # Heading with a [heading link](https://example.com/heading)

                A paragraph with a [paragraph link](https://example.com/paragraph).

                > A quotation with a [quoted link](https://example.com/quoted).

                - A list item with a [list link](https://example.com/list).
                """
        )
        let theme = ReaderTheme()
        var underlinedLinks = 0

        for block in blocks {
            let presented = theme.presentationText(for: block.text)
            for run in presented.runs where run.link != nil {
                #expect(
                    run.underlineStyle == .single,
                    "A link in \(block.kind) must not rely on color alone."
                )
                underlinedLinks += 1
            }
        }
        #expect(underlinedLinks == 4)
    }

    @Test func underliningNeverChangesCharactersEmphasisOrColor() {
        let text = linkedParagraph()
        let presented = ReaderTheme().presentationText(for: text)

        #expect(String(presented.characters) == String(text.characters))
        #expect(
            presented.runs.map(\.inlinePresentationIntent)
                == text.runs.map(\.inlinePresentationIntent)
        )
        #expect(text.runs.allSatisfy { $0.foregroundColor == nil })
        #expect(
            presented.runs.allSatisfy { $0.foregroundColor == nil },
            "The theme resolves colors through adaptive styles, never by rewriting text."
        )
        #expect(
            presented.runs.map(\.link) == text.runs.map(\.link),
            "The link destinations the document declared must survive untouched."
        )
    }

    @Test func textWithoutLinksIsUnchanged() {
        let text = MarkdownBlockRenderer.blocks(
            from: "Plain prose with *emphasis* and `code`."
        )[0].text

        #expect(ReaderTheme().presentationText(for: text) == text)
    }
}
