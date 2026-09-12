import Foundation

nonisolated struct DocumentFindOptions: Equatable, Sendable {
    var caseSensitive = false
    var diacriticSensitive = false
    static let `default` = DocumentFindOptions()
}

nonisolated struct DocumentFindMatch: Equatable, Hashable, Sendable {
    let leafID: Int
    /// UTF-16 offsets in the rendered leaf, never persisted across presentations.
    let range: NSRange
}

nonisolated struct DocumentFindIndex: Sendable {
    struct Unit: Sendable {
        let leafID: Int
        let text: String
        let excluded: [NSRange]
    }
    let units: [Unit]

    init(_ document: MarkdownRenderDocument) {
        units = document.leafIDs.map { id in
            let block = document[id]
            var excluded: [NSRange] = []
            var offset = 0
            for run in block.text.runs {
                let length = String(block.text.characters[run.range]).utf16.count
                if run.markdownImage != nil { excluded.append(NSRange(location: offset, length: length)) }
                offset += length
            }
            if case .metadata(.formatted(let metadata)) = block.kind {
                offset = 0
                for row in metadata.rows {
                    excluded.append(NSRange(location: offset + row.key.utf16.count, length: 2))
                    offset += row.key.utf16.count + 2 + row.value.utf16.count
                    excluded.append(NSRange(location: offset, length: 1))
                    offset += 1
                }
            }
            return Unit(leafID: id, text: String(block.text.characters), excluded: excluded)
        }
    }

    func matches(for query: String, options: DocumentFindOptions = .default) -> [DocumentFindMatch] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var comparison: NSString.CompareOptions = [.literal]
        if !options.caseSensitive { comparison.insert(.caseInsensitive) }
        if !options.diacriticSensitive { comparison.insert(.diacriticInsensitive) }
        return units.flatMap { unit -> [DocumentFindMatch] in
            guard !Task.isCancelled else { return [] }
            let text = unit.text as NSString
            var offset = 0
            var result: [DocumentFindMatch] = []
            while offset < text.length, !Task.isCancelled {
                let range = text.range(of: query, options: comparison,
                                       range: NSRange(location: offset, length: text.length - offset))
                guard range.location != NSNotFound, range.length > 0 else { break }
                if !unit.excluded.contains(where: { NSIntersectionRange($0, range).length > 0 }) {
                    result.append(DocumentFindMatch(leafID: unit.leafID, range: range))
                }
                offset = NSMaxRange(range)
            }
            return result
        }
    }

    static func step(from current: Int?, count: Int, reverse: Bool, wrap: Bool = true)
        -> (index: Int, wrapped: Bool)? {
        guard count > 0 else { return nil }
        guard let current, (0..<count).contains(current) else {
            return (reverse ? count - 1 : 0, false)
        }
        let next = current + (reverse ? -1 : 1)
        if (0..<count).contains(next) { return (next, false) }
        return wrap ? (reverse ? count - 1 : 0, true) : nil
    }

    static func initialIndex(in matches: [DocumentFindMatch], atOrAfterLeaf leafID: Int?) -> Int? {
        guard !matches.isEmpty else { return nil }
        guard let leafID else { return 0 }
        return matches.firstIndex(where: { $0.leafID >= leafID }) ?? 0
    }
}
