//
//  ReadingHistoryStoreTests.swift
//  NeoMDTests
//

import CoreGraphics
import Foundation
import Testing
@testable import NeoMD

/// Owned-storage coverage for the private position store and its main-actor service.
///
/// Every test uses its own temporary directory or an in-memory substitute; the real
/// user's application-support history, recent-document list and defaults are never
/// read, written or cleared. Recreating a store instance is a durable round trip, not
/// a real relaunch: native reopen, relaunch, quit and menu behavior stay unverified.
struct ReadingHistoryStoreTests {

    // MARK: - Owned storage substitutes

    final class OwnedStorage: ReadingHistoryStorage, @unchecked Sendable {
        private let lock = NSLock()
        private var payloads: [Data] = []
        private var stored: Data?
        private var gateArmed: Bool
        private var gateReleased = false
        private var failSaves: Bool
        private var loadError: Error?

        init(initial: Data? = nil, gateFirstSave: Bool = false,
             failSaves: Bool = false, loadError: Error? = nil) {
            self.stored = initial
            self.gateArmed = gateFirstSave
            self.failSaves = failSaves
            self.loadError = loadError
        }

        func load(maximumBytes: Int) async throws -> Data? {
            if let failure = lock.withLock({ loadError }) { throw failure }
            let data = lock.withLock { stored }
            if let data, data.count > maximumBytes {
                throw ReadingHistoryStorageError.tooLarge(data.count)
            }
            return data
        }

        func save(_ data: Data) async throws {
            let waits: Bool = lock.withLock {
                guard gateArmed, !gateReleased else { return false }
                gateArmed = false
                return true
            }
            if waits {
                var spins = 0
                while !lock.withLock({ gateReleased }), spins < 10_000 {
                    await Task.yield()
                    spins += 1
                }
            }
            if lock.withLock({ failSaves }) { throw CocoaError(.fileWriteNoPermission) }
            lock.withLock {
                payloads.append(data)
                stored = data
            }
        }

        func releaseGate() { lock.withLock { gateReleased = true } }
        var savedPayloads: [Data] { lock.withLock { payloads } }
        var current: Data? { lock.withLock { stored } }
    }

    /// A durable locator for `text`, produced by the shared capture implementation.
    static func locator(_ text: String, fraction: Double = 0.5) -> ReadingHistoryLocator {
        let index = ReadingHistoryLocatorTests.index([text])
        guard let entry = index.entries.first,
              let captured = DocumentContentLocator.capture(
                anchor: .block(id: entry.id, fraction: CGFloat(fraction)), in: index) else {
            return .edge(.top)
        }
        return ReadingHistoryLocator(captured)
    }

    private static func observation(_ url: URL, _ text: String,
                                    serial: Int, epoch: Int = 0) -> ReadingHistoryObservation {
        ReadingHistoryObservation(url: url, locator: locator(text), serial: serial, epoch: epoch)
    }

    static func ownedDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeoMD-History-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    // MARK: - Store

    @Test func roundTripRestoresDistinctSameBasenameURLsAcrossStoreInstances() async throws {
        let root = try Self.ownedDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ReadingHistoryFileStorage(directory: root.appendingPathComponent("history"))

        let alpha = root.appendingPathComponent("alpha/Report.MD")
        let beta = root.appendingPathComponent("beta/Report.MD")
        #expect(alpha.lastPathComponent == beta.lastPathComponent)

        let store = ReadingHistoryStore(storage: storage)
        #expect(await store.record(Self.observation(alpha, "amber", serial: 1)))
        #expect(await store.record(Self.observation(beta, "cobalt", serial: 2)))
        await store.flush()

        let reopened = ReadingHistoryStore(storage: storage)
        #expect(await reopened.position(for: alpha) == Self.locator("amber"))
        #expect(await reopened.position(for: beta) == Self.locator("cobalt"))
        #expect(await reopened.position(for: alpha) != Self.locator("cobalt"))
        #expect(await reopened.keys().count == 2)
        #expect(await reopened.issue == nil)

        // Private storage only: nothing lands beside the documents.
        let entries = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
        #expect(entries == ["history"])
        #expect(FileManager.default.fileExists(atPath: storage.fileURL.path))
    }

