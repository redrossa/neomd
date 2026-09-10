import SwiftUI

/// Presentation-only decoration. Kerning reserves room without adding characters,
/// attachment carriers, accessibility children or actions to selectable text.
enum MarkdownColorSwatch {
    static let attribute = NSAttributedString.Key("NeoMD.PassiveColorSwatch")
    static func side(scale: CGFloat) -> CGFloat { 9 * scale }
    static func gap(scale: CGFloat) -> CGFloat { 3 * scale }

    static func color(_ value: MarkdownColorReference) -> NSColor {
        NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: 1)
    }

}
