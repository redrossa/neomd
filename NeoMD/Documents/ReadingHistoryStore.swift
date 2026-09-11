//
//  ReadingHistoryStore.swift
//  NeoMD
//

import Foundation

/// The normalized identity of a remembered document.
///
/// Identity is the complete file URL, so two documents sharing a basename in
/// different folders are always separate entries. Case and Unicode are preserved and
/// symbolic links are never resolved: this deliberately identifies a location, not an
/// inode, so an atomic replacement keeps its history.
nonisolated enum ReadingHistoryKey {

    /// Generous ceiling that still refuses unbounded stored path data.
    static let maximumBytes = 16 * 1024

    static func normalized(_ url: URL) -> String? {
        guard url.isFileURL, url.query == nil, url.fragment == nil, !url.path.isEmpty else {
            return nil
        }
        let key = url.standardizedFileURL.absoluteString
        guard !key.isEmpty, key.utf8.count <= maximumBytes else { return nil }
        return key
    }

    static func normalized(key: String) -> String? {
        guard let url = URL(string: key) else { return nil }
        return normalized(url)
    }
}

/// One remembered document position.
nonisolated struct ReadingHistoryRecord: Codable, Equatable, Sendable {
    let key: String
    let locator: ReadingHistoryLocator
    /// The observation serial of the capture that produced this position. The greatest
    /// serial wins, so the last place actually read wins over the last reader closed.
    let serial: Int
}

/// The versioned envelope written to private storage.
nonisolated struct ReadingHistoryEnvelope: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let records: [ReadingHistoryRecord]

    init(records: [ReadingHistoryRecord], version: Int = currentVersion) {
        self.version = version
        self.records = records
    }
}

/// A readable, actionable description of a history problem. Reading itself always
/// continues; history is never allowed to block a readable document.
nonisolated enum ReadingHistoryIssue: Equatable, Sendable {
    case restorationUnavailable
    case savingUnavailable

    var message: String {
        switch self {
        case .restorationUnavailable:
            "NeoMD couldn’t use your saved reading positions. This document opens at the beginning."
        case .savingUnavailable:
            "NeoMD can’t save your reading position right now. Reading is unaffected."
        }
    }
}

nonisolated enum ReadingHistoryStorageError: Error, Equatable {
    /// The stored history exceeds the supported size and is not decoded.
    case tooLarge(Int)
}

/// The injected private storage boundary. Production uses an application-support file;
/// tests use owned temporary directories or memory, never the real user's history.
nonisolated protocol ReadingHistoryStorage: Sendable {
    func load(maximumBytes: Int) async throws -> Data?
    func save(_ data: Data) async throws
}

/// The default dependency: remembers nothing and writes nothing. Model initializers
/// and hosted unit processes use it so merely launching a test host cannot read or
/// write the real user's reading history.
nonisolated struct ReadingHistoryInertStorage: ReadingHistoryStorage {
    init() {}
    func load(maximumBytes: Int) async throws -> Data? { nil }
    func save(_ data: Data) async throws {}
}

/// Private application-support storage.
///
/// Nothing from the Markdown source is written here: no document bytes, no excerpts,
/// no sidecars, no extended attributes and no security-scoped bookmarks. Only the
/// normalized URL, the bounded locator and ordering metadata are stored.
nonisolated struct ReadingHistoryFileStorage: ReadingHistoryStorage {
    static let fileName = "reading-history-v1.json"

    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    /// The production location, under the app's own application-support directory.
    static func applicationSupport(
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "io.neomd.NeoMD",
        fileManager: FileManager = .default
    ) throws -> ReadingHistoryFileStorage {
        let root = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                       appropriateFor: nil, create: true)
        return ReadingHistoryFileStorage(directory: root.appendingPathComponent(bundleIdentifier,
                                                                               isDirectory: true))
    }

    var fileURL: URL { directory.appendingPathComponent(Self.fileName, isDirectory: false) }

    func load(maximumBytes: Int) async throws -> Data? {
        let url = fileURL
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return nil }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maximumBytes else { throw ReadingHistoryStorageError.tooLarge(size) }
        return try Data(contentsOf: url)
    }

    func save(_ data: Data) async throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let url = fileURL
        try data.write(to: url, options: [.atomic])
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

