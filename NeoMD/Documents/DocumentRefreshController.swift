//
//  DocumentRefreshController.swift
//  NeoMD
//

import Foundation
import Synchronization

/// One immutable result of a settled external write, prepared off the main actor.
nonisolated struct DocumentRefreshPayload: Sendable {
    let revision: UInt64
    let fileURL: URL
    let text: String
    let rendered: MarkdownRenderDocument
    let index: DocumentContentIndex
}

/// A quiet, reader-facing refresh failure. The underlying cause is kept for
/// diagnostics and never shown in the reading surface.
nonisolated struct DocumentRefreshFailure: Equatable, Sendable {
    static let message = "Couldn’t update this document. Showing the last readable version; retrying."

    let message: String
    let diagnostic: String

    init(diagnostic: String, message: String = DocumentRefreshFailure.message) {
        self.message = message
        self.diagnostic = diagnostic
    }
}

nonisolated enum DocumentRefreshOutcome: Sendable {
    case updated(DocumentRefreshPayload)
    case unavailable(DocumentRefreshFailure)
}

/// Everything the refresh pipeline needs from its native document, as copied
/// closures. Tests inject logical time and in-memory reads; production injects the
/// presenter's current URL and the coordinated read-only file access.
nonisolated struct DocumentRefreshSource: Sendable {
    var now: @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var url: @Sendable () -> URL? = { nil }
    var stamp: @Sendable (URL) throws -> RegularMarkdownRead.Stamp = { try RegularMarkdownRead.stamp(at: $0) }
    var snapshot: @Sendable (URL) throws -> RegularMarkdownRead.Snapshot = {
        try RegularMarkdownRead.snapshot(at: $0)
    }
    /// Keeps the native document's text current so a later viewer of the same
    /// native identity does not open stale bytes.
    var publish: @Sendable (String) -> Void = { _ in }
    /// The pipeline drives itself in production. Tests call `tick(at:)` with logical
    /// time instead of sleeping on a real clock.
    var automaticPolling = true
}

