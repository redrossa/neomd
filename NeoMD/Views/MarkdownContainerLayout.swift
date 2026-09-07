import SwiftUI

/// Pure numeric layout over a preorder arena. No ancestor-path arrays, recursive
/// measurement, or source-shaped view graph. Each edge is visited a fixed number
/// of times. Leaf measurement is the only content-dependent cost.
nonisolated struct MarkdownContainerGeometry {
    struct Measurement {
        var size: CGSize
        var baseline: CGFloat
        static let zero = Measurement(size: .zero, baseline: 0)
    }

    struct Entry {
        let id: Int
        let depth: Int
        let naturalX: CGFloat
        let x: CGFloat
        let width: CGFloat
        let quoted: Bool
        let compressed: Bool
        var caption: String?
    }

    struct Result {
        let frames: [CGRect]
        let nodeFrames: [CGRect]
        let quoteBars: [CGRect]
        let size: CGSize
        let baseline: CGFloat
        let operations: Int
    }

    let document: MarkdownRenderDocument
    let rootID: Int
    let width: CGFloat
    let budget: CGFloat
    let entries: [Entry]
    let preparationOperations: Int

    /// Semantic offsets, not a zip with all arena nodes. Decorations do not
    /// allocate native/AX views; anchored nodes still receive a real marker.
    let viewEntries: [Entry]

    private static func requiresView(_ entry: Entry, document: MarkdownRenderDocument) -> Bool {
        let node = document[entry.id]
        if node.isLeaf || entry.caption != nil || !node.anchors.isEmpty { return true }
        // Preserve the existing shallow quote AX context/identifier. These
        // carry no drawing; the width-bounded compressed interior has none.
        if node.kind == .blockQuote && !entry.compressed { return true }
        switch node.kind {
        case .listItem, .footnote: return true
        default: return false
        }
    }

    init(document: MarkdownRenderDocument, rootID: Int, width: CGFloat) {
        self.document = document
        self.rootID = rootID
        self.width = max(0, width)
        budget = max(0, width - min(240, width * 0.6))
        var entries: [Entry] = []
        var operations = 0
        for id in document.subtreeIDs(in: rootID) {
            let node = document[id]
            var naturalX: CGFloat = 0
            var depth = 1
            var quoted = false
            if let parentID = node.parentID, parentID >= rootID {
                let parent = document[parentID]
                let entry = entries[parentID - rootID]
                naturalX = entry.naturalX + Self.inset(parent.kind)
                if case .listItem = parent.kind, case .listItem = node.kind { naturalX -= 14 }
                depth = entry.depth + 1
                quoted = entry.quoted || parent.kind == .blockQuote
            }
            let compressed = !node.isLeaf && naturalX + Self.inset(node.kind) > budget
            let x = min(naturalX, budget)
            entries.append(Entry(id: id, depth: depth, naturalX: naturalX, x: x,
                                 width: max(0, width - x), quoted: quoted,
                                 compressed: compressed, caption: nil))
            operations += 1
        }
        // Group only homogeneous unary quote runs; never cross branching or a
        // list/task/footnote/leaf boundary. Every semantic node remains in entries.
        var offset = 0
        while offset < entries.count {
            let entry = entries[offset]
            let node = document[entry.id]
            guard entry.compressed else { offset += 1; operations += 1; continue }
            if node.kind == .blockQuote {
                var end = offset
                while document[entries[end].id].childIDs.count == 1,
                      let child = document[entries[end].id].childIDs.first,
                      document[child].kind == .blockQuote {
                    end = child - rootID
                    operations += 1
                }
                let range = end == offset ? "Depth \(entry.depth)" : "Depths \(entry.depth)–\(entries[end].depth)"
                entries[offset].caption = "\(range) · quote indentation compressed"
                offset = end + 1
            } else {
                switch node.kind {
                case .listItem: entries[offset].caption = "Depth \(entry.depth) · list item · indentation compressed"
                case .footnote(let ordinal): entries[offset].caption = "Depth \(entry.depth) · footnote \(ordinal) · indentation compressed"
                default: break
                }
                offset += 1
            }
            operations += 1
        }
        self.entries = entries
        viewEntries = entries.filter { Self.requiresView($0, document: document) }
        preparationOperations = operations + entries.count
    }

    private static func inset(_ kind: MarkdownBlock.Kind) -> CGFloat {
        switch kind {
        case .blockQuote: 15
        case .listItem, .footnote: 36
        default: 0
        }
    }

    /// One measurement per entry: native leaf, marker, passive caption, or zero.
    func place(_ measurements: [Measurement]) -> Result {
        precondition(measurements.count == entries.count)
        var heights = [CGFloat](repeating: 0, count: entries.count)
        var baselines = heights
        var childOffsets = heights
        var ownOffsets = heights
        var childStarts = heights
        var operations = preparationOperations
        for entry in entries.reversed() {
            let index = entry.id - rootID
            let node = document[entry.id]
            let own = measurements[index]
            if node.isLeaf {
                heights[index] = own.size.height
                baselines[index] = own.baseline
            } else {
                var childHeight: CGFloat = 0
                for (position, child) in node.childIDs.enumerated() {
                    if position > 0 { childHeight += 16 }
                    childStarts[child - rootID] = childHeight
                    childHeight += heights[child - rootID]
                    operations += 1
                }
                let firstBaseline = node.childIDs.first.map { baselines[$0 - rootID] } ?? 0
                if entry.caption != nil {
                    childOffsets[index] = own.size.height + 8
                    heights[index] = childHeight + childOffsets[index]
                    baselines[index] = own.baseline
                } else if case .listItem = node.kind, !entry.compressed {
                    let baseline = max(firstBaseline, own.baseline)
                    ownOffsets[index] = baseline - own.baseline
                    childOffsets[index] = baseline - firstBaseline
                    heights[index] = max(ownOffsets[index] + own.size.height, childOffsets[index] + childHeight)
                    baselines[index] = baseline
                } else {
                    heights[index] = max(childHeight, own.size.height)
                    baselines[index] = firstBaseline
                }
            }
            operations += 1
        }
        var origins = [CGFloat](repeating: 0, count: entries.count)
        var frames = [CGRect](repeating: .zero, count: entries.count)
        var nodeFrames = frames
        var bars: [CGRect] = []
        for entry in entries {
            let index = entry.id - rootID
            let node = document[entry.id]
            if let parent = node.parentID, parent >= rootID {
                origins[index] = origins[parent - rootID] + childOffsets[parent - rootID] + childStarts[index]
            }
            let own = measurements[index]
            frames[index] = CGRect(x: entry.x, y: origins[index] + ownOffsets[index],
                                   width: own.size.width, height: own.size.height)
            nodeFrames[index] = CGRect(x: entry.x, y: origins[index], width: entry.width, height: heights[index])
            if node.kind == .blockQuote {
                // Deeper rules overlap within the bounded indent, never text.
                // Passive depth rows expose the exact compressed semantic run.
                bars.append(CGRect(x: min(entry.naturalX, max(0, budget - 3)), y: origins[index],
                                   width: min(3, budget), height: heights[index]))
            }
            operations += 1
        }
        return Result(frames: frames, nodeFrames: nodeFrames, quoteBars: bars,
                      size: CGSize(width: width, height: heights.first ?? 0),
                      baseline: baselines.first ?? 0, operations: operations)
    }
}

