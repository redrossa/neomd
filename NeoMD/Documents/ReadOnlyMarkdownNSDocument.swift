import AppKit
import Darwin
import Synchronization

/// Native identity only. Each attached window owns its own immutable presentation.
@objc(ReadOnlyMarkdownNSDocument)
final class ReadOnlyMarkdownNSDocument: NSDocument {
    nonisolated private let payload = Mutex<String>("")
    nonisolated var text: String { payload.withLock { $0 } }
    /// Stable identity of this native document for refresh delivery guards.
    nonisolated let bindingID = UUID()
    /// The one refresh pipeline for this document, shared by every viewer of it.
    nonisolated let refresh = DocumentRefreshController()

    nonisolated override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool { true }
    nonisolated override func read(from url: URL, ofType typeName: String) throws {
        let text = try MarkdownTextDecoder.text(from: RegularMarkdownRead.data(at: url))
        payload.withLock { $0 = text }
    }

    // MARK: External change observation

    /// Starts observing for one viewer. The first viewer starts the pipeline; a later
    /// viewer of the same native document catches up without disturbing the others.
    nonisolated func observeExternalChanges(for viewer: UUID,
                                            deliver: @escaping DocumentRefreshController.Delivery) {
        refresh.bind(source)
        refresh.attach(viewer, deliver: deliver)
    }

    nonisolated func stopObservingExternalChanges(for viewer: UUID) {
        refresh.detach(viewer)
    }

    /// Reads through the current presented URL, never an older descriptor, so an
    /// atomic replacement is read as the file that now has this path.
    nonisolated private var source: DocumentRefreshSource {
        DocumentRefreshSource(
            url: { [weak self] in self?.presentedItemURL },
            stamp: { try RegularMarkdownRead.stamp(at: $0) },
            snapshot: { [weak self] url in
                guard let self else { return try RegularMarkdownRead.snapshot(at: url) }
                return try coordinatedSnapshot(at: url)
            },
            publish: { [weak self] text in self?.payload.withLock { $0 = text } })
    }

    /// Read-only coordinated access: `.withoutChanges` never asks another app to save
    /// merely because NeoMD is refreshing. Runs off the main actor, and the claim is
    /// released before the bytes are decoded or rendered.
    nonisolated func coordinatedSnapshot(at url: URL) throws -> RegularMarkdownRead.Snapshot {
        var result: Result<RegularMarkdownRead.Snapshot, any Error>?
        var coordinationFailure: NSError?
        NSFileCoordinator(filePresenter: self).coordinate(
            readingItemAt: url, options: [.withoutChanges], error: &coordinationFailure
        ) { accessor in
            result = Result { try RegularMarkdownRead.snapshot(at: accessor) }
        }
        if let coordinationFailure { throw coordinationFailure }
        guard let result else { throw MarkdownDocument.Failure.notAReadableFile }
        return try result.get()
    }

    // MARK: NSFilePresenter

    /// Enqueue one lightweight invalidation. Reading, decoding and rendering never
    /// happen on the presenter queue, and the superclass reload path is not used.
    nonisolated override func presentedItemDidChange() {
        refresh.invalidate()
    }

    /// Keep the native move behaviour; the pipeline then follows the new identity
    /// because it always resolves the current presented URL.
    nonisolated override func presentedItemDidMove(to newURL: URL) {
        super.presentedItemDidMove(to: newURL)
        refresh.invalidate()
    }

    /// A deleted file must keep its last readable rendering on screen, so this
    /// document deliberately does not take NSDocument's default closing behaviour.
    nonisolated override func accommodatePresentedItemDeletion(
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        refresh.invalidate()
        completionHandler(nil)
    }

    /// There are never unsaved changes to write, so another writer is released
    /// immediately instead of being blocked behind the rejecting save API.
    nonisolated override func savePresentedItemChanges(
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        completionHandler(nil)
    }

