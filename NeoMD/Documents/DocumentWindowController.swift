import AppKit
import SwiftUI

final class DocumentWindowController: NSWindowController, NSWindowDelegate {
    let session: DocumentReadSession
    private let coordinator: DocumentOpeningCoordinator

    init(session: DocumentReadSession, coordinator: DocumentOpeningCoordinator) {
        self.session = session
        self.coordinator = coordinator
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.minSize = NSSize(width: 480, height: 320)
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        super.init(window: window)
        shouldCloseDocument = false
        window.delegate = self
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func install(_ input: PreparedReadingDocument) {
        guard let window else { return }
        let frame = window.frame
        let host = NSHostingController(rootView:
            DocumentReaderView(prepared: input, session: session, openingCoordinator: coordinator).id(input.id))
        host.view.frame = window.contentView?.bounds ?? window.contentLayoutRect
        window.contentViewController = host
        if window.frame != frame { window.setFrame(frame, display: true) }
        synchronizeWindowTitleWithDocumentName()
    }

    override func synchronizeWindowTitleWithDocumentName() {
        guard let url = session.prepared?.fileURL else { return }
        window?.title = url.lastPathComponent
        window?.representedURL = url
        window?.isDocumentEdited = false
    }

    func windowWillClose(_ notification: Notification) { coordinator.close(self) }

    @objc func revealDocument(_ sender: Any?) {
        guard let url = session.prepared?.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
