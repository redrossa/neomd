import AppKit
import Darwin
import Testing
import Synchronization
@testable import NeoMD

struct NativeNavigationTests {
    @MainActor private func input(_ name: String) -> PreparedReadingDocument {
        let url = URL(fileURLWithPath: "/tmp/\(name).md")
        return PreparedReadingDocument(text: name, fileURL: url,
            rendered: MarkdownBlockRenderer.render(from: name, documentURL: url))
    }

    @Test func batchPolicyRejectsInsteadOfSilentlyChoosingOrOpeningExtraReaders() throws {
        let first = URL(fileURLWithPath: "/tmp/a.md")
        let second = URL(fileURLWithPath: "/tmp/b.MD")
        let other = URL(fileURLWithPath: "/tmp/other.txt")
        #expect(try MarkdownDropRouting.singleFile(from: [other, first]) == first)
        #expect(throws: MarkdownDropRouting.Failure.multiple) {
            try MarkdownDropRouting.singleFile(from: [first, second])
        }
        #expect(throws: MarkdownDropRouting.Failure.empty) {
            try MarkdownDropRouting.singleFile(from: [other])
        }
    }

    @Test @MainActor func imageRetryRetriesOnlyDeniedImagesWithoutGrantCallback() async {
        let attempts = Mutex(0)
        let denied = URL(fileURLWithPath: "/owned-test/denied.png")
        let missing = URL(fileURLWithPath: "/owned-test/missing.png")
        let store = MarkdownImageStore { url in
            attempts.withLock { $0 += 1 }
            return .unavailable(url == denied ? .inaccessible : .missing)
        }
        store.load(denied)
        store.load(missing)
        while store.states[denied] == .loading || store.states[missing] == .loading { await Task.yield() }
        #expect(attempts.withLock { $0 } == 2)
        store.retryInaccessible()
        while store.states[denied] == .loading { await Task.yield() }
        #expect(attempts.withLock { $0 } == 3)
        #expect(store.states[missing] == .unavailable(.missing))
        store.reset()
    }

    @Test @MainActor func capturedDestinationCancelFailureAndClosedWindowPreservePresentation() {
        let first = DocumentReadSession()
        let other = DocumentReadSession()
        let original = input("original")
        #expect(first.commit(original, fragment: nil, token: first.begin()))
        let captured = first
        let panel = captured.begin()
        _ = other.begin() // Becoming active elsewhere cannot redirect the captured request.
        let coordinator = DocumentOpeningCoordinator()
        coordinator.cancelReservation(captured, token: panel)
        #expect(!first.accepts(panel))
        #expect(first.prepared?.id == original.id)
        #expect(other.prepared == nil)
        let failed = first.begin()
        // No commit on a loader error: the complete old snapshot remains installed.
        #expect(first.accepts(failed))
        #expect(first.prepared?.id == original.id)
        let late = first.begin()
        first.close()
        #expect(!first.commit(input("late"), fragment: "late", token: late))
        #expect(first.prepared?.id == original.id)
        #expect(first.section == nil)
    }

    @Test @MainActor func failedAndCanceledPreparationNeverPublish() async {
        let session = DocumentReadSession()
        let original = input("original")
        #expect(session.commit(original, fragment: nil, token: session.begin()))
        let failureToken = session.begin()
        do {
            _ = try await session.stage(token: failureToken) { throw MarkdownDocument.Failure.notAReadableFile }
            Issue.record("Injected preparation failure must propagate")
        } catch {}
        #expect(session.prepared?.id == original.id)
        let token = session.begin()
        var resume: CheckedContinuation<Void, Never>?
        let task = Task { @MainActor in
            try await session.stage(token: token) {
                await withCheckedContinuation { resume = $0 }
                return input("canceled")
            }
        }
        while resume == nil { await Task.yield() }
        task.cancel()
        resume?.resume()
        do { _ = try await task.value; Issue.record("Canceled preparation must not publish") }
        catch { #expect(error is CancellationError) }
        #expect(session.prepared?.id == original.id)
        #expect(session.section == nil)
    }

    @Test @MainActor func suspendedOlderPreparationCannotWinOrClearNewerFragment() async {
        let session = DocumentReadSession()
        let original = input("original")
        #expect(session.commit(original, fragment: nil, token: session.begin()))
        let old = session.begin()
        let oldInput = input("old")
        var resume: CheckedContinuation<Void, Never>?
        let task = Task { @MainActor in
            await withCheckedContinuation { resume = $0 }
            return session.commit(oldInput, fragment: "old", token: old)
        }
        while resume == nil { await Task.yield() }
        let newer = input("newer")
        #expect(session.commit(newer, fragment: "newer", token: session.begin()))
        resume?.resume()
        #expect(await task.value == false)
        #expect(session.prepared?.id == newer.id)
        #expect(session.section?.fragment == "newer")
        let pending = session.begin()
        session.navigate("same-document")
        #expect(!session.commit(oldInput, fragment: nil, token: pending))
        #expect(session.section?.fragment == "same-document")
    }

    @Test func canonicalReservationsProtectSharedCandidatesAndOtherViewers() throws {
        let folder = try ownedFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("file.md")
        try Data().write(to: file)
        let alias = folder.appendingPathComponent("alias.md")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: file)
        var reservations = NativeDocumentReservations()
        reservations.reserve(file)
        reservations.reserve(alias)
        reservations.release(file)
        #expect(!reservations.canClose(alias, viewerCount: 0))
        reservations.release(alias)
        #expect(!reservations.canClose(file, viewerCount: 1))
        #expect(reservations.canClose(file, viewerCount: 0))
        reservations.release(alias) // Repeated cleanup cannot underflow.
        #expect(reservations.canClose(file, viewerCount: 0))
    }

    @Test func safeReadRejectsDirectoriesMissingFilesAndFIFOsWithoutBlocking() throws {
        let folder = try ownedFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("empty.md")
        try Data().write(to: file)
        #expect(try RegularMarkdownRead.data(at: file).isEmpty)
        #expect(throws: (any Error).self) { try RegularMarkdownRead.data(at: folder) }
        #expect(throws: (any Error).self) { try RegularMarkdownRead.data(at: folder.appendingPathComponent("missing.md")) }
        let fifo = folder.appendingPathComponent("pipe.md")
        #expect(mkfifo(fifo.path, 0o600) == 0)
        #expect(throws: (any Error).self) { try RegularMarkdownRead.data(at: fifo) }
    }

    @Test func allFileLinksUseConservativeDispositionIncludingSymlinks() throws {
        let folder = try ownedFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("notes.md")
        try Data("inert text; never launched".utf8).write(to: file)
        #expect(try LocalFileDisposition.resolve(file) == .markdown)
        let safe = folder.appendingPathComponent("notes.txt")
        try Data("safe text".utf8).write(to: safe)
        #expect(try LocalFileDisposition.resolve(safe) == .external)
        // Only an owned inert text copy gets executable metadata. No program is executed.
        #expect(chmod(file.path, 0o700) == 0)
        let alias = folder.appendingPathComponent("alias.md")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: file)
        #expect(try LocalFileDisposition.resolve(file) == .reveal)
        #expect(try LocalFileDisposition.resolve(alias) == .reveal)
        #expect(throws: (any Error).self) { try RegularMarkdownRead.data(at: alias) }
        #expect(throws: (any Error).self) { try LocalFileDisposition.resolve(folder.appendingPathComponent("missing")) }
    }

    @Test @MainActor func nativeWriteAndMetadataAPIsRejectWithoutChangingOwnedSource() throws {
        let folder = try ownedFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("source.md")
        let destination = folder.appendingPathComponent("destination.md")
        let bytes = Data("# Read only\n".utf8)
        try bytes.write(to: file)
        let before = try FileManager.default.attributesOfItem(atPath: file.path)
        let document = ReadOnlyMarkdownNSDocument()
        try document.read(from: file, ofType: "net.daringfireball.markdown")
        document.fileURL = file
        #expect(document.text == "# Read only\n")
        #expect(!document.isDocumentEdited)
        #expect(throws: (any Error).self) { try document.data(ofType: "markdown") }
        #expect(throws: (any Error).self) { try document.fileWrapper(ofType: "markdown") }
        #expect(throws: (any Error).self) { try document.write(to: file, ofType: "markdown") }
        #expect(throws: (any Error).self) { try document.write(to: file, ofType: "markdown", for: .saveOperation, originalContentsURL: file) }
        #expect(throws: (any Error).self) { try document.writeSafely(to: file, ofType: "markdown", for: .saveOperation) }
        #expect(throws: (any Error).self) { try document.duplicate() }
        var rejected = 0
        let reject: (Error?) -> Void = { error in
            #expect(error != nil)
            rejected += 1
        }
        document.save(to: file, ofType: "markdown", for: .saveOperation, completionHandler: reject)
        document.autosave(withImplicitCancellability: false, completionHandler: reject)
        document.move(to: destination, completionHandler: reject)
        document.lock(completionHandler: reject)
        document.unlock(completionHandler: reject)
        #expect(rejected == 5)
        // Invoke the actual deprecated Objective-C selectors, not a policy enum.
        let backup = NSSelectorFromString("writeWithBackupToFile:ofType:saveOperation:")
        typealias Backup = @convention(c) (AnyObject, Selector, NSString, NSString, UInt) -> Bool
        let backupImplementation = try #require(document.method(for: backup))
        #expect(!unsafeBitCast(backupImplementation, to: Backup.self)(document, backup, file.path as NSString, "markdown", 0))
        let legacy = NSSelectorFromString("writeToURL:ofType:")
        typealias LegacyWrite = @convention(c) (AnyObject, Selector, NSURL, NSString) -> Bool
        let legacyImplementation = try #require(document.method(for: legacy))
        #expect(!unsafeBitCast(legacyImplementation, to: LegacyWrite.self)(document, legacy, file as NSURL, "markdown"))
        document.rename(nil)
        document.move(nil)
        document.lock(nil)
        document.unlock(nil)
        document.save(nil)
        document.saveAs(nil)
        document.saveTo(nil)
        document.duplicate(nil)
        document.close()
        let after = try FileManager.default.attributesOfItem(atPath: file.path)
        #expect(try Data(contentsOf: file) == bytes)
        #expect(before[.modificationDate] as? Date == after[.modificationDate] as? Date)
        #expect(before[.posixPermissions] as? Int == after[.posixPermissions] as? Int)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["source.md"])
    }

    private func ownedFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
