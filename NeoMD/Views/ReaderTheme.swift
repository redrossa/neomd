//
//  ReaderTheme.swift
//  NeoMD
//

import SwiftUI

/// The reader's appearance policy.
///
/// NeoMD follows the Mac's light and dark appearance by drawing every surface with
/// adaptive system styles — `Color.primary`, `.secondary`, `.tertiary`, `.quaternary`,
/// `Divider`, the accent color, native text selection, and native alerts. Those styles
/// resolve against the environment, so a system appearance change repaints an open
/// document in place: nothing is re-parsed, no window is replaced, and the reading
/// position is untouched.
///
/// This type holds the small amount of appearance policy that a semantic style cannot
/// express, and records the invariants that later reading stories inherit.
///
/// - Important: The reader never applies a page-wide color transform. Appearance is
///   achieved by resolving adaptive colors, never by inverting, multiplying, hue
///   rotating, desaturating, or blending a rendered page. Document-provided content
///   therefore keeps the colors its author chose. Image rendering, including
///   appearance-specific image sources, is not part of this foundation.
/// - Important: No distinction the reader draws depends on color alone. Headings differ
///   in size and weight, quotations carry an indent and a leading rule, code keeps a
///   monospaced face inside its own container, list items keep literal markers, and a
///   thematic break is a rule. A link keeps the platform and GitHub convention of a
///   tinted label and is always underlined as well, so it stays recognizable when the
///   tint cannot be seen or is not perceived as a difference.
nonisolated struct ReaderTheme: Equatable, Sendable {

    /// Applies the appearance policy that inline text carries.
    ///
    /// The renderer stays free of presentation concerns, so link runs are given their
    /// non-color affordance here. Every link is underlined, in every appearance and
    /// with no accessibility setting required, because the tint alone would make the
    /// distinction depend on color. Supported HTML wrappers carry semantic attributes
    /// from the renderer; scripts use a smaller block-appropriate font and baseline.
    /// Neither document characters nor colors are rewritten here.
    func presentationText(
        for text: AttributedString,
        headingLevel: Int? = nil
    ) -> AttributedString {
        var presented = text
        for run in text.runs {
            if run.link != nil || run.markdownInlineStyle == .underline {
                presented[run.range].underlineStyle = .single
            }
            if let style = run.markdownInlineStyle,
               style == .subscriptText || style == .superscriptText {
                presented[run.range].font = scriptFont(headingLevel: headingLevel)
                presented[run.range].baselineOffset = style == .subscriptText ? -3 : 5
            }
        }
        return presented
    }

    private func scriptFont(headingLevel: Int?) -> Font {
        switch headingLevel {
        case 1: .system(.title3, weight: .semibold)
        case 2: .system(.headline, weight: .semibold)
        case 3, 4: .system(.subheadline, weight: .semibold)
        case 5, 6: .system(.caption, weight: .semibold)
        default: .footnote
        }
    }
}
