//
//  ReadingHistoryService.swift
//  NeoMD
//

import Foundation

/// Main-actor coordination for the private reading history.
///
/// Owns the bounded store, the process-wide observation serials and one cached
/// capture per viewer. Store operations are queued in order, so a clear can never be
/// overtaken by a capture that was accepted before it. Reading is never blocked by
/// history: every failure is quiet, and no history work touches a document's bytes or
/// modification time.
final class ReadingHistoryService {

    private let store: ReadingHistoryStore
    private let allocator = ReadingHistorySerialAllocator()
    private var captures: [UUID: ReadingHistoryCapture] = [:]
    private var work: Task<Void, Never>?
    /// The clear epoch. Captures and restorations from an older epoch are rejected.
    private(set) var epoch = 0

    init(store: ReadingHistoryStore = ReadingHistoryStore()) {
        self.store = store
    }

    /// The production service.
    ///
    /// A hosted non-interaction test process gets inert storage, so merely launching
    /// the test host can never read, write or clear the real user's reading history.
    /// An unavailable application-support location degrades to inert storage instead
    /// of blocking a readable document.
    static func production() -> ReadingHistoryService {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              NSClassFromString("XCTestCase") == nil,
              let storage = try? ReadingHistoryFileStorage.applicationSupport() else {
            return ReadingHistoryService()
        }
        return ReadingHistoryService(store: ReadingHistoryStore(storage: storage))
    }

    /// The remembered position for a document, ready for the shared remapper.
    func restoration(for url: URL) async -> DocumentContentLocator? {
        let requested = epoch
        await work?.value
        let stored = await store.position(for: url)
        // A clear that landed while this load was in flight wins.
        guard requested == epoch else { return nil }
        return stored?.restored
    }

    /// Accepts one viewer's settled reading position.
    ///
    /// An unchanged position from an idle viewer allocates no serial and is not a new
    /// observation, so it cannot outrank a newer position read elsewhere.
    func observe(_ locator: DocumentContentLocator, url: URL, session: UUID) {
        let projected = ReadingHistoryLocator(locator)
        var capture = captures[session] ?? ReadingHistoryCapture()
        defer { captures[session] = capture }
        guard capture.isNewObservation(url: url, locator: projected, epoch: epoch) else { return }
        let observation = ReadingHistoryObservation(url: url, locator: projected,
                                                    serial: allocator.next(), epoch: epoch)
        capture.accept(observation)
        enqueue { await $0.record(observation) }
    }

    /// Flushes one viewer's cached capture with its ORIGINAL serial, so closing an
    /// older idle reader cannot clobber a more recently read position.
    func flush(session: UUID) {
        guard let observation = captures[session]?.flushed(epoch: epoch) else { return }
        enqueue { await $0.record(observation) }
    }

    func flushAll() {
        for session in captures.keys { flush(session: session) }
    }

    func forget(session: UUID) {
        captures.removeValue(forKey: session)
    }

    /// Forgets every remembered position and rejects pre-clear work still in flight.
    /// Open readers keep their current place; no reader is closed or moved.
    func clear() {
        captures.removeAll()
        epoch += 1
        let target = epoch
        enqueue { await $0.clear(epoch: target) }
    }

    /// Awaits the queued work and the writes it scheduled, for a successful quit.
    func drain() async {
        await work?.value
        await store.flush()
    }

    func issue() async -> ReadingHistoryIssue? {
        await work?.value
        return await store.issue
    }

    /// Serializes store operations in the order they were accepted.
    private func enqueue(_ operation: @escaping @Sendable (ReadingHistoryStore) async -> Void) {
        let store = store
        let previous = work
        work = Task {
            await previous?.value
            await operation(store)
        }
    }
}
