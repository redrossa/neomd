import AppKit
import SwiftUI

/// A copied tracking value, never an ambient event queried during asynchronous work.
nonisolated enum DocumentLinkActivation: Equatable, Sendable {
    case ordinary
    case additionalReader

    init(pointer: Bool, command: Bool, control: Bool) {
        self = pointer && command && !control ? .additionalReader : .ordinary
    }

    /// Custom environment callbacks do not receive SwiftUI's automatic fallback.
    @MainActor static func external(_ url: URL, customAction: Bool,
                                    dispatch: (URL) -> Void) -> OpenURLAction.Result {
        guard customAction else { return .systemAction }
        dispatch(url)
        return .handled
    }
}

/// Nested tracking restores its caller; detach invalidates every enclosing scope.
final class DocumentLinkPointerScope {
    private(set) var activation: DocumentLinkActivation?
    private var generation = 0

    func tracking(_ value: DocumentLinkActivation, perform: () throws -> Void) rethrows {
        let previous = activation
        let capturedGeneration = generation
        activation = value
        defer { if generation == capturedGeneration { activation = previous } }
        try perform()
    }

    func clear() {
        generation += 1
        activation = nil
    }
}

extension EnvironmentValues {
    @Entry var documentPointerOpenURL: ((URL, DocumentLinkActivation) -> Void)? = nil
}

/// Captured before the first await. Additional requests never begin or own source work.
struct DocumentLocalLinkRequest {
    let source: DocumentReadSession
    let presentation: UUID
    let target: DocumentLocalTarget
    let destination: DocumentReadSession
    let token: Int
    let coordinator: DocumentOpeningCoordinator

    init(source: DocumentReadSession, presentation: UUID, target: DocumentLocalTarget,
         activation: DocumentLinkActivation, coordinator: DocumentOpeningCoordinator) {
        self.source = source
        self.presentation = presentation
        self.target = target
        self.coordinator = coordinator
        destination = activation == .additionalReader ? coordinator.destination(newWindow: true) : source
        token = destination.begin()
    }

    func run(
        classify: (URL) async throws -> LocalFileDisposition = { url in
            try await Task.detached { try LocalFileDisposition.resolve(url) }.value
        },
        open: ((DocumentLocalTarget, DocumentReadSession, Int) async throws -> Void)? = nil,
        dispatch: (LocalFileDisposition, URL) async throws -> Void = { disposition, url in
            if disposition == .reveal { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            else { _ = try await NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration()) }
        }
    ) async {
        defer { coordinator.finishLinkRequest(destination, token: token) }
        do {
            guard isCurrent else { return }
            let disposition = try await classify(target.fileURL)
            guard isCurrent else { return }
            if disposition == .markdown {
                if let open { try await open(target, destination, token) }
                else {
                    _ = try await coordinator.open(target.fileURL, fragment: target.fragment,
                                                   in: destination, token: token)
                }
            } else {
                try await dispatch(disposition, target.fileURL)
            }
        } catch is CancellationError {} catch {
            // Never look up the active reader or show a modal for an uncommitted destination.
            if isCurrent, source.isOpen, source.prepared?.id == presentation {
                source.notice = DocumentOpeningCoordinator.failureMessage(target.fileURL)
            }
        }
    }

    private var isCurrent: Bool {
        !coordinator.isTerminating && destination.accepts(token) && !Task.isCancelled
    }
}
