import Foundation
import SwiftUI
import Testing
@testable import NeoMD

@MainActor struct DocumentReaderScrollPolicyTests {
    @Test func userPhasesRejectAutomaticViewportRestoration() {
        for phase: ScrollPhase in [.tracking, .interacting, .decelerating] {
            var policy = DocumentReaderScrollPolicy()
            #expect(policy.observe(phase)) // Includes a first-observed deceleration.
            #expect(!policy.permitsAutomatic(viewportChanged: true, selectionDragging: false))
            #expect(!policy.observe(phase))
        }
        var policy = DocumentReaderScrollPolicy()
        #expect(!policy.observe(.animating))
        #expect(policy.permitsAutomatic(viewportChanged: true, selectionDragging: false))
        #expect(!policy.permitsAutomatic(viewportChanged: true, selectionDragging: true))
        #expect(!policy.permitsAutomatic(viewportChanged: false, selectionDragging: false))
    }

    @Test func userTakeoverInvalidatesDelayedPasses() {
        var policy = DocumentReaderScrollPolicy()
        let search = policy.explicitIntent()
        var restoration = DocumentReaderResizeRestoration()
        restoration.beginIfNeeded(at: .bottom)
        let scheduled = restoration.schedule()
        #expect(policy.permits(search, selectionDragging: false, presentationCurrent: true))
        if policy.observe(.decelerating) { restoration.cancelForUserScroll() }
        #expect(scheduled != nil && !restoration.isPending)
        for phase: ScrollPhase in [.decelerating, .idle] {
            policy.observe(phase)
            // Valid detached results can publish, but this token cannot reveal them.
            #expect(!policy.permits(search, selectionDragging: false, presentationCurrent: true))
        }
        let freshFind = policy.explicitIntent()
        #expect(policy.permits(freshFind, selectionDragging: false, presentationCurrent: true))
        let section = policy.explicitIntent()
        #expect(!policy.permits(freshFind, selectionDragging: false, presentationCurrent: true))
        #expect(!policy.permits(section, selectionDragging: false, presentationCurrent: false))
        #expect(!policy.permits(section, selectionDragging: true, presentationCurrent: true))
        policy.observe(.tracking)
        policy.observe(.idle)
        #expect(!policy.permits(section, selectionDragging: false, presentationCurrent: true))
    }

    @Test func freshExplicitIntentCanInterruptUserPhaseButNotNextTakeover() {
        var policy = DocumentReaderScrollPolicy()
        policy.observe(.decelerating)
        let intent = policy.explicitIntent()
        policy.observe(.animating)
        #expect(policy.permits(intent, selectionDragging: false, presentationCurrent: true))
        policy.observe(.interacting)
        #expect(!policy.permits(intent, selectionDragging: false, presentationCurrent: true))
        policy.observe(.idle)
        #expect(!policy.permits(intent, selectionDragging: false, presentationCurrent: true))
    }

    @Test func passiveCacheRetainsIdentityAndSemanticAnchor() {
        let cache = DocumentReaderScrollObservation()
        let alias = cache
        let other = DocumentReaderScrollObservation()
        cache.anchor = .block(id: 2, fraction: 0.4)
        cache.frames = [2: CGRect(x: 0, y: 100, width: 400, height: 900)]
        // Early reflow frames must not themselves replace the pre-resize anchor.
        alias.frames[2]?.size.height = 1200
        #expect(cache === alias && cache !== other)
        #expect(cache.frames[2]?.height == 1200)
        #expect(alias.anchor == .block(id: 2, fraction: 0.4))
        #expect(other.frames.isEmpty && other.anchor == nil)
    }

    @Test func passiveGeometryKeepsLatestCoordinatesWithoutCommands() {
        let cache = DocumentReaderScrollObservation()
        let token = cache.policy.generation
        for (offset, height): (CGFloat, CGFloat) in [(800, 4000), (600, 4200), (400, 3900)] {
            cache.metrics = .init(contentHeight: height, viewportSize: CGSize(width: 480, height: 600),
                visibleRect: CGRect(x: 0, y: offset, width: 480, height: 600),
                topInset: 32, bottomInset: 32, isAtTop: false, isAtBottom: false)
            #expect(cache.metrics.visibleRect.minY == offset)
            #expect(cache.metrics.contentHeight == height)
            #expect(!cache.policy.permitsAutomatic(viewportChanged: false, selectionDragging: false))
            #expect(cache.policy.generation == token)
            #expect(cache.metrics.clampedVerticalOffset(-100) == -32)
            #expect(cache.metrics.clampedVerticalOffset(10000) == height - 600 + 32)
        }
        #expect(DocumentReaderScrollMetrics.zero.clampedVerticalOffset(10) == 0)
    }

    @Test func selectionBusySurvivesScrollIdle() {
        let preference = ReadingSizePreference()
        var reflow = ReadingSizeReflow(preference: preference)
        let cache = DocumentReaderScrollObservation()
        cache.policy.observe(.decelerating)
        preference.apply(.increase)
        preference.apply(.increase)
        cache.policy.observe(.idle)
        var captures: [DocumentReadingAnchor] = []
        for (work, dragging) in [(1, true), (0, true), (1, false)] {
            let busy = DocumentReaderScrollPolicy.hasReadingActivity(isScrolling: false,
                interactiveWork: work, selectionDragging: dragging)
            reflow.reconcile(preference, eligible: !busy) { captures.append(.top) }
            #expect(busy && reflow.isQueued(preference) && captures.isEmpty)
        }
        // Production captures this before draining queued requests, not the old anchor.
        cache.anchor = .block(id: 4, fraction: 0.7)
        let busy = DocumentReaderScrollPolicy.hasReadingActivity(isScrolling: false,
            interactiveWork: 0, selectionDragging: false)
        for _ in 0..<2 {
            reflow.reconcile(preference, eligible: !busy) { captures.append(cache.anchor ?? .top) }
        }
        #expect(captures == [.block(id: 4, fraction: 0.7)])
        #expect(reflow.applied == .largest && !reflow.isQueued(preference))
    }

    @Test func captureNeverRequestsRestoration() throws {
        let text = "# Title\n\nBody"
        let input = PreparedReadingDocument(text: text, fileURL: URL(fileURLWithPath: "/tmp/p9-value.md"),
            rendered: MarkdownBlockRenderer.render(from: text))
        let session = DocumentReadSession()
        _ = session.commit(input, fragment: nil, token: session.begin())
        let generation = session.generation
        var observations = 0
        session.positionObserver = { _, _ in observations += 1 }
        let leaf = try #require(input.index.entries.first)
        for anchor: DocumentReadingAnchor in [.top, .block(id: leaf.id, fraction: 0.2), .block(id: leaf.id, fraction: 0.6)] {
            let locator = try #require(DocumentContentLocator.capture(anchor: anchor, in: input.index))
            session.recordReadingPosition(locator, presentation: input.id)
            #expect(session.readingPosition == nil && session.section == nil)
            #expect(session.generation == generation)
            #expect(session.capturedPosition(for: input.id) == locator)
        }
        #expect(observations == 3)
    }
}