/// The bounded private reading-position store.
///
/// Writes are serialized and coalesced, and a late write can never regress the stored
/// revision. Clearing increments an epoch so delayed pre-clear captures, restorations
/// and writes are rejected without disturbing any open reader.
actor ReadingHistoryStore {

    static let maximumRecords = 100
    static let maximumBytes = 1 << 20

    private let storage: ReadingHistoryStorage
    private var records: [String: ReadingHistoryRecord] = [:]
    private var isLoaded = false
    private var epochValue = 0
    private var revision = 0
    private var writtenRevision = 0
    private var writer: Task<Void, Never>?
    private var issueValue: ReadingHistoryIssue?

    init(storage: ReadingHistoryStorage = ReadingHistoryInertStorage()) {
        self.storage = storage
    }

    /// The current clear epoch. A capture or restoration carrying an older epoch is
    /// rejected, so clearing cannot be undone by delayed work already in flight.
    var epoch: Int { epochValue }

    var issue: ReadingHistoryIssue? { issueValue }

    /// The revision durably handed to storage; never regresses.
    var storedRevision: Int { writtenRevision }

    /// The remembered position for a document, or `nil` when there is none.
    func position(for url: URL) async -> ReadingHistoryLocator? {
        guard let key = ReadingHistoryKey.normalized(url) else { return nil }
        await loadIfNeeded()
        return records[key]?.locator
    }

    func keys() async -> [String] {
        await loadIfNeeded()
        return records.keys.sorted()
    }

    /// Accepts a genuinely newer observation for one document.
    ///
    /// Returns `false` for a stale epoch, an unusable URL, a malformed locator, or a
    /// serial that does not exceed the serial already remembered for that document.
    @discardableResult
    func record(_ observation: ReadingHistoryObservation) async -> Bool {
        guard observation.epoch == epochValue,
              observation.locator.isWellFormed,
              let key = ReadingHistoryKey.normalized(observation.url) else { return false }
        await loadIfNeeded()
        guard observation.epoch == epochValue else { return false }
        if let existing = records[key], existing.serial >= observation.serial { return false }
        records[key] = ReadingHistoryRecord(key: key, locator: observation.locator,
                                            serial: observation.serial)
        trim()
        markChanged()
        return true
    }

    /// Forgets every remembered position and adopts the caller's new epoch, so every
    /// pre-clear capture still in flight is rejected. Open readers keep their current
    /// place; only the private history is emptied.
    @discardableResult
    func clear(epoch: Int) -> Int {
        epochValue = max(epochValue + 1, epoch)
        records.removeAll()
        // Nothing on disk may be restored after a clear, so a later lazy load is moot.
        isLoaded = true
        issueValue = nil
        markChanged()
        return epochValue
    }

    /// Awaits every write scheduled before this call.
    func flush() async {
        await writer?.value
    }

    // MARK: - Loading

    private func loadIfNeeded() async {
        guard !isLoaded else { return }
        isLoaded = true
        // A clear that lands while this load is in flight must win: its epoch supersedes
        // everything read from disk beforehand.
        let epochAtStart = epochValue
        do {
            let loaded = try await storage.load(maximumBytes: Self.maximumBytes)
            guard epochAtStart == epochValue else { return }
            guard let data = loaded else { return }
            guard data.count <= Self.maximumBytes else {
                issueValue = .restorationUnavailable
                return
            }
            let envelope = try JSONDecoder().decode(ReadingHistoryEnvelope.self, from: data)
            guard envelope.version == ReadingHistoryEnvelope.currentVersion else {
                issueValue = .restorationUnavailable
                return
            }
            var accepted: [String: ReadingHistoryRecord] = [:]
            var rejected = false
            for stored in envelope.records {
                guard let key = ReadingHistoryKey.normalized(key: stored.key),
                      stored.serial >= 0,
                      stored.locator.isWellFormed else {
                    rejected = true
                    continue
                }
                if let existing = accepted[key], existing.serial >= stored.serial { continue }
                accepted[key] = ReadingHistoryRecord(key: key, locator: stored.locator,
                                                     serial: stored.serial)
            }
            records = accepted
            if rejected { issueValue = .restorationUnavailable }
            trim()
        } catch {
            // Unreadable or unsupported history never blocks a readable document.
            guard epochAtStart == epochValue else { return }
            issueValue = .restorationUnavailable
        }
    }

    // MARK: - Bounds

    /// Retention order: newest accepted capture first, URL as the final tie-break.
    private func retentionOrder() -> [ReadingHistoryRecord] {
        records.values.sorted { lhs, rhs in
            if lhs.serial != rhs.serial { return lhs.serial > rhs.serial }
            return lhs.key < rhs.key
        }
    }

    private func trim() {
        var ordered = retentionOrder()
        if ordered.count > Self.maximumRecords {
            ordered.removeLast(ordered.count - Self.maximumRecords)
        }
        while !ordered.isEmpty, encodedSize(of: ordered) > Self.maximumBytes {
            ordered.removeLast()
        }
        guard ordered.count != records.count else { return }
        records = Dictionary(uniqueKeysWithValues: ordered.map { ($0.key, $0) })
    }

    private func encodedSize(of ordered: [ReadingHistoryRecord]) -> Int {
        encoded(ordered)?.count ?? 0
    }

    private func encoded(_ ordered: [ReadingHistoryRecord]) -> Data? {
        try? JSONEncoder().encode(ReadingHistoryEnvelope(records: ordered))
    }

    // MARK: - Serialized writes

    private func markChanged() {
        revision += 1
        let previous = writer
        writer = Task { [weak self] in
            await previous?.value
            await self?.write()
        }
    }

    private func write() async {
        // Coalesced: several accepted captures between writes produce one write.
        guard revision > writtenRevision else { return }
        let target = revision
        guard let data = encoded(retentionOrder()) else {
            issueValue = .savingUnavailable
            return
        }
        do {
            try await storage.save(data)
            // A late completion can never lower the durable revision.
            writtenRevision = max(writtenRevision, target)
            if issueValue == .savingUnavailable { issueValue = nil }
        } catch {
            issueValue = .savingUnavailable
        }
    }
}
