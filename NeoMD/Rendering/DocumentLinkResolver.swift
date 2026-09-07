import Foundation

nonisolated enum DocumentLinkDestination: Equatable {
    case block(Int), top, missing(String), external

    static func resolve(url: URL, anchors: [String: Int]) -> Self {
        guard url.scheme == nil, url.host == nil, url.path.isEmpty,
              let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment else {
            return .external
        }
        guard !fragment.isEmpty else { return .top }
        if let id = anchors[fragment] { return .block(id) }
        // Stable fallback chooses the earliest block, not Dictionary iteration order.
        if let id = anchors.filter({ $0.key.caseInsensitiveCompare(fragment) == .orderedSame })
            .map(\.value).min() { return .block(id) }
        return .missing(fragment)
    }
}
