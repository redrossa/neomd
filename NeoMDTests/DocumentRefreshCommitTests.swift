//
//  DocumentRefreshCommitTests.swift
//  NeoMDTests
//

import Foundation
import Testing
@testable import NeoMD

/// Viewer-side refresh transaction regressions for #23: ticket guards, position
/// transport and the quiet status. Pure session state; no window, hosting
/// controller, event or file access is involved.
@MainActor
struct DocumentRefreshCommitTests {
    private static let url = URL(fileURLWithPath: "/tmp/m1-23/live.md")

    private static func prepared(_ markdown: String) -> PreparedReadingDocument {
        PreparedReadingDocument(text: markdown, fileURL: url,
                                rendered: MarkdownBlockRenderer.render(from: markdown, documentURL: url))
    }

    private static func leafID(prefix: String, in document: MarkdownRenderDocument) throws -> Int {
        try #require(document.leaves.first { String($0.text.characters).hasPrefix(prefix) }?.id)
    }

    private static func viewer(_ markdown: String,
                               binding: UUID) -> (DocumentReadSession, PreparedReadingDocument) {
        let session = DocumentReadSession()
        let input = prepared(markdown)
        session.binding = binding
        _ = session.commit(input, fragment: nil, token: session.begin())
        return (session, input)
    }

    @Test func refreshTicketRequiresAnIdleViewerBoundToThisDocument() throws {
        let binding = UUID()
        let (session, input) = Self.viewer("# One", binding: binding)
        #expect(session.refreshTicket(binding: binding, revision: 1) != nil)
        #expect(session.refreshTicket(binding: UUID(), revision: 1) == nil)

        session.isUserBusy = true
        #expect(session.refreshTicket(binding: binding, revision: 1) == nil)
        session.isUserBusy = false

        session.task = Task {}
        #expect(session.refreshTicket(binding: binding, revision: 1) == nil)
        session.task = nil

        session.navigate("section")
        #expect(session.refreshTicket(binding: binding, revision: 1) == nil)
        #expect(session.takeSection(for: input.id) != nil)
        let resumed = try #require(session.refreshTicket(binding: binding, revision: 1))
        #expect(resumed.presentation == input.id)
        #expect(resumed.session == session.id)

        session.close()
        #expect(session.refreshTicket(binding: binding, revision: 1) == nil)
    }

    @Test func commitRefreshReplacesContentWithoutStartingAUserRequest() throws {
        let binding = UUID()
        let (session, first) = Self.viewer("# One", binding: binding)
        let generation = session.generation
        let ticket = try #require(session.refreshTicket(binding: binding, revision: 7))
        let second = Self.prepared("# Two")

        #expect(session.commitRefresh(second, ticket: ticket, restoration: .top))
        #expect(session.prepared?.id == second.id)
        #expect(session.prepared?.text == "# Two")
        // A file change must not cancel user work or clear an explicit destination.
        #expect(session.generation == generation)
        #expect(session.task == nil)
        #expect(session.section == nil)
        #expect(session.readingPosition?.anchor == .top)

        // The consumed ticket cannot be replayed against the new presentation.
        #expect(!session.commitRefresh(Self.prepared("# Three"), ticket: ticket, restoration: nil))
        #expect(session.prepared?.id == second.id)
        #expect(first.id != second.id)
    }

    @Test func aStaleOrForeignTicketIsRefused() throws {
        let binding = UUID()
        let (session, _) = Self.viewer("# One", binding: binding)
        let ticket = try #require(session.refreshTicket(binding: binding, revision: 3))
        let other = DocumentReadSession()
        other.binding = binding
        _ = other.commit(Self.prepared("# Other"), fragment: nil, token: other.begin())

        #expect(!other.commitRefresh(Self.prepared("# Two"), ticket: ticket, restoration: nil))
        #expect(other.prepared?.text == "# Other")

        // A newer user request supersedes an older refresh authority.
        _ = session.begin()
        #expect(!session.commitRefresh(Self.prepared("# Two"), ticket: ticket, restoration: nil))
        #expect(session.prepared?.text == "# One")
    }

