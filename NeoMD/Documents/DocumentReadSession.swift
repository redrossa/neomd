import Foundation
import Observation

nonisolated struct PreparedReadingDocument: Sendable {
    let id = UUID()
    let text: String
    let fileURL: URL
    let rendered: MarkdownRenderDocument
    /// Copied content identities for this rendering, built with it off the main actor
    /// so capturing a reading position stays a small value copy.
    let index: DocumentContentIndex

    init(text: String, fileURL: URL, rendered: MarkdownRenderDocument) {
        self.text = text
        self.fileURL = fileURL
        self.rendered = rendered
        index = DocumentContentIndex(rendered)
    }

    /// A distinct presentation of one settled refresh result, for one viewer.
    init(_ payload: DocumentRefreshPayload) {
        text = payload.text
        fileURL = payload.fileURL
        rendered = payload.rendered
        index = payload.index
    }
}

/// A position restoration handed across a successful presentation replacement.
/// The view consumes it once, for the matching presentation only.
nonisolated struct ReadingPositionRequest: Equatable, Sendable {
    enum Reason: Equatable, Sendable {
        case refresh
        /// A remembered position restored on a successful new or replacement reopen.
        case reopenHistory
    }

    let presentation: UUID
    let serial: Int
    let anchor: DocumentReadingAnchor
    let reason: Reason
}

/// Authority to install one settled external revision in one viewer.
nonisolated struct RefreshTicket: Equatable, Sendable {
    let binding: UUID
    let session: UUID
    let presentation: UUID
    let generation: Int
    let revision: UInt64
}

/// Request state is independent of native windows and can be tested without UI.
@Observable final class DocumentReadSession {
    let id = UUID()
    private(set) var isOpen = true
    private(set) var generation = 0
    var prepared: PreparedReadingDocument?
    var notice: String?
    var section: SectionRequest?
    /// Quiet background-refresh status, deliberately separate from `notice` so a
    /// transient link or open message is never overwritten or announced again.
    private(set) var refreshStatus: String?
    /// Restoration for the presentation that was just installed, consumed once.
    private(set) var readingPosition: ReadingPositionRequest?
    @ObservationIgnored var task: Task<Void, Never>?
    /// The native document identity this viewer currently shows.
    @ObservationIgnored var binding: UUID?
    /// Set while the reader is scrolling, navigating or restoring a position.
    @ObservationIgnored var isUserBusy = false
    @ObservationIgnored private var capture: (presentation: UUID, locator: DocumentContentLocator)?
    @ObservationIgnored private var restorationSerial = 0
    /// Set by the opening coordinator so an accepted capture also reaches the private
    /// reading history. Capture itself stays a small value copy in the reader.
    @ObservationIgnored var positionObserver: ((DocumentContentLocator, URL) -> Void)?

    struct SectionRequest: Equatable {
        let presentation: UUID
        let serial: Int
        let fragment: String
    }

    @discardableResult func begin() -> Int {
        task?.cancel()
        task = nil
        generation += 1
        section = nil
        return generation
    }
    func accepts(_ token: Int) -> Bool { isOpen && token == generation }
    func close() { isOpen = false; _ = begin() }
    func finish(_ token: Int) { if token == generation { task = nil } }
    func stage(token: Int, prepare: () async throws -> PreparedReadingDocument) async throws -> PreparedReadingDocument {
        guard accepts(token), !Task.isCancelled else { throw CancellationError() }
        let input = try await prepare()
        guard accepts(token), !Task.isCancelled else { throw CancellationError() }
        return input
    }
    func commit(_ input: PreparedReadingDocument, fragment: String?, token: Int) -> Bool {
        guard accepts(token) else { return false }
        prepared = input
        notice = nil
        refreshStatus = nil
        readingPosition = nil
        capture = nil
        section = fragment.map { SectionRequest(presentation: input.id, serial: token, fragment: $0) }
        return true
    }
    func navigate(_ fragment: String?) {
        let token = begin()
        // An explicit destination always outranks an automatic refresh restoration.
        readingPosition = nil
        section = fragment.flatMap { fragment in
            prepared.map { SectionRequest(presentation: $0.id, serial: token, fragment: fragment) }
        }
    }
    func takeSection(for presentation: UUID) -> SectionRequest? {
        guard section?.presentation == presentation else { return nil }
        defer { section = nil }
        return section
    }

    // MARK: External refresh

    /// Copies the reader's current position for the installed presentation only.
    func recordReadingPosition(_ locator: DocumentContentLocator, presentation: UUID) {
        guard isOpen, let prepared, prepared.id == presentation else { return }
        capture = (presentation, locator)
        positionObserver?(locator, prepared.fileURL)
    }

    /// Hands a remembered position to the presentation that was just installed. The
    /// view consumes it once; an explicit section request still outranks it.
    func requestReadingPosition(_ anchor: DocumentReadingAnchor, presentation: UUID,
                                reason: ReadingPositionRequest.Reason) {
        guard isOpen, prepared?.id == presentation, section == nil else { return }
        restorationSerial += 1
        readingPosition = ReadingPositionRequest(presentation: presentation,
                                                 serial: restorationSerial,
                                                 anchor: anchor, reason: reason)
    }

    func capturedPosition(for presentation: UUID) -> DocumentContentLocator? {
        guard let capture, capture.presentation == presentation else { return nil }
        return capture.locator
    }

    /// Authority to install a settled revision, or nil while this viewer is busy,
    /// closed, bound elsewhere or already showing a different presentation.
    func refreshTicket(binding: UUID, revision: UInt64) -> RefreshTicket? {
        guard isOpen, self.binding == binding, let prepared,
              task == nil, section == nil, !isUserBusy else { return nil }
        return RefreshTicket(binding: binding, session: id, presentation: prepared.id,
                             generation: generation, revision: revision)
    }

    /// Installs a settled external revision in one synchronous transaction.
    ///
    /// This is deliberately not `begin()`: an external write must not cancel a user's
    /// open request, clear an explicit section or take over `task`.
    func commitRefresh(_ input: PreparedReadingDocument, ticket: RefreshTicket,
                       restoration: DocumentReadingAnchor?) -> Bool {
        guard isOpen, ticket.session == id, ticket.binding == binding,
              ticket.generation == generation, prepared?.id == ticket.presentation,
              task == nil, section == nil, !isUserBusy else { return false }
        restorationSerial += 1
        prepared = input
        refreshStatus = nil
        capture = nil
        readingPosition = restoration.map {
            ReadingPositionRequest(presentation: input.id, serial: restorationSerial,
                                   anchor: $0, reason: .refresh)
        }
        return true
    }

    func takeReadingPosition(for presentation: UUID) -> ReadingPositionRequest? {
        guard readingPosition?.presentation == presentation else { return nil }
        defer { readingPosition = nil }
        return readingPosition
    }

    /// A quiet, deduplicated refresh failure that keeps the last good rendering.
    func reportRefreshFailure(_ message: String) {
        guard isOpen, prepared != nil, refreshStatus != message else { return }
        refreshStatus = message
    }

    func clearRefreshStatus() {
        guard refreshStatus != nil else { return }
        refreshStatus = nil
    }
}
