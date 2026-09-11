//
//  DocumentRefreshControllerTests.swift
//  NeoMDTests
//

import Darwin
import Foundation
import Testing
@testable import NeoMD

/// Pipeline regressions for #23 criteria C1, C2 and C4 using injected logical time
/// and an in-memory source. No file presenter is registered, no host event is waited
/// for and no real clock is slept on; this is model evidence, not native proof.
struct DocumentRefreshControllerTests {

    /// An in-memory stand-in for one watched path.
    private final class SourceStub: @unchecked Sendable {
        var text = "# One"
        var failure: (any Error)?
        var generation = 0
        private(set) var published: [String] = []
        private(set) var reads = 0
        var duringRead: (@Sendable () -> Void)?

        func write(_ text: String) {
            self.text = text
            generation += 1
        }

        func fail(_ error: any Error) {
            failure = error
            generation += 1
        }

        func recover(_ text: String) {
            failure = nil
            self.text = text
            generation += 1
        }

        func stamp() throws -> RegularMarkdownRead.Stamp {
            if let failure { throw failure }
            return DocumentRefreshControllerTests.stamp(inode: UInt64(generation + 1),
                                                        size: Int64(text.utf8.count),
                                                        seconds: generation)
        }

        func snapshot() throws -> RegularMarkdownRead.Snapshot {
            reads += 1
            duringRead?()
            if let failure { throw failure }
            return RegularMarkdownRead.Snapshot(data: Data(text.utf8), stamp: try stamp())
        }

        func record(_ text: String) { published.append(text) }

        func source(url: URL, now: @escaping @Sendable () -> TimeInterval) -> DocumentRefreshSource {
            DocumentRefreshSource(now: now, url: { url },
                                  stamp: { [self] _ in try stamp() },
                                  snapshot: { [self] _ in try snapshot() },
                                  publish: { [self] text in record(text) })
        }
    }

    private final class Collector: @unchecked Sendable {
        private(set) var outcomes: [DocumentRefreshOutcome] = []

        var updates: [DocumentRefreshPayload] {
            outcomes.compactMap { if case .updated(let payload) = $0 { payload } else { nil } }
        }
        var failures: [DocumentRefreshFailure] {
            outcomes.compactMap { if case .unavailable(let failure) = $0 { failure } else { nil } }
        }

        func receive(_ outcome: DocumentRefreshOutcome) { outcomes.append(outcome) }
        func reset() { outcomes.removeAll() }
    }

    private static func stamp(inode: UInt64, size: Int64, seconds: Int) -> RegularMarkdownRead.Stamp {
        var value = stat()
        value.st_dev = 1
        value.st_ino = inode
        value.st_size = size
        value.st_mode = S_IFREG | 0o644
        value.st_mtimespec = timespec(tv_sec: seconds, tv_nsec: 0)
        value.st_ctimespec = timespec(tv_sec: seconds, tv_nsec: 0)
        return RegularMarkdownRead.Stamp(value)
    }

    private static let url = URL(fileURLWithPath: "/tmp/m1-23/live.md")

    /// Drives the controller without starting its real poll task.
    private static func harness(_ stub: SourceStub) -> DocumentRefreshController {
        let controller = DocumentRefreshController()
        var source = stub.source(url: url, now: { 0 })
        source.automaticPolling = false
        controller.rebind(source)
        return controller
    }

    /// Settles whatever the stub currently holds, starting at `time`.
    @discardableResult
    private static func settle(_ controller: DocumentRefreshController,
                               from time: TimeInterval) -> TimeInterval {
        var cursor = time
        for _ in 0..<4 {
            controller.tick(at: cursor)
            cursor += DocumentRefreshState.quietInterval
        }
        return cursor
    }

    // MARK: C1 and C2

    @Test func aBurstOfWritesPublishesOnlyTheSettledRevisionOnce() throws {
        let stub = SourceStub()
        let controller = Self.harness(stub)
        let collector = Collector()
        controller.attach(UUID()) { collector.receive($0) }

        controller.tick(at: 0)
        stub.write("# Two")
        controller.tick(at: 0.1)
        stub.write("# Three")
        controller.tick(at: 0.2)
        // Still inside the trailing quiet interval of the last write.
        controller.tick(at: 0.45)
        #expect(collector.updates.isEmpty)
        #expect(stub.reads == 0)

        controller.tick(at: 0.55)
        let updates = collector.updates
        #expect(updates.count == 1)
        #expect(updates.first?.text == "# Three")
        #expect(stub.reads == 1)
        #expect(stub.published == ["# Three"])
        // Its render and locator index travel with the payload.
        #expect(updates.first?.index.entries.isEmpty == false)
    }

    @Test func aWriteLandingDuringPreparationRejectsTheSupersededResult() throws {
        let stub = SourceStub()
        let controller = Self.harness(stub)
        let collector = Collector()
        controller.attach(UUID()) { collector.receive($0) }
        stub.duringRead = { [weak controller] in controller?.invalidate() }

        Self.settle(controller, from: 0)
        #expect(stub.reads >= 1)
        #expect(collector.updates.isEmpty, "a read that crossed a newer write must not publish")

        stub.duringRead = nil
        Self.settle(controller, from: 4)
        #expect(collector.updates.count == 1)
        #expect(collector.updates.first?.text == "# One")
    }

