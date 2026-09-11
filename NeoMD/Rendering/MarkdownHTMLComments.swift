import Foundation

/// Receives only original cmark HTML literals, never decoded text/code. Surviving
/// tag boundaries remain separate so removal cannot manufacture HTML authority.
nonisolated struct MarkdownHTMLComments {
    struct Piece {
        let text: String
        let eligibleTag: Bool
    }
    private var opaque: String?
    private static let opaqueNames: Set<String> = ["script", "style", "textarea", "title", "pre", "code"]

    mutating func filter(_ source: String, inline: Bool) -> [Piece] {
        let scalars = Array(source.unicodeScalars)
        var result: [Piece] = []
        var cursor = 0
        var plainStart = 0
        func matches(_ text: String, at index: Int) -> Bool {
            let expected = Array(text.unicodeScalars)
            guard expected.count <= scalars.count - index else { return false }
            return scalars[index..<(index + expected.count)].elementsEqual(expected)
        }
        func append(_ lower: Int, _ upper: Int, tag: Bool = false) {
            if lower < upper {
                result.append(Piece(text: String(String.UnicodeScalarView(scalars[lower..<upper])), eligibleTag: tag))
            }
        }
        while cursor < scalars.count {
            guard scalars[cursor] == "<" else { cursor += 1; continue }
            if opaque == nil, matches("<!--", at: cursor) {
                var end: Int?
                if inline, matches("<!-->", at: cursor) { end = cursor + 5 }
                else if inline, matches("<!--->", at: cursor) { end = cursor + 6 }
                else {
                    var scan = cursor + 4
                    while scan < scalars.count {
                        if matches("-->", at: scan) { end = scan + 3; break }
                        if matches("--!>", at: scan) { end = scan + 4; break }
                        scan += 1
                    }
                }
                guard let end else { break } // incomplete syntax remains literal
                append(plainStart, cursor)
                cursor = end
                plainStart = cursor
                continue
            }
            // cmark also classifies CDATA, processing instructions and
            // declarations as HTML. Their contents are literal, not comments.
            if opaque == nil, matches("<![CDATA[", at: cursor) || matches("<?", at: cursor) ||
                (matches("<!", at: cursor) && !matches("<!--", at: cursor)) {
                let terminator = matches("<![CDATA[", at: cursor) ? "]]>" : matches("<?", at: cursor) ? "?>" : ">"
                var scan = cursor + 2
                var quote: Unicode.Scalar?
                var end: Int?
                while scan < scalars.count {
                    let scalar = scalars[scan]
                    if terminator == ">", let current = quote {
                        if scalar == current { quote = nil }
                    } else if terminator == ">", scalar == "\"" || scalar == "'" { quote = scalar }
                    else if matches(terminator, at: scan) { end = scan + terminator.unicodeScalars.count; break }
                    scan += 1
                }
                guard let end else { break }
                append(plainStart, end)
                cursor = end
                plainStart = end
                continue
            }
            if let tag = Self.tag(scalars, at: cursor) {
                append(plainStart, cursor)
                let wasOpaque = opaque != nil
                if let name = opaque {
                    if tag.closing, tag.name == name { opaque = nil }
                } else if !tag.closing, !tag.selfClosing, Self.opaqueNames.contains(tag.name) {
                    opaque = tag.name
                }
                append(cursor, tag.end, tag: !wasOpaque && opaque == nil)
                cursor = tag.end
                plainStart = cursor
            } else {
                // An undecidable tag must not expose a quoted attribute comment.
                if cursor + 1 < scalars.count, Self.letter(scalars[cursor + 1]) { break }
                cursor += 1
            }
        }
        append(plainStart, scalars.count)
        return result
    }

    private struct Tag {
        let name: String
        let closing: Bool
        let selfClosing: Bool
        let end: Int
    }
    private static func letter(_ scalar: Unicode.Scalar) -> Bool {
        (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }
    private static func space(_ scalar: Unicode.Scalar) -> Bool {
        [9, 10, 12, 13, 32].contains(scalar.value)
    }
    private static func tag(_ scalars: [Unicode.Scalar], at start: Int) -> Tag? {
        var cursor = start + 1
        var closing = false
        if cursor < scalars.count, scalars[cursor] == "/" { closing = true; cursor += 1 }
        guard cursor < scalars.count, letter(scalars[cursor]) else { return nil }
        let nameStart = cursor
        while cursor < scalars.count, letter(scalars[cursor]) || (48...57).contains(scalars[cursor].value) || scalars[cursor] == "-" {
            cursor += 1
        }
        let name = String(String.UnicodeScalarView(scalars[nameStart..<cursor])).lowercased()
        guard cursor < scalars.count, space(scalars[cursor]) || scalars[cursor] == ">" || scalars[cursor] == "/" else { return nil }
        var quote: Unicode.Scalar?
        while cursor < scalars.count {
            let scalar = scalars[cursor]
            if let current = quote {
                if scalar == current { quote = nil }
            } else if scalar == "\"" || scalar == "'" { quote = scalar }
            else if scalar == ">" {
                return Tag(name: name, closing: closing, selfClosing: scalars[cursor - 1] == "/", end: cursor + 1)
            }
            cursor += 1
        }
        return nil
    }
}

/// Distinct source-token IDs prevent AttributedString from coalescing neighboring
/// eligible tags across a removed comment. The IDs carry no display semantics.
nonisolated enum MarkdownHTMLTokenAttribute: AttributedStringKey {
    typealias Value = Int
    static let name = "NeoMD.HTMLToken"
}
