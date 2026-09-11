import AppKit
import Darwin
import Synchronization

/// Native identity only. Each attached window owns its own immutable presentation.
@objc(ReadOnlyMarkdownNSDocument)
final class ReadOnlyMarkdownNSDocument: NSDocument {
    nonisolated private let payload = Mutex<String>("")
    nonisolated var text: String { payload.withLock { $0 } }

    nonisolated override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool { true }
    nonisolated override func read(from url: URL, ofType typeName: String) throws {
        let text = try MarkdownTextDecoder.text(from: RegularMarkdownRead.data(at: url))
        payload.withLock { $0 = text }
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
    static func data(at url: URL) throws -> Data {
        guard url.isFileURL else { throw MarkdownDocument.Failure.notAReadableFile }
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { Darwin.close(descriptor) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_mode & 0o111 == 0 else { throw MarkdownDocument.Failure.notAReadableFile }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 65536)
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count == 0 { return result }
            if count < 0 {
                if errno == EINTR { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            result.append(contentsOf: buffer.prefix(count))
        }
    }
}
