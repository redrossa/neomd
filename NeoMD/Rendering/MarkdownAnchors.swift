import Foundation

/// Document-local GitHub-style heading identifiers.
nonisolated struct MarkdownAnchorSlugger {
    private var issued: Set<String> = []

    mutating func slug(for text: AttributedString) -> String {
        var visible = ""
        for run in text.runs where run.markdownGeneratedReference == nil {
            visible += String(text.characters[run.range])
        }
        let allowed = CharacterSet.letters.union(.decimalDigits).union(.nonBaseCharacters)
        let base = String(String.UnicodeScalarView(visible.lowercased().unicodeScalars.filter {
            allowed.contains($0) || [.letterNumber, .otherNumber, .connectorPunctuation].contains($0.properties.generalCategory) || $0 == "-" || $0 == " "
        })).replacingOccurrences(of: " ", with: "-")
        var candidate = base
        var suffix = 0
        while issued.contains(candidate) {
            suffix += 1
            candidate = "\(base)-\(suffix)"
        }
        issued.insert(candidate)
        return candidate
    }
}

/// Allocations are indexed by occurrence/definition identity by the caller. Reserve
/// every preferred name up front so a collision suffix cannot steal a later name.
nonisolated struct MarkdownGeneratedAnchorAllocator {
    private var used: Set<String>
    private let preferred: Set<String>

    init(authored: [String], preferred: [String]) {
        used = Set(authored)
        self.preferred = Set(preferred)
    }

    mutating func allocate(_ name: String) -> String {
        if used.insert(name).inserted { return name }
        var suffix = 1
        while used.contains("\(name)-\(suffix)") || preferred.contains("\(name)-\(suffix)") {
            suffix += 1
        }
        let result = "\(name)-\(suffix)"
        used.insert(result)
        return result
    }

    static func url(for anchor: String) -> URL {
        var components = URLComponents()
        components.fragment = anchor
        return components.url!
    }
}