/// The single refresh pipeline owned by one native document.
///
/// Presenter invalidations and the bounded metadata poll feed the same scheduler,
/// so there is never a second reader racing the first. Exactly one preparation runs
/// at a time and only its current result is published; a viewer that declines a
/// delivery keeps the result available and is offered it again on a later tick.
///
/// Nothing here writes to the file, prompts to save, creates windows or touches
/// document history.
nonisolated final class DocumentRefreshController: Sendable {
    typealias Delivery = @Sendable (DocumentRefreshOutcome) -> Void

    private struct Subscriber {
        let deliver: Delivery
        var revision: UInt64?
        var failure: DocumentRefreshFailure?
    }

    private struct Storage {
        var source = DocumentRefreshSource()
        var bound = false
        var state = DocumentRefreshState()
        var subscribers: [UUID: Subscriber] = [:]
        var latest: DocumentRefreshPayload?
        var failure: DocumentRefreshFailure?
        var lastSample = -Double.greatestFiniteMagnitude
    }

    private let storage = Mutex(Storage())
    private let poll = Mutex<Task<Void, Never>?>(nil)

    init() {}

    deinit { poll.withLock { $0?.cancel(); $0 = nil } }

    /// Installs the owning document's access closures once.
    func bind(_ source: DocumentRefreshSource) {
        storage.withLock { storage in
            guard !storage.bound else { return }
            storage.bound = true
            storage.source = source
        }
    }

    /// Replaces the source unconditionally. Only tests and rebinding need this.
    func rebind(_ source: DocumentRefreshSource) {
        storage.withLock { storage in
            storage.bound = true
            storage.source = source
        }
    }

    var latestRevision: UInt64? { storage.withLock { $0.latest?.revision } }
    var isObserving: Bool { storage.withLock { $0.state.subscribed } }

    /// Adds one viewer. The first attachment starts the poll and forces a settled
    /// check, closing the gap between the initial read and observation.
    func attach(_ id: UUID, deliver: @escaping Delivery) {
        let source = storage.withLock { $0.source }
        let start = storage.withLock { storage -> Bool in
            storage.subscribers[id] = Subscriber(deliver: deliver)
            guard !storage.state.subscribed else { return false }
            storage.state.start(at: source.now())
            storage.lastSample = -Double.greatestFiniteMagnitude
            return true
        }
        if start, source.automaticPolling { startPolling() }
        // A late viewer catches up to the latest known result. Identical content is
        // suppressed where it commits, so this cannot rehost an up-to-date reader.
        deliverPending()
    }

    /// Removes one viewer. Other viewers keep observing; the last detach stops work.
    func detach(_ id: UUID) {
        let stop = storage.withLock { storage -> Bool in
            storage.subscribers.removeValue(forKey: id)
            guard storage.subscribers.isEmpty, storage.state.subscribed else { return false }
            storage.state.stop()
            return true
        }
        guard stop else { return }
        poll.withLock { $0?.cancel(); $0 = nil }
    }

    /// Thread-safe entry point for nonisolated file-presenter callbacks.
    func invalidate() {
        let source = storage.withLock { $0.source }
        let now = source.now()
        storage.withLock { $0.state.invalidate(at: now) }
    }

    /// Records that a viewer actually installed a result, so it is not offered again.
    func acknowledge(_ id: UUID, revision: UInt64) {
        storage.withLock { storage in
            storage.subscribers[id]?.revision = revision
            storage.subscribers[id]?.failure = nil
        }
    }

    func acknowledge(_ id: UUID, failure: DocumentRefreshFailure) {
        storage.withLock { $0.subscribers[id]?.failure = failure }
    }

    /// One scheduler step at logical `time`: sample, settle, prepare, deliver.
    ///
    /// Synchronous on purpose: the poll runs it off the main actor and tests drive it
    /// with injected time instead of sleeping on host callbacks.
    func tick(at time: TimeInterval) {
        let source = storage.withLock { $0.source }
        guard let url = source.url() else { return }
        let due = storage.withLock { storage -> Bool in
            guard storage.state.subscribed else { return false }
            guard storage.state.pending || storage.state.retryNeeded
                    || time - storage.lastSample >= DocumentRefreshState.pollInterval else { return false }
            storage.lastSample = time
            return true
        }
        guard due else { return }
        // Metadata sampling and reading happen without the lock held: a presenter
        // callback must never wait behind file access.
        let stamp = try? source.stamp(url)
        guard let ticket = storage.withLock({ $0.state.observe(stamp, at: time) }) else {
            deliverPending()
            return
        }
        finish(ticket, prepare(url, revision: ticket.revision, with: source), with: source)
        deliverPending()
    }

    private func prepare(_ url: URL, revision: UInt64,
                         with source: DocumentRefreshSource) -> Result<DocumentRefreshPayload, any Error> {
        Result {
            let snapshot = try source.snapshot(url)
            let text = try MarkdownTextDecoder.text(from: snapshot.data)
            let rendered = MarkdownBlockRenderer.render(from: text, documentURL: url)
            return DocumentRefreshPayload(revision: revision, fileURL: url, text: text,
                                          rendered: rendered, index: DocumentContentIndex(rendered))
        }
    }

    private func finish(_ ticket: DocumentRefreshState.Ticket,
                        _ result: Result<DocumentRefreshPayload, any Error>,
                        with source: DocumentRefreshSource) {
        let published: String? = storage.withLock { storage -> String? in
            switch result {
            case .success(let payload):
                guard storage.state.complete(ticket, succeeded: true) else { return nil }
                storage.failure = nil
                guard storage.latest?.text != payload.text || storage.latest?.fileURL != payload.fileURL else {
                    // A readable file with unchanged content is a recovery, not an
                    // update: clear a viewer's failure without reinstalling anything.
                    let recovered = storage.subscribers.filter { $0.value.failure != nil }.map(\.key)
                    for id in recovered {
                        storage.subscribers[id]?.failure = nil
                        storage.subscribers[id]?.revision = nil
                    }
                    return nil
                }
                storage.latest = payload
                return payload.text
            case .failure(let error):
                guard storage.state.complete(ticket, succeeded: false) else { return nil }
                storage.failure = DocumentRefreshFailure(diagnostic: String(describing: error))
                return nil
            }
        }
        guard let published else { return }
        source.publish(published)
    }

    /// Offers the current result to every viewer that has not accepted it yet.
    private func deliverPending() {
        let pending: [(Delivery, DocumentRefreshOutcome)] = storage.withLock {
            storage -> [(Delivery, DocumentRefreshOutcome)] in
            var pending: [(Delivery, DocumentRefreshOutcome)] = []
            var offered: [UUID] = []
            for (id, subscriber) in storage.subscribers {
                if let payload = storage.latest, subscriber.revision != payload.revision {
                    pending.append((subscriber.deliver, .updated(payload)))
                } else if let failure = storage.failure, subscriber.failure != failure {
                    pending.append((subscriber.deliver, .unavailable(failure)))
                    offered.append(id)
                }
            }
            // A status is idempotent: record it as offered so a quiet failure is not
            // re-announced on every poll while it persists.
            for id in offered { storage.subscribers[id]?.failure = storage.failure }
            return pending
        }
        for (deliver, outcome) in pending { deliver(outcome) }
    }

    private func startPolling() {
        poll.withLock { existing in
            existing?.cancel()
            existing = Task.detached(priority: .utility) { [weak self] in
                while !Task.isCancelled {
                    guard let self else { return }
                    let source = storage.withLock { $0.source }
                    tick(at: source.now())
                    try? await Task.sleep(for: .seconds(DocumentRefreshState.quietInterval))
                }
            }
        }
    }
}