    @Test func normalizedKeysRetainCaseUnicodeAndLocation() {
        let lower = URL(fileURLWithPath: "/tmp/notes/report.md")
        let upper = URL(fileURLWithPath: "/tmp/notes/Report.MD")
        #expect(ReadingHistoryKey.normalized(lower) != ReadingHistoryKey.normalized(upper))

        let unicode = URL(fileURLWithPath: "/tmp/café 日本語/Report.MD")
        let key = ReadingHistoryKey.normalized(unicode)
        #expect(key != nil)
        #expect(URL(string: key ?? "")?.path == unicode.path)

        // Dot components collapse to one identity; symbolic links are not resolved.
        #expect(ReadingHistoryKey.normalized(URL(fileURLWithPath: "/tmp/a/../notes/./report.md"))
            == ReadingHistoryKey.normalized(lower))

        // Distinct folders sharing a basename stay distinct.
        #expect(ReadingHistoryKey.normalized(URL(fileURLWithPath: "/tmp/alpha/Report.MD"))
            != ReadingHistoryKey.normalized(URL(fileURLWithPath: "/tmp/beta/Report.MD")))

        // Rejected: non-file schemes, query and fragment keys, oversized paths.
        #expect(ReadingHistoryKey.normalized(key: "https://example.com/a.md") == nil)
        #expect(ReadingHistoryKey.normalized(key: "file:///tmp/a.md?x=1") == nil)
        #expect(ReadingHistoryKey.normalized(key: "file:///tmp/a.md#checkpoint") == nil)
        #expect(ReadingHistoryKey.normalized(key: "not a url at all") == nil)
        let long = "/tmp/" + String(repeating: "d", count: ReadingHistoryKey.maximumBytes)
        #expect(ReadingHistoryKey.normalized(URL(fileURLWithPath: long)) == nil)
    }

    @Test func boundedRecordsEvictOldestAcceptedCapturesDeterministically() async {
        let storage = OwnedStorage()
        let store = ReadingHistoryStore(storage: storage)
        let total = ReadingHistoryStore.maximumRecords + 1

        for index in 0..<total {
            let url = URL(fileURLWithPath: "/tmp/history/doc-\(index).md")
            #expect(await store.record(Self.observation(url, "body \(index)", serial: index + 1)))
        }
        await store.flush()

        #expect(await store.keys().count == ReadingHistoryStore.maximumRecords)
        // The oldest accepted capture is the one evicted.
        #expect(await store.position(for: URL(fileURLWithPath: "/tmp/history/doc-0.md")) == nil)
        #expect(await store.position(for: URL(fileURLWithPath: "/tmp/history/doc-1.md")) != nil)

        #expect((storage.current?.count ?? 0) <= ReadingHistoryStore.maximumBytes)
        let envelope = try? JSONDecoder().decode(ReadingHistoryEnvelope.self,
                                                 from: storage.current ?? Data())
        #expect(envelope?.version == ReadingHistoryEnvelope.currentVersion)
        #expect(envelope?.records.count == ReadingHistoryStore.maximumRecords)
    }

    @Test func oversizedStoredHistoryIsRejectedBeforeItIsDecoded() async {
        let oversized = Data(repeating: UInt8(ascii: "{"), count: ReadingHistoryStore.maximumBytes + 1)
        let store = ReadingHistoryStore(storage: OwnedStorage(initial: oversized))
        #expect(await store.position(for: URL(fileURLWithPath: "/tmp/a.md")) == nil)
        #expect(await store.issue == .restorationUnavailable)
    }

    @Test func clearRejectsPreClearWorkAndAllowsNewReading() async {
        let storage = OwnedStorage()
        let store = ReadingHistoryStore(storage: storage)
        let url = URL(fileURLWithPath: "/tmp/history/cleared.md")
        #expect(await store.record(Self.observation(url, "before", serial: 5)))
        await store.flush()

        let staleEpoch = await store.epoch
        let epoch = await store.clear(epoch: staleEpoch + 1)
        #expect(epoch == staleEpoch + 1)
        #expect(await store.position(for: url) == nil)

        // A delayed pre-clear capture, and an idle reader's close flush, cannot resurrect.
        #expect(!(await store.record(Self.observation(url, "before", serial: 6, epoch: staleEpoch))))
        #expect(await store.position(for: url) == nil)

        // Genuinely new reading after the clear is remembered again.
        #expect(await store.record(Self.observation(url, "after", serial: 7, epoch: epoch)))
        await store.flush()
        #expect(await store.position(for: url) == Self.locator("after"))

        let reopened = ReadingHistoryStore(storage: storage)
        #expect(await reopened.position(for: url) == Self.locator("after"))
        #expect(await reopened.keys().count == 1)
    }

    @Test func lateWriteCompletionNeverRegressesStoredState() async {
        let storage = OwnedStorage(gateFirstSave: true)
        let store = ReadingHistoryStore(storage: storage)
        let first = URL(fileURLWithPath: "/tmp/history/first.md")
        let second = URL(fileURLWithPath: "/tmp/history/second.md")

        #expect(await store.record(Self.observation(first, "one", serial: 10)))
        #expect(await store.record(Self.observation(second, "two", serial: 11)))
        storage.releaseGate()
        await store.flush()

        // Writes are serialized and coalesced; the durable payload is the newest state.
        let counts = storage.savedPayloads.compactMap {
            try? JSONDecoder().decode(ReadingHistoryEnvelope.self, from: $0).records.count
        }
        #expect(!counts.isEmpty)
        #expect(counts == counts.sorted())
        #expect(counts.last == 2)
        #expect(await store.storedRevision >= 2)

        let reopened = ReadingHistoryStore(storage: storage)
        #expect(await reopened.position(for: first) == Self.locator("one"))
        #expect(await reopened.position(for: second) == Self.locator("two"))
    }

    @Test func staleSerialsAndUnusableInputAreRejected() async {
        let store = ReadingHistoryStore(storage: OwnedStorage())
        let url = URL(fileURLWithPath: "/tmp/history/serials.md")

        #expect(await store.record(Self.observation(url, "newer", serial: 11)))
        #expect(!(await store.record(Self.observation(url, "older", serial: 10))))
        #expect(!(await store.record(Self.observation(url, "same", serial: 11))))
        #expect(await store.position(for: url) == Self.locator("newer"))

        let malformed = ReadingHistoryObservation(
            url: url, locator: ReadingHistoryLocator(digest: 7, ordinal: 4, total: 2),
            serial: 99, epoch: 0)
        #expect(!(await store.record(malformed)))

        let remote = ReadingHistoryObservation(
            url: URL(string: "https://example.com/a.md") ?? url,
            locator: Self.locator("remote"), serial: 99, epoch: 0)
        #expect(!(await store.record(remote)))
        #expect(await store.position(for: url) == Self.locator("newer"))
    }

    @Test func invalidHistoryNeverBlocksReadingAndPreservesValidSiblings() async throws {
        let valid = URL(fileURLWithPath: "/tmp/history/valid.md")
        let good = ReadingHistoryRecord(key: ReadingHistoryKey.normalized(valid) ?? "",
                                        locator: Self.locator("kept"), serial: 4)
        let corrupt = [
            ReadingHistoryRecord(key: "https://example.com/a.md", locator: Self.locator("x"), serial: 1),
            ReadingHistoryRecord(key: "file:///tmp/history/q.md?x=1", locator: Self.locator("x"), serial: 1),
            ReadingHistoryRecord(key: ReadingHistoryKey.normalized(
                URL(fileURLWithPath: "/tmp/history/bad-ordinal.md")) ?? "",
                locator: ReadingHistoryLocator(digest: 7, ordinal: 9, total: 2), serial: 1),
            ReadingHistoryRecord(key: ReadingHistoryKey.normalized(
                URL(fileURLWithPath: "/tmp/history/negative.md")) ?? "",
                locator: Self.locator("x"), serial: -1),
            good
        ]
        let mixed = try JSONEncoder().encode(ReadingHistoryEnvelope(records: corrupt))
        let store = ReadingHistoryStore(storage: OwnedStorage(initial: mixed))
        #expect(await store.position(for: valid) == Self.locator("kept"))
        #expect(await store.keys().count == 1)
        #expect(await store.issue == .restorationUnavailable)

        // Unsupported versions, undecodable bytes and unreadable storage start empty.
        let future = try JSONEncoder().encode(ReadingHistoryEnvelope(records: [good], version: 99))
        let unsupported = ReadingHistoryStore(storage: OwnedStorage(initial: future))
        #expect(await unsupported.position(for: valid) == nil)
        #expect(await unsupported.issue == .restorationUnavailable)

        let garbage = ReadingHistoryStore(storage: OwnedStorage(initial: Data("not json".utf8)))
        #expect(await garbage.position(for: valid) == nil)
        #expect(await garbage.issue == .restorationUnavailable)

        let unreadable = ReadingHistoryStore(
            storage: OwnedStorage(loadError: CocoaError(.fileReadNoPermission)))
        #expect(await unreadable.position(for: valid) == nil)
        #expect(await unreadable.issue == .restorationUnavailable)

        // Failing saves report an actionable issue instead of losing the reader.
        let unwritable = ReadingHistoryStore(storage: OwnedStorage(failSaves: true))
        #expect(await unwritable.record(Self.observation(valid, "kept", serial: 1)))
        await unwritable.flush()
        #expect(await unwritable.issue == .savingUnavailable)
        #expect(await unwritable.position(for: valid) == Self.locator("kept"))
        #expect(!ReadingHistoryIssue.savingUnavailable.message.isEmpty)
        #expect(!ReadingHistoryIssue.restorationUnavailable.message.isEmpty)
    }

    @Test func inertStorageIsTheDefaultSoHostedTestsTouchNoUserHistory() async {
        let store = ReadingHistoryStore()
        let url = URL(fileURLWithPath: "/tmp/history/inert.md")
        #expect(await store.record(Self.observation(url, "body", serial: 1)))
        await store.flush()
        #expect(await store.position(for: url) == Self.locator("body"))

        // Nothing is durable: a new store over inert storage starts empty.
        #expect(await ReadingHistoryStore().position(for: url) == nil)
    }

    @Test @MainActor func productionServiceUsesInertStorageInAHostedTestProcess() async {
        // This unit process is hosted by the app, so the production factory must not
        // reach the real user's application-support history.
        let service = ReadingHistoryService.production()
        let url = URL(fileURLWithPath: "/tmp/history/production-guard.md")
        #expect(await service.restoration(for: url) == nil)
    }

    @Test func historyOperationsLeaveOwnedSourceBytesAndModificationTimeUnchanged() async throws {
        let root = try Self.ownedDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Report.MD")
        let markdown = "# Owned\n\nThe amber checkpoint paragraph stays byte-identical.\n"
        try Data(markdown.utf8).write(to: source)
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: fixedDate],
                                              ofItemAtPath: source.path)

        let bytes = try Data(contentsOf: source)
        let modified = try FileManager.default
            .attributesOfItem(atPath: source.path)[.modificationDate] as? Date

        let storage = ReadingHistoryFileStorage(directory: root.appendingPathComponent("history"))
        let store = ReadingHistoryStore(storage: storage)
        let rendered = MarkdownBlockRenderer.render(from: markdown, documentURL: source)
        let index = DocumentContentIndex(rendered)
        let entry = try #require(index.entries.last)
        let captured = try #require(DocumentContentLocator.capture(
            anchor: .block(id: entry.id, fraction: 0.4), in: index))
        #expect(await store.record(ReadingHistoryObservation(
            url: source, locator: ReadingHistoryLocator(captured), serial: 1, epoch: 0)))
        await store.flush()
        let reopened = ReadingHistoryStore(storage: storage)
        let restored = await reopened.position(for: source)
        #expect(restored != nil)
        _ = restored?.restored?.resolve(in: index)

        #expect(try Data(contentsOf: source) == bytes)
        let after = try FileManager.default
            .attributesOfItem(atPath: source.path)[.modificationDate] as? Date
        #expect(after == modified)

        // No sidecar, temporary file or extended attribute lands beside the document.
        let siblings = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
        #expect(siblings == ["Report.MD", "history"])
    }

    // MARK: - Observation serials and the main-actor service

    @Test @MainActor func laterCaptureWinsRegardlessOfCloseOrder() async {
        let allocator = ReadingHistorySerialAllocator()
        let url = URL(fileURLWithPath: "/tmp/history/shared.md")
        var readerA = ReadingHistoryCapture()
        var readerB = ReadingHistoryCapture()

        #expect(readerA.isNewObservation(url: url, locator: Self.locator("early"), epoch: 0))
        readerA.accept(ReadingHistoryObservation(url: url, locator: Self.locator("early"),
                                                 serial: allocator.next(), epoch: 0))
        #expect(readerB.isNewObservation(url: url, locator: Self.locator("later"), epoch: 0))
        readerB.accept(ReadingHistoryObservation(url: url, locator: Self.locator("later"),
                                                 serial: allocator.next(), epoch: 0))
        #expect(readerA.observation?.serial == 1)
        #expect(readerB.observation?.serial == 2)

        // An idle reader republishing the same geometry is not a new observation, so
        // no serial is allocated for it.
        #expect(!readerA.isNewObservation(url: url, locator: Self.locator("early"), epoch: 0))
        // A malformed capture is never a new observation either.
        #expect(!readerA.isNewObservation(
            url: url, locator: ReadingHistoryLocator(digest: 7, ordinal: 4, total: 1), epoch: 0))
        // A stale epoch cannot resurrect a cleared position.
        #expect(!readerA.isNewObservation(url: url, locator: Self.locator("early"), epoch: -1))
        // Automatic remapping preserves the original serial.
        #expect(readerA.remap(Self.locator("early", fraction: 0.51))?.serial == 1)

        let store = ReadingHistoryStore(storage: OwnedStorage())
        // Reader B closes first, then the older reader A: original serials decide.
        if let flushed = readerB.flushed(epoch: 0) { #expect(await store.record(flushed)) }
        if let flushed = readerA.flushed(epoch: 0) { #expect(!(await store.record(flushed))) }
        #expect(await store.position(for: url) == Self.locator("later"))

        // A clear epoch invalidates a cached capture rather than resurrecting it.
        #expect(readerA.flushed(epoch: 1) == nil)
        readerB.invalidate()
        #expect(readerB.flushed(epoch: 0) == nil)
    }

    @Test @MainActor func serviceRemembersTheLastPlaceReadAndHonoursClear() async throws {
        let root = try Self.ownedDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ReadingHistoryFileStorage(directory: root.appendingPathComponent("history"))
        let service = ReadingHistoryService(store: ReadingHistoryStore(storage: storage))

        let url = URL(fileURLWithPath: "/tmp/history/service.md")
        let index = ReadingHistoryLocatorTests.index(["Intro", "Target", "End"])
        let early = try #require(DocumentContentLocator.capture(
            anchor: .block(id: index.entries[0].id, fraction: 0.1), in: index))
        let later = try #require(DocumentContentLocator.capture(
            anchor: .block(id: index.entries[1].id, fraction: 0.6), in: index))
        let viewerA = UUID()
        let viewerB = UUID()

        service.observe(early, url: url, session: viewerA)
        service.observe(later, url: url, session: viewerB)
        // Idle republication from the older viewer must not win.
        service.observe(early, url: url, session: viewerA)
        service.flush(session: viewerB)
        service.flush(session: viewerA)
        await service.drain()

        let restored = try #require(await service.restoration(for: url))
        #expect(restored.resolve(in: index) == later.resolve(in: index))

        // A separate service over the same owned storage restores the same place.
        let reopened = ReadingHistoryService(store: ReadingHistoryStore(storage: storage))
        #expect(try #require(await reopened.restoration(for: url)).resolve(in: index)
            == later.resolve(in: index))

        // Clearing forgets everything and rejects the pre-clear cached captures.
        let epoch = service.epoch
        service.clear()
        #expect(service.epoch == epoch + 1)
        service.flush(session: viewerB)
        await service.drain()
        #expect(await service.restoration(for: url) == nil)

        // Genuinely new reading after a clear is remembered again.
        service.observe(early, url: url, session: viewerA)
        await service.drain()
        #expect(try #require(await service.restoration(for: url)).resolve(in: index)
            == early.resolve(in: index))
    }
}
