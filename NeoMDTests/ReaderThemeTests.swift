//
//  ReaderThemeTests.swift
//  NeoMDTests
//

import SwiftUI
import Testing
@testable import NeoMD

/// Covers the appearance policy the reader applies to inline text.
struct ReaderThemeTests {

    /// A rendered paragraph that mixes a link with ordinary and emphasized prose.
    private func linkedParagraph() -> AttributedString {
        let blocks = MarkdownBlockRenderer.blocks(
            from: "Read the [release checklist](https://example.com/checklist) before **shipping**."
        )
        return blocks[0].text
    }

    @Test func linksStayTintedOnlyUntilTheReaderAsksToDifferentiateWithoutColor() {
        #expect(ReaderTheme().linkPresentation == .tint)
        #expect(ReaderTheme(differentiateWithoutColor: false).linkPresentation == .tint)
        #expect(
            ReaderTheme(differentiateWithoutColor: true).linkPresentation
                == .tintAndUnderline
        )
    }

    @Test func defaultPresentationLeavesRenderedTextExactlyAsParsed() {
        let text = linkedParagraph()
        #expect(ReaderTheme().presentationText(for: text) == text)
    }

    @Test func differentiatingWithoutColorUnderlinesOnlyTheLinkRuns() throws {
        let text = linkedParagraph()
        let presented = ReaderTheme(differentiateWithoutColor: true)
            .presentationText(for: text)

        var underlinedLinkRuns = 0
        for run in presented.runs {
            if run.link == nil {
                #expect(
                    run.underlineStyle == nil,
                    "Ordinary prose must not gain a link's underline."
                )
            } else {
                #expect(run.underlineStyle == .single)
                underlinedLinkRuns += 1
            }
        }
        #expect(underlinedLinkRuns == 1)
        #expect(
            presented.runs.contains { $0.link?.absoluteString == "https://example.com/checklist" }
        )
    }

    @Test func underliningNeverChangesCharactersEmphasisOrColor() {
        let text = linkedParagraph()
        let presented = ReaderTheme(differentiateWithoutColor: true)
            .presentationText(for: text)

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
    }

    @Test func textWithoutLinksIsUnchangedInEitherPresentation() {
        let text = MarkdownBlockRenderer.blocks(
            from: "Plain prose with *emphasis* and `code`."
        )[0].text

        #expect(ReaderTheme().presentationText(for: text) == text)
        #expect(
            ReaderTheme(differentiateWithoutColor: true).presentationText(for: text)
                == text
        )
    }
}
