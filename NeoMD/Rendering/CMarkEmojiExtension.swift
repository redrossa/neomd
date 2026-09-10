import CMarkGFM
import Foundation

/// Raw parser candidates retain provenance through text consolidation and link resolution.
nonisolated enum CMarkEmojiExtension {
    static let aliases: [String: String] = {
        guard let url = Bundle.main.url(forResource: "gemoji-aliases", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let aliases = try? JSONDecoder().decode([String: String].self, from: data) else {
            preconditionFailure("Bundled Unicode emoji corpus is missing or invalid")
        }
        return aliases
    }()
    private static let maximumAliasBytes = aliases.keys.map { $0.utf8.count }.max() ?? 0

    static let syntax: OpaquePointer = {
        let syntax = cmark_syntax_extension_new("neomd-emoji-candidate")!
        let characters = cmark_llist_append(cmark_get_default_mem_allocator(), nil,
                                            UnsafeMutableRawPointer(bitPattern: 58))
        cmark_syntax_extension_set_special_inline_chars(syntax, characters)
        cmark_syntax_extension_set_match_inline_func(syntax) { ext, _, _, character, parser in
            guard character == 58, let parser else { return nil }
            let start = cmark_inline_parser_get_offset(parser)
            var bytes: [UInt8] = []
            for distance in 1...(maximumAliasBytes + 1) {
                let byte = cmark_inline_parser_peek_at(parser, start + Int32(distance))
                if byte == 58 {
                    let alias = String(decoding: bytes, as: UTF8.self)
                    guard aliases[alias] != nil,
                          let node = cmark_node_new(CMARK_NODE_CUSTOM_INLINE) else { return nil }
                    cmark_node_set_syntax_extension(node, ext)
                    cmark_node_set_on_enter(node, ":" + alias + ":")
                    cmark_inline_parser_set_offset(parser, start + Int32(distance) + 1)
                    return node
                }
                guard (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57) ||
                        byte == 95 || byte == 43 || byte == 45 else { return nil }
                bytes.append(byte)
            }
            return nil
        }
        return syntax
    }()

    static func text(_ node: OpaquePointer, imageAlternative: Bool) -> String? {
        guard cmark_node_get_type(node) == CMARK_NODE_CUSTOM_INLINE,
              cmark_node_get_syntax_extension(node) == syntax,
              let raw = cmark_node_get_on_enter(node) else { return nil }
        let token = String(cString: raw)
        return imageAlternative ? token : aliases[String(token.dropFirst().dropLast())]
    }
}
