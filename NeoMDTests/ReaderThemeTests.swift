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

    /// A link whose label is only partly emphasized still carries one continuous rule.
    ///
    /// The underline is applied per run, so a label split across several runs would be a
    /// gapped rule. `AttributedString`'s full Markdown syntax happens to collapse
    /// emphasis inside a link label into a single run today, which is why this asserts
    /// the outcome — every character of the label underlined — rather than a run count:
    /// the rule stays continuous whether or not a future parser splits the label.
    @Test func aPartlyEmphasizedLinkLabelIsUnderlinedFromEndToEnd() throws {
        let text = MarkdownBlockRenderer.blocks(
            from: "Read the [**release** checklist](https://example.com/checklist) before shipping."
        )[0].text
        let presented = ReaderTheme().presentationText(for: text)

        let labelRuns = presented.runs.filter { $0.link != nil }
        #expect(!labelRuns.isEmpty, "The fixture should render a link.")
        #expect(labelRuns.allSatisfy { $0.underlineStyle == .single })

        let label = try #require(labelRuns.first).range.lowerBound
            ..< (try #require(labelRuns.last).range.upperBound)
        #expect(String(presented[label].characters) == "release checklist")

        // No character between the label's first and last run may miss the rule, or the
        // underline would break exactly where the emphasis does.
        let underlined = presented.runs
            .filter { $0.underlineStyle == .single }
            .map(\.range)
        for index in presented.characters[label].indices {
            #expect(
                underlined.contains { $0.contains(index) },
                "The underline breaks inside the link label."
            )
        }

        #expect(presented.runs.allSatisfy { $0.link != nil || $0.underlineStyle == nil })
        #expect(String(presented.characters) == String(text.characters))
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
