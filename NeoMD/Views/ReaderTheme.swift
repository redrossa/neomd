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
///   therefore keeps the colors its author chose. MarkdownImageParagraph honours
///   this invariant while selecting appearance-specific image sources.
/// - Important: No distinction the reader draws depends on color alone. Headings differ
///   in size and weight, quotations carry an indent and a leading rule, code keeps a
///   monospaced face inside its own container, list items keep literal markers, and a
///   thematic break is a rule. A link keeps the platform and GitHub convention of a
///   tinted label and is always underlined as well, so it stays recognizable when the
///   tint cannot be seen or is not perceived as a difference. Syntax highlighting is
///   supplementary: literal code remains understandable without token colors.
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
            if run.inlinePresentationIntent?.contains(.code) == true {
                presented[run.range].font = inlineCodeFont(headingLevel: headingLevel)
                presented[run.range].backgroundColor = Self.codeBackground
            }
            if let token = run.markdownCodeToken {
                presented[run.range].foregroundColor = Self.tokenColor(token)
            }
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

    /// Explicit opaque surfaces make the contrast contract measurable in both appearances.
    static func codeBackgroundRGB(dark: Bool) -> UInt32 { dark ? 0x252b33 : 0xf6f8fa }

    static var codeBackground: Color {
        adaptive(light: codeBackgroundRGB(dark: false), dark: codeBackgroundRGB(dark: true))
    }

    static func tokenRGB(_ token: MarkdownCodeToken, dark: Bool) -> UInt32 {
        switch token {
        case .keyword, .marker: dark ? 0xff7b72 : 0xa31525
        case .string, .codeSpan: dark ? 0xa5d6ff : 0x0a3069
        case .comment: dark ? 0x9da7b3 : 0x57606a
        case .number: dark ? 0x79c0ff : 0x0550ae
        case .key, .heading: dark ? 0xd2a8ff : 0x6639ba
        case .emphasis, .link: dark ? 0x7ee787 : 0x116329
        }
    }

    private static func tokenColor(_ token: MarkdownCodeToken) -> Color {
        adaptive(light: tokenRGB(token, dark: false), dark: tokenRGB(token, dark: true))
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((rgb >> 16) & 255) / 255,
                           green: Double((rgb >> 8) & 255) / 255,
                           blue: Double(rgb & 255) / 255, alpha: 1)
        })
    }

    private func inlineCodeFont(headingLevel: Int?) -> Font {
        switch headingLevel {
        case 1: .system(.largeTitle, design: .monospaced, weight: .semibold)
        case 2: .system(.title, design: .monospaced, weight: .semibold)
        case 3: .system(.title2, design: .monospaced, weight: .semibold)
        case 4: .system(.title3, design: .monospaced, weight: .semibold)
        case 5: .system(.headline, design: .monospaced)
        case 6: .system(.subheadline, design: .monospaced, weight: .semibold)
        default: .system(.body, design: .monospaced)
        }
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
