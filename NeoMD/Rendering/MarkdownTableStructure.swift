//
//  MarkdownTableStructure.swift
//  NeoMD
//

import Foundation

/// Flat, owned GFM table metadata.
///
/// Rows and columns carry integers and value descriptors only: never recursively
/// owned blocks and never a parser pointer. Row offsets are half-open ranges into
/// the table node's `childIDs`, so destruction stays bounded-depth and the table
/// node itself owns no inline payload of its own.
nonisolated struct MarkdownTableStructure: Equatable, Sendable {
    /// The column alignment authored in the delimiter row.
    nonisolated enum Alignment: String, Equatable, Sendable, CaseIterable {
        case unspecified, left, center, right

        /// cmark-gfm stores one ASCII byte per column; anything else is unspecified.
        init(cmarkValue: UInt8) {
            switch cmarkValue {
            case UInt8(ascii: "l"): self = .left
            case UInt8(ascii: "c"): self = .center
            case UInt8(ascii: "r"): self = .right
            default: self = .unspecified
            }
        }
    }

    nonisolated struct Row: Equatable, Sendable {
        let isHeader: Bool
        /// Half-open offsets into the owning table's `childIDs`.
        let cells: Range<Int>
    }

    let alignments: [Alignment]
    let rows: [Row]

    var columnCount: Int { alignments.count }
    var rowCount: Int { rows.count }

    /// GFM specifies at most one header row, and never a row header column.
    var headerRowIndex: Int? { rows.firstIndex(where: \.isHeader) }

    func alignment(column: Int) -> Alignment {
        alignments.indices.contains(column) ? alignments[column] : .unspecified
    }

    /// The row that owns a `childIDs` offset, or nil when the offset is out of range.
    func rowIndex(containing offset: Int) -> Int? {
        rows.firstIndex { $0.cells.contains(offset) }
    }
}

/// A cell coordinate inside one immutable rendering.
///
/// This is presentation-lifetime identity, not a persisted address: it is only
/// meaningful for the `MarkdownRenderDocument` that produced it.
nonisolated struct MarkdownTableCellAddress: Equatable, Hashable, Sendable {
    let tableID: Int
    /// Zero-based; the header row is row 0 when the table has one.
    let rowIndex: Int
    let columnIndex: Int
    let leafID: Int
}

/// A cell address bound to a live native rendering generation.
///
/// Native registrations must reject a stale generation rather than reusing an
/// address whose document has already been replaced.
nonisolated struct MarkdownTableCellRegistration: Equatable, Hashable, Sendable {
    let address: MarkdownTableCellAddress
    let generation: Int

    func isValid(in generation: Int) -> Bool { self.generation == generation }
}

extension MarkdownRenderDocument {
    /// The table structure owned by `id`, when that node is a table.
    nonisolated func tableStructure(_ id: Int) -> MarkdownTableStructure? {
        guard nodes.indices.contains(id), case .table(let structure) = nodes[id].kind else { return nil }
        return structure
    }

    /// Bounds-checked row/column lookup. Nothing is fabricated for a missing coordinate.
    nonisolated func tableCell(tableID: Int, row: Int, column: Int) -> MarkdownTableCellAddress? {
        guard let structure = tableStructure(tableID),
              structure.rows.indices.contains(row),
              structure.alignments.indices.contains(column) else { return nil }
        let offset = structure.rows[row].cells.lowerBound + column
        guard structure.rows[row].cells.contains(offset),
              nodes[tableID].childIDs.indices.contains(offset) else { return nil }
        return MarkdownTableCellAddress(tableID: tableID, rowIndex: row, columnIndex: column,
                                        leafID: nodes[tableID].childIDs[offset])
    }

    /// The address of a cell leaf, or nil when the leaf is ordinary prose.
    nonisolated func tableCell(for leafID: Int) -> MarkdownTableCellAddress? {
        guard nodes.indices.contains(leafID), let parent = nodes[leafID].parentID,
              let structure = tableStructure(parent),
              let offset = nodes[parent].childIDs.firstIndex(of: leafID),
              let row = structure.rowIndex(containing: offset) else { return nil }
        return tableCell(tableID: parent, row: row,
                         column: offset - structure.rows[row].cells.lowerBound)
    }

    /// Every cell address of a table, in row-major reading order.
    nonisolated func tableCells(in tableID: Int) -> [MarkdownTableCellAddress] {
        guard let structure = tableStructure(tableID) else { return [] }
        return structure.rows.indices.flatMap { row in
            (0..<structure.columnCount).compactMap { tableCell(tableID: tableID, row: row, column: $0) }
        }
    }

    /// The header cell that labels this cell's column.
    ///
    /// The same column's header is returned for every body cell, including a cell
    /// in the header row itself. A table without a header row has none, and a row
    /// header is never invented.
    nonisolated func columnHeader(for address: MarkdownTableCellAddress) -> MarkdownTableCellAddress? {
        guard tableCell(tableID: address.tableID, row: address.rowIndex,
                        column: address.columnIndex) == address,
              let structure = tableStructure(address.tableID),
              let header = structure.headerRowIndex else { return nil }
        return tableCell(tableID: address.tableID, row: header, column: address.columnIndex)
    }

    /// The header cells of a table, in column order.
    nonisolated func columnHeaders(in tableID: Int) -> [MarkdownTableCellAddress] {
        guard let structure = tableStructure(tableID), let header = structure.headerRowIndex else { return [] }
        return (0..<structure.columnCount).compactMap { tableCell(tableID: tableID, row: header, column: $0) }
    }
}