struct MarkdownContainerLayout: Layout {
    let geometry: MarkdownContainerGeometry
    let decoration: MarkdownQuoteDecoration

    struct Cache {
        var result: MarkdownContainerGeometry.Result?
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }
    func updateCache(_ cache: inout Cache, subviews: Subviews) { cache.result = nil }

    private func measured(_ subviews: Subviews) -> MarkdownContainerGeometry.Result {
        let entries = geometry.viewEntries
        precondition(entries.count == subviews.count)
        var measurements = [MarkdownContainerGeometry.Measurement](repeating: .zero, count: geometry.entries.count)
        for (entry, view) in zip(entries, subviews) {
            let node = geometry.document[entry.id]
            if node.kind == .blockQuote && entry.caption == nil { continue }
            let width: CGFloat
            if !node.isLeaf, entry.caption == nil {
                width = node.kind == .blockQuote || entry.compressed ? 0 : 28
            } else { width = entry.width }
            let dimension = view.dimensions(in: ProposedViewSize(width: width, height: nil))
            measurements[entry.id - geometry.rootID] = MarkdownContainerGeometry.Measurement(
                size: CGSize(width: width, height: dimension.height), baseline: dimension[.firstTextBaseline])
        }
        return geometry.place(measurements)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let result = measured(subviews)
        cache.result = result
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let result = cache.result ?? measured(subviews)
        decoration.bars = result.quoteBars
        for (entry, view) in zip(geometry.viewEntries, subviews) {
            let index = entry.id - geometry.rootID
            let frame = geometry.document[entry.id].kind == .blockQuote && entry.caption == nil
                ? result.nodeFrames[index] : result.frames[index]
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }
}