    @Test func aSettledEmptyFileIsValidContent() throws {
        let stub = SourceStub()
        stub.text = ""
        let controller = Self.harness(stub)
        let collector = Collector()
        controller.attach(UUID()) { collector.receive($0) }

        Self.settle(controller, from: 0)
        #expect(collector.updates.count == 1)
        #expect(collector.updates.first?.text == "")
        #expect(collector.updates.first?.index.isEmpty == true)
        #expect(collector.failures.isEmpty)
    }

    // MARK: C4

    @Test func anUnreadableFileKeepsTheLastResultAndRecoversWithoutANewEvent() throws {
        let stub = SourceStub()
        let controller = Self.harness(stub)
        let collector = Collector()
        let viewer = UUID()
        controller.attach(viewer) { collector.receive($0) }
        var cursor = Self.settle(controller, from: 0)
        let first = try #require(collector.updates.first)
        controller.acknowledge(viewer, revision: first.revision)
        collector.reset()

        stub.fail(POSIXError(.ENOENT))
        cursor = Self.settle(controller, from: cursor)
        let failure = try #require(collector.failures.first)
        #expect(collector.failures.count == 1, "a quiet status is not repeated every poll")
        #expect(collector.updates.isEmpty, "the last good rendering is retained")
        #expect(failure.message == DocumentRefreshFailure.message)
        #expect(failure.diagnostic.isEmpty == false)
        controller.acknowledge(viewer, failure: failure)
        collector.reset()

        // Retry continues without another presenter callback.
        stub.fail(POSIXError(.EACCES))
        cursor = Self.settle(controller, from: cursor)
        #expect(collector.updates.isEmpty)
        collector.reset()

        stub.recover("# Recovered")
        cursor = Self.settle(controller, from: cursor)
        let recovered = try #require(collector.updates.last)
        #expect(recovered.text == "# Recovered")
        #expect(recovered.revision != first.revision)
    }

    @Test func recoveringWithIdenticalContentClearsStatusWithoutANewRevision() throws {
        let stub = SourceStub()
        let controller = Self.harness(stub)
        let collector = Collector()
        let viewer = UUID()
        controller.attach(viewer) { collector.receive($0) }
        var cursor = Self.settle(controller, from: 0)
        let first = try #require(collector.updates.first)
        controller.acknowledge(viewer, revision: first.revision)

        stub.fail(POSIXError(.EACCES))
        cursor = Self.settle(controller, from: cursor)
        let failure = try #require(collector.failures.first)
        controller.acknowledge(viewer, failure: failure)
        collector.reset()

        stub.recover("# One")
        cursor = Self.settle(controller, from: cursor)
        let offered = try #require(collector.updates.last)
        #expect(offered.revision == first.revision, "identical content is not a new revision")
        #expect(offered.text == "# One")
        #expect(controller.latestRevision == first.revision)
        #expect(stub.published == ["# One"], "identical content is not republished natively")
    }

    // MARK: Viewer independence and ownership

    @Test func aViewerThatDeclinesIsOfferedTheSameResultAgain() throws {
        let stub = SourceStub()
        let controller = Self.harness(stub)
        let accepting = Collector()
        let declining = Collector()
        let acceptingID = UUID()
        controller.attach(acceptingID) { accepting.receive($0) }
        controller.attach(UUID()) { declining.receive($0) }

        var cursor = Self.settle(controller, from: 0)
        let payload = try #require(accepting.updates.first)
        controller.acknowledge(acceptingID, revision: payload.revision)
        #expect(declining.updates.count == 1)
        accepting.reset()
        declining.reset()

        // Polls continue; only the viewer that never accepted is offered it again.
        cursor = Self.settle(controller, from: cursor + DocumentRefreshState.pollInterval)
        #expect(accepting.updates.isEmpty)
        #expect(declining.updates.isEmpty == false)
        #expect(declining.updates.allSatisfy { $0.revision == payload.revision })
        _ = cursor
    }

    @Test func aLateViewerCatchesUpWithoutDisturbingTheOthers() throws {
        let stub = SourceStub()
        let controller = Self.harness(stub)
        let first = Collector()
        let firstID = UUID()
        controller.attach(firstID) { first.receive($0) }
        let cursor = Self.settle(controller, from: 0)
        let payload = try #require(first.updates.first)
        controller.acknowledge(firstID, revision: payload.revision)
        first.reset()

        let late = Collector()
        controller.attach(UUID()) { late.receive($0) }
        #expect(late.updates.count == 1)
        #expect(late.updates.first?.revision == payload.revision)
        #expect(first.outcomes.isEmpty, "an existing viewer is not touched by a new one")
        _ = cursor
    }

    @Test func theLastDetachStopsWorkAndEarlierDetachesDoNot() throws {
        let stub = SourceStub()
        let controller = Self.harness(stub)
        let staying = Collector()
        let leaving = Collector()
        let leavingID = UUID()
        controller.attach(leavingID) { leaving.receive($0) }
        let stayingID = UUID()
        controller.attach(stayingID) { staying.receive($0) }

        controller.detach(leavingID)
        #expect(controller.isObserving)
        var cursor = Self.settle(controller, from: 0)
        #expect(staying.updates.count == 1)
        #expect(leaving.outcomes.isEmpty)
        controller.acknowledge(stayingID, revision: try #require(staying.updates.first).revision)
        staying.reset()

        controller.detach(stayingID)
        #expect(!controller.isObserving)
        stub.write("# Ignored")
        cursor = Self.settle(controller, from: cursor)
        #expect(staying.outcomes.isEmpty, "a detached viewer receives nothing")
        _ = cursor
    }
}
