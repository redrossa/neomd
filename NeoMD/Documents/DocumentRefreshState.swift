import Foundation

/// Logical-time scheduler shared by presenter invalidations and metadata polling.
/// No task, file presenter, window, or wall clock is owned by this value.
nonisolated struct DocumentRefreshState: Sendable {
    struct Ticket: Equatable, Sendable {
        let generation: UInt64
        let revision: UInt64
    }

    static let quietInterval: TimeInterval = 0.3
    static let pollInterval: TimeInterval = 1
    private(set) var generation: UInt64 = 0
    private(set) var revision: UInt64 = 0
    private(set) var active: Ticket?
    private(set) var pending = false
    private(set) var subscribed = false
    private(set) var retryNeeded = false
    private var quietSince: TimeInterval = 0
    private var sample: RegularMarkdownRead.Stamp?

    mutating func start(at time: TimeInterval) {
        guard !subscribed else { return }
        subscribed = true
        generation &+= 1
        invalidate(at: time)
    }

    mutating func stop() {
        subscribed = false
        generation &+= 1
        pending = false
        retryNeeded = false
        sample = nil
        // Keep the active slot until its completion, even across detach/reattach.
        // Cancellation of a synchronous parser is not proof that it has exited.
    }

    mutating func invalidate(at time: TimeInterval) {
        guard subscribed else { return }
        revision &+= 1
        pending = true
        quietSince = time
        sample = nil
    }

    /// A second equal path sample after the quiet interval permits preparation.
    mutating func observe(_ stamp: RegularMarkdownRead.Stamp?, at time: TimeInterval) -> Ticket? {
        guard subscribed else { return nil }
        if stamp != sample {
            invalidate(at: time)
            sample = stamp
        }
        if retryNeeded && !pending {
            invalidate(at: time)
            sample = stamp
        }
        guard pending, active == nil, time - quietSince >= Self.quietInterval else { return nil }
        let ticket = Ticket(generation: generation, revision: revision)
        active = ticket
        pending = false
        return ticket
    }

    func accepts(_ ticket: Ticket) -> Bool {
        subscribed && ticket.generation == generation && ticket.revision == revision && active == ticket
    }

    /// Return true only for a still-current result. A stale completion frees the
    /// sole preparation slot but cannot clear a newer pending invalidation.
    @discardableResult mutating func complete(_ ticket: Ticket, succeeded: Bool) -> Bool {
        guard active == ticket else { return false }
        let accepted = accepts(ticket)
        active = nil
        if accepted { retryNeeded = !succeeded }
        return accepted
    }
}
