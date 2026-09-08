import AppKit
import ImageIO

nonisolated enum MarkdownImageFailure: Equatable, Sendable {
    case missing, inaccessible, undecodable, unavailable
}

nonisolated enum MarkdownImageLoadResult: Sendable {
    case loaded(CGImage, natural: CGSize)
    case unavailable(MarkdownImageFailure)
}

/// Called from a detached task. Only concrete bitmap storage crosses to the UI;
/// in particular, deferred vector representations remain local to this decoder.
nonisolated enum MarkdownImageLoader {
    static func load(_ url: URL) async -> MarkdownImageLoadResult {
        guard !Task.isCancelled else { return .unavailable(.unavailable) }
        let data: Data
        if url.isFileURL {
            switch LocalFileAccessProbe.state(of: url) {
            case .missing: return .unavailable(.missing)
            case .inaccessible: return .unavailable(.inaccessible)
            case .readable(let directory):
                guard !directory else { return .unavailable(.undecodable) }
            }
            do { data = try Data(contentsOf: url) }
            catch { return .unavailable(.inaccessible) }
        } else {
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return .unavailable(.unavailable) }
            do {
                let (body, response) = try await URLSession.shared.data(from: url)
                guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                    return .unavailable(.unavailable)
                }
                data = body
            } catch { return .unavailable(.unavailable) }
        }
        guard !Task.isCancelled else { return .unavailable(.unavailable) }
        return decode(data)
    }

    static func decode(_ data: Data) -> MarkdownImageLoadResult {
        autoreleasepool {
            if let source = CGImageSourceCreateWithData(data as CFData, nil),
               let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) {
                return .loaded(image, natural: CGSize(width: image.width, height: image.height))
            }
            guard let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else {
                return .unavailable(.undecodable)
            }
            let bitmap = image.representations.first { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }
            let natural = bitmap.map { CGSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? image.size
            var rect = CGRect(origin: .zero, size: image.size)
            guard let raster = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
                return .unavailable(.undecodable)
            }
            return .loaded(raster, natural: natural)
        }
    }
}