    @Test func restorationIsConsumedOnceByItsOwnPresentation() throws {
        let binding = UUID()
        let (session, _) = Self.viewer("# One\n\nBody.", binding: binding)
        let ticket = try #require(session.refreshTicket(binding: binding, revision: 2))
        let second = Self.prepared("# One\n\nBody.\n\nMore.")
        #expect(session.commitRefresh(second, ticket: ticket,
                                      restoration: .block(id: 1, fraction: 0.25)))

        #expect(session.takeReadingPosition(for: UUID()) == nil)
        let request = try #require(session.takeReadingPosition(for: second.id))
        #expect(request.anchor == .block(id: 1, fraction: 0.25))
        #expect(request.reason == .refresh)
        #expect(request.presentation == second.id)
        #expect(session.takeReadingPosition(for: second.id) == nil)
    }

    @Test func explicitNavigationAndOpeningOutrankAutomaticRestoration() throws {
        let binding = UUID()
        let (session, _) = Self.viewer("# One", binding: binding)
        let ticket = try #require(session.refreshTicket(binding: binding, revision: 4))
        let second = Self.prepared("# Two")
        #expect(session.commitRefresh(second, ticket: ticket, restoration: .bottom))
        #expect(session.readingPosition != nil)

        session.navigate("somewhere")
        #expect(session.readingPosition == nil)

        // Once the explicit destination has been consumed, refresh resumes.
        #expect(session.takeSection(for: second.id) != nil)
        let ticket2 = try #require(session.refreshTicket(binding: binding, revision: 5))
        let third = Self.prepared("# Three")
        #expect(session.commitRefresh(third, ticket: ticket2, restoration: .bottom))
        #expect(session.readingPosition != nil)

        // An explicit open replaces the presentation and drops automatic restoration.
        _ = session.commit(Self.prepared("# Opened"), fragment: nil, token: session.begin())
        #expect(session.readingPosition == nil)
    }

    @Test func aQuietStatusKeepsTheLastRenderingAndNeverTouchesOtherNotices() throws {
        let binding = UUID()
        let (session, first) = Self.viewer("# One", binding: binding)
        session.notice = "Opened link"

        session.reportRefreshFailure(DocumentRefreshFailure.message)
        #expect(session.refreshStatus == DocumentRefreshFailure.message)
        #expect(session.notice == "Opened link")
        #expect(session.prepared?.id == first.id, "the last successful rendering is retained")

        session.reportRefreshFailure(DocumentRefreshFailure.message)
        #expect(session.refreshStatus == DocumentRefreshFailure.message)

        session.clearRefreshStatus()
        #expect(session.refreshStatus == nil)
        #expect(session.notice == "Opened link")

        // A viewer with nothing rendered has no quiet refresh state to show.
        let empty = DocumentReadSession()
        empty.reportRefreshFailure(DocumentRefreshFailure.message)
        #expect(empty.refreshStatus == nil)

        // A successful refresh clears only the refresh status.
        session.reportRefreshFailure(DocumentRefreshFailure.message)
        let ticket = try #require(session.refreshTicket(binding: binding, revision: 9))
        #expect(session.commitRefresh(Self.prepared("# Two"), ticket: ticket, restoration: nil))
        #expect(session.refreshStatus == nil)
        #expect(session.notice == "Opened link")
    }

    @Test func capturedPositionsBelongToOnePresentation() throws {
        let binding = UUID()
        let (session, first) = Self.viewer("# One\n\nBody.", binding: binding)
        let locator = try #require(DocumentContentLocator.capture(
            anchor: .block(id: try Self.leafID(prefix: "Body.", in: first.rendered), fraction: 0.5),
            in: first.index))

        session.recordReadingPosition(locator, presentation: UUID())
        #expect(session.capturedPosition(for: first.id) == nil)

        session.recordReadingPosition(locator, presentation: first.id)
        #expect(session.capturedPosition(for: first.id) == locator)
        #expect(session.capturedPosition(for: UUID()) == nil)

        let ticket = try #require(session.refreshTicket(binding: binding, revision: 11))
        #expect(session.commitRefresh(Self.prepared("# One"), ticket: ticket, restoration: nil))
        #expect(session.capturedPosition(for: first.id) == nil, "a stale capture cannot survive")
    }

    /// The exact sequence the coordinator performs: capture, resolve into the new
    /// index, commit, then hand the request to the next presentation.
    @Test func aRemappedPositionSurvivesInsertedMetadataAndProse() throws {
        let binding = UUID()
        let (session, first) = Self.viewer("# Title\n\nAlpha paragraph.\n\nWatched paragraph.", binding: binding)
        let second = Self.prepared(
            "---\ntitle: Two\n---\n# Title\n\nInserted paragraph.\n\nAlpha paragraph.\n\nWatched paragraph.")
        let oldTarget = try Self.leafID(prefix: "Watched paragraph.", in: first.rendered)
        let newTarget = try Self.leafID(prefix: "Watched paragraph.", in: second.rendered)
        #expect(oldTarget != newTarget, "metadata and inserted prose must shift render IDs")

        let locator = try #require(DocumentContentLocator.capture(
            anchor: .block(id: oldTarget, fraction: 0.65), in: first.index))
        session.recordReadingPosition(locator, presentation: first.id)

        let ticket = try #require(session.refreshTicket(binding: binding, revision: 12))
        let restoration = session.capturedPosition(for: ticket.presentation)?.resolve(in: second.index)
        #expect(session.commitRefresh(second, ticket: ticket, restoration: restoration))

        let request = try #require(session.takeReadingPosition(for: second.id))
        #expect(request.anchor == .block(id: newTarget, fraction: 0.65))
    }
}