    nonisolated override class var autosavesInPlace: Bool { false }
    override class var autosavesDrafts: Bool { false }
    override class var preservesVersions: Bool { false }
    override class var writableTypes: [String] { [] }
    nonisolated override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] { [] }
    override var isDocumentEdited: Bool { false }
    override var hasUnautosavedChanges: Bool { false }
    override func updateChangeCount(_ change: NSDocument.ChangeType) {}
    override func scheduleAutosaving() {}

    nonisolated override func data(ofType typeName: String) throws -> Data { throw MarkdownDocument.Failure.readOnly }
    nonisolated override func fileWrapper(ofType typeName: String) throws -> FileWrapper { throw MarkdownDocument.Failure.readOnly }
    nonisolated override func write(to url: URL, ofType typeName: String) throws { throw MarkdownDocument.Failure.readOnly }
    nonisolated override func write(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, originalContentsURL: URL?) throws { throw MarkdownDocument.Failure.readOnly }
    nonisolated override func writeSafely(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) throws { throw MarkdownDocument.Failure.readOnly }
    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) { completionHandler(MarkdownDocument.Failure.readOnly) }
    override func autosave(withImplicitCancellability: Bool, completionHandler: @escaping (Error?) -> Void) { completionHandler(MarkdownDocument.Failure.readOnly) }
    override func duplicate() throws -> NSDocument { throw MarkdownDocument.Failure.readOnly }
    override func move(to url: URL, completionHandler: ((Error?) -> Void)? = nil) { completionHandler?(MarkdownDocument.Failure.readOnly) }
    override func lock(completionHandler: ((Error?) -> Void)? = nil) { completionHandler?(MarkdownDocument.Failure.readOnly) }
    override func unlock(completionHandler: ((Error?) -> Void)? = nil) { completionHandler?(MarkdownDocument.Failure.readOnly) }
    override func move(completionHandler: ((Bool) -> Void)? = nil) { completionHandler?(false) }
    override func lock(completionHandler: ((Bool) -> Void)? = nil) { completionHandler?(false) }
    override func unlock(completionHandler: ((Bool) -> Void)? = nil) { completionHandler?(false) }
    override func save(_ sender: Any?) {}
    override func saveAs(_ sender: Any?) {}
    override func saveTo(_ sender: Any?) {}
    override func saveToPDF(_ sender: Any?) {}
    override func duplicate(_ sender: Any?) {}
    override func rename(_ sender: Any?) {}
    override func move(_ sender: Any?) {}
    override func moveToUbiquityContainer(_ sender: Any?) {}
    override func lock(_ sender: Any?) {}
    override func unlock(_ sender: Any?) {}
    override func revertToSaved(_ sender: Any?) {}
    override func save(withDelegate delegate: Any?, didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        reject(delegate, selector: didSaveSelector, context: contextInfo)
    }
    override func autosave(withDelegate delegate: Any?, didAutosave didAutosaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        reject(delegate, selector: didAutosaveSelector, context: contextInfo)
    }
    override func duplicate(withDelegate delegate: Any?, didDuplicate didDuplicateSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        reject(delegate, selector: didDuplicateSelector, context: contextInfo)
    }
    override func runModalSavePanel(for saveOperation: NSDocument.SaveOperationType, delegate: Any?, didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        reject(delegate, selector: didSaveSelector, context: contextInfo)
    }
    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, delegate: Any?, didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        reject(delegate, selector: didSaveSelector, context: contextInfo)
    }
    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool { false }
    // Deprecated pre-Swift write entry points are rejected by the companion
    // Objective-C category; Swift makes those superclass overrides unavailable.

    /// NSDocument's public legacy callbacks use this documented four-argument ABI.
    private func reject(_ delegate: Any?, selector: Selector?, context: UnsafeMutableRawPointer?) {
        guard let object = delegate as? NSObject, let selector, object.responds(to: selector),
              let implementation = object.method(for: selector) else { return }
        typealias Callback = @convention(c) (AnyObject, Selector, NSDocument, Bool, UnsafeMutableRawPointer?) -> Void
        unsafeBitCast(implementation, to: Callback.self)(object, selector, self, false, context)
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        // Allow only non-mutating document actions. Reader text commands live on responders.
        item.action == #selector(close)
    }
}

/// Open nonblocking, then validate the opened object, not just a racy path probe.
nonisolated enum RegularMarkdownRead {
    struct Stamp: Equatable, Sendable {
        let device: Int32
        let inode: UInt64
        let size: Int64
        let mode: UInt16
        let modifiedSeconds: Int
        let modifiedNanoseconds: Int
        let changedSeconds: Int
        let changedNanoseconds: Int

        init(_ value: stat) {
            device = value.st_dev
            inode = value.st_ino
            size = value.st_size
            mode = value.st_mode
            modifiedSeconds = value.st_mtimespec.tv_sec
            modifiedNanoseconds = value.st_mtimespec.tv_nsec
            changedSeconds = value.st_ctimespec.tv_sec
            changedNanoseconds = value.st_ctimespec.tv_nsec
        }
    }

    struct Snapshot: Sendable {
        let data: Data
        let stamp: Stamp
    }

    enum SnapshotFailure: Error { case unstable }

    /// Samples the object that currently has this path. `Darwin.stat` is shadowed by
    /// the `stat` struct of the same name, so the sample is taken through a
    /// short-lived nonblocking descriptor, which also validates the file kind.
    static func stamp(at url: URL) throws -> Stamp {
        guard url.isFileURL else { throw MarkdownDocument.Failure.notAReadableFile }
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { Darwin.close(descriptor) }
        return Stamp(try metadata(of: descriptor))
    }

    private static func metadata(of descriptor: Int32) throws -> stat {
        var value = stat()
        guard fstat(descriptor, &value) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        try validate(value)
        return value
    }

    private static func validate(_ metadata: stat) throws {
        guard metadata.st_mode & S_IFMT == S_IFREG, metadata.st_mode & 0o111 == 0 else {
            throw MarkdownDocument.Failure.notAReadableFile
        }
    }

    /// Opening can race the writer this app exists to watch. A bounded retry keeps a
    /// momentary atomic replacement from failing the open, and never returns bytes
    /// that were read across a write.
    static func data(at url: URL) throws -> Data {
        for _ in 0..<2 {
            do { return try snapshot(at: url).data }
            catch is SnapshotFailure { continue }
        }
        return try snapshot(at: url).data
    }

    /// Fresh read-only descriptor on every attempt, including atomic replacement.
    /// The optional seam permits deterministic owned-file race regression tests.
    static func snapshot(at url: URL, afterRead: (() throws -> Void)? = nil) throws -> Snapshot {
        guard url.isFileURL else { throw MarkdownDocument.Failure.notAReadableFile }
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { Darwin.close(descriptor) }
        let before = Stamp(try metadata(of: descriptor))
        guard try stamp(at: url) == before else { throw SnapshotFailure.unstable }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 65536)
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            result.append(contentsOf: buffer.prefix(count))
        }
        try afterRead?()
        guard Stamp(try metadata(of: descriptor)) == before, try stamp(at: url) == before else {
            throw SnapshotFailure.unstable
        }
        return Snapshot(data: result, stamp: before)
    }
}
