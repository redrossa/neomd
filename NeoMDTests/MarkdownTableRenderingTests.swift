import Foundation
import Testing
@testable import NeoMD

/// Structure, ownership and inline preservation for GFM tables.
///
/// Every expectation is parser/arena data. No view, window, event or accessibility
/// action is used here; native table presentation remains unverified.
struct MarkdownTableRenderingTests {
    private struct ExpectedTable: Decodable {
        let alignments: [String]
        let headerRows: [Int]
        let rows: [[String]]
    }

    private struct ExpectedAnchor: Decodable {
        let name: String
        let table: Int
        let row: Int
        let column: Int
    }

    private struct StructureCase: Decodable {
        let id: String
        let source: String
        let tables: [ExpectedTable]
        var codeCells: [[Int]]?
        var anchors: [ExpectedAnchor]?
        var absentVisibleText: [String]?
        var presentVisibleText: [String]?
        var taskCount: Int?
        var codeText: String?
    }

    private static func fixtureCases() throws -> [StructureCase] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("docs/fixtures/m1-19-tables/structure-cases.json"))
        return try JSONDecoder().decode([StructureCase].self, from: data)
    }

    private func tableIDs(_ document: MarkdownRenderDocument) -> [Int] {
        document.nodes.filter(\.isTable).map(\.id)
    }

    private func rowTexts(_ document: MarkdownRenderDocument, tableID: Int) -> [[String]] {
        guard let structure = document.tableStructure(tableID) else { return [] }
        return structure.rows.indices.map { row in
            (0..<structure.columnCount).map { column in
                document.tableCell(tableID: tableID, row: row, column: column)
                    .map { String(document[$0.leafID].text.characters) } ?? "<missing>"
            }
        }
    }

    @Test func structureFixtureCasesMatchOwnedRowsColumnsAndAlignments() throws {
        let cases = try Self.fixtureCases()
        #expect(cases.count == 11)
        var asserted = 0
        for structureCase in cases {
            let document = MarkdownBlockRenderer.render(from: structureCase.source)
            let tables = tableIDs(document)
            #expect(tables.count == structureCase.tables.count, "\(structureCase.id) table count")
            for (index, expected) in structureCase.tables.enumerated() {
                let tableID = try #require(tables.indices.contains(index) ? tables[index] : nil, "\(structureCase.id)")
                let structure = try #require(document.tableStructure(tableID), "\(structureCase.id)")
                #expect(structure.alignments.map(\.rawValue) == expected.alignments, "\(structureCase.id) alignments")
                #expect(structure.rows.indices.filter { structure.rows[$0].isHeader } == expected.headerRows,
                        "\(structureCase.id) header rows")
                #expect(rowTexts(document, tableID: tableID) == expected.rows, "\(structureCase.id) cells")
                // Parser normalization, not source pipe counts, defines the width.
                #expect(structure.rows.allSatisfy { $0.cells.count == structure.columnCount },
                        "\(structureCase.id) normalized row width")
                asserted += 1
            }
            for coordinate in structureCase.codeCells ?? [] {
                let address = try #require(document.tableCell(tableID: tables[coordinate[0]],
                                                              row: coordinate[1], column: coordinate[2]))
                #expect(document[address.leafID].text.runs.contains {
                    $0.inlinePresentationIntent?.contains(.code) == true
                }, "\(structureCase.id) code span retained")
                asserted += 1
            }
            for anchor in structureCase.anchors ?? [] {
                let address = try #require(document.tableCell(tableID: tables[anchor.table],
                                                              row: anchor.row, column: anchor.column))
                #expect(document.anchorTargets[anchor.name] == address.leafID,
                        "\(structureCase.id) anchor targets its own cell")
                asserted += 1
            }
            let visible = document.leaves.map { String($0.text.characters) }
            for hidden in structureCase.absentVisibleText ?? [] {
                #expect(!visible.contains { $0.contains(hidden) }, "\(structureCase.id) hidden text")
                asserted += 1
            }
            for present in structureCase.presentVisibleText ?? [] {
                #expect(visible.contains { $0.contains(present) }, "\(structureCase.id) readable recovery")
                asserted += 1
            }
            if let taskCount = structureCase.taskCount {
                #expect(document.nodes.filter { $0.task != nil }.count == taskCount,
                        "\(structureCase.id) literal task markers")
                asserted += 1
            }
            if let codeText = structureCase.codeText {
                #expect(document.leaves.contains {
                    if case .codeBlock = $0.kind { return String($0.text.characters) == codeText }
                    return false
                }, "\(structureCase.id) fenced example stays literal")
                asserted += 1
            }
        }
        // Every fixture case contributed at least one executed expectation.
        #expect(asserted == 18)
    }

    @Test func cellsAreOrdinaryLeavesWithContiguousPreorderTableOwnership() throws {
        let document = MarkdownBlockRenderer.render(from: """
        before

        | A | B |
        | --- | --- |
        | c | d |

        after
        """)
        let tableID = try #require(tableIDs(document).first)
        let table = document[tableID]
        #expect(!table.isLeaf)
        // A table is not a prose leaf and carries no duplicate visible text.
        #expect(String(table.text.characters).isEmpty)
        #expect(table.childIDs == Array(tableID + 1...tableID + 4))
        #expect(document.subtreeIDs(in: tableID) == tableID..<(tableID + 5))
        for id in table.childIDs {
            #expect(document[id].parentID == tableID)
            #expect(document[id].isLeaf)
            #expect(document[id].childIDs.isEmpty)
            #expect(document.lazyRootIDs[id] == document.lazyRootIDs[tableID])
        }
        // Cells appear exactly once, in row-major reading order.
        let cells = document.tableCells(in: tableID)
        #expect(cells.map(\.leafID) == table.childIDs)
        #expect(document.leafIDs.filter(table.childIDs.contains) == table.childIDs)
        #expect(cells.map { String(document[$0.leafID].text.characters) } == ["A", "B", "c", "d"])
        #expect(document.leaves(in: tableID).count == 4)
    }

    @Test func inlineFormattingCuesLinksAndImagesSurviveInsideCells() throws {
        let document = MarkdownBlockRenderer.render(from: """
        | **bold** `code` | [link](https://example.com) ![alt](a.png) | H~2~O <sub>2</sub><sup>3</sup> |
        | --- | :---: | ---: |
        | ~~gone~~ *slant* | :smile: `#12AB34` | <ins>under</ins> |
        """)
        let tableID = try #require(tableIDs(document).first)
        let text: (Int, Int) -> AttributedString = { row, column in
            document.tableCell(tableID: tableID, row: row, column: column)
                .map { document[$0.leafID].text } ?? AttributedString()
        }
        #expect(text(0, 0).runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
        #expect(text(0, 0).runs.contains { $0.inlinePresentationIntent?.contains(.code) == true })
        #expect(text(0, 1).runs.contains { $0.link?.absoluteString == "https://example.com" })
        #expect(text(0, 1).runs.contains { $0.markdownImage != nil })
        #expect(text(0, 2).runs.contains { $0.markdownInlineStyle == .subscriptText })
        #expect(text(0, 2).runs.contains { $0.markdownInlineStyle == .superscriptText })
        #expect(text(1, 0).runs.contains { $0.inlinePresentationIntent?.contains(.strikethrough) == true })
        #expect(text(1, 0).runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true })
        #expect(text(1, 1).runs.contains { $0.markdownColorReference != nil })
        #expect(String(text(1, 1).characters).contains("\u{1F604}"))
        #expect(text(1, 2).runs.contains { $0.markdownInlineStyle == .underline })
        // Image occurrence identity stays distinct from surrounding prose.
        let occurrences = text(0, 1).runs.compactMap { $0.markdownImage?.occurrence }
        #expect(Set(occurrences).count == 1)
    }

    @Test func contextsFixtureKeepsMetadataTasksQuotesAlertsAndFootnotesSeparate() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let fixture = root.appendingPathComponent("docs/fixtures/m1-19-tables/contexts.md")
        let source = try String(contentsOf: fixture, encoding: .utf8)
        let document = MarkdownBlockRenderer.render(from: source, documentURL: fixture)
        let tables = tableIDs(document)
        // Task, quote, alert, general and footnote-body tables. The document's
        // YAML metadata is a separate surface and never a table.
        #expect(tables.count == 5)
        #expect(document.nodes.contains { if case .metadata = $0.kind { return true }; return false })
        #expect(document.nodes.allSatisfy { node in
            if case .metadata = node.kind { return node.parentID == nil }
            return true
        })
        for tableID in tables {
            let structure = try #require(document.tableStructure(tableID))
            #expect(structure.headerRowIndex == 0)
            #expect(structure.rows.allSatisfy { $0.cells.count == structure.columnCount })
            #expect(document[tableID].childIDs.allSatisfy { document[$0].parentID == tableID })
        }
        // A real enclosing task keeps its state; a literal marker in a cell does not.
        let taskContext = try #require(tables.first)
        let literal = try #require(document.tableCell(tableID: taskContext, row: 2, column: 0))
        #expect(String(document[literal.leafID].text.characters) == "[ ] not a checkbox")
        #expect(document[literal.leafID].task == nil)
        #expect(document.nodes.filter { $0.task == .complete }.count == 1)
        // The empty anchor cell is its own destination, not its neighbour.
        let general = tables[3]
        let anchorCell = try #require(document.tableCell(tableID: general, row: 2, column: 0))
        #expect(document.anchorTargets["empty-cell"] == anchorCell.leafID)
        #expect(String(document[anchorCell.leafID].text.characters).isEmpty)
        // Repeated references return to their own cells, never to the table start.
        let first = try #require(document.tableCell(tableID: general, row: 3, column: 0))
        let second = try #require(document.tableCell(tableID: general, row: 3, column: 1))
        let returns = document.leaves.filter {
            $0.text.runs.contains { $0.markdownGeneratedReference == .footnoteReturn }
        }
        let destinations = returns.flatMap { leaf in
            leaf.text.runs.compactMap { $0.link?.fragment }
        }
        #expect(destinations.count == 2)
        #expect(Set(destinations).count == 2)
        for destination in destinations {
            let target = try #require(document.anchorTargets[destination])
            #expect(target == first.leafID || target == second.leafID)
        }
        // The authored heading collision never steals the generated note anchor.
        #expect(document.anchorTargets["fn-same"] != nil)
        #expect(document.nodes.contains { if case .footnote = $0.kind { return true }; return false })
        // Adjacent same-URL images stay distinct; a missing image keeps its text.
        let images = try #require(document.tableCell(tableID: general, row: 4, column: 0))
        let occurrences = document[images.leafID].text.runs.compactMap { $0.markdownImage?.occurrence }
        #expect(Set(occurrences).count == 2)
        let missing = try #require(document.tableCell(tableID: general, row: 4, column: 2))
        #expect(String(document[missing.leafID].text.characters) == "missing illustration")
    }

    @Test func deeplyNestedTableKeepsBoundedFlatOwnership() throws {
        let source = String(repeating: "> ", count: 500)
            + "\n" + String(repeating: "> ", count: 500) + "| A | B |\n"
            + String(repeating: "> ", count: 500) + "| --- | --- |\n"
            + String(repeating: "> ", count: 500) + "| c | d |\n"
        let document = MarkdownBlockRenderer.render(from: source)
        let tableID = try #require(tableIDs(document).first)
        #expect(document[tableID].childIDs.count == 4)
        #expect(document.tableCells(in: tableID).count == 4)
        // Every cell is reachable as a leaf of the outermost quote root.
        let root = try #require(document.rootIDs.first)
        #expect(document.leaves(in: root).count >= 4)
        #expect(document.subtreeEnds[tableID] == tableID + 5)
    }

    @Test func headerOnlyAndAllEmptyTablesAreRetained() throws {
        let document = MarkdownBlockRenderer.render(from: "| | |\n| --- | --- |\n")
        let tableID = try #require(tableIDs(document).first)
        let structure = try #require(document.tableStructure(tableID))
        #expect(structure.rowCount == 1 && structure.columnCount == 2)
        #expect(document[tableID].childIDs.count == 2)
        #expect(document[tableID].childIDs.allSatisfy { document[$0].text.characters.isEmpty })
        // An empty column never collapses, and the cells keep distinct identities.
        #expect(Set(document[tableID].childIDs).count == 2)
    }

    @Test func tableFollowingMetadataRemainsSeparate() throws {
        let document = MarkdownBlockRenderer.render(from: """
        ---
        title: Example
        ---
        | A |
        | --- |
        | b |
        """)
        let metadata = try #require(document.nodes.first { if case .metadata = $0.kind { return true }; return false })
        let tableID = try #require(tableIDs(document).first)
        #expect(metadata.id != tableID)
        #expect(document[tableID].parentID == nil)
        #expect(document.tableStructure(metadata.id) == nil)
    }
}
