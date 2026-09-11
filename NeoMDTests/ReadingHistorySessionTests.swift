//
//  ReadingHistorySessionTests.swift
//  NeoMDTests
//

import CoreGraphics
import Foundation
import Testing
@testable import NeoMD

/// The session seams a remembered position travels through.
///
/// Model state only: no window, hosting controller, event, menu or accessibility
/// action is used, so real reopening, relaunching and scrolling stay unverified.
@MainActor
struct ReadingHistorySessionTests {

    private static let markdown = """
    # Head

    First paragraph.

    The amber checkpoint paragraph.

    Last paragraph.
    """

    private static func prepared(_ url: URL) -> PreparedReadingDocument {
        PreparedReadingDocument(text: markdown, fileURL: url,
                                rendered: MarkdownBlockRenderer.render(from: markdown,
                                                                       documentURL: url))
    }

    @Test func rememberedPositionIsConsumedOnceForItsOwnPresentation() throws {
        let url = URL(fileURLWithPath: "/tmp/history/session.md")
        let input = Self.prepared(url)
        let session = DocumentReadSession()
        #expect(session.commit(input, fragment: nil, token: session.begin()))

        let target = try #require(input.index.entries.dropFirst().first)
        session.requestReadingPosition(.block(id: target.id, fraction: 0.5),
                                       presentation: input.id, reason: .reopenHistory)

        // Another viewer's presentation can never consume this request.
        #expect(session.takeReadingPosition(for: UUID()) == nil)
        let request = try #require(session.takeReadingPosition(for: input.id))
        #expect(request.reason == .reopenHistory)
        #expect(request.anchor == .block(id: target.id, fraction: 0.5))
        #expect(session.takeReadingPosition(for: input.id) == nil)
    }

    @Test func explicitFragmentsOutrankRememberedPositions() {
        let url = URL(fileURLWithPath: "/tmp/history/fragment.md")
        let input = Self.prepared(url)

        // A named destination wins: the coordinator never asks for history, and a
        // request that arrived anyway is refused while a section is pending.
        let named = DocumentReadSession()
        #expect(named.commit(input, fragment: "head", token: named.begin()))
        named.requestReadingPosition(.bottom, presentation: input.id, reason: .reopenHistory)
        #expect(named.readingPosition == nil)

        // An empty fragment means the top, and is still an explicit request.
        let top = DocumentReadSession()
        #expect(top.commit(input, fragment: "", token: top.begin()))
        top.requestReadingPosition(.bottom, presentation: input.id, reason: .reopenHistory)
        #expect(top.readingPosition == nil)
        #expect(top.takeSection(for: input.id)?.fragment == "")

        // New user intent during the same reader lifetime cancels a pending apply.
        let cancelled = DocumentReadSession()
        #expect(cancelled.commit(input, fragment: nil, token: cancelled.begin()))
        cancelled.requestReadingPosition(.bottom, presentation: input.id, reason: .reopenHistory)
        #expect(cancelled.readingPosition != nil)
        cancelled.navigate("head")
        #expect(cancelled.readingPosition == nil)
    }

    @Test func closedAndReplacedPresentationsRefuseRestoration() {
        let url = URL(fileURLWithPath: "/tmp/history/stale.md")
        let input = Self.prepared(url)
        let replacement = Self.prepared(url)

        let session = DocumentReadSession()
        #expect(session.commit(input, fragment: nil, token: session.begin()))
        // A request for a presentation this viewer no longer shows is dropped.
        #expect(session.commit(replacement, fragment: nil, token: session.begin()))
        session.requestReadingPosition(.bottom, presentation: input.id, reason: .reopenHistory)
        #expect(session.readingPosition == nil)

        session.close()
        session.requestReadingPosition(.bottom, presentation: replacement.id, reason: .reopenHistory)
        #expect(session.readingPosition == nil)
    }

    @Test func acceptedCapturesReachTheHistoryObserverWithTheirDocumentURL() throws {
        let url = URL(fileURLWithPath: "/tmp/history/observed.md")
        let input = Self.prepared(url)
        let session = DocumentReadSession()
        #expect(session.commit(input, fragment: nil, token: session.begin()))

        var seen: [URL] = []
        session.positionObserver = { _, observed in seen.append(observed) }

        let entry = try #require(input.index.entries.first)
        let locator = try #require(DocumentContentLocator.capture(
            anchor: .block(id: entry.id, fraction: 0.3), in: input.index))
        session.recordReadingPosition(locator, presentation: input.id)
        #expect(seen == [url])
        #expect(session.capturedPosition(for: input.id) == locator)

        // Geometry from a presentation this viewer no longer shows is ignored.
        session.recordReadingPosition(locator, presentation: UUID())
        #expect(seen.count == 1)

        // A closed viewer publishes nothing further.
        session.close()
        session.recordReadingPosition(locator, presentation: input.id)
        #expect(seen.count == 1)
    }

    /// A remembered position is expressed against the rendering that is actually
    /// installed, including one whose IDs have all shifted since it was captured.
    @Test func rememberedPositionsResolveIntoTheInstalledRendering() throws {
        let url = URL(fileURLWithPath: "/tmp/history/shifted.md")
        let input = Self.prepared(url)
        let entry = try #require(input.index.entries.first {
            String(input.rendered[$0.id].text.characters).hasPrefix("The amber checkpoint")
        })
        let captured = try #require(DocumentContentLocator.capture(
            anchor: .block(id: entry.id, fraction: 0.5), in: input.index))
        let stored = try #require(ReadingHistoryLocator(captured).restored)

        let shiftedSource = "---\nreview: updated\n---\n\nInserted preface.\n\n" + Self.markdown
        let shifted = PreparedReadingDocument(
            text: shiftedSource, fileURL: url,
            rendered: MarkdownBlockRenderer.render(from: shiftedSource, documentURL: url))

        let session = DocumentReadSession()
        #expect(session.commit(shifted, fragment: nil, token: session.begin()))
        session.requestReadingPosition(stored.resolve(in: shifted.index),
                                       presentation: shifted.id, reason: .reopenHistory)

        let request = try #require(session.takeReadingPosition(for: shifted.id))
        guard case .block(let id, let fraction) = request.anchor else {
            Issue.record("the remembered position did not resolve to a block")
            return
        }
        #expect(String(shifted.rendered[id].text.characters)
            == String(input.rendered[entry.id].text.characters))
        #expect(id != entry.id)
        #expect(abs(Double(fraction) - 0.5) < 0.0001)
    }
}
