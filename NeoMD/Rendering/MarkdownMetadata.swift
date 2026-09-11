import Foundation

/// Flat ownership: collection and alias edges are indices, never recursive values.
nonisolated struct MarkdownMetadata: Equatable, Sendable {
    enum Value: Equatable, Sendable {
        case scalar(String, quoted: Bool)
        case mapping
        case sequence
        case alias(Int)
    }

    struct Node: Equatable, Sendable {
        let value: Value
        let tag: String?
        let anchor: String?
        var children: [Int] = [] // mapping: alternating key/value indices
    }

    struct Row: Equatable, Sendable {
        let key: String
        let value: String
        var accessibilityLabel: String { key + ": " + value }
    }

    let nodes: [Node]
    let rows: [Row]
    var plainText: String { rows.map(\.accessibilityLabel).joined(separator: "\n") }

    /// Index-linked contexts avoid copying ever-growing paths on every descent.
    private struct Context {
        let parent: Int?
        let label: String
    }
    private enum Work {
        case visit(Int, Int?)
        case leave(Int)
    }

    static func project(_ nodes: [Node], limits: YAMLMetadataLimits) throws -> MarkdownMetadata {
        guard !nodes.isEmpty else {
            let row = Row(key: "Metadata", value: "Empty document")
            guard limits.visits >= 1, limits.outputBytes >= row.key.utf8.count + row.value.utf8.count else {
                throw YAMLMetadataError.limit
            }
            return MarkdownMetadata(nodes: [], rows: [row])
        }
        var contexts: [Context] = []
        var work: [Work] = [.visit(0, nil)]
        var active: Set<Int> = []
        var rows: [Row] = []
        var visits = 0
        var bytes = 0
        func context(_ parent: Int?, _ label: String) -> Int {
            contexts.append(Context(parent: parent, label: label))
            return contexts.count - 1
        }
        func countVisit() throws {
            guard visits < limits.visits else { throw YAMLMetadataError.limit }
            visits += 1
        }
        func emit(_ at: Int?, _ value: String) throws {
            var labels: [String] = []
            var current = at
            var size = value.utf8.count
            guard size <= limits.outputBytes - bytes else { throw YAMLMetadataError.limit }
            while let index = current {
                let label = contexts[index].label
                let addition = label.utf8.count + (labels.isEmpty ? 0 : " › ".utf8.count)
                guard addition <= limits.outputBytes - bytes - size else { throw YAMLMetadataError.limit }
                size += addition
                labels.append(label)
                current = contexts[index].parent
            }
            if labels.isEmpty {
                labels = ["Value"]
                size += 5
            }
            guard size <= limits.outputBytes - bytes, rows.count < limits.visits else { throw YAMLMetadataError.limit }
            bytes += size
            rows.append(Row(key: labels.reversed().joined(separator: " › "), value: value))
        }
        while let next = work.popLast() {
            switch next {
            case .leave(let index): active.remove(index)
            case .visit(let index, let path):
                try countVisit()
                guard nodes.indices.contains(index), active.insert(index).inserted else { throw YAMLMetadataError.invalid }
                work.append(.leave(index))
                let node = nodes[index]
                if let tag = node.tag { try emit(context(path, "Tag"), tag) }
                switch node.value {
                case .alias(let target): work.append(.visit(target, path))
                case .scalar(let text, let quoted):
                    try emit(path, text.isEmpty ? (quoted ? "Empty string" : "Empty value") : text)
                case .sequence:
                    if node.children.isEmpty { try emit(path, "Empty sequence") }
                    for (offset, child) in node.children.enumerated().reversed() {
                        work.append(.visit(child, context(path, "Item \(offset + 1)")))
                    }
                case .mapping:
                    guard node.children.count.isMultiple(of: 2) else { throw YAMLMetadataError.invalid }
                    if node.children.isEmpty { try emit(path, "Empty mapping") }
                    var entries: [Work] = []
                    for offset in stride(from: 0, to: node.children.count, by: 2) {
                        let key = node.children[offset]
                        let value = node.children[offset + 1]
                        if case .scalar(let text, let quoted) = nodes[key].value, nodes[key].tag == nil {
                            try countVisit()
                            let label = text.isEmpty ? (quoted ? "Empty string key" : "Empty key") : text
                            entries.append(.visit(value, context(path, label)))
                        } else {
                            let entry = context(path, "Entry \(offset / 2 + 1)")
                            entries.append(.visit(key, context(entry, "Key")))
                            entries.append(.visit(value, context(entry, "Value")))
                        }
                    }
                    work.append(contentsOf: entries.reversed())
                }
            }
        }
        return MarkdownMetadata(nodes: nodes, rows: rows)
    }
}

nonisolated struct YAMLMetadataLimits: Sendable {
    var inputBytes = 256 * 1024
    var depth = 64
    var nodes = 10_000
    var events = 40_000
    var visits = 20_000
    var outputBytes = 1024 * 1024
}

nonisolated enum YAMLMetadataError: Error {
    case invalid, limit
}
