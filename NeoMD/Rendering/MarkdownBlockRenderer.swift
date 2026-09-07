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
    }

    nonisolated var markdown: MarkdownAttributes.Type { MarkdownAttributes.self }
}

extension AttributeDynamicLookup {
    nonisolated subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.MarkdownAttributes, T>
    ) -> T { self[T.self] }
}

/// One rendered block of a Markdown document.
nonisolated struct MarkdownBlock: Identifiable, Sendable {

    /// How a block should be presented.
    nonisolated enum Kind: Equatable, Sendable {
        case paragraph
        case heading(level: Int)
        case codeBlock
        case blockQuote
        case listItem(marker: String, depth: Int)
        case thematicBreak
    }

    /// Position of the block in the document, stable for the lifetime of a rendering.
    let id: Int
    let kind: Kind
    /// The block's text with inline formatting applied and Markdown syntax removed.
    let text: AttributedString
}

/// Converts Markdown source into presentable blocks.
///
/// This is a first, deliberately small presentation pass so an opened document shows
/// rendered content rather than raw syntax. Full GitHub-style typography belongs to the
/// later reading stories and will replace the styling, not this parsing boundary.
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

        var blocks: [MarkdownBlock] = []
        var emittedListItems: Set<Int> = []
        for (intent, range) in parsed.runs[\.presentationIntent] {
            var kind = kind(for: intent)
            if case .listItem(_, let depth) = kind,
               let item = intent?.components.first(where: {
                   if case .listItem = $0.kind { return true }
                   return false
               }), !emittedListItems.insert(item.identity).inserted {
                kind = .listItem(marker: "", depth: depth)
            }
            var text = AttributedString(parsed[range])
            text.presentationIntent = nil
            text = trimmed(text, keepingIndentation: kind == .codeBlock)

            if kind == .thematicBreak {
                blocks.append(MarkdownBlock(id: blocks.count, kind: kind, text: AttributedString()))
                continue
            }
            guard !text.characters.isEmpty else { continue }
            blocks.append(MarkdownBlock(id: blocks.count, kind: kind, text: text))
        }
        return blocks
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
            guard let label = try? AttributedString(
                markdown: String(source[range]),
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ), label.unicodeScalars.elementsEqual(parsed.unicodeScalars[run.range]) else { continue }
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
        var listDepth = 0
        var ordinal: Int?
        var isOrderedList = false
        var isCodeBlock = false
        var isBlockQuote = false
        var isThematicBreak = false

        for component in intent.components {
            switch component.kind {
            case .header(let level):
                headingLevel = headingLevel ?? level
            case .codeBlock:
                isCodeBlock = true
            case .blockQuote:
                isBlockQuote = true
            case .thematicBreak:
                isThematicBreak = true
            case .listItem(let value):
                listDepth += 1
                if ordinal == nil { ordinal = value }
            case .orderedList:
                if listDepth <= 1 { isOrderedList = true }
            default:
                break
            }
        }

        if isThematicBreak { return .thematicBreak }
        if let headingLevel { return .heading(level: min(max(headingLevel, 1), 6)) }
        if isCodeBlock { return .codeBlock }
        if listDepth > 0 {
            let marker = isOrderedList ? "\(ordinal ?? 1)." : unorderedMarker(depth: listDepth)
            return .listItem(marker: marker, depth: listDepth)
        }
        if isBlockQuote { return .blockQuote }
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
    /// Code blocks keep leading indentation, which is part of their content.
    private static func trimmed(_ text: AttributedString, keepingIndentation: Bool) -> AttributedString {
        var text = text
        let isTrimmable: (Character) -> Bool = keepingIndentation
            ? { $0.isNewline }
            : { $0.isWhitespace }

        while let first = text.characters.first, isTrimmable(first) {
            text.removeSubrange(text.startIndex..<text.characters.index(after: text.startIndex))
        }
        while let last = text.characters.last, last.isNewline || (!keepingIndentation && last.isWhitespace) {
            text.removeSubrange(text.characters.index(text.endIndex, offsetBy: -1)..<text.endIndex)
        }
        return text
    }
}
