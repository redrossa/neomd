//
//  MarkdownBlockRenderer.swift
//  NeoMD
//

import Foundation

/// Semantic inline formatting; presentation stays in the reader theme.
nonisolated enum MarkdownInlineStyle: String, Sendable {
    case subscriptText, superscriptText, underline
}

nonisolated enum MarkdownInlineStyleAttribute: AttributedStringKey {
    typealias Value = MarkdownInlineStyle
    static let name = "NeoMD.InlineStyle"
}

extension AttributeScopes {
    nonisolated struct MarkdownAttributes: AttributeScope {
        let markdownInlineStyle: MarkdownInlineStyleAttribute
        let markdownCodeToken: MarkdownCodeTokenAttribute
    }

    nonisolated var markdown: MarkdownAttributes.Type { MarkdownAttributes.self }
}

extension AttributeDynamicLookup {
    nonisolated subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.MarkdownAttributes, T>
    ) -> T { self[T.self] }
}

/// One rendered leaf or quote/list container, with document-order identity.
nonisolated struct MarkdownBlock: Identifiable, Sendable {

    /// How a block should be presented.
    nonisolated enum Kind: Equatable, Sendable {
        case paragraph
        case heading(level: Int)
        case codeBlock(language: String?)
        case blockQuote
        case listItem(marker: String, depth: Int)
        case thematicBreak
    }

    /// Position of the block in the document, stable for the lifetime of a rendering.
    let id: Int
    let kind: Kind
    /// The block's text with inline formatting applied and Markdown syntax removed.
    let text: AttributedString
    var children: [MarkdownBlock] = []

    var leaves: [MarkdownBlock] {
        children.isEmpty ? [self] : children.flatMap(\.leaves)
    }

    /// Every descendant resolves to the directly addressable lazy-stack target.
    static func lazyAncestors(in blocks: [MarkdownBlock]) -> [Int: Int] {
        var result: [Int: Int] = [:]
        func visit(_ block: MarkdownBlock, ancestor: Int) {
            result[block.id] = ancestor
            for child in block.children { visit(child, ancestor: ancestor) }
        }
        for block in blocks { visit(block, ancestor: block.id) }
        return result
    }
}

