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
///   thematic break is a rule. Links follow the platform and GitHub convention of a
///   tinted label, and gain an underline when the reader has asked macOS to
///   differentiate without color.
nonisolated struct ReaderTheme: Equatable, Sendable {

    /// How inline links are distinguished from surrounding prose.
    nonisolated enum LinkPresentation: Equatable, Sendable {
        /// A tinted label, matching the platform and GitHub convention.
        case tint
        /// A tinted and underlined label, so the link is legible without color.
        case tintAndUnderline
    }

    /// Mirrors the macOS "Differentiate without color" accessibility setting.
    let differentiateWithoutColor: Bool

    init(differentiateWithoutColor: Bool = false) {
        self.differentiateWithoutColor = differentiateWithoutColor
    }

    var linkPresentation: LinkPresentation {
        differentiateWithoutColor ? .tintAndUnderline : .tint
    }

    /// Applies the appearance policy that inline text carries.
    ///
    /// The renderer stays free of presentation concerns, so link runs are given their
    /// non-color affordance here. Only the underline attribute is added: no color,
    /// font, or character of the document is changed.
    func presentationText(for text: AttributedString) -> AttributedString {
        guard linkPresentation == .tintAndUnderline else { return text }

        var presented = text
        for run in text.runs where run.link != nil {
            presented[run.range].underlineStyle = .single
        }
        return presented
    }
}
