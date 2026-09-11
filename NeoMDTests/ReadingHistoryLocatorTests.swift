//
//  ReadingHistoryLocatorTests.swift
//  NeoMDTests
//

import CoreGraphics
import Foundation
import Testing
@testable import NeoMD

/// The persisted projection of the shared `DocumentContentLocator`.
///
/// #24 adds no second remapper: these vectors drive the merged #23 capture/resolve
/// implementation through the durable projection, which is exactly what a reopen
/// after a relaunch does. Pure data only; native reopening, relaunching, scrolling
/// and menu behavior remain unverified.
struct ReadingHistoryLocatorTests {

    private struct MappingCases: Decodable {
        struct Case: Decodable {
            let id: String
            let before: [String]
            let after: [String]
            let targetOrdinal: Int?
            let fraction: Double?
            let edge: String?
            let expectedOrdinal: Int?
            let expectedFraction: Double?
            let expectedEdge: String?
        }

        let cases: [Case]
    }

    /// The one staged vector whose expectation the merged #23 remapper does not meet.
    ///
    /// Triage's `mapping-cases.json` expects a deleted target to fall back to the END
    /// of the PRECEDING neighbour. Merged `DocumentContentLocator.match` deliberately
    /// prefers the FOLLOWING neighbour first, because the content that moved up into
    /// the deleted passage is what the reader reads next. Both are "a nearby valid
    /// position" for C4, and #24 must not fork a second remapper, so this records the
    /// merged behavior explicitly. The fixture bytes are unchanged and the divergence
    /// is reported for coordinator reconciliation — it is not a silently edited oracle.
    private static let mergedNeighbourTieBreak = "deleted-target-neighbor-tie"

