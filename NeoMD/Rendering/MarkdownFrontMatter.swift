import Foundation

/// The exact candidate is kept separately from the parser feed, including BOM
/// and original delimiter terminators. Neither recovery nor metadata is Markdown.
nonisolated struct MarkdownFrontMatter: Sendable {
    enum Content: Equatable, Sendable {
        case formatted(MarkdownMetadata)
        case literal(Substring)

        static let explanation = "Metadata couldn’t be formatted; its text is shown below"
        var plainText: String {
            switch self {
            case .formatted(let metadata): metadata.plainText
            case .literal(let source): String(source)
            }
        }
    }

    let candidate: Substring
    let payload: Substring
    let body: Substring
    let parserSource: String
    let content: Content

    static func extract(_ source: String, limits: YAMLMetadataLimits = .init()) -> MarkdownFrontMatter? {
        let bytes = source.utf8
        var start = bytes.startIndex
        if source.unicodeScalars.first == "\u{FEFF}" { start = bytes.index(start, offsetBy: 3) }
        func line(_ start: String.Index) -> (end: String.Index, next: String.Index) {
            var cursor = start
            while cursor < bytes.endIndex, bytes[cursor] != 10, bytes[cursor] != 13 { bytes.formIndex(after: &cursor) }
            let end = cursor
            if cursor < bytes.endIndex {
                let cr = bytes[cursor] == 13
                bytes.formIndex(after: &cursor)
                if cr, cursor < bytes.endIndex, bytes[cursor] == 10 { bytes.formIndex(after: &cursor) }
            }
            return (end, cursor)
        }
        func delimiter(_ start: String.Index, _ end: String.Index, closing: Bool) -> Bool {
            var cursor = start
            var prefix: [UInt8] = []
            for _ in 0..<3 {
                guard cursor < end else { return false }
                prefix.append(bytes[cursor]); bytes.formIndex(after: &cursor)
            }
            guard prefix == [45, 45, 45] || (closing && prefix == [46, 46, 46]) else { return false }
            while cursor < end {
                guard bytes[cursor] == 32 || bytes[cursor] == 9 else { return false }
                bytes.formIndex(after: &cursor)
            }
            return true
        }
        let opening = line(start)
        guard delimiter(start, opening.end, closing: false), opening.next > opening.end else { return nil }
        var cursor = opening.next
        while cursor < bytes.endIndex {
            let current = line(cursor)
            if delimiter(cursor, current.end, closing: true) {
                let candidate = source[..<current.next]
                let payload = source[opening.next..<cursor]
                let body = source[current.next...]
                let content: Content
                do { content = .formatted(try YAMLMetadataParser.parse(payload, limits: limits)) }
                catch { content = .literal(candidate) }
                // Only physical line endings survive; no long whitespace prefix.
                let mask = String(decoding: candidate.utf8.filter { $0 == 10 || $0 == 13 }, as: UTF8.self)
                return MarkdownFrontMatter(candidate: candidate, payload: payload, body: body,
                    parserSource: mask + body, content: content)
            }
            cursor = current.next
        }
        return nil
    }
}
