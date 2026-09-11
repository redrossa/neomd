import AppKit
import Testing
@testable import NeoMD

@MainActor struct DocumentLinkActivationTests {
    private func prepared(_ url: URL = URL(fileURLWithPath: "/tmp/source.md")) -> PreparedReadingDocument {
        PreparedReadingDocument(text: "# Heading", fileURL: url,
            rendered: MarkdownBlockRenderer.render(from: "# Heading", documentURL: url))
    }

    private func source() -> DocumentReadSession {
        let session = DocumentReadSession()
        _ = session.commit(prepared(), fragment: "source-section", token: session.begin())
        session.notice = "source-notice"
        return session
    }

    private func request(_ source: DocumentReadSession, _ coordinator: DocumentOpeningCoordinator,
                         activation: DocumentLinkActivation = .additionalReader,
                         fragment: String? = "heading") -> DocumentLocalLinkRequest {
        DocumentLocalLinkRequest(source: source, presentation: source.prepared!.id,
            target: DocumentLocalTarget(fileURL: source.prepared!.fileURL, fragment: fragment),
            activation: activation, coordinator: coordinator)
    }

    @Test func immutablePointerPolicyAndBoundedNestedCleanup() throws {
        var command = true
        let captured = DocumentLinkActivation(pointer: true, command: command, control: false)
        command = false
        #expect(captured == .additionalReader)
        #expect(DocumentLinkActivation(pointer: true, command: command, control: false) == .ordinary)
        #expect(DocumentLinkActivation(pointer: true, command: true, control: true) == .ordinary)
        #expect(DocumentLinkActivation(pointer: false, command: true, control: false) == .ordinary)
        let scope = DocumentLinkPointerScope()
        scope.tracking(captured) {
            #expect(scope.activation == .additionalReader)
            scope.tracking(.ordinary) { #expect(scope.activation == .ordinary) }
            #expect(scope.activation == captured)
        }
        #expect(scope.activation == nil)
        do { try scope.tracking(captured) { throw CancellationError() } } catch {}
        #expect(scope.activation == nil)
        scope.tracking(captured) {
            scope.tracking(.ordinary) { scope.clear() }
            #expect(scope.activation == nil)
        }
        #expect(scope.activation == nil)
    }

    @Test func additionalSelfAndAlreadyOpenTargetsHaveIndependentState() async {
        let coordinator = DocumentOpeningCoordinator()
        let a = source()
        let b = source()
        let c = source()
        let original = a.prepared!.id
        let generation = a.generation
        let section = a.section
        let bSection = b.section
        let sourceTask = Task<Void, Never> {}
        a.task = sourceTask
        var active = a
        for fragment in ["heading", nil] as [String?] {
            let captured = request(a, coordinator, fragment: fragment)
            active = c
            #expect(captured.destination !== a && captured.destination !== b && captured.destination !== active)
            #expect(captured.destination.prepared == nil)
            var commits = 0
            await captured.run(classify: { _ in .markdown }, open: { target, destination, token in
                #expect(destination === captured.destination)
                let input = try await destination.stage(token: token) { prepared(target.fileURL) }
                #expect(destination.commit(input, fragment: target.fragment, token: token))
                commits += 1
            }, dispatch: { _, _ in Issue.record("Markdown must not dispatch externally") })
            #expect(commits == 1)
            #expect(captured.destination.prepared?.id != original)
            #expect(captured.destination.section?.fragment == fragment)
            #expect(a.prepared?.id == original && a.generation == generation)
            #expect(a.section == section && a.notice == "source-notice")
            #expect(a.task == sourceTask && !sourceTask.isCancelled)
            #expect(b.section == bSection)
            #expect(coordinator.reservedSessions.isEmpty && coordinator.windows.isEmpty)
        }
        a.task = nil
    }

    @Test func customExternalFallbackDispatchesOnceAndStandardDefersToSwiftUI() {
        let url = URL(string: "https://example.com/#heading")!
        var dispatches = 0
        _ = DocumentLinkActivation.external(url, customAction: false) { _ in dispatches += 1 }
        #expect(dispatches == 0)
        _ = DocumentLinkActivation.external(url, customAction: true) { actual in
            #expect(actual == url)
            dispatches += 1
        }
        #expect(dispatches == 1)
    }

    @Test func ordinaryCaptureRemainsSourceBound() async {
        let coordinator = DocumentOpeningCoordinator()
        let a = source()
        let c = source()
        let captured = request(a, coordinator, activation: .ordinary)
        _ = c.begin()
        #expect(captured.destination === a)
        #expect(coordinator.reservedSessions.isEmpty)
        await captured.run(classify: { _ in .markdown }, open: { target, destination, token in
            #expect(destination === a)
            #expect(destination.commit(prepared(target.fileURL), fragment: target.fragment, token: token))
        })
        #expect(a.section?.fragment == "heading")
        #expect(c.prepared?.id != a.prepared?.id)
    }

    @Test func failuresReleaseReservationsAndOnlyNotifyLiveSource() async {
        for phase in 0..<4 {
            let coordinator = DocumentOpeningCoordinator()
            let a = source()
            let c = source()
            let original = a.prepared!.id
            let generation = a.generation
            let section = a.section
            let captured = request(a, coordinator)
            var commits = 0
            await captured.run(classify: { _ in
                if phase == 0 { throw MarkdownDocument.Failure.notAReadableFile }
                if phase == 2 { a.close() }
                if phase == 3 { _ = a.commit(prepared(), fragment: "new", token: a.begin()) }
                return .markdown
            }, open: { _, destination, token in
                _ = try await destination.stage(token: token) { throw MarkdownDocument.Failure.notAReadableFile }
                commits += 1
            })
            #expect(commits == 0 && coordinator.windows.isEmpty && coordinator.reservedSessions.isEmpty)
            #expect(c.notice == "source-notice")
            if phase < 2 {
                #expect(a.notice?.contains("Check file permissions") == true)
                #expect(a.prepared?.id == original && a.section == section && a.generation == generation)
            } else if phase == 2 { #expect(a.notice == "source-notice") }
            else { #expect(a.notice == nil) }
        }
    }

    @Test func cancellationAndTerminationAtClassificationNeverOpen() async {
        for terminate in [false, true] {
            let coordinator = DocumentOpeningCoordinator()
            let a = source()
            let captured = request(a, coordinator)
            var resume: CheckedContinuation<Void, Never>?
            let task = Task { await captured.run(classify: { _ in
                await withCheckedContinuation { resume = $0 }
                return .markdown
            }, open: { _, _, _ in Issue.record("Canceled classification must not open") }) }
            while resume == nil { await Task.yield() }
            if terminate { coordinator.applicationWillTerminate() } else { task.cancel() }
            resume?.resume()
            await task.value
            #expect(coordinator.reservedSessions.isEmpty && coordinator.windows.isEmpty)
            #expect(a.notice == "source-notice")
        }
    }

    @Test func sourceReplacementDoesNotCancelAdditionalRequest() async {
        let coordinator = DocumentOpeningCoordinator()
        let a = source()
        let captured = request(a, coordinator)
        var resume: CheckedContinuation<Void, Never>?
        var opened = 0
        let task = Task { await captured.run(classify: { _ in
            await withCheckedContinuation { resume = $0 }
            return .markdown
        }, open: { _, destination, token in
            #expect(destination.accepts(token))
            opened += 1
        }) }
        captured.destination.task = task
        while resume == nil { await Task.yield() }
        let replacement = prepared()
        #expect(a.commit(replacement, fragment: "replacement", token: a.begin()))
        resume?.resume()
        await task.value
        #expect(opened == 1 && !task.isCancelled)
        #expect(a.prepared?.id == replacement.id && a.section?.fragment == "replacement")
        #expect(coordinator.reservedSessions.isEmpty)
    }

    @Test func nonMarkdownDispatchesExactlyOnceAndReleasesUnusedReader() async {
        for disposition in [LocalFileDisposition.external, .reveal] {
            let coordinator = DocumentOpeningCoordinator()
            let a = source()
            let generation = a.generation
            let captured = request(a, coordinator)
            var dispatches = 0
            await captured.run(classify: { _ in disposition },
                open: { _, _, _ in Issue.record("Non-Markdown must not open a reader") },
                dispatch: { actual, url in
                    #expect(actual == disposition && url == captured.target.fileURL)
                    dispatches += 1
                })
            #expect(dispatches == 1 && a.generation == generation)
            #expect(coordinator.reservedSessions.isEmpty && coordinator.windows.isEmpty)
        }
    }

    @Test func earlyOpenGuardAndStaleCleanupReleaseOnlyOwnedReservation() async {
        let coordinator = DocumentOpeningCoordinator() // No native controller: exercise real early guard.
        let a = source()
        let captured = request(a, coordinator)
        await captured.run(classify: { _ in .markdown })
        #expect(coordinator.reservedSessions.isEmpty)
        #expect(a.notice == "source-notice")
        let newer = request(a, coordinator)
        let next = newer.destination.begin()
        coordinator.finishLinkRequest(newer.destination, token: newer.token)
        #expect(coordinator.reservedSessions[newer.destination.id] === newer.destination)
        #expect(newer.destination.accepts(next))
        coordinator.finishLinkRequest(newer.destination, token: next)
        #expect(coordinator.reservedSessions.isEmpty)
    }

    @Test func canceledStagingCannotCommitOrNotify() async {
        let coordinator = DocumentOpeningCoordinator()
        let a = source()
        let section = a.section
        let captured = request(a, coordinator)
        var resume: CheckedContinuation<Void, Never>?
        var commits = 0
        let task = Task { await captured.run(classify: { _ in .markdown }, open: { target, destination, token in
            let input = try await destination.stage(token: token) {
                await withCheckedContinuation { resume = $0 }
                return prepared(target.fileURL)
            }
            if destination.commit(input, fragment: target.fragment, token: token) { commits += 1 }
        }) }
        while resume == nil { await Task.yield() }
        task.cancel()
        resume?.resume()
        await task.value
        #expect(commits == 0 && coordinator.reservedSessions.isEmpty && coordinator.windows.isEmpty)
        #expect(a.section == section && a.notice == "source-notice")
    }

    @Test func readingFixtureCopiesPreservesBytesAndModificationDates() async throws {
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/m1-p6-command-click/docs")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["source.md", "Target café.MD", "empty.md"] {
            let url = folder.appendingPathComponent(name)
            try FileManager.default.copyItem(at: fixtures.appendingPathComponent(name), to: url)
            let before = try Data(contentsOf: url)
            let date = try #require(url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            let a = source()
            let coordinator = DocumentOpeningCoordinator()
            let captured = DocumentLocalLinkRequest(source: a, presentation: a.prepared!.id,
                target: DocumentLocalTarget(fileURL: url, fragment: nil), activation: .additionalReader,
                coordinator: coordinator)
            var commits = 0
            await captured.run(open: { target, destination, token in
                let input = try await destination.stage(token: token) {
                    let text = try MarkdownTextDecoder.text(from: RegularMarkdownRead.data(at: target.fileURL))
                    return PreparedReadingDocument(text: text, fileURL: target.fileURL,
                        rendered: MarkdownBlockRenderer.render(from: text, documentURL: target.fileURL))
                }
                if destination.commit(input, fragment: target.fragment, token: token) { commits += 1 }
            })
            #expect(commits == 1 && coordinator.reservedSessions.isEmpty)
            #expect(try Data(contentsOf: url) == before)
            #expect(try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == date)
        }
    }

    @Test func whitespaceLinkUsesNativeRangesWhileUnlinkedImageStaysSwiftUI() {
        var whitespace = AttributedString("   ")
        let url = URL(string: "target.md#heading")!
        whitespace.link = url
        #expect(MarkdownLinkedImageText.requiresNativeText(whitespace))
        let content = MarkdownLinkedImageContent.make(.init(text: whitespace, states: [:], dark: false,
                                                            width: 400, headingLevel: nil))
        #expect(content.attribute(.link, at: 1, effectiveRange: nil) as? URL == url)
        #expect(!MarkdownLinkedImageText.requiresNativeText(AttributedString("   ")))
        let rendered = MarkdownBlockRenderer.render(from: "![badge](badge.svg)")
        #expect(!MarkdownLinkedImageText.requiresNativeText(rendered.roots[0].text))
        let linked = MarkdownBlockRenderer.render(from: "[![badge](badge.svg)](target.md)")
        #expect(MarkdownLinkedImageText.requiresNativeText(linked.roots[0].text))
    }
}
