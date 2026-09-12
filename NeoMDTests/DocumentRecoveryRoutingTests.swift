import Foundation
import Testing
@testable import NeoMD

@MainActor struct DocumentRecoveryRoutingTests {
    private func reader(_ name: String = "original") -> DocumentReadSession {
        let session = DocumentReadSession()
        let url = URL(fileURLWithPath: "/owned-model/\(name).md")
        let text = "# \(name)\n\nBody paragraph."
        let input = PreparedReadingDocument(text: text, fileURL: url,
                                            rendered: MarkdownBlockRenderer.render(from: text))
        _ = session.commit(input, fragment: nil, token: session.begin())
        session.binding = UUID()
        session.notice = "fragment notice"
        session.findQuery = "Body"
        session.isFindPresented = true
        return session
    }

    @Test func reportingCapturesDestinationAndRejectsStaleClosedCanceledAndTerminatingWork() {
        let coordinator = DocumentOpeningCoordinator()
        var reports: [(String, UUID, Bool)] = []
        coordinator.errorPresenter = { reports.append(($0, $1, $2)) }
        let source = reader()
        let other = reader("other")
        let token = source.begin()
        let url = URL(fileURLWithPath: "/attempted/café.md")
        coordinator.report(POSIXError(.ENOENT), at: url, in: source, token: token)
        #expect(reports.count == 1 && reports[0].1 == source.id && reports[0].2)
        #expect(reports[0].0.contains(url.path))
        #expect(source.notice == "fragment notice" && other.notice == "fragment notice")
        let empty = DocumentReadSession()
        coordinator.report(POSIXError(.EACCES), at: url, in: empty, token: empty.begin())
        #expect(reports.count == 2 && reports[1].1 == empty.id && !reports[1].2)
        coordinator.report(CancellationError(), at: url, in: source, token: token)
        coordinator.report(NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
                                  userInfo: [NSUnderlyingErrorKey: CocoaError(.userCancelled)]),
                           at: url, in: source, token: token)
        let presentation = source.prepared?.id
        _ = source.begin()
        #expect(!coordinator.canReport(in: source, token: token, presentation: presentation))
        coordinator.report(POSIXError(.EIO), at: url, in: source, token: token)
        source.close()
        coordinator.report(POSIXError(.EIO), at: url, in: source, token: source.generation)
        coordinator.applicationWillTerminate() // No windows/history entries/panels exist.
        coordinator.report(POSIXError(.EIO), at: url, in: other, token: other.generation)
        #expect(reports.count == 2 && coordinator.windows.isEmpty)
    }

    @Test func ordinaryAndAdditionalFailuresOnlyReachTheLiveCapturedSource() async throws {
        for activation in [DocumentLinkActivation.ordinary, .additionalReader] {
            for phase in 0..<6 {
                let coordinator = DocumentOpeningCoordinator()
                var reports: [UUID] = []
                coordinator.errorPresenter = { _, id, _ in reports.append(id) }
                let source = reader()
                let other = reader("other")
                let original = try #require(source.prepared)
                let request = DocumentLocalLinkRequest(source: source, presentation: original.id,
                    target: DocumentLocalTarget(fileURL: URL(fileURLWithPath: "/attempted/missing.md"), fragment: nil),
                    activation: activation, coordinator: coordinator,
                    capturePlacement: { _ in DocumentWindowPlacement(sourceFrame: nil, screenID: nil, capturedVisibleFrame: nil) })
                await request.run(classify: { _ in
                    await Task.yield()
                    switch phase {
                    case 1: source.close()
                    case 2: source.prepared = other.prepared
                    case 3: _ = source.begin()
                    case 4: throw CancellationError()
                    case 5: throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
                                         userInfo: [NSUnderlyingErrorKey: CocoaError(.userCancelled)])
                    default: break
                    }
                    throw POSIXError(.ENOENT)
                }, open: { _, _, _, _ in Issue.record("A failed classification must not open") },
                dispatch: { _, _ in Issue.record("A failed classification must not dispatch") })
                #expect(reports == (phase == 0 ? [source.id] : []))
                #expect(other.notice == "fragment notice")
                if phase != 2 { #expect(source.prepared?.id == original.id) }
                #expect(coordinator.windows.isEmpty && coordinator.reservedSessions.isEmpty)
            }
        }
    }

    @Test func typedStagingFailuresPreserveCompleteLastGoodStateAndOtherViewer() async throws {
        for failure: Error in [POSIXError(.ENOENT), POSIXError(.EACCES), POSIXError(.EIO),
                               MarkdownTextDecoder.Failure.unrecognizedTextEncoding,
                               MarkdownDocument.Failure.notAReadableFile] {
            let source = reader()
            let other = reader("other")
            let original = try #require(source.prepared)
            let otherID = other.prepared?.id
            let binding = source.binding
            let locator = try #require(DocumentContentLocator.capture(anchor: .top, in: original.index))
            source.recordReadingPosition(locator, presentation: original.id)
            let token = source.begin()
            do {
                _ = try await source.stage(token: token) { throw failure }
                Issue.record("Expected staging failure")
            } catch { #expect(DocumentOpenFailure.normalized(error, at: original.fileURL) != nil) }
            #expect(source.prepared?.id == original.id && source.prepared?.text == original.text)
            #expect(source.prepared?.fileURL == original.fileURL)
            #expect(source.prepared?.rendered.nodes.map(\.id) == original.rendered.nodes.map(\.id))
            #expect(source.prepared?.index.entries == original.index.entries)
            #expect(source.capturedPosition(for: original.id) == locator && source.binding == binding)
            #expect(source.findQuery == "Body" && source.isFindPresented)
            #expect(source.notice == "fragment notice" && other.prepared?.id == otherID)
            #expect(source.generation == token && source.section == nil)
        }
    }
}
