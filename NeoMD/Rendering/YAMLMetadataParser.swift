import Foundation
import LibYAML

/// One parser and one flat arena per call. All C-owned bytes are copied before
/// deleting their event; the input buffer outlives every parse operation.
nonisolated enum YAMLMetadataParser {
    static func parse(_ payload: Substring, limits: YAMLMetadataLimits = .init()) throws -> MarkdownMetadata {
        guard payload.utf8.count <= limits.inputBytes else { throw YAMLMetadataError.limit }
        let bytes = Array(payload.utf8)
        return try bytes.withUnsafeBufferPointer { buffer in
            var parser = yaml_parser_t()
            guard yaml_parser_initialize(&parser) != 0 else { throw YAMLMetadataError.invalid }
            defer { yaml_parser_delete(&parser) }
            // Empty buffers still require a non-null pointer in libyaml's API.
            var empty: UInt8 = 0
            return try withUnsafePointer(to: &empty) { emptyPointer in
                yaml_parser_set_input_string(&parser, buffer.baseAddress ?? emptyPointer, buffer.count)
                return try consume(&parser, limits: limits)
            }
        }
    }

    private static func consume(_ parser: inout yaml_parser_t, limits: YAMLMetadataLimits) throws -> MarkdownMetadata {
        var nodes: [MarkdownMetadata.Node] = []
        var containers: [Int] = []
        var anchors: [String: Int] = [:]
        var events = 0
        var documents = 0
        var ended = false
        var root: Int?
        while true {
            var event = yaml_event_t()
            guard yaml_parser_parse(&parser, &event) != 0 else { throw YAMLMetadataError.invalid }
            defer { yaml_event_delete(&event) }
            guard events < limits.events else { throw YAMLMetadataError.limit }
            events += 1
            var value: MarkdownMetadata.Value?
            var tag: String?
            var anchor: String?
            var opens = false
            switch event.type {
            case YAML_STREAM_START_EVENT: break
            case YAML_DOCUMENT_START_EVENT:
                documents += 1
                guard documents == 1, !ended else { throw YAMLMetadataError.invalid }
            case YAML_DOCUMENT_END_EVENT:
                guard containers.isEmpty, root != nil else { throw YAMLMetadataError.invalid }
                ended = true
            case YAML_STREAM_END_EVENT:
                guard containers.isEmpty, documents == 0 || ended else { throw YAMLMetadataError.invalid }
                return try MarkdownMetadata.project(nodes, limits: limits)
            case YAML_SCALAR_EVENT:
                let scalar = event.data.scalar
                let text = String(decoding: UnsafeBufferPointer(start: scalar.value, count: scalar.length), as: UTF8.self)
                value = .scalar(text, quoted: scalar.style != YAML_PLAIN_SCALAR_STYLE)
                tag = string(scalar.tag)
                anchor = string(scalar.anchor)
            case YAML_ALIAS_EVENT:
                guard let name = string(event.data.alias.anchor), let target = anchors[name] else { throw YAMLMetadataError.invalid }
                value = .alias(target)
            case YAML_MAPPING_START_EVENT:
                value = .mapping
                tag = string(event.data.mapping_start.tag)
                anchor = string(event.data.mapping_start.anchor)
                opens = true
            case YAML_SEQUENCE_START_EVENT:
                value = .sequence
                tag = string(event.data.sequence_start.tag)
                anchor = string(event.data.sequence_start.anchor)
                opens = true
            case YAML_MAPPING_END_EVENT, YAML_SEQUENCE_END_EVENT:
                guard let index = containers.popLast() else { throw YAMLMetadataError.invalid }
                if event.type == YAML_MAPPING_END_EVENT {
                    guard nodes[index].value == .mapping, nodes[index].children.count.isMultiple(of: 2) else { throw YAMLMetadataError.invalid }
                } else if nodes[index].value != .sequence { throw YAMLMetadataError.invalid }
            default: throw YAMLMetadataError.invalid
            }
            if let value {
                guard documents == 1, !ended else { throw YAMLMetadataError.invalid }
                guard nodes.count < limits.nodes, !opens || containers.count < limits.depth else { throw YAMLMetadataError.limit }
                let index = nodes.count
                nodes.append(.init(value: value, tag: tag, anchor: anchor))
                if let parent = containers.last { nodes[parent].children.append(index) }
                else {
                    guard root == nil else { throw YAMLMetadataError.invalid }
                    root = index
                }
                if let anchor { anchors[anchor] = index }
                if opens { containers.append(index) }
            }
        }
    }

    private static func string(_ pointer: UnsafePointer<UInt8>?) -> String? {
        pointer.map { String(cString: $0) }
    }
}
