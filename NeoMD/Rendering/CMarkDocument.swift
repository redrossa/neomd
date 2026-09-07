import CMarkGFM
import Foundation

/// Parser-local ownership. Only copied Swift values may leave the rendering call.
nonisolated final class CMarkDocument {
    private static let extensionsRegistered: Void = {
        cmark_gfm_core_extensions_ensure_registered()
    }()

    // The pinned inline parser toggles process-global character tables per parse.
    // Serialize C parsing only; completed, separately owned trees adapt concurrently.
    private static let parsingLock = NSLock()

    let root: OpaquePointer
    private let parser: OpaquePointer

    init(markdown: String) {
        _ = Self.extensionsRegistered
        Self.parsingLock.lock()
        defer { Self.parsingLock.unlock() }
        let parser = cmark_parser_new(CMARK_OPT_DEFAULT | CMARK_OPT_FOOTNOTES)!
        self.parser = parser
        for name in ["autolink", "strikethrough", "table", "tasklist"] {
            cmark_parser_attach_syntax_extension(parser, cmark_find_syntax_extension(name))
        }
        markdown.utf8CString.withUnsafeBufferPointer { bytes in
            cmark_parser_feed(parser, bytes.baseAddress, bytes.count - 1)
        }
        root = cmark_parser_finish(parser)
    }

    deinit {
        cmark_node_free(root)
        cmark_parser_free(parser)
    }

    static func typeName(_ node: OpaquePointer) -> String {
        // The pinned public type-string function omits the two core footnote kinds.
        switch cmark_node_get_type(node) {
        case CMARK_NODE_FOOTNOTE_DEFINITION: return "footnote_definition"
        case CMARK_NODE_FOOTNOTE_REFERENCE: return "footnote_reference"
        default: return String(cString: cmark_node_get_type_string(node))
        }
    }

    static func literal(_ node: OpaquePointer) -> String {
        cmark_node_get_literal(node).map { String(cString: $0) } ?? ""
    }

    static func children(_ node: OpaquePointer) -> [OpaquePointer] {
        var result: [OpaquePointer] = []
        var child = cmark_node_first_child(node)
        while let current = child {
            result.append(current)
            child = cmark_node_next(current)
        }
        return result
    }
}
