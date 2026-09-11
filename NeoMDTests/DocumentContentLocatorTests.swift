//
//  DocumentContentLocatorTests.swift
//  NeoMDTests
//

import Foundation
import Testing
@testable import NeoMD

/// Pure remapping regressions for #23 criterion C3, driven by the staged fixture
/// packet in `docs/fixtures/m1-23-refresh`. No window, host, event or file writing.
struct DocumentContentLocatorTests {

    // MARK: Fixtures

    private static func fixture(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "docs/fixtures/m1-23-refresh")
        return try String(contentsOf: root.appending(path: name), encoding: .utf8)
    }

    private static func rendered(_ name: String) throws -> MarkdownRenderDocument {
        MarkdownBlockRenderer.render(from: try fixture(name),
                                     documentURL: URL(fileURLWithPath: "/tmp/m1-23/\(name)"))
    }

    private static func plain(_ block: MarkdownBlock) -> String {
        String(block.text.characters)
    }

    private static func leafIDs(prefix: String, in document: MarkdownRenderDocument) -> [Int] {
        document.leaves.filter { plain($0).hasPrefix(prefix) }.map(\.id)
    }

    private static func leafID(prefix: String, in document: MarkdownRenderDocument) throws -> Int {
        let matches = leafIDs(prefix: prefix, in: document)
        return try #require(matches.first)
    }

    private static func resolvedID(_ anchor: DocumentReadingAnchor) -> Int? {
        if case .block(let id, _) = anchor { return id }
        return nil
    }

    private static func resolvedFraction(_ anchor: DocumentReadingAnchor) -> CGFloat? {
        if case .block(_, let fraction) = anchor { return fraction }
        return nil
    }

    private static func locator(prefix: String, fraction: CGFloat,
                                in document: MarkdownRenderDocument) throws -> DocumentContentLocator {
        let index = DocumentContentIndex(document)
        let id = try leafID(prefix: prefix, in: document)
        return try #require(DocumentContentLocator.capture(anchor: .block(id: id, fraction: fraction),
                                                           in: index))
    }

    // MARK: Documented fixture cases

    /// P1: metadata and inserted prose shift every later render ID; the watched
    /// paragraph and its within-block fraction must survive anyway.
    @Test func insertedMetadataAndProseKeepTheWatchedPassageAndFraction() throws {
        let watched = "WATCHED PASSAGE CAFÉ 日本語:"
        let old = try Self.rendered("v1.md")
        let new = try Self.rendered("v2-metadata-insert.md")
        let oldID = try Self.leafID(prefix: watched, in: old)
        let newID = try Self.leafID(prefix: watched, in: new)
        #expect(oldID != newID, "the fixture must actually shift render IDs")

        let anchor = try Self.locator(prefix: watched, fraction: 0.65, in: old)
            .resolve(in: DocumentContentIndex(new))
        #expect(Self.resolvedID(anchor) == newID)
        #expect(Self.resolvedFraction(anchor) == 0.65)
    }

    /// P2: identical words alone cannot choose between two repeated paragraphs.
    @Test func repeatedPassageResolvesToItsOwnNeighbourContext() throws {
        let repeated = "Repeated passage. Identical words alone"
        let old = try Self.rendered("v1.md")
        let new = try Self.rendered("v2-metadata-insert.md")
        let oldMatches = Self.leafIDs(prefix: repeated, in: old)
        let newMatches = Self.leafIDs(prefix: repeated, in: new)
        #expect(oldMatches.count == 2)
        #expect(newMatches.count == 2)

        let index = DocumentContentIndex(old)
        // Macros do not nest: every identifier is bound before it reaches #require.
        let oldSecondID = try #require(oldMatches.last)
        let second = try #require(DocumentContentLocator.capture(
            anchor: .block(id: oldSecondID, fraction: 0.4), in: index))
        let anchor = second.resolve(in: DocumentContentIndex(new))
        #expect(Self.resolvedID(anchor) == newMatches.last)
        #expect(Self.resolvedID(anchor) != newMatches.first)
        #expect(Self.resolvedFraction(anchor) == 0.4)

        let oldFirstID = try #require(oldMatches.first)
        let first = try #require(DocumentContentLocator.capture(
            anchor: .block(id: oldFirstID, fraction: 0.4), in: index))
        #expect(Self.resolvedID(first.resolve(in: DocumentContentIndex(new))) == newMatches.first)
    }

    /// P3: the watched paragraph is deleted; a surviving immediate neighbour is used.
    @Test func deletedTargetFallsBackToASurvivingNeighbour() throws {
        let old = try Self.rendered("v2-metadata-insert.md")
        let new = try Self.rendered("v3-target-deleted.md")
        #expect(Self.leafIDs(prefix: "WATCHED PASSAGE CAFÉ 日本語:", in: new).isEmpty)

        let anchor = try Self.locator(prefix: "WATCHED PASSAGE CAFÉ 日本語:", fraction: 0.65, in: old)
            .resolve(in: DocumentContentIndex(new))
        let id = try #require(Self.resolvedID(anchor))
        let text = Self.plain(new[id])
        #expect(text.hasPrefix("BEFORE WATCH:") || text.hasPrefix("AFTER WATCH:"))
        // Documented tie break: the content that moved up into the deleted passage.
        #expect(text.hasPrefix("AFTER WATCH:"))
        #expect(Self.resolvedFraction(anchor) == 0)
    }

    /// P4: a nested quotation leaf keeps its identity and stays materializable.
    @Test func nestedLeafSurvivesInsertionAndKeepsALazyRoot() throws {
        let old = try Self.rendered("v1.md")
        let new = try Self.rendered("v2-metadata-insert.md")
        let newID = try Self.leafID(prefix: "Nested quotation LEAF", in: new)
        let anchor = try Self.locator(prefix: "Nested quotation LEAF", fraction: 0.5, in: old)
            .resolve(in: DocumentContentIndex(new))
        #expect(Self.resolvedID(anchor) == newID)
        #expect(Self.resolvedFraction(anchor) == 0.5)
        // A nested leaf is not its own lazy root, so restoration has an outer target.
        #expect(new.lazyRootIDs[newID] != newID)
    }

    /// P5: an emptied document is valid content, and every capture stays legal.
    @Test func emptyRenderingResolvesToTheTopEdge() throws {
        let old = try Self.rendered("v3-target-deleted.md")
        let empty = DocumentContentIndex(try Self.rendered("empty.md"))
        #expect(empty.isEmpty)

        #expect(try Self.locator(prefix: "AFTER WATCH:", fraction: 0.5, in: old)
            .resolve(in: empty) == .top)
        #expect(DocumentContentLocator(place: .bottom).resolve(in: empty) == .top)
        #expect(DocumentContentLocator(place: .top).resolve(in: empty) == .top)
    }

    /// A much shorter recovered snapshot still produces a valid nearby target.
    @Test func shorterRecoveredSnapshotClampsToAValidLeaf() throws {
        let old = try Self.rendered("v3-target-deleted.md")
        let new = try Self.rendered("v4-recovered.md")
        let index = DocumentContentIndex(new)
        let anchor = try Self.locator(prefix: "Closing passage FOXTROT", fraction: 0.5, in: old)
            .resolve(in: index)
        let id = try #require(Self.resolvedID(anchor))
        #expect(new.nodes.indices.contains(id))
        #expect(index.offset(forTarget: id) != nil)
    }

    // MARK: Edges and identity policy

    @Test func edgesRoundTripAndUnknownTargetsProduceNoLocator() throws {
        let document = try Self.rendered("v1.md")
        let index = DocumentContentIndex(document)
        #expect(DocumentContentLocator.capture(anchor: .top, in: index)?.resolve(in: index) == .top)
        #expect(DocumentContentLocator.capture(anchor: .bottom, in: index)?.resolve(in: index) == .bottom)
        #expect(DocumentContentLocator.capture(anchor: .block(id: 9_999, fraction: 0.5), in: index) == nil)
    }

    @Test func invalidFractionsAreClampedToAValidRange() throws {
        let document = try Self.rendered("v1.md")
        let index = DocumentContentIndex(document)
        let id = try Self.leafID(prefix: "Opening passage ALPHA", in: document)
        for (input, expected) in [(CGFloat(2), CGFloat(1)), (-3, 0), (.nan, 0), (.infinity, 0)] {
            let locator = try #require(DocumentContentLocator.capture(
                anchor: .block(id: id, fraction: input), in: index))
            #expect(Self.resolvedFraction(locator.resolve(in: index)) == expected)
        }
    }

    @Test func movedContentFollowsItsTextAndCodeKeepsItsWhitespace() throws {
        let url = URL(fileURLWithPath: "/tmp/m1-23/moved.md")
        let old = MarkdownBlockRenderer.render(from: "Alpha\n\nBravo\n\nCharlie", documentURL: url)
        let new = MarkdownBlockRenderer.render(from: "Delta\n\nEcho\n\nFoxtrot\n\nBravo", documentURL: url)
        let index = DocumentContentIndex(old)
        let bravo = try #require(DocumentContentIndex(new).entries.last)
        let locator = try #require(DocumentContentLocator.capture(
            anchor: .block(id: try Self.leafID(prefix: "Bravo", in: old), fraction: 0.25), in: index))
        let anchor = locator.resolve(in: DocumentContentIndex(new))
        #expect(Self.resolvedID(anchor) == bravo.id)
        #expect(Self.resolvedFraction(anchor) == 0.25)

        let indented = MarkdownBlockRenderer.render(from: "```\n  spaced\n```", documentURL: url)
        let flush = MarkdownBlockRenderer.render(from: "```\nspaced\n```", documentURL: url)
        let indentedEntry = try #require(DocumentContentIndex(indented).entries.first)
        let flushEntry = try #require(DocumentContentIndex(flush).entries.first)
        #expect(indentedEntry.digest != flushEntry.digest)
    }

    @Test func hiddenAnchorsAreNeverRestorationTargets() throws {
        let url = URL(fileURLWithPath: "/tmp/m1-23/anchors.md")
        // A trailing authored anchor has no following block, so it renders as a
        // zero-height anchor leaf of its own.
        let document = MarkdownBlockRenderer.render(from: "Visible text.\n\n<a id=\"mark\"></a>",
                                                    documentURL: url)
        let anchors = document.leafIDs.filter { document[$0].kind == .anchor }
        #expect(!anchors.isEmpty, "the fixture must actually produce an anchor leaf")
        let index = DocumentContentIndex(document)
        #expect(index.entries.count == document.leafIDs.count - anchors.count)
        for id in anchors {
            #expect(DocumentContentLocator.capture(anchor: .block(id: id, fraction: 0.5),
                                                   in: index) == nil)
        }
    }

    @Test func digestsAreStableAcrossIdenticalRenderingsAndTagBlockKind() throws {
        let url = URL(fileURLWithPath: "/tmp/m1-23/kinds.md")
        let source = "# Repeat\n\nRepeat\n"
        let first = DocumentContentIndex(MarkdownBlockRenderer.render(from: source, documentURL: url))
        let second = DocumentContentIndex(MarkdownBlockRenderer.render(from: source, documentURL: url))
        #expect(first.entries.map(\.digest) == second.entries.map(\.digest))
        #expect(first.entries.count == 2)
        // A heading and a paragraph with the same words are not the same content.
        #expect(first.entries[0].digest != first.entries[1].digest)
    }
}
