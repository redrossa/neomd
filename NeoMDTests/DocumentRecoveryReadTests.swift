import Darwin
import Foundation
import Testing
import Synchronization
@testable import NeoMD

@MainActor struct DocumentRecoveryReadTests {
    @Test func fiveOwnedReadDecodeRenderAndSessionCloseCyclesNeverChangeBytesOrNanosecondMtime() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in DocumentRecoveryFixtureTests.files {
            let url = folder.appendingPathComponent(name)
            try FileManager.default.copyItem(at: DocumentRecoveryFixtureTests.folder.appendingPathComponent(name), to: url)
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        for name in names {
            let url = folder.appendingPathComponent(name)
            let before = try Data(contentsOf: url)
            var metadata = stat()
            #expect(stat(url.path, &metadata) == 0)
            for _ in 0..<5 {
                let bytes = try RegularMarkdownRead.data(at: url)
                let text = try MarkdownTextDecoder.text(from: bytes)
                let input = PreparedReadingDocument(text: text, fileURL: url,
                    rendered: MarkdownBlockRenderer.render(from: text, documentURL: url))
                let session = DocumentReadSession()
                #expect(session.commit(input, fragment: nil, token: session.begin()))
                session.close() // Model only: no NSDocument, window, save or history.
                #expect(!session.isOpen && session.prepared?.id == input.id)
                #expect(bytes == before)
                #expect(try Data(contentsOf: url) == before)
                var after = stat()
                #expect(stat(url.path, &after) == 0)
                #expect(after.st_mtimespec.tv_sec == metadata.st_mtimespec.tv_sec)
                #expect(after.st_mtimespec.tv_nsec == metadata.st_mtimespec.tv_nsec)
                #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted() == names)
            }
        }
    }

    @Test func quietRefreshRetriesIOAndDefensiveDecodeFailuresWithoutReplacingLastGoodState() throws {
        for error: Error in [POSIXError(.ENOENT), POSIXError(.EACCES), POSIXError(.EIO),
                             MarkdownTextDecoder.Failure.unrecognizedTextEncoding] {
            for recoveredText in ["Good", "Recovered"] {
                let state = Mutex<(text: String, error: Error?)>(("Good", nil))
                let outcomes = Mutex<[DocumentRefreshOutcome]>([])
                var metadata = stat()
                metadata.st_mode = S_IFREG | 0o644
                metadata.st_ino = 1
                metadata.st_size = 4
                let stamp = RegularMarkdownRead.Stamp(metadata)
                let url = URL(fileURLWithPath: "/in-memory/good.md")
                let controller = DocumentRefreshController()
                controller.rebind(DocumentRefreshSource(now: { 0 }, url: { url }, stamp: { _ in
                    try state.withLock { if let error = $0.error { throw error }; return stamp }
                }, snapshot: { _ in
                    try state.withLock {
                        if let error = $0.error { throw error }
                        return RegularMarkdownRead.Snapshot(data: Data($0.text.utf8), stamp: stamp)
                    }
                }, automaticPolling: false))
                let viewer = UUID()
                controller.attach(viewer) { outcome in outcomes.withLock { $0.append(outcome) } }
                func settle(_ start: Double) {
                    for tick in 0..<10 { controller.tick(at: start + Double(tick)) }
                }
                settle(0)
                let first = try #require(outcomes.withLock { values in
                    values.compactMap { if case .updated(let payload) = $0 { payload } else { nil } }.first
                })
                controller.acknowledge(viewer, revision: first.revision)
                outcomes.withLock { $0.removeAll() }
                let session = DocumentReadSession()
                let input = PreparedReadingDocument(first)
                #expect(session.commit(input, fragment: nil, token: session.begin()))
                session.notice = "fragment notice"
                state.withLock { $0.error = error }
                settle(10)
                let failures = outcomes.withLock { $0.compactMap {
                    if case .unavailable(let failure) = $0 { failure } else { nil }
                } }
                #expect(failures.count == 1)
                let failure = try #require(failures.first)
                session.reportRefreshFailure(failure.message)
                #expect(session.prepared?.id == input.id && session.notice == "fragment notice")
                controller.acknowledge(viewer, failure: failure)
                outcomes.withLock { $0.removeAll() }
                state.withLock { $0 = (recoveredText, nil) }
                settle(20) // Retry without an event, presenter or real clock.
                let recovered = try #require(outcomes.withLock { $0.compactMap {
                    if case .updated(let payload) = $0 { payload } else { nil }
                }.last })
                #expect(recovered.text == recoveredText)
                #expect((recovered.revision == first.revision) == (recoveredText == "Good"))
                session.clearRefreshStatus()
                #expect(session.refreshStatus == nil && session.notice == "fragment notice")
                controller.detach(viewer)
            }
        }
    }

    @Test func actualReadFailuresKeepLastGoodStateAndOwnedExecutableUntouched() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let executable = folder.appendingPathComponent("inert.md")
        let bytes = Data("inert text, never executed".utf8)
        try bytes.write(to: executable)
        #expect(chmod(executable.path, 0o700) == 0)
        var before = stat()
        #expect(stat(executable.path, &before) == 0)
        let session = DocumentReadSession()
        let good = PreparedReadingDocument(text: "Good", fileURL: folder.appendingPathComponent("good.md"),
                                           rendered: MarkdownBlockRenderer.render(from: "Good"))
        #expect(session.commit(good, fragment: nil, token: session.begin()))
        for url in [folder.appendingPathComponent("missing.md"), folder, executable] {
            let token = session.begin()
            do {
                _ = try await session.stage(token: token) {
                    let text = try MarkdownTextDecoder.text(from: RegularMarkdownRead.data(at: url))
                    return PreparedReadingDocument(text: text, fileURL: url,
                                                   rendered: MarkdownBlockRenderer.render(from: text))
                }
                Issue.record("Expected actual read failure")
            } catch {
                let failure = try #require(DocumentOpenFailure.normalized(error, at: url))
                #expect(failure.kind == (url.lastPathComponent == "missing.md" ? .missing : .unsuitableItem))
            }
            #expect(session.prepared?.id == good.id && session.prepared?.text == "Good")
        }
        #expect(try Data(contentsOf: executable) == bytes)
        var after = stat()
        #expect(stat(executable.path, &after) == 0)
        #expect(after.st_mtimespec.tv_sec == before.st_mtimespec.tv_sec)
        #expect(after.st_mtimespec.tv_nsec == before.st_mtimespec.tv_nsec)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["inert.md"])
    }
}
