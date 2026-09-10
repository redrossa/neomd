import AppKit
import CoreText
import SwiftUI
import Testing
@testable import NeoMD

@MainActor
struct FontPolicyParityTests {
    // Independent accepted-main formulas, not expectations derived from ReaderTheme.
    static func baselineCode(_ level: Int?) -> Font {
        switch level {
        case 1: .system(.largeTitle, design: .monospaced, weight: .semibold)
        case 2: .system(.title, design: .monospaced, weight: .semibold)
        case 3: .system(.title2, design: .monospaced, weight: .semibold)
        case 4: .system(.title3, design: .monospaced, weight: .semibold)
        case 5: .system(.headline, design: .monospaced)
        case 6: .system(.subheadline, design: .monospaced, weight: .semibold)
        default: .system(.body, design: .monospaced)
        }
    }

    static func baselineScript(_ level: Int?) -> Font {
        switch level {
        case 1: .system(.title3, weight: .semibold)
        case 2: .system(.headline, weight: .semibold)
        case 3, 4: .system(.subheadline, weight: .semibold)
        case 5, 6: .system(.caption, weight: .semibold)
        default: .footnote
        }
    }

    @Test func resolvedCodeAndScriptFontsMatchAcceptedDefaultPolicy() throws {
        let context = EnvironmentValues().fontResolutionContext
        let block = try #require(MarkdownBlockRenderer.render(from: "`code` H<sub>2</sub> x<sup>3</sup>").leaves.first)
        for level in [nil, 1, 2, 3, 4, 5, 6] as [Int?] {
            let text = ReaderTheme().presentationText(for: block.text, headingLevel: level)
            let native = MarkdownLinkedImageContent.make(.init(text: text, states: [:], dark: false, width: 760, headingLevel: level, scale: 1))
            for (token, baseline, offset) in [("code", Self.baselineCode(level), CGFloat(0)), ("2", Self.baselineScript(level), -3), ("3", Self.baselineScript(level), 5)] {
                let range = try #require(text.range(of: token))
                let actual = try #require(text[range].font).resolve(in: context)
                let expected = baseline.resolve(in: context)
                let index = (native.string as NSString).range(of: token).location
                let font = try #require(native.attribute(.font, at: index, effectiveRange: nil) as? NSFont)
                print("FONT_PARITY level=\(String(describing: level)) token=\(token) baseline=\(CTFontCopyPostScriptName(expected.ctFont))/\(expected.pointSize) swift=\(CTFontCopyPostScriptName(actual.ctFont))/\(actual.pointSize) native=\(font.fontName)/\(font.pointSize)")
                #expect(actual.pointSize == expected.pointSize)
                #expect(actual.weight == expected.weight)
                #expect(actual.isMonospaced == expected.isMonospaced)
                #expect(font.pointSize == expected.pointSize)
                // The semantic SFNSMono font lacks the fixed-pitch symbolic bit
                // despite resolving monospaced. Verify actual glyph advances below.
                let traits = CTFontCopyTraits(font as CTFont) as NSDictionary
                let baselineTraits = CTFontCopyTraits(expected.ctFont) as NSDictionary
                for key in [kCTFontWeightTrait, kCTFontWidthTrait, kCTFontSlantTrait] {
                    #expect(traits[key] as? NSNumber == baselineTraits[key] as? NSNumber)
                }
                for character in ["i", "m", "W", "."] {
                    func advance(_ font: CTFont) -> Double {
                        let string = NSAttributedString(string: character, attributes: [.font: font])
                        return CTLineGetTypographicBounds(CTLineCreateWithAttributedString(string), nil, nil, nil)
                    }
                    #expect(abs(advance(font as CTFont) - advance(expected.ctFont)) < 0.0001)
                }
                #expect((native.attribute(.baselineOffset, at: index, effectiveRange: nil) as? NSNumber)?.doubleValue ?? 0 == Double(offset))
            }
        }
    }
}
