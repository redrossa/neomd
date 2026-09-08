import Foundation

nonisolated struct DocumentLocalTarget: Equatable, Sendable {
    let fileURL: URL
    /// Already decoded exactly once by URLComponents.
    let fragment: String?
}

nonisolated enum DocumentLocalPath {
    static func resolve(_ url: URL, relativeTo documentURL: URL) -> DocumentLocalTarget? {
        guard url.scheme == nil, url.host == nil, documentURL.isFileURL,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              !components.path.isEmpty else { return nil }
        let path = components.path.hasPrefix("/") ? String(components.path.dropFirst()) : components.path
        return DocumentLocalTarget(
            fileURL: documentURL.deletingLastPathComponent().appendingPathComponent(path).standardizedFileURL,
            fragment: components.fragment
        )
    }
}

nonisolated enum DocumentLinkDestination: Equatable {
    case block(Int), top, missing(String), external
    case local(DocumentLocalTarget)

    static func resolve(url: URL, anchors: [String: Int], documentURL: URL? = nil) -> Self {
        if let documentURL, let target = DocumentLocalPath.resolve(url, relativeTo: documentURL) {
            return .local(target)
        }
        guard url.scheme == nil, url.host == nil, url.path.isEmpty,
              let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment else {
            return .external
        }
        return resolve(fragment: fragment, anchors: anchors)
    }

    /// Accepts decoded fragments, including literal percent signs and URL delimiters.
    static func resolve(fragment: String, anchors: [String: Int]) -> Self {
        guard !fragment.isEmpty else { return .top }
        if let id = anchors[fragment] { return .block(id) }
        // Stable fallback chooses the earliest block, not Dictionary iteration order.
        if let id = anchors.filter({ $0.key.caseInsensitiveCompare(fragment) == .orderedSame })
            .map(\.value).min() { return .block(id) }
        return .missing(fragment)
    }
}
