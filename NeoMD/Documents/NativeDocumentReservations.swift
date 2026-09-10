import Foundation

/// Counts consumers before native acquisition begins, including deduplicated opens.
nonisolated struct NativeDocumentReservations {
    private var counts: [URL: Int] = [:]
    static func key(_ url: URL) -> URL { url.standardizedFileURL.resolvingSymlinksInPath() }
    mutating func reserve(_ url: URL) { counts[Self.key(url), default: 0] += 1 }
    mutating func release(_ url: URL) {
        let key = Self.key(url)
        guard let count = counts[key] else { return }
        counts[key] = count > 1 ? count - 1 : nil
    }
    func canClose(_ url: URL, viewerCount: Int) -> Bool {
        viewerCount == 0 && counts[Self.key(url), default: 0] == 0
    }
}
