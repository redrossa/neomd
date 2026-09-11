import AppKit

/// Captures destinations before panels/awaits and stages before native ownership changes.
final class DocumentOpeningCoordinator {
    weak var documentController: MarkdownDocumentController?
    private(set) var windows: [UUID: DocumentWindowController] = [:]
    private var firstReader = DocumentReadSession()
    private var reservations = NativeDocumentReservations()
    private(set) var reservedSessions: [UUID: DocumentReadSession] = [:]
    private var lifecycle = DocumentWindowLifecycle()
    var isTerminating: Bool { lifecycle.isTerminating }
    var shouldShowNoDocumentWindow: Bool { lifecycle.shouldShowNoDocumentWindow }
    @discardableResult func documentWindowDidAppear(id: UUID) -> DocumentWindowLifecycle.Directive {
        lifecycle.documentWindowDidAppear(id: id)
    }
    @discardableResult func documentWindowDidDisappear(id: UUID) -> DocumentWindowLifecycle.Directive {
        lifecycle.documentWindowDidDisappear(id: id)
    }

    func destination(newWindow: Bool = false) -> DocumentReadSession {
        if newWindow {
            let session = DocumentReadSession()
            reservedSessions[session.id] = session
            return session
        }
        if let controller = (NSApp.keyWindow?.windowController as? DocumentWindowController)
            ?? (NSApp.mainWindow?.windowController as? DocumentWindowController) {
            return controller.session
        }
        if let controller = windows.values.first { return controller.session }
        if !firstReader.isOpen { firstReader = DocumentReadSession() }
        return firstReader
    }

    func capturePlacement(for sourceID: UUID) -> DocumentWindowPlacement {
        DocumentWindowPlacement.capture(window: windows[sourceID]?.window)
    }

    func close(_ controller: DocumentWindowController) {
        controller.session.close()
        windows.removeValue(forKey: controller.session.id)
        documentWindowDidDisappear(id: controller.session.id)
        let old = controller.document as? ReadOnlyMarkdownNSDocument
        old?.removeWindowController(controller)
        if let old { releaseIfUnused(old) }
    }

    func applicationWillTerminate() {
        _ = lifecycle.applicationWillTerminate()
        for window in windows.values { window.session.close() }
        for session in reservedSessions.values { session.close() }
        firstReader.close()
        documentController?.cancelPanels()
    }

    func cancelReservation(_ session: DocumentReadSession, token: Int) {
        guard session.accepts(token) else { return }
        _ = session.begin()
        reservedSessions.removeValue(forKey: session.id)
    }

    func finishLinkRequest(_ session: DocumentReadSession, token: Int) {
        // Closed sessions must be released too, but stale work cannot release newer work.
        if session.generation == token || !session.isOpen {
            reservedSessions.removeValue(forKey: session.id)
        }
        session.finish(token)
    }

    func open(_ url: URL, fragment: String? = nil, in session: DocumentReadSession,
              token: Int? = nil, placement: DocumentWindowPlacement? = nil) async throws -> (ReadOnlyMarkdownNSDocument, Bool) {
        let serial = token ?? session.begin()
        defer {
            if session.generation == serial || !session.isOpen {
                reservedSessions.removeValue(forKey: session.id)
            }
        }
        guard !isTerminating, session.accepts(serial), let documentController else { throw CancellationError() }
        if session.prepared?.fileURL.standardizedFileURL == url.standardizedFileURL,
           let document = windows[session.id]?.document as? ReadOnlyMarkdownNSDocument {
            session.navigate(fragment)
            return (document, true)
        }
        let key = url.standardizedFileURL.resolvingSymlinksInPath()
        // Reserve BEFORE awaiting: concurrent super opens can return the same native identity.
        reservations.reserve(key)
        var acquired: ReadOnlyMarkdownNSDocument?
        defer {
            reservations.release(key)
            if let candidate = acquired ?? documentController.document(for: key) as? ReadOnlyMarkdownNSDocument {
                releaseIfUnused(candidate)
            }
        }
        try await Task.detached(priority: .userInitiated) {
            guard url.isFileURL, MarkdownFileType.claimsFile(at: url),
                  LocalFileAccessProbe.state(of: url) == .readable(isDirectory: false) else {
                throw MarkdownDocument.Failure.notAReadableFile
            }
            let values = try key.resourceValues(forKeys: [.isApplicationKey, .isExecutableKey])
            guard values.isApplication == false, values.isExecutable == false else {
                throw MarkdownDocument.Failure.notAReadableFile
            }
        }.value
        guard !isTerminating, session.accepts(serial) else { throw CancellationError() }
        let (document, alreadyOpen) = try await documentController.acquireWithoutDisplaying(key)
        acquired = document
        guard !isTerminating, session.accepts(serial) else { throw CancellationError() }
        let text = document.text
        let input = try await session.stage(token: serial) {
            await Task.detached(priority: .userInitiated) {
                PreparedReadingDocument(text: text, fileURL: url,
                    rendered: MarkdownBlockRenderer.render(from: text, documentURL: url))
            }.value
        }
        guard !isTerminating, session.accepts(serial) else { throw CancellationError() }
        // No suspension from this guard through the entire commit.
        let controller = windows[session.id] ?? DocumentWindowController(session: session, coordinator: self,
                                                                         placement: placement)
        let previous = controller.document as? ReadOnlyMarkdownNSDocument
        document.addWindowController(controller)
        _ = session.commit(input, fragment: fragment, token: serial)
        windows[session.id] = controller
        documentWindowDidAppear(id: session.id)
        controller.install(input)
        if session === firstReader { firstReader = DocumentReadSession() }
        if let previous, previous !== document { releaseIfUnused(previous) }
        documentController.recordCommitted(url)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        return (document, alreadyOpen)
    }

    func request(_ urls: [URL], in session: DocumentReadSession) {
        let token = session.begin()
        let url: URL
        do { url = try MarkdownDropRouting.singleFile(from: urls) }
        catch {
            report(error.localizedDescription, in: session)
            cancelReservation(session, token: token)
            return
        }
        session.task = Task {
            defer { session.finish(token) }
            do { _ = try await open(url, in: session, token: token) }
            catch is CancellationError {} catch {
                if session.accepts(token) { report(Self.failureMessage(url), in: session) }
            }
        }
    }

    func report(_ message: String, in session: DocumentReadSession) {
        guard !isTerminating, session.isOpen else { return }
        if session.prepared != nil { session.notice = message }
        else {
            let alert = NSAlert()
            alert.messageText = "Couldn’t Open Document"
            alert.informativeText = message
            alert.runModal()
        }
    }

    private func releaseIfUnused(_ document: ReadOnlyMarkdownNSDocument) {
        guard let url = document.fileURL,
              reservations.canClose(url, viewerCount: document.windowControllers.count) else { return }
        document.close()
    }

    static func failureMessage(_ url: URL) -> String {
        "Couldn’t read ‘\(url.path)’. Check that the file hasn’t moved and its volume is connected. Check file permissions in Finder and NeoMD’s access in System Settings > Privacy & Security, then try opening it again."
    }
}
