import SwiftUI
import Testing
@testable import NeoMD

/// Pure finite table geometry and the local overflow action policy.
///
/// Measurements are supplied as numbers; no view, scroller, window or event is
/// created, so actual scrolling and keyboard behaviour remain unverified.
@MainActor
struct MarkdownTableLayoutTests {
    private func layout(_ viewport: CGFloat, _ widths: [CGFloat], scale: CGFloat = 1) -> MarkdownTableLayout {
        MarkdownTableLayout(viewportWidth: viewport, preferredContentWidths: widths, scale: scale)
    }

    @Test(arguments: [0, 1, 240, 320, 760] as [CGFloat])
    func columnsStayWithinPolicyBoundsAndNeverReportAWiderOuterWidth(_ viewport: CGFloat) {
        for scale: CGFloat in [1, 1.5, 2] {
            let narrow = layout(viewport, [10, 20], scale: scale)
            let wide = layout(viewport, Array(repeating: 4000, count: 12), scale: scale)
            let minimum = MarkdownTableLayout.minimumCellWidth * scale + narrow.padding * 2
            let maximum = MarkdownTableLayout.maximumCellWidth * scale + wide.padding * 2
            #expect(narrow.columnWidths.allSatisfy { $0 >= minimum - 0.001 })
            #expect(wide.columnWidths.allSatisfy { $0 <= maximum + 0.001 })
            #expect(narrow.columnWidths.allSatisfy(\.isFinite) && wide.columnWidths.allSatisfy(\.isFinite))
            // The viewport is what the reader allotted; only the internal document
            // may be wider, and a fitting table fills it exactly.
            #expect(narrow.viewportWidth == max(1, viewport))
            #expect(wide.viewportWidth == max(1, viewport))
            if !narrow.overflows {
                #expect(abs(narrow.contentWidth - narrow.viewportWidth) < 0.001)
            }
            #expect(wide.contentWidth >= wide.viewportWidth)
        }
    }

    @Test func invalidProposalsAreClampedToFinitePositiveGeometry() {
        for viewport: CGFloat in [-100, 0, .nan, .infinity] {
            let policy = layout(viewport, [.nan, .infinity, -40])
            #expect(policy.viewportWidth == 1)
            #expect(policy.columnWidths.count == 3)
            #expect(policy.columnWidths.allSatisfy { $0.isFinite && $0 > 0 })
            #expect(policy.contentWidth.isFinite)
            #expect(policy.clampedOffset(.nan) == 0)
            #expect(policy.clampedOffset(.infinity) == policy.maximumOffset)
        }
        let scaled = layout(400, [100, 100], scale: .nan)
        #expect(scaled.scale == 1 && scaled.padding == MarkdownTableLayout.cellPadding)
    }

    @Test func singleColumnAndTwelveColumnOverflowTransitions() {
        let single = layout(760, [200])
        #expect(single.columnWidths.count == 1)
        #expect(!single.overflows)
        #expect(single.maximumOffset == 0)
        #expect(single.clampedOffset(500) == 0, "A fitting table stays pinned to its leading edge")

        let twelve = layout(760, Array(repeating: 300, count: 12))
        #expect(twelve.overflows)
        #expect(twelve.maximumOffset == twelve.contentWidth - 760)
        #expect(twelve.clampedOffset(-40) == 0)
        #expect(twelve.clampedOffset(1_000_000) == twelve.maximumOffset)
        // Column origins are cumulative and stay inside the internal document.
        #expect(twelve.columnX(0) == 0)
        #expect(twelve.columnX(12) == twelve.contentWidth)
        for column in 0..<12 {
            #expect(twelve.columnX(column) + twelve.columnWidths[column] <= twelve.contentWidth + 0.001)
            #expect(twelve.contentWidth(column: column) == twelve.columnWidths[column] - twelve.padding * 2)
        }
        #expect(twelve.columnX(-1) == 0 && twelve.contentWidth(column: 99) == 1)
    }

