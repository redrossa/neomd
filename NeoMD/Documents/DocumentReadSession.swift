import Foundation
import Observation

nonisolated struct PreparedReadingDocument: Sendable {
    let id = UUID()
    let text: String
    let fileURL: URL
    let rendered: MarkdownRenderDocument
}

/// Request state is independent of native windows and can be tested without UI.
@Observable final class DocumentReadSession {
    let id = UUID()
    private(set) var isOpen = true
    private(set) var generation = 0
    var prepared: PreparedReadingDocument?
    var notice: String?
    var section: SectionRequest?
    @ObservationIgnored var task: Task<Void, Never>?

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
        section = fragment.map { SectionRequest(presentation: input.id, serial: token, fragment: $0) }
        return true
    }
    func navigate(_ fragment: String?) {
        let token = begin()
        section = fragment.flatMap { fragment in
            prepared.map { SectionRequest(presentation: $0.id, serial: token, fragment: fragment) }
        }
    }
    func takeSection(for presentation: UUID) -> SectionRequest? {
        guard section?.presentation == presentation else { return nil }
        defer { section = nil }
        return section
    }
}
