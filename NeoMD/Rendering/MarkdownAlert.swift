import CMarkGFM
import Foundation

nonisolated enum MarkdownAlert: String, CaseIterable, Sendable {
    case note = "NOTE", tip = "TIP", important = "IMPORTANT", warning = "WARNING", caution = "CAUTION"

    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .note: "info.circle"
        case .tip: "lightbulb"
        case .important: "bubble.left.and.exclamationmark.bubble.right"
        case .warning: "exclamationmark.triangle"
        case .caution: "hand.raised"
        }
    }
}

extension CMarkDocument {
    /// Verify both the physical quote opening and its direct parser-owned inline shape.
    func alert(_ quote: OpaquePointer) -> (MarkdownAlert, OpaquePointer, Int)? {
        guard cmark_node_parent(quote) == root,
              let paragraph = cmark_node_first_child(quote), Self.typeName(paragraph) == "paragraph",
              cmark_node_get_start_line(paragraph) == cmark_node_get_start_line(quote),
              let line = sourceLine(Int(cmark_node_get_start_line(quote))) else { return nil }
        let prefix = line.prefix(while: { $0 == 32 })
        guard prefix.count <= 3 else { return nil }
        var opening = line.dropFirst(prefix.count)
        guard opening.first == 62 else { return nil }
        opening = opening.dropFirst().drop(while: { $0 == 32 || $0 == 9 })
        while opening.last == 32 || opening.last == 9 { opening = opening.dropLast() }
        guard let kind = MarkdownAlert.allCases.first(where: { Array("[!\($0.rawValue)]".utf8) == Array(opening) }),
              let first = cmark_node_first_child(paragraph), Self.typeName(first) == "text",
              Self.literal(first).trimmingCharacters(in: .whitespaces) == "[!\(kind.rawValue)]" else { return nil }
        if let separator = cmark_node_next(first) {
            guard ["softbreak", "linebreak"].contains(Self.typeName(separator)) else { return nil }
            return (kind, paragraph, 2)
        }
        return (kind, paragraph, 1)
    }
}
