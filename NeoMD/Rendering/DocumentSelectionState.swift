import Foundation

/// The value-side authority of one reader. Native adapters retain only their own
/// token; neither a late detach nor a cancelled acquisition can release a successor.
nonisolated struct DocumentSelectionState: Sendable {
    struct Scope: Equatable, Sendable {
        let reader: UUID
        let presentation: UUID
        let generation: Int
    }

    struct Registration: Equatable, Sendable {
        let scope: Scope
        let key: DocumentTextProjection.Key
        let token: UUID
    }

    struct Operation: Equatable, Sendable {
        let scope: Scope
        let token: UUID
    }

    let scope: Scope
    private(set) var projection: DocumentTextProjection
    private(set) var selection: DocumentTextProjection.Selection?
    private(set) var operation: Operation?
    private(set) var registrations: [DocumentTextProjection.Key: Registration] = [:]

    init(reader: UUID, generation: Int, projection: DocumentTextProjection) {
        scope = Scope(reader: reader, presentation: projection.presentation, generation: generation)
        self.projection = projection
    }

    @discardableResult
    mutating func register(_ key: DocumentTextProjection.Key, scope: Scope) -> Registration? {
        guard scope == self.scope, projection.fragment(for: key) != nil else { return nil }
        let registration = Registration(scope: scope, key: key, token: UUID())
        registrations[key] = registration
        return registration
    }

    mutating func unregister(_ registration: Registration) {
        guard registrations[registration.key] == registration else { return }
        registrations.removeValue(forKey: registration.key)
    }

    func accepts(_ registration: Registration) -> Bool {
        registration.scope == scope && registrations[registration.key] == registration
    }

    @discardableResult
    mutating func beginOperation() -> Operation {
        let next = Operation(scope: scope, token: UUID())
        operation = next
        return next
    }

    @discardableResult
    mutating func finishOperation(_ token: Operation) -> Bool {
        guard operation == token else { return false }
        operation = nil
        return true
    }

    @discardableResult
    mutating func setSelection(_ next: DocumentTextProjection.Selection?, scope: Scope) -> Bool {
        guard scope == self.scope else { return false }
        if let next, projection.fragment(for: next.anchor.key) == nil || projection.fragment(for: next.extent.key) == nil {
            return false
        }
        selection = next
        return true
    }

    var copiedText: String { selection.map { projection.copiedText(for: $0) } ?? "" }

    func slice(for registration: Registration) -> NSRange? {
        guard accepts(registration), let selection else { return nil }
        return projection.slices(for: selection).first { $0.key == registration.key }?.range
    }

    /// The mounted native adapter uses MarkdownCellDisplayProjection to remap an
    /// endpoint before publishing a genuine content replacement. Decoration-only
    /// changes have no reason to call this method.
    @discardableResult
    mutating func replace(_ fragment: DocumentTextProjection.Fragment,
                          registration: Registration,
                          remap: (Int) -> Int) -> Bool {
        guard accepts(registration), registration.key == fragment.key else { return false }
        func endpoint(_ endpoint: DocumentTextProjection.Endpoint) -> DocumentTextProjection.Endpoint {
            guard endpoint.key == fragment.key else { return endpoint }
            return .init(key: endpoint.key, offset: remap(endpoint.offset))
        }
        selection = selection.map { .init(anchor: endpoint($0.anchor), extent: endpoint($0.extent)) }
        projection = projection.replacing(fragment)
        return true
    }
}

/// Kept independently of history and find state. The session transfers this value
/// only after accepting a same-document refresh and scopes consumption to its new host.
nonisolated struct DocumentSelectionTransfer: Sendable {
    let presentation: UUID
    private(set) var descriptor: DocumentTextProjection.RefreshDescriptor?

    mutating func take(for presentation: UUID) -> DocumentTextProjection.RefreshDescriptor? {
        guard self.presentation == presentation else { return nil }
        defer { descriptor = nil }
        return descriptor
    }
}