/// Converts Markdown source into presentable blocks.
///
/// Foundation supplies semantic leaves and ancestry. Identity-based folding preserves
/// quote/list order and marker ownership; code keeps its literal scalars and receives
/// supplementary lexical token attributes. Presentation remains in the theme/views.
///
/// The renderer is pure and free of UI state so it can run off the main thread and be
/// unit tested directly.
nonisolated enum MarkdownBlockRenderer {

    /// Renders `markdown` into blocks, in document order.
    ///
    /// Malformed input never fails the open: the parser returns what it could
    /// understand, and a total failure falls back to the source as a single paragraph.
    static func blocks(from markdown: String) -> [MarkdownBlock] {
        guard !markdown.isEmpty else { return [] }

        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .full
        options.appliesSourcePositionAttributes = true
        options.failurePolicy = .returnPartiallyParsedIfPossible

        let parsed: AttributedString
        do {
            let attributed = try AttributedString(markdown: markdown, options: options)
            parsed = applyingInlineHTML(recoveringLinkHTML(attributed, source: markdown))
        } catch {
            return [MarkdownBlock(id: 0, kind: .paragraph, text: AttributedString(markdown))]
        }

        var entries: [Entry] = []
        for (intent, range) in parsed.runs[\.presentationIntent] {
            let kind = kind(for: intent)
            var text = AttributedString(parsed[range])
            text.presentationIntent = nil
            if case .codeBlock(let hint) = kind {
                // Parser-provided boundary blank lines are content, not separators.
                if let language = CodeLanguage(infoString: hint) {
                    text = CodeSyntaxHighlighter.highlight(text, language: language)
                }
            } else {
                text = trimmed(text, keepingIndentation: false)
            }
            guard !text.characters.isEmpty || kind == .thematicBreak else { continue }
            entries.append(Entry(kind: kind, text: text, ancestry: ancestry(for: intent)))
        }
        var cursor = 0
        var nextID = 0
        return fold(entries, cursor: &cursor, depth: 0, parent: nil, nextID: &nextID)
    }

    private struct Ancestor {
        let identity: Int
        let kind: MarkdownBlock.Kind
    }

    private struct Entry {
        let kind: MarkdownBlock.Kind
        let text: AttributedString
        let ancestry: [Ancestor]
    }

    /// Keep the actual outer-to-inner order: a quote in a list is not a list in a quote.
    private static func ancestry(for intent: PresentationIntent?) -> [Ancestor] {
        var result: [Ancestor] = []
        var ordered = false
        var depth = 0
        for component in (intent?.components ?? []).reversed() {
            switch component.kind {
            case .orderedList: ordered = true
            case .unorderedList: ordered = false
            case .listItem(let ordinal):
                depth += 1
                result.append(Ancestor(identity: component.identity, kind: .listItem(
                    marker: ordered ? "\(ordinal)." : unorderedMarker(depth: depth), depth: depth
                )))
            case .blockQuote:
                result.append(Ancestor(identity: component.identity, kind: .blockQuote))
            default: break
            }
        }
        return result
    }

    /// A single cursor consumes each leaf once; containers own markers and boundaries.
    private static func fold(
        _ entries: [Entry], cursor: inout Int, depth: Int, parent: Int?, nextID: inout Int
    ) -> [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        while cursor < entries.count {
            let entry = entries[cursor]
            if let parent, entry.ancestry.count < depth || entry.ancestry[depth - 1].identity != parent {
                break
            }
            let id = nextID
            nextID += 1
            if entry.ancestry.count > depth {
                let ancestor = entry.ancestry[depth]
                let children = fold(entries, cursor: &cursor, depth: depth + 1,
                                    parent: ancestor.identity, nextID: &nextID)
                result.append(MarkdownBlock(id: id, kind: ancestor.kind,
                                            text: AttributedString(), children: children))
            } else {
                result.append(MarkdownBlock(id: id, kind: entry.kind, text: entry.text))
                cursor += 1
            }
        }
        return result
    }

    /// Foundation flattens link labels. Recover only parser-confirmed HTML provenance,
    /// never inferred tags in rendered text; code and escaped labels can look identical.
    private static func recoveringLinkHTML(_ parsed: AttributedString, source: String) -> AttributedString {
        var result = parsed
        for run in parsed.runs where run.link != nil {
            guard let position = run.markdownSourcePosition,
                  var range = Range<String.Index>(position, in: source) else { continue }
            // Source positions omit code delimiters at either edge of a label.
            while range.lowerBound > source.startIndex,
                  source[source.index(before: range.lowerBound)] == "`" {
                range = source.index(before: range.lowerBound)..<range.upperBound
            }
            while range.upperBound < source.endIndex, source[range.upperBound] == "`" {
                range = range.lowerBound..<source.index(after: range.upperBound)
            }
            guard var label = try? AttributedString(
                markdown: String(source[range]),
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) else { continue }
            if !label.unicodeScalars.elementsEqual(parsed.unicodeScalars[run.range]) {
                guard var candidate = try? AttributedString(
                    markdown: String(source[range]), options: .init(interpretedSyntax: .full)
                ) else { continue }
                // Full link parsing omits semantic breaks, but preserves code-span spaces.
                // Normalize only the temporary parser-marked provenance candidate.
                let breaks = candidate.runs.filter {
                    $0.inlinePresentationIntent?.contains(.softBreak) == true ||
                    $0.inlinePresentationIntent?.contains(.lineBreak) == true
                }.map(\.range)
                for range in breaks.reversed() { candidate.removeSubrange(range) }
                label = candidate
            }
            guard label.unicodeScalars.elementsEqual(parsed.unicodeScalars[run.range]) else { continue }
            for token in label.runs where token.inlinePresentationIntent?.contains(.inlineHTML) == true {
                let lower = parsed.unicodeScalars.index(run.range.lowerBound, offsetBy:
                    label.unicodeScalars.distance(from: label.startIndex, to: token.range.lowerBound))
                let upper = parsed.unicodeScalars.index(lower, offsetBy:
                    label.unicodeScalars.distance(from: token.range.lowerBound, to: token.range.upperBound))
                var intent = parsed[lower..<upper].inlinePresentationIntent ?? []
                intent.insert(.inlineHTML)
                result[lower..<upper].inlinePresentationIntent = intent
            }
        }
        return result
    }

    private struct HTMLTag {
        let name: String
        let closing: Bool
        let range: Range<AttributedString.Index>

        var style: MarkdownInlineStyle? {
            switch name {
            case "sub": .subscriptText
            case "sup": .superscriptText
            case "ins": .underline
            default: nil
            }
        }
    }

    /// Only complete, properly nested groups of supported inline wrappers are consumed.
    /// A malformed group remains literal, including any otherwise matched inner pair.
    /// Work within a presentation block: wrappers never leak into another paragraph or code.
    private static func applyingInlineHTML(_ parsed: AttributedString) -> AttributedString {
        var output = AttributedString()
        for (_, range) in parsed.runs[\.presentationIntent] {
            output.append(stylingInlineHTML(AttributedString(parsed[range])))
        }
        return output
    }

    private static func stylingInlineHTML(_ text: AttributedString) -> AttributedString {
        guard text.runs.contains(where: { $0.inlinePresentationIntent?.contains(.inlineHTML) == true }) else {
            return text
        }
        // The Markdown parser has already identified HTML, excluding escaped text and code.
        // Quoted attribute values may contain >; attributes themselves are never interpreted.
        // Tokenize entire tags (including unsupported ones), not apparent tags inside
        // an attribute or comment. Unsupported markup is never removed or interpreted.
        let pattern = #"<!--[\s\S]*?-->|<\s*(/?)\s*([a-zA-Z][a-zA-Z0-9-]*)(?=\s|/?>)(?:[^>\"']|\"[^\"]*\"|'[^']*')*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        var tags: [HTMLTag] = []
        for run in text.runs where run.inlinePresentationIntent?.contains(.inlineHTML) == true {
            let source = String(String.UnicodeScalarView(text.unicodeScalars[run.range]))
            for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                guard let matchRange = Range(match.range, in: source),
                      let nameRange = Range(match.range(at: 2), in: source),
                      !source[matchRange].hasSuffix("/>") else { continue }
                let lower = text.unicodeScalars.index(
                    run.range.lowerBound,
                    offsetBy: source.unicodeScalars.distance(from: source.startIndex, to: matchRange.lowerBound)
                )
                let upper = text.unicodeScalars.index(lower, offsetBy: source.unicodeScalars[matchRange].count)
                tags.append(HTMLTag(
                    name: source[nameRange].lowercased(),
                    closing: match.range(at: 1).length > 0,
                    range: lower..<upper
                ))
            }
        }

        var stack: [HTMLTag] = []
        var pending: [(HTMLTag, HTMLTag)] = []
        var pairs: [(HTMLTag, HTMLTag)] = []
        for tag in tags {
            if !tag.closing {
                stack.append(tag)
            } else if let opening = stack.last, opening.name == tag.name {
                stack.removeLast()
                if opening.style != nil { pending.append((opening, tag)) }
                if stack.isEmpty {
                    pairs.append(contentsOf: pending)
                    pending.removeAll()
                }
            } else {
                // Crossing tags invalidate the whole in-flight group, not just the closer.
                stack.removeAll()
                pending.removeAll()
            }
        }

        var result = text
        // Outer first, then inner, so nested sub/sup use the innermost style.
        for (opening, closing) in pairs.sorted(by: { $0.0.range.lowerBound < $1.0.range.lowerBound }) {
            result[opening.range.upperBound..<closing.range.lowerBound].markdownInlineStyle = opening.style
        }
        let removals = pairs.flatMap { [$0.0.range, $0.1.range] }
            .sorted { $0.lowerBound > $1.lowerBound }
        for range in removals { result.removeSubrange(range) }
        return result
    }

    /// Maps a run's presentation intent onto a block kind.
    private static func kind(for intent: PresentationIntent?) -> MarkdownBlock.Kind {
        guard let intent else { return .paragraph }

        var headingLevel: Int?
        var codeKind: MarkdownBlock.Kind?
        var isThematicBreak = false

        for component in intent.components {
            switch component.kind {
            case .header(let level):
                headingLevel = headingLevel ?? level
            case .codeBlock(let hint):
                codeKind = .codeBlock(language: hint?.split(whereSeparator: \.isWhitespace).first.map { $0.lowercased() })
            case .thematicBreak:
                isThematicBreak = true
            default:
                break
            }
        }

        if isThematicBreak { return .thematicBreak }
        if let headingLevel { return .heading(level: min(max(headingLevel, 1), 6)) }
        if let codeKind { return codeKind }
        return .paragraph
    }

    /// The bullet used at a given nesting depth, mirroring the usual Markdown convention.
    private static func unorderedMarker(depth: Int) -> String {
        switch (depth - 1) % 3 {
        case 0: "\u{2022}"
        case 1: "\u{25E6}"
        default: "\u{25AA}"
        }
    }

    /// Removes the blank space blocks pick up from their separators.
    ///
    /// Inline code keeps every parser-normalized scalar, including boundary spaces.
    private static func trimmed(_ text: AttributedString, keepingIndentation: Bool) -> AttributedString {
        var text = text
        let isTrimmable: (Character) -> Bool = keepingIndentation
            ? { $0.isNewline }
            : { $0.isWhitespace }

        while let first = text.characters.first, isTrimmable(first) {
            let range = text.startIndex..<text.characters.index(after: text.startIndex)
            guard !text[range].runs.contains(where: { $0.inlinePresentationIntent?.contains(.code) == true }) else { break }
            text.removeSubrange(range)
        }
        while let last = text.characters.last, last.isNewline || (!keepingIndentation && last.isWhitespace) {
            let range = text.characters.index(text.endIndex, offsetBy: -1)..<text.endIndex
            guard !text[range].runs.contains(where: { $0.inlinePresentationIntent?.contains(.code) == true }) else { break }
            text.removeSubrange(range)
        }
        return text
    }
}
