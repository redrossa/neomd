import Foundation
import Testing
@testable import NeoMD

/// Cell address, reading order and header association descriptors.
///
/// These are pure value mappings. They describe what the native surface must
/// expose; they are not evidence that an accessibility tree, VoiceOver or focus
/// actually behaves that way.
struct MarkdownTableAddressTests {
    private func document() -> MarkdownRenderDocument {
        MarkdownBlockRenderer.render(from: """
        | Same | Same | |
        | --- | :---: | ---: |
        | left | middle | right |
        | left | middle | right |
        """)
    }

    @Test func addressesAreStableRowMajorAndDistinctForRepeatedText() throws {
        let document = document()
        let tableID = try #require(document.nodes.first(where: \.isTable)?.id)
        let cells = document.tableCells(in: tableID)
        #expect(cells.count == 9)
        #expect(cells.map(\.rowIndex) == [0, 0, 0, 1, 1, 1, 2, 2, 2])
        #expect(cells.map(\.columnIndex) == [0, 1, 2, 0, 1, 2, 0, 1, 2])
        // Row-major reading order matches the arena's own leaf order.
        #expect(cells.map(\.leafID) == document[tableID].childIDs)
        #expect(cells.map(\.leafID) == cells.map(\.leafID).sorted())
        // Repeated strings and empty headers never merge into one address.
        #expect(Set(cells).count == 9)
        #expect(Set(cells.map(\.leafID)).count == 9)
        let texts = cells.map { String(document[$0.leafID].text.characters) }
        #expect(texts.filter { $0 == "Same" }.count == 2)
        #expect(texts.filter(\.isEmpty).count == 1)
        // The same coordinate resolves to the same address in both directions.
        for cell in cells {
            #expect(document.tableCell(for: cell.leafID) == cell)
            #expect(document.tableCell(tableID: tableID, row: cell.rowIndex, column: cell.columnIndex) == cell)
        }
    }

    @Test func lookupIsBoundsSafeAndNeverInventsACell() throws {
        let document = document()
        let tableID = try #require(document.nodes.first(where: \.isTable)?.id)
        #expect(document.tableCell(tableID: tableID, row: -1, column: 0) == nil)
        #expect(document.tableCell(tableID: tableID, row: 3, column: 0) == nil)
        #expect(document.tableCell(tableID: tableID, row: 0, column: -1) == nil)
        #expect(document.tableCell(tableID: tableID, row: 0, column: 3) == nil)
        #expect(document.tableCell(tableID: -1, row: 0, column: 0) == nil)
        #expect(document.tableCell(tableID: document.nodes.count, row: 0, column: 0) == nil)
        // A prose leaf is not a cell, and a table is not its own cell.
        #expect(document.tableCell(for: tableID) == nil)
        #expect(document.tableStructure(tableID + 1) == nil)
        let prose = MarkdownBlockRenderer.render(from: "just a paragraph")
        #expect(prose.tableCell(for: 0) == nil)
        #expect(prose.tableStructure(0) == nil)
        #expect(prose.tableCells(in: 0).isEmpty)
        #expect(prose.columnHeaders(in: 0).isEmpty)
    }

    @Test func everyBodyCellAssociatesItsOwnColumnHeader() throws {
        let document = document()
        let tableID = try #require(document.nodes.first(where: \.isTable)?.id)
        let headers = document.columnHeaders(in: tableID)
        #expect(headers.count == 3)
        #expect(headers.map(\.rowIndex) == [0, 0, 0])
        #expect(headers.map(\.columnIndex) == [0, 1, 2])
        // Duplicate and blank header labels stay separate elements.
        #expect(Set(headers.map(\.leafID)).count == 3)
        for cell in document.tableCells(in: tableID) {
            let header = try #require(document.columnHeader(for: cell))
            #expect(header == headers[cell.columnIndex])
            #expect(header.rowIndex == 0)
        }
        // A header cell's own column header is itself, and no row header exists.
        #expect(document.columnHeader(for: headers[1]) == headers[1])
        let structure = try #require(document.tableStructure(tableID))
        #expect(structure.rows.filter(\.isHeader).count == 1)
        #expect(structure.headerRowIndex == 0)
        #expect(structure.rows.indices.filter { structure.rows[$0].isHeader } == [0])
    }

    @Test func aTableWithoutAHeaderRowHasNoHeaderAssociation() {
        // GFM always produces a header row; a descriptor without one must still be
        // safe, and must not invent a row or column header.
        let structure = MarkdownTableStructure(
            alignments: [.left, .right],
            rows: [.init(isHeader: false, cells: 0..<2), .init(isHeader: false, cells: 2..<4)])
        #expect(structure.headerRowIndex == nil)
        let nodes = [
            MarkdownBlock(id: 0, kind: .table(structure), text: "", childIDs: [1, 2, 3, 4]),
            MarkdownBlock(id: 1, kind: .paragraph, text: "a", parentID: 0),
            MarkdownBlock(id: 2, kind: .paragraph, text: "b", parentID: 0),
            MarkdownBlock(id: 3, kind: .paragraph, text: "c", parentID: 0),
            MarkdownBlock(id: 4, kind: .paragraph, text: "d", parentID: 0)
        ]
        let document = MarkdownRenderDocument(nodes: nodes, rootIDs: [0])
        let cell = MarkdownTableCellAddress(tableID: 0, rowIndex: 1, columnIndex: 1, leafID: 4)
        #expect(document.tableCell(tableID: 0, row: 1, column: 1) == cell)
        #expect(document.columnHeader(for: cell) == nil)
        #expect(document.columnHeaders(in: 0).isEmpty)
        #expect(structure.rowIndex(containing: 3) == 1)
        #expect(structure.rowIndex(containing: 9) == nil)
    }

    @Test func registrationsRejectAStaleRenderingGeneration() throws {
        let document = document()
        let tableID = try #require(document.nodes.first(where: \.isTable)?.id)
        let address = try #require(document.tableCell(tableID: tableID, row: 1, column: 2))
        let registration = MarkdownTableCellRegistration(address: address, generation: 7)
        #expect(registration.isValid(in: 7))
        #expect(!registration.isValid(in: 6))
        #expect(!registration.isValid(in: 8))
        // The address is presentation-lifetime identity, not persisted identity:
        // an identical coordinate in a new generation is a different registration.
        #expect(MarkdownTableCellRegistration(address: address, generation: 8) != registration)
        #expect(MarkdownTableCellRegistration(address: address, generation: 7) == registration)
    }

    @Test func alignmentValuesFollowTheParsersOwnBytes() {
        #expect(MarkdownTableStructure.Alignment(cmarkValue: UInt8(ascii: "l")) == .left)
        #expect(MarkdownTableStructure.Alignment(cmarkValue: UInt8(ascii: "c")) == .center)
        #expect(MarkdownTableStructure.Alignment(cmarkValue: UInt8(ascii: "r")) == .right)
        #expect(MarkdownTableStructure.Alignment(cmarkValue: 0) == .unspecified)
        #expect(MarkdownTableStructure.Alignment(cmarkValue: UInt8(ascii: "x")) == .unspecified)
        #expect(MarkdownTableStructure.Alignment.allCases.map(\.rawValue)
            == ["unspecified", "left", "center", "right"])
    }
}
