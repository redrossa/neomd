import Foundation
import Testing
@testable import NeoMD

/// Scheduler regressions for #23. Every step uses injected logical time; nothing
/// sleeps on a real clock and no observer is registered.
///
/// `observe`/`complete` are `mutating`, so each result is bound to a local before it
/// reaches an `#expect`/`#require` macro.
struct DocumentRefreshStateTests {
    @Test func rapidInvalidationsWaitForTrailingQuietBoundary() {
        var state = DocumentRefreshState()
        state.start(at: 0)
        state.invalidate(at: 0.1)
        state.invalidate(at: 0.2)
        let early = state.observe(nil, at: 0.49)
        #expect(early == nil)
        let settled = state.observe(nil, at: 0.51)
        #expect(settled != nil)
        let duplicate = state.observe(nil, at: 1)
        #expect(duplicate == nil)
    }

    @Test func supersededCompletionCannotClearLatestPendingRevision() throws {
        var state = DocumentRefreshState()
        state.start(at: 0)
        let started = state.observe(nil, at: 0.31)
        let first = try #require(started)
        state.invalidate(at: 0.4)
        let blocked = state.observe(nil, at: 0.8)
        #expect(blocked == nil, "only one preparation runs at a time")
        let staleAccepted = state.complete(first, succeeded: true)
        #expect(!staleAccepted)
        let resumed = state.observe(nil, at: 0.8)
        let second = try #require(resumed)
        #expect(second.revision > first.revision)
        let currentAccepted = state.complete(second, succeeded: true)
        #expect(currentAccepted)
        let idle = state.observe(nil, at: 2)
        #expect(idle == nil)
    }

    @Test func failedReadRetriesWithoutAnotherPresenterEvent() throws {
        var state = DocumentRefreshState()
        state.start(at: 0)
        let started = state.observe(nil, at: 0.31)
        let first = try #require(started)
        let failedAccepted = state.complete(first, succeeded: false)
        #expect(failedAccepted)
        let tooSoon = state.observe(nil, at: 1)
        #expect(tooSoon == nil)
        let retried = state.observe(nil, at: 1.31)
        let retry = try #require(retried)
        let recovered = state.complete(retry, succeeded: true)
        #expect(recovered)
        #expect(!state.retryNeeded)
    }

    @Test func detachReattachDoesNotLaunchOverStillRunningPreparation() throws {
        var state = DocumentRefreshState()
        state.start(at: 0)
        let started = state.observe(nil, at: 0.31)
        let first = try #require(started)
        state.stop()
        state.start(at: 1)
        let tooSoon = state.observe(nil, at: 1.31)
        #expect(tooSoon == nil, "the previous preparation still owns the only slot")
        let staleAccepted = state.complete(first, succeeded: true)
        #expect(!staleAccepted)
        let resumed = state.observe(nil, at: 1.32)
        let current = try #require(resumed)
        #expect(current.generation != first.generation)
    }
}