    @Test func rowHeightsFollowTheTallestCellAndKeepEmptyRowsVisible() {
        for scale: CGFloat in [1, 1.5, 2] {
            let policy = layout(400, [120, 120], scale: scale)
            let minimum = MarkdownTableLayout.minimumCellHeight * scale + policy.padding * 2
            #expect(policy.rowHeight(cellHeights: []) == minimum)
            #expect(policy.rowHeight(cellHeights: [0, 0]) == minimum)
            #expect(policy.rowHeight(cellHeights: [.nan, .infinity]) == minimum)
            // Wrapped text grows its row; nothing is truncated to a fixed height.
            let wrapped = policy.rowHeight(cellHeights: [18, 96])
            #expect(wrapped == 96 + policy.padding * 2)
            #expect(wrapped > policy.rowHeight(cellHeights: [18, 40]))
            #expect(policy.minimumRowHeight == minimum)
        }
    }

    @Test(arguments: [MarkdownTableStructure.Alignment.unspecified, .left, .center, .right])
    func alignmentIsAColumnDescriptorIndependentOfGeometry(_ alignment: MarkdownTableStructure.Alignment) {
        let structure = MarkdownTableStructure(
            alignments: [alignment, .left, .center, .right],
            rows: [.init(isHeader: true, cells: 0..<4), .init(isHeader: false, cells: 4..<8)])
        #expect(structure.alignment(column: 0) == alignment)
        #expect(structure.alignment(column: 4) == .unspecified, "Out of range stays unspecified")
        #expect(structure.columnCount == 4 && structure.rowCount == 2)
        #expect(structure.headerRowIndex == 0)
        let policy = layout(760, Array(repeating: 150, count: 4))
        #expect(policy.columnWidths.count == structure.columnCount)
        #expect(Set(policy.columnWidths).count == 1, "Alignment never changes column geometry")
    }

    @Test func tableIsOneAtomicLayoutEntryWithNoDuplicateOuterCellViews() throws {
        let document = MarkdownBlockRenderer.render(from: """
        > | A | B |
        > | --- | --- |
        > | c | d |
        """)
        let root = document.rootIDs[0]
        for width: CGFloat in [120, 320, 760] {
            let geometry = MarkdownContainerGeometry(document: document, rootID: root, width: width)
            let tableID = try #require(document.nodes.first(where: \.isTable)?.id)
            let viewIDs = geometry.viewEntries.map(\.id)
            #expect(viewIDs.contains(tableID))
            // Cells own semantics in the arena but emit no outer view or frame.
            #expect(document[tableID].childIDs.allSatisfy { !viewIDs.contains($0) })
            var measurements = [MarkdownContainerGeometry.Measurement](
                repeating: .zero, count: geometry.entries.count)
            let tableHeight: CGFloat = 140
            for entry in geometry.viewEntries {
                let node = document[entry.id]
                measurements[entry.id - root] = .init(
                    size: CGSize(width: entry.width, height: node.isTable ? tableHeight : 0), baseline: 0)
            }
            let result = geometry.place(measurements)
            // The table's own measurement is its height: it is never a vertical sum
            // of its cells plus block gaps.
            #expect(result.frames[tableID - root].height == tableHeight)
            #expect(result.size.height == tableHeight)
            #expect(result.size.width == width, "The outer width never expands")
            #expect(document[tableID].childIDs.allSatisfy { result.frames[$0 - root] == .zero })
        }
    }

    @Test func candidateOrderPlacesOneOverflowStopBeforeRowMajorCellStops() throws {
        let document = MarkdownBlockRenderer.render(from: """
        intro

        | A | [B](https://example.com) |
        | --- | --- |
        | c | d |

        | E |
        | --- |
        | f |
        """)
        let tables = document.nodes.filter(\.isTable).map(\.id)
        #expect(tables.count == 2)
        let candidates = DocumentReaderTraversal.candidates(in: document)
        let overflow = candidates.filter { if case .tableOverflow = $0 { return true }; return false }
        #expect(overflow == [.tableOverflow(tables[0]), .tableOverflow(tables[1])])
        for tableID in tables {
            let stop = try #require(candidates.firstIndex(of: .tableOverflow(tableID)))
            let cells = document[tableID].childIDs
            let cellStops = candidates.indices.filter {
                candidates[$0].leafID.map(cells.contains) == true
            }
            #expect(cellStops.allSatisfy { $0 > stop }, "The overflow stop precedes its own cells")
            // Cell stops stay in row-major order, with separate text and link stops.
            let order = cellStops.compactMap { candidates[$0].leafID }
            #expect(order == order.sorted())
        }
        #expect(candidates.contains(.links(document[tables[0]].childIDs[1])))
        #expect(candidates.contains(.text(document[tables[0]].childIDs[1])))
        // The stop is skipped at traversal time when the table fits; the candidate
        // list itself stays stable and pure.
        #expect(DocumentReaderFocusTarget.tableOverflow(tables[0]).leafID == tables[0])
    }

