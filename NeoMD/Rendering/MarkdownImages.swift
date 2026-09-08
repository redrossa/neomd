import Foundation
import CoreGraphics

nonisolated struct MarkdownImage: Hashable, Sendable {
    let source: URL?
    let lightSource: URL?
    let darkSource: URL?
    var occurrence: String? = nil

    func url(preferringDark: Bool) -> URL? {
        (preferringDark ? darkSource : lightSource) ?? source
    }
}

nonisolated enum MarkdownImageAttribute: AttributedStringKey {
    typealias Value = MarkdownImage
    static let name = "NeoMD.Image"
}

nonisolated enum MarkdownImageLayout {
    static func displaySize(natural: CGSize, availableWidth: CGFloat) -> CGSize {
        guard natural.width.isFinite, natural.height.isFinite, availableWidth.isFinite,
              natural.width > 0, natural.height > 0, availableWidth > 0 else { return .zero }
        let width = min(natural.width, availableWidth)
        return CGSize(width: width, height: natural.height * width / natural.width)
    }
}

/// Deliberately limited to the documented standalone appearance-source picture form.
/// Unsupported HTML remains literal; no web engine or document scripts are involved.
nonisolated enum MarkdownPictureParser {
    static let emptyAltCarrier = "\u{FFFC}"

    static func parse(_ html: String, documentURL: URL?) -> (image: MarkdownImage, alt: String)? {
        guard let outer = captures(#"^\s*<picture\s*>([\s\S]*?)</picture\s*>\s*$"#, in: html).first else { return nil }
        let body = outer[1]
        let tags = captures(#"<\s*(source|img)\b((?:[^>\"']|\"[^\"]*\"|'[^']*')*)/?>"#, in: body)
        let remainder = body.replacingOccurrences(of: #"<\s*(source|img)\b((?:[^>\"']|\"[^\"]*\"|'[^']*')*)/?>"#,
                                                  with: "", options: [.regularExpression, .caseInsensitive])
        guard remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var fallback: String?
        var alt = ""
        var light: URL?
        var dark: URL?
        for tag in tags {
            guard let attributes = attributes(in: tag[2]) else { return nil }
            if tag[1].lowercased() == "img" {
                guard fallback == nil, let src = attributes["src"] else { return nil }
                fallback = src
                alt = attributes["alt"] ?? ""
            } else if let media = attributes["media"],
                      let scheme = captures(#"^\s*\(\s*prefers-color-scheme\s*:\s*(dark|light)\s*\)\s*$"#, in: media).first,
                      let candidate = attributes["srcset"]?.split(separator: ",").first?.split(whereSeparator: \.isWhitespace).first {
                let url = resolve(String(candidate), documentURL: documentURL)
                if scheme[1].lowercased() == "dark", dark == nil { dark = url }
                if scheme[1].lowercased() == "light", light == nil { light = url }
            }
        }
        guard let fallback else { return nil }
        return (MarkdownImage(source: resolve(fallback, documentURL: documentURL), lightSource: light, darkSource: dark), alt)
    }

    private static func resolve(_ destination: String, documentURL: URL?) -> URL? {
        guard let url = URL(string: destination) else { return nil }
        return documentURL.flatMap { DocumentLocalPath.resolve(url, relativeTo: $0)?.fileURL } ?? url
    }

    private static func attributes(in source: String) -> [String: String]? {
        let pattern = #"([\w-]+)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>\"'=<>`]+))"#
        let remainder = source.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard remainder.isEmpty || remainder == "/" else { return nil }
        var result: [String: String] = [:]
        for match in captures(pattern, in: source) {
            guard result[match[1].lowercased()] == nil else { return nil }
            let value = match.dropFirst(2).first(where: { !$0.isEmpty }) ?? ""
            result[match[1].lowercased()] = value
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&amp;", with: "&")
        }
        return result
    }

    private static func captures(_ pattern: String, in source: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        return regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).map { match in
            (0..<match.numberOfRanges).map { index in
                Range(match.range(at: index), in: source).map { String(source[$0]) } ?? ""
            }
        }
    }
}
