import Foundation
import Testing
@testable import NeoMD

@MainActor struct ReadingSizeRestorationTests {
    private func session() -> DocumentReadSession {
        let session = DocumentReadSession()
        let text = "AMBER prose\n\n> CHARLIE nested\n\n| Header |\n| --- |\n| JADE cell |"
        let input = PreparedReadingDocument(text: text, fileURL: URL(fileURLWithPath: "/tmp/value-only-size.md"),
                                            rendered: MarkdownBlockRenderer.render(from: text))
        _ = session.commit(input, fragment: nil, token: session.begin())
        return session
    }

    @Test func busyRequestsRetainHistoryAndConsumeExactlyOnceAtIdle() throws {
        let session = session()
        let id = try #require(session.prepared?.id)
        for reason: ReadingPositionRequest.Reason in [.reopenHistory, .refresh, .readingSize] {
            session.requestReadingPosition(.bottom, presentation: id, reason: reason)
            let pending = session.readingPosition
            #expect(session.takeReadingPosition(for: id, isActive: true) == nil)
            #expect(session.readingPosition == pending)
            #expect(session.takeReadingPosition(for: UUID()) == nil)
            #expect(session.takeReadingPosition(for: id) == pending)
            #expect(session.takeReadingPosition(for: id) == nil)
        }
    }

    @Test func explicitIntentReplacementAndCloseRejectObsoleteRequests() throws {
        let session = session()
        let input = try #require(session.prepared)
        session.requestReadingPosition(.bottom, presentation: input.id, reason: .readingSize)
        session.cancelReadingPosition()
        #expect(session.takeReadingPosition(for: input.id) == nil)
        session.requestReadingPosition(.bottom, presentation: input.id, reason: .readingSize)
        session.navigate("header")
        #expect(session.readingPosition == nil)
        session.requestReadingPosition(.top, presentation: input.id, reason: .readingSize)
        #expect(session.readingPosition == nil)
        _ = session.takeSection(for: input.id)
        session.requestReadingPosition(.bottom, presentation: input.id, reason: .readingSize)
        session.close()
        #expect(session.takeReadingPosition(for: input.id) == nil)
    }

    @Test func queuedCommandsPrepareBeforePublishingAndKeepLatestDesiredOnly() {
        let preference = ReadingSizePreference()
        var reflow = ReadingSizeReflow(preference: preference)
        var preparations = 0
        preference.apply(.increase)
        reflow.reconcile(preference, eligible: false) { preparations += 1 }
        preference.apply(.increase)
        #expect(reflow.applied == .actual && reflow.isQueued(preference))
        #expect(preparations == 0)
        var observed: ReadingSize?
        let before = reflow.applied
        reflow.reconcile(preference, eligible: true) { observed = before; preparations += 1 }
        #expect(observed == .actual && preparations == 1)
        #expect(reflow.applied == .largest && !reflow.isQueued(preference))
        preference.apply(.increase)
        reflow.reconcile(preference, eligible: true) { preparations += 1 }
        #expect(preparations == 1)
        preference.apply(.reset)
        reflow.reconcile(preference, eligible: true) { preparations += 1 }
        #expect(reflow.applied == .actual && preparations == 2)
    }

    @Test func debugInitialOverrideYieldsToExplicitNoChangePreferenceCommand() {
        let preference = ReadingSizePreference()
        var reflow = ReadingSizeReflow(preference: preference, initial: .largest)
        preference.apply(.reset)
        var prepared = false
        reflow.reconcile(preference, eligible: true) { prepared = true }
        #expect(prepared && reflow.applied == .actual)
        #expect(ReadingSizeReflow(preference: preference).applied == .actual)
    }

    @Test func eachReaderKeepsItsOwnLocatorAndPreparedContent() throws {
        let first = session(), second = session()
        let input = try #require(first.prepared)
        let other = try #require(second.prepared)
        let preference = ReadingSizePreference()
        for leaf in input.rendered.leaves where ["AMBER", "CHARLIE", "JADE"].contains(where: { String(leaf.text.characters).hasPrefix($0) }) {
            for fraction: CGFloat in [0, 0.25, 0.65, 1] {
                let anchor = DocumentReadingAnchor.block(id: leaf.id, fraction: fraction)
                let locator = try #require(DocumentContentLocator.capture(anchor: anchor, in: input.index))
                first.recordReadingPosition(locator, presentation: input.id)
                second.recordReadingPosition(try #require(DocumentContentLocator.capture(anchor: .bottom, in: other.index)), presentation: other.id)
                preference.apply(.increase)
                #expect(first.capturedPosition(for: input.id)?.resolve(in: input.index) == anchor)
                #expect(second.capturedPosition(for: other.id)?.resolve(in: other.index) == .bottom)
                #expect(first.prepared?.id == input.id && first.prepared?.text == input.text)
                #expect(first.prepared?.index.entries == input.index.entries)
            }
        }
        var restoration = DocumentReaderResizeRestoration()
        restoration.beginIfNeeded(at: .bottom)
        let old = restoration.schedule()
        restoration.beginIfNeeded(at: .top)
        let scheduled = restoration.schedule()
        let latest = try #require(scheduled)
        #expect(restoration.pendingAnchor == .bottom)
        #expect(old != latest)
        restoration.cancelForUserScroll()
        #expect(restoration.pendingAnchor(for: latest) == nil)
    }

    @Test func oldFindHighlightCannotTakeSizeOwnedReflow() {
        #expect(!ReadingSizeReflow.shouldRevealExistingFind(viewportChanged: true, hasHighlight: true, sizeOwnsRestoration: true))
        #expect(ReadingSizeReflow.shouldRevealExistingFind(viewportChanged: true, hasHighlight: true, sizeOwnsRestoration: false))
        #expect(!ReadingSizeReflow.shouldRevealExistingFind(viewportChanged: false, hasHighlight: true, sizeOwnsRestoration: false))
    }

    @Test func modelCommandsDoNotWriteDocumentBytesOrModificationDate() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("source.md")
        let bytes = Data("# Unchanged\n".utf8)
        try bytes.write(to: url)
        let before = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let preference = ReadingSizePreference()
        preference.apply(.increase); preference.apply(.increase); preference.apply(.decrease); preference.apply(.reset)
        #expect(try Data(contentsOf: url) == bytes)
        #expect(try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == before)
    }
}