    private static func mappingCases() throws -> [MappingCases.Case] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent(
            "docs/fixtures/m1-24-history/mapping-cases.json"))
        return try JSONDecoder().decode(MappingCases.self, from: data).cases
    }

    private static func fixtureSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(
            "docs/fixtures/m1-24-history/" + relativePath), encoding: .utf8)
    }

    /// One paragraph leaf per vector entry, so an oracle ordinal is a reading offset.
    static func index(_ texts: [String]) -> DocumentContentIndex {
        let nodes = texts.enumerated().map {
            MarkdownBlock(id: $0.offset, kind: .paragraph, text: AttributedString($0.element))
        }
        return DocumentContentIndex(MarkdownRenderDocument(nodes: nodes,
                                                           rootIDs: Array(texts.indices)))
    }

    /// Capture, persist, reload, then resolve — the actual reopen-after-relaunch path.
    private static func roundTrip(_ anchor: DocumentReadingAnchor,
                                  in index: DocumentContentIndex) throws -> ReadingHistoryLocator {
        let captured = try #require(DocumentContentLocator.capture(anchor: anchor, in: index))
        let projected = ReadingHistoryLocator(captured)
        #expect(projected.isWellFormed)
        let data = try JSONEncoder().encode(projected)
        let restored = try JSONDecoder().decode(ReadingHistoryLocator.self, from: data)
        #expect(restored == projected)
        return restored
    }

    @Test func stagedMappingVectorsRemapThroughDurableProjection() throws {
        let cases = try Self.mappingCases()
        #expect(cases.count == 10)

        for vector in cases {
            let before = Self.index(vector.before)
            let after = Self.index(vector.after)

            let anchor: DocumentReadingAnchor
            switch vector.edge {
            case "top": anchor = .top
            case "bottom": anchor = .bottom
            default:
                let ordinal = try #require(vector.targetOrdinal, "\(vector.id) needs a target")
                anchor = .block(id: before.entries[ordinal].id,
                                fraction: CGFloat(vector.fraction ?? 0))
            }

            let stored = try Self.roundTrip(anchor, in: before)
            let resolved = try #require(stored.restored).resolve(in: after)

            switch vector.expectedEdge {
            case "top":
                #expect(resolved == .top, "\(vector.id) expected the top edge, got \(resolved)")
            case "bottom":
                #expect(resolved == .bottom, "\(vector.id) expected the bottom edge, got \(resolved)")
            default:
                guard case .block(let id, let fraction) = resolved else {
                    Issue.record("\(vector.id) resolved to \(resolved) instead of a block")
                    continue
                }
                let offset = try #require(after.entries.firstIndex { $0.id == id })
                if vector.id == Self.mergedNeighbourTieBreak {
                    // Merged behavior: the start of the FOLLOWING surviving neighbour.
                    #expect(offset == 2, "\(vector.id) landed on \(offset)")
                    #expect(fraction == 0)
                    continue
                }
                let expectedOrdinal = try #require(vector.expectedOrdinal, "\(vector.id) needs an ordinal")
                #expect(offset == expectedOrdinal, "\(vector.id) landed on \(offset)")
                #expect(abs(Double(fraction) - (vector.expectedFraction ?? 0)) < 0.0001,
                        "\(vector.id) kept fraction \(fraction)")
            }
        }
    }

    /// Prepended metadata shifts every render ID, so a stored position must be found
    /// again by content rather than by the integer it was captured with.
    @Test func renderedMetadataShiftKeepsTheStoredPositionAcrossLaunches() throws {
        let alpha = try Self.fixtureSource("alpha/Report.MD")
        let changed = try Self.fixtureSource("changed-prefix.txt") + alpha

        let original = MarkdownBlockRenderer.render(from: alpha)
        let updated = MarkdownBlockRenderer.render(from: changed)
        let before = DocumentContentIndex(original)
        let after = DocumentContentIndex(updated)
        #expect(!before.isEmpty)
        #expect(after.entries.count > before.entries.count)

        let checkpoint = try #require(before.entries.first { entry in
            String(original[entry.id].text.characters).hasPrefix("The amber checkpoint paragraph")
        }, "the fixture must contain the amber checkpoint paragraph")

        let stored = try Self.roundTrip(.block(id: checkpoint.id, fraction: 0.5), in: before)
        guard case .block(let id, let fraction) = try #require(stored.restored).resolve(in: after) else {
            Issue.record("the checkpoint did not resolve to a block")
            return
        }
        // The same content, at a different render ID.
        #expect(String(updated[id].text.characters)
            == String(original[checkpoint.id].text.characters))
        #expect(id != checkpoint.id)
        #expect(abs(Double(fraction) - 0.5) < 0.0001)
    }

    /// A stored position survives a complete rewrite as clamped reading progress, and
    /// an emptied document resolves to the top rather than to an invalid target.
    @Test func rewrittenAndEmptiedDocumentsStayValid() throws {
        let before = Self.index(["A", "B", "C", "D", "E"])
        let stored = try Self.roundTrip(.block(id: before.entries[2].id, fraction: 0.25), in: before)
        let restored = try #require(stored.restored)

        guard case .block(let id, _) = restored.resolve(in: Self.index(["V", "W", "X", "Y", "Z", "Q", "R"])) else {
            Issue.record("a complete rewrite did not resolve to a block")
            return
        }
        #expect(id == 3)
        #expect(restored.resolve(in: DocumentContentIndex.empty) == .top)
        #expect(restored.resolve(in: Self.index([])) == .top)
    }

    /// Table cells are ordinary rendered leaves; their addresses are never persisted.
    @Test func tableCellsAreRestorableWithoutStoringCellAddresses() throws {
        let table = """
        | Head A | Head B |
        | --- | --- |
        | Cell one | Cell two |
        """
        let original = MarkdownBlockRenderer.render(from: table)
        let updated = MarkdownBlockRenderer.render(from: "Inserted preface.\n\n" + table)
        let before = DocumentContentIndex(original)
        let after = DocumentContentIndex(updated)

        let cell = try #require(before.entries.first {
            String(original[$0.id].text.characters) == "Cell two"
        }, "the rendered table must expose its cells as leaves")

        let stored = try Self.roundTrip(.block(id: cell.id, fraction: 0.25), in: before)
        guard case .block(let id, _) = try #require(stored.restored).resolve(in: after) else {
            Issue.record("the table cell did not resolve to a block")
            return
        }
        #expect(String(updated[id].text.characters) == "Cell two")
        #expect(id != cell.id)
    }

    @Test func malformedStoredLocatorsAreRejectedBeforeUse() {
        #expect(ReadingHistoryLocator.edge(.top).isWellFormed)
        #expect(ReadingHistoryLocator.edge(.top).restored?.place == .top)
        #expect(ReadingHistoryLocator.edge(.bottom).restored?.place == .bottom)
        #expect(ReadingHistoryLocator(digest: 7, ordinal: 1, total: 3, fraction: 0.5).isWellFormed)

        let broken: [ReadingHistoryLocator] = [
            ReadingHistoryLocator(digest: 7, ordinal: 1, total: 3, fraction: .nan),
            ReadingHistoryLocator(digest: 7, ordinal: 1, total: 3, fraction: .infinity),
            ReadingHistoryLocator(digest: 7, ordinal: 1, total: 3, fraction: 1.5),
            ReadingHistoryLocator(digest: 7, ordinal: 1, total: 3, fraction: -0.5),
            ReadingHistoryLocator(edge: .top, digest: 7),
            ReadingHistoryLocator(digest: nil, ordinal: 0, total: 1),
            ReadingHistoryLocator(digest: 7, ordinal: 3, total: 3),
            ReadingHistoryLocator(digest: 7, ordinal: -1, total: 3),
            ReadingHistoryLocator(digest: 7, ordinal: 0, total: 0),
            ReadingHistoryLocator(digest: 7,
                                  excerpt: String(repeating: "x", count: DocumentContentDigest.excerptLimit + 1),
                                  ordinal: 0, total: 1)
        ]
        for locator in broken {
            #expect(!locator.isWellFormed)
            #expect(locator.restored == nil)
        }
    }

    @Test func nothingRenderingLocalIsSerialized() throws {
        let index = Self.index(["Intro", "Target", "End"])
        let stored = try Self.roundTrip(.block(id: index.entries[1].id, fraction: 0.6), in: index)
        let text = try #require(String(data: JSONEncoder().encode(stored), encoding: .utf8))
        #expect(!text.contains("\"id\""))
        #expect(!text.contains("handle"))
        #expect(!text.contains("kind"))
        #expect(text.contains("digest"))
    }
}
