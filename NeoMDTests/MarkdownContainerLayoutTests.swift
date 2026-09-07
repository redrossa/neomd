import SwiftUI
import Testing
@testable import NeoMD

struct MarkdownContainerLayoutTests {
    private func measurements(_ geometry: MarkdownContainerGeometry) -> [MarkdownContainerGeometry.Measurement] {
        geometry.entries.map { entry in
            let node = geometry.document[entry.id]
            if node.isLeaf { return .init(size: CGSize(width: entry.width, height: 18), baseline: 14) }
            if entry.caption != nil { return .init(size: CGSize(width: entry.width, height: 20), baseline: 15) }
            if node.kind == .blockQuote { return .zero }
            return .init(size: CGSize(width: 28, height: 16), baseline: 12)
        }
    }

    @Test func shallowQuoteTaskFootnotePreservesWidthsAndBaselines() {
        let document = MarkdownRenderDocument(nodes: [
            MarkdownBlock(id: 0, kind: .blockQuote, text: "", childIDs: [1]),
            MarkdownBlock(id: 1, kind: .listItem(marker: "5.", depth: 1), text: "", childIDs: [2], parentID: 0, task: .incomplete),
            MarkdownBlock(id: 2, kind: .footnote(ordinal: 1), text: "", childIDs: [3], parentID: 1),
            MarkdownBlock(id: 3, kind: .paragraph, text: "two lines", parentID: 2)
        ], rootIDs: [0])
        for width: CGFloat in [320, 760] {
            let geometry = MarkdownContainerGeometry(document: document, rootID: 0, width: width)
            var sizes = measurements(geometry)
            sizes[3] = .init(size: CGSize(width: width - 87, height: 40), baseline: 14)
            let result = geometry.place(sizes)
            #expect(geometry.entries.map(\.naturalX) == [0, 15, 51, 87])
            #expect(geometry.entries.map(\.depth) == [1, 2, 3, 4])
            #expect(geometry.entries.allSatisfy { !$0.compressed && $0.caption == nil })
            #expect(result.frames[3] == CGRect(x: 87, y: 0, width: width - 87, height: 40))
            #expect(result.frames[1].minY + sizes[1].baseline == result.frames[3].minY + sizes[3].baseline)
            #expect(result.frames[2].minY == result.frames[3].minY)
            #expect(result.quoteBars == [CGRect(x: 0, y: 0, width: 3, height: 40)])
            #expect(result.size == CGSize(width: width, height: 40))
        }
    }

    @Test func nestedListAdjustmentAndContinuationSpacing() {
        let document = MarkdownBlockRenderer.render(from: "- first\n  - nested\n\n  after")
        let geometry = MarkdownContainerGeometry(document: document, rootID: 0, width: 320)
        let result = geometry.place(measurements(geometry))
        #expect(document.nodes.map(\.id) == [0, 1, 2, 3, 4])
        #expect(geometry.entries.map(\.x) == [0, 36, 22, 58, 36])
        #expect(result.frames[1].minY == 0)
        #expect(result.frames[3].minY == 34)
        #expect(result.frames[4].minY == 68)
        #expect(result.size.height == 86)
    }

    @Test func exactWidthBoundaryAndUnrelatedShallowSibling() {
        // Eight quotes naturally require 120pt; at W=300 budget is exactly 120.
        let document = MarkdownBlockRenderer.render(from: String(repeating: "> ", count: 8) + "deep\n\n> shallow")
        let boundary = MarkdownContainerGeometry(document: document, rootID: 0, width: 300)
        let compressed = MarkdownContainerGeometry(document: document, rootID: 0, width: 299)
        #expect(boundary.entries.allSatisfy { !$0.compressed })
        #expect(compressed.entries.contains { $0.compressed })
        #expect(compressed.entries.last!.width >= min(240, 299 * 0.6))
        let shallow = MarkdownContainerGeometry(document: document, rootID: document.rootIDs[1], width: 299)
        #expect(shallow.entries.allSatisfy { !$0.compressed })
        #expect(shallow.entries.last!.x == 15)
    }

    @Test(arguments: [1000, 10000, 50000])
    func branchingHasFixedLinearWorkAndNoMarkerCollisions(_ depth: Int) {
        var nodes: [MarkdownBlock] = []
        for level in 0..<depth {
            let id = 2 * level
            nodes.append(MarkdownBlock(id: id, kind: .blockQuote, text: "",
                childIDs: level == depth - 1 ? [id + 1] : [id + 1, id + 2],
                parentID: level == 0 ? nil : id - 2))
            nodes.append(MarkdownBlock(id: id + 1, kind: .paragraph, text: AttributedString("retained \(level)"), parentID: id))
        }
        let document = MarkdownRenderDocument(nodes: nodes, rootIDs: [0])
        let geometry = MarkdownContainerGeometry(document: document, rootID: 0, width: 320)
        let result = geometry.place(measurements(geometry))
        #expect(geometry.entries.count == nodes.count)
        #expect(result.operations <= 6 * nodes.count)
        #expect(result.quoteBars.count == depth)
        #expect(result.frames.count == nodes.count)
        var previousBottom: CGFloat = -1
        for entry in geometry.entries where document[entry.id].isLeaf {
            let frame = result.frames[entry.id]
            #expect(frame.minY > previousBottom)
            #expect(frame.minX <= geometry.budget)
            #expect(frame.width >= 192)
            #expect(document[entry.id].parentID == entry.id - 1)
            previousBottom = frame.maxY
        }
        print("BRANCH_LINEAR nodes=\(nodes.count) operations=\(result.operations)")
    }

    @Test func unaryGroupingDoesNotCrossMixedContainerOrLeafBoundary() {
        let document = MarkdownBlockRenderer.render(from: String(repeating: "> ", count: 50000) + "retained")
        let geometry = MarkdownContainerGeometry(document: document, rootID: 0, width: 320)
        #expect(geometry.entries.count == 50001)
        #expect(geometry.viewEntries.map(\.id) == Array(0...8) + [50000], "Only shallow AX context, the caption and native leaf allocate subviews")
        #expect(geometry.entries.compactMap(\.caption).count == 1)
        #expect(geometry.entries.compactMap(\.caption).first == "Depths 9–50000 · quote indentation compressed")
        let result = geometry.place(measurements(geometry))
        #expect(result.operations <= 6 * document.nodes.count)
        #expect(result.frames.last!.width == 192)
        #expect(result.frames.last!.minY == 28)
    }
}