    @Test func overflowActionPolicyMirrorsTheCodeOverflowConventions() {
        let plan = { (key: MarkdownTableKey, modifiers: EventModifiers) in
            MarkdownTableLayout.action(for: key, modifiers: modifiers, offset: 100, viewportWidth: 500)
        }
        #expect(plan(.left, []) == .scroll(60))
        #expect(plan(.right, []) == .scroll(140))
        #expect(plan(.left, .option) == .scroll(100 - 400))
        #expect(plan(.right, .option) == .scroll(500))
        #expect(plan(.left, .command) == .leadingEdge)
        #expect(plan(.right, .command) == .trailingEdge)
        #expect(plan(.home, []) == .leadingEdge)
        #expect(plan(.end, []) == .trailingEdge)
        #expect(plan(.pageUp, []) == .page(isUp: true))
        #expect(plan(.pageDown, []) == .page(isUp: false))
        #expect(plan(.pageDown, .command) == .ignored)
        #expect(plan(.escape, []) == .returnToReader)
        #expect(plan(.tab, .option) == .traverse(reverse: false))
        #expect(plan(.tab, [.option, .shift]) == .traverse(reverse: true))
        #expect(plan(.tab, []) == .ignored, "Plain Tab is never trapped by the table")
        // Shift and Control stay available to native text selection.
        #expect(plan(.left, .shift) == .ignored)
        #expect(plan(.right, .control) == .ignored)
        // A non-finite live offset cannot produce a non-finite instruction.
        if case .scroll(let value) = MarkdownTableLayout.action(
            for: .right, modifiers: [], offset: .nan, viewportWidth: 500) {
            #expect(value == 40)
        } else {
            Issue.record("Right arrow must scroll")
        }
        #expect(MarkdownTableView.key(for: .leftArrow) == .left)
        #expect(MarkdownTableView.key(for: .upArrow) == nil)
    }

    @Test func tableSurfaceTokensAreExplicitAndAdaptInBothAppearances() {
        for dark in [false, true] {
            let header = ReaderTheme.tableHeaderBackgroundRGB(dark: dark)
            let alternate = ReaderTheme.tableAlternateRowRGB(dark: dark)
            let border = ReaderTheme.tableBorderRGB(dark: dark)
            // Rules stay distinct from both surfaces, so a cell boundary never
            // depends on the background difference alone.
            #expect(border != header && border != alternate)
            #expect(header != alternate)
            // Light surfaces stay light and dark surfaces stay dark: no page-wide
            // inversion of one appearance into the other.
            let luminance = { (rgb: UInt32) in
                Double((rgb >> 16) & 255) + Double((rgb >> 8) & 255) + Double(rgb & 255)
            }
            #expect(dark ? luminance(header) < 383 : luminance(header) > 383)
            #expect(dark ? luminance(alternate) < 383 : luminance(alternate) > 383)
        }
        #expect(ReaderTheme.tableHeaderBackgroundRGB(dark: false) != ReaderTheme.tableHeaderBackgroundRGB(dark: true))
        #expect(ReaderTheme.tableBorderRGB(dark: false) != ReaderTheme.tableBorderRGB(dark: true))
        // A rule never disappears, and grows with the reading scale.
        #expect(ReaderTheme.tableBorderWidth(scale: 1) == 1)
        #expect(ReaderTheme.tableBorderWidth(scale: 1.5) == 1)
        #expect(ReaderTheme.tableBorderWidth(scale: 2) == 2)
        #expect(ReaderTheme.tableBorderWidth(scale: .nan) == 1)
        #expect(ReaderTheme.tableBorderWidth(scale: 0) == 1)
    }

    @Test func metricsReportOverflowOnlyWhenTheDocumentExceedsTheViewport() {
        var metrics = MarkdownTableMetrics.zero
        #expect(!metrics.overflows)
        metrics.viewportWidth = 400
        metrics.contentWidth = 400
        #expect(!metrics.overflows)
        metrics.contentWidth = 401
        #expect(metrics.overflows)
    }
}
