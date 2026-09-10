import Foundation

/// Deliberately bounded color values, not a CSS evaluator.
nonisolated struct MarkdownColorReference: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    static func parse(_ text: String) -> Self? {
        let bytes = Array(text.utf8)
        if bytes.count == 7, bytes.first == 35 {
            guard bytes.dropFirst().allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
                  let rgb = UInt32(text.dropFirst(), radix: 16) else { return nil }
            return Self(red: Double((rgb >> 16) & 255) / 255,
                        green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
        }
        let hsl = text.hasPrefix("hsl(")
        guard hsl || text.hasPrefix("rgb("), bytes.last == 41 else { return nil }
        let parts = bytes.dropFirst(4).dropLast().split(separator: 44, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var values: [Double] = []
        for (index, part) in parts.enumerated() {
            var token = Array(part.drop(while: { $0 == 32 || $0 == 9 }))
            while token.last == 32 || token.last == 9 { token.removeLast() }
            if hsl && index > 0 {
                guard token.last == 37 else { return nil }
                token.removeLast()
            }
            guard !token.isEmpty else { return nil }
            var dots = 0
            var digits = 0
            for byte in token {
                if (48...57).contains(byte) { digits += 1 }
                else if hsl && byte == 46 { dots += 1 }
                else { return nil }
            }
            guard digits > 0, dots <= 1,
                  let value = Double(String(decoding: token, as: UTF8.self)), value.isFinite,
                  value >= 0, value <= (hsl ? (index == 0 ? 360 : 100) : 255) else { return nil }
            values.append(value)
        }
        if !hsl { return Self(red: values[0] / 255, green: values[1] / 255, blue: values[2] / 255) }
        let hue = values[0] / 60
        let saturation = values[1] / 100
        let lightness = values[2] / 100
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let x = chroma * (1 - abs(hue.truncatingRemainder(dividingBy: 2) - 1))
        let offset = lightness - chroma / 2
        let channels: (Double, Double, Double)
        switch hue {
        case ..<1: channels = (chroma, x, 0)
        case ..<2: channels = (x, chroma, 0)
        case ..<3: channels = (0, chroma, x)
        case ..<4: channels = (0, x, chroma)
        case ..<5: channels = (x, 0, chroma)
        default: channels = (chroma, 0, x)
        }
        return Self(red: channels.0 + offset, green: channels.1 + offset, blue: channels.2 + offset)
    }
}

nonisolated enum MarkdownColorReferenceAttribute: AttributedStringKey {
    typealias Value = MarkdownColorReference
    static let name = "NeoMD.ColorReference"
}
