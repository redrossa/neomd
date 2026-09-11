import AppKit
import UniformTypeIdentifiers

final class MarkdownDocumentController: NSDocumentController {
    let openingCoordinator = DocumentOpeningCoordinator()
    private var panels: [NSOpenPanel] = []
    private var startupPending = false
    private var startupConsumed = false
    private var presentingStartupPicker = false
    private weak var startupPanel: NSOpenPanel?

    override init() {
        super.init()
        openingCoordinator.documentController = self
    }
    required init?(coder: NSCoder) { nil }

    override func documentClass(forType typeName: String) -> AnyClass? {
        typeName == MarkdownFileType.markdown.identifier ? ReadOnlyMarkdownNSDocument.self : nil
    }

    override func openDocument(_ sender: Any?) {
        explicitFileIntent()
        showPicker(newWindow: false)
    }
    override func newDocument(_ sender: Any?) {
        explicitFileIntent()
        showPicker(newWindow: true)
    }

    func scheduleStartupPicker() {
        guard !startupConsumed else { return }
        startupConsumed = true
        startupPending = true
        Task { @MainActor in
            guard startupPending, !openingCoordinator.isTerminating else { return }
            startupPending = false
            presentingStartupPicker = true
            showPicker(newWindow: false)
            presentingStartupPicker = false
        }
    }

    func explicitFileIntent() {
        startupConsumed = true
        startupPending = false
        startupPanel?.cancel(nil)
        startupPanel = nil
    }

    private func showPicker(newWindow: Bool) {
        guard !openingCoordinator.isTerminating else { return }
        let destination = openingCoordinator.destination(newWindow: newWindow)
        let token = destination.begin()
        beginOpenPanel { [weak self] urls in
            guard let self else { return }
            guard let url = urls?.first, destination.accepts(token) else {
                openingCoordinator.cancelReservation(destination, token: token)
                return
            }
            destination.task = Task { @MainActor in
                defer { destination.finish(token) }
                do { _ = try await self.openingCoordinator.open(url, in: destination, token: token) }
                catch is CancellationError {} catch {
                    if destination.accepts(token) { self.openingCoordinator.report(DocumentOpeningCoordinator.failureMessage(url), in: destination) }
                }
            }
        }
    }

    override func beginOpenPanel(_ openPanel: NSOpenPanel, forTypes inTypes: [String]?, completionHandler: @escaping (Int) -> Void) {
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = MarkdownFileType.readableContentTypes
        panels.append(openPanel)
        if presentingStartupPicker { startupPanel = openPanel }
        super.beginOpenPanel(openPanel, forTypes: inTypes) { [weak self, weak openPanel] result in
            self?.panels.removeAll { $0 === openPanel }
            completionHandler(result)
        }
    }

    func cancelPanels() { for panel in panels { panel.cancel(nil) }; panels.removeAll() }

    override func openDocument(withContentsOf url: URL, display displayDocument: Bool,
                               completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void) {
        explicitFileIntent()
        let destination = openingCoordinator.destination()
        let token = destination.begin()
        destination.task = Task { @MainActor in
            defer { destination.finish(token) }
            do {
                let (document, alreadyOpen) = try await openingCoordinator.open(url, in: destination, token: token)
                completionHandler(document, alreadyOpen, nil)
            } catch { completionHandler(nil, false, error) }
        }
    }

    func acquireWithoutDisplaying(_ url: URL) async throws -> (ReadOnlyMarkdownNSDocument, Bool) {
        try await withCheckedThrowingContinuation { continuation in
            super.openDocument(withContentsOf: url, display: false) { document, alreadyOpen, error in
                if let error { continuation.resume(throwing: error) }
                else if let document = document as? ReadOnlyMarkdownNSDocument {
                    continuation.resume(returning: (document, alreadyOpen))
                } else { continuation.resume(throwing: MarkdownDocument.Failure.notAReadableFile) }
            }
        }
    }

    // Superclass acquisition must not record abandoned candidates in Open Recent.
    override func noteNewRecentDocumentURL(_ url: URL) {}
    override func noteNewRecentDocument(_ document: NSDocument) {}
    func recordCommitted(_ url: URL) { super.noteNewRecentDocumentURL(url) }

    // The existing native Clear Menu command clears the remembered reading positions
    // too. Open readers keep their current place and no second control is added.
    override func clearRecentDocuments(_ sender: Any?) {
        super.clearRecentDocuments(sender)
        openingCoordinator.clearReadingHistory()
    }

    @objc func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        explicitFileIntent()
        openingCoordinator.request([url], in: openingCoordinator.destination())
    }
}
