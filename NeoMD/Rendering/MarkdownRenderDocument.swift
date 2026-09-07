import Foundation

/// A complete immutable rendering generation. Edges contain integers, never owned
/// nodes/handles, so destruction has bounded call depth even for extreme nesting.
/// IDs are contiguous preorder indices; subtree intervals are half-open.
nonisolated struct MarkdownRenderDocument: Sendable {
    let nodes: [MarkdownBlock]
    let rootIDs: [Int]
    let leafIDs: [Int]
    let subtreeEnds: [Int]
    let firstLeafIDs: [Int]
    let lastLeafIDs: [Int]
    let lazyRootIDs: [Int]
    let anchorTargets: [String: Int]

    static let empty = MarkdownRenderDocument(nodes: [], rootIDs: [])

    init(nodes: [MarkdownBlock], rootIDs: [Int]) {
        self.nodes = nodes
        self.rootIDs = rootIDs
        var ends = nodes.indices.map { $0 + 1 }
        var first = Array(nodes.indices)
        var last = first
        var roots = first
        var leaves: [Int] = []
        var anchors: [String: Int] = [:]
        for node in nodes {
            if let parent = node.parentID { roots[node.id] = roots[parent] }
            if node.isLeaf { leaves.append(node.id) }
            for anchor in node.anchors where anchors[anchor] == nil { anchors[anchor] = node.id }
        }
        for node in nodes.reversed() {
            if let child = node.childIDs.first { first[node.id] = first[child] }
            if let child = node.childIDs.last {
                last[node.id] = last[child]
                ends[node.id] = ends[child]
            }
        }
        leafIDs = leaves
        subtreeEnds = ends
        firstLeafIDs = first
        lastLeafIDs = last
        lazyRootIDs = roots
        anchorTargets = anchors
    }

    subscript(id: Int) -> MarkdownBlock { nodes[id] }
    var roots: [MarkdownBlock] { rootIDs.map { nodes[$0] } }
    var leaves: [MarkdownBlock] { leafIDs.map { nodes[$0] } }

    func children(of id: Int) -> [MarkdownBlock] { nodes[id].childIDs.map { nodes[$0] } }
    func subtreeIDs(in id: Int) -> Range<Int> { id..<subtreeEnds[id] }

    func leaves(in id: Int) -> [MarkdownBlock] {
        subtreeIDs(in: id).compactMap { nodes[$0].isLeaf ? nodes[$0] : nil }
    }
}
