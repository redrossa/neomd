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

nonisolated enum MarkdownGeneratedReference: String, Sendable {
    case footnoteReference, footnoteReturn
}

nonisolated enum MarkdownGeneratedReferenceAttribute: AttributedStringKey {
    typealias Value = MarkdownGeneratedReference
    static let name = "NeoMD.GeneratedReference"
}

extension AttributeScopes {
    nonisolated struct MarkdownAttributes: AttributeScope {
        let markdownInlineStyle: MarkdownInlineStyleAttribute
        let markdownCodeToken: MarkdownCodeTokenAttribute
        let markdownGeneratedReference: MarkdownGeneratedReferenceAttribute
    }

    nonisolated var markdown: MarkdownAttributes.Type { MarkdownAttributes.self }
}

extension AttributeDynamicLookup {
    nonisolated subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.MarkdownAttributes, T>
    ) -> T { self[T.self] }
}

/// Immutable checklist status, never an editable control value.
nonisolated enum MarkdownTaskState: Equatable, Sendable {
    case incomplete, complete
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
        case footnote(ordinal: Int)
        case anchor
    }

    /// Position of the block in the document, stable for the lifetime of a rendering.
    let id: Int
    let kind: Kind
    /// The block's text with inline formatting applied and Markdown syntax removed.
    let text: AttributedString
    var children: [MarkdownBlock] = []
    let task: MarkdownTaskState?
    var anchors: [String]

    init(id: Int, kind: Kind, text: AttributedString,
         children: [MarkdownBlock] = [], task: MarkdownTaskState? = nil, anchors: [String] = []) {
        self.id = id
        self.kind = kind
        self.text = text
        self.children = children
        self.task = task
        self.anchors = anchors
    }

    var leaves: [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        var stack = [self]
        while let block = stack.popLast() {
            if block.children.isEmpty { result.append(block) }
            else { stack.append(contentsOf: block.children.reversed()) }
        }
        return result
    }

    static func anchorTargets(in blocks: [MarkdownBlock]) -> [String: Int] {
        var result: [String: Int] = [:]
        var stack = Array(blocks.reversed())
        while let block = stack.popLast() {
            for anchor in block.anchors where result[anchor] == nil { result[anchor] = block.id }
            stack.append(contentsOf: block.children.reversed())
        }
        return result
    }

    /// Every descendant resolves to the directly addressable lazy-stack target.
    static func lazyAncestors(in blocks: [MarkdownBlock]) -> [Int: Int] {
        var result: [Int: Int] = [:]
        var stack = blocks.reversed().map { ($0, $0.id) }
        while let (block, ancestor) = stack.popLast() {
            result[block.id] = ancestor
            stack.append(contentsOf: block.children.reversed().map { ($0, ancestor) })
        }
        return result
    }
}

/// Converts Markdown source into presentable blocks.
///
/// The pinned cmark-gfm AST supplies semantic leaves and ancestry. Code keeps its
/// literal scalars and receives supplementary lexical token attributes.
/// Presentation remains in the theme/views.
///
/// The renderer is pure and free of UI state so it can run off the main thread and be
/// unit tested directly.
nonisolated enum MarkdownBlockRenderer {

    /// Renders `markdown` into blocks, in document order.
    ///
    /// Malformed syntax remains readable according to cmark-gfm's recovery rules.
    static func blocks(from markdown: String) -> [MarkdownBlock] {
        guard !markdown.isEmpty else { return [] }

        let document = CMarkDocument(markdown: markdown)
        return CMarkBlockAdapter(document: document).blocks()
    }


    private struct HTMLTag {
        let name: String
        let closing: Bool
        let range: Range<AttributedString.Index>
        var anchor: String? = nil

        var style: MarkdownInlineStyle? {
            switch name {
            case "sub": .subscriptText
            case "sup": .superscriptText
            case "ins": .underline
            default: nil
            }
        }
    }

    /// Only complete, properly nested inline wrappers are consumed within a leaf.
    static func inlineHTML(_ text: AttributedString) -> (text: AttributedString, anchors: [String]) {
        guard text.runs.contains(where: { $0.inlinePresentationIntent?.contains(.inlineHTML) == true }) else {
            return (text, [])
        }
        // The Markdown parser has already identified HTML, excluding escaped text and code.
        // Quoted attribute values may contain >; attributes themselves are never interpreted.
        // Tokenize entire tags (including unsupported ones), not apparent tags inside
        // an attribute or comment. Unsupported markup is never removed or interpreted.
        let pattern = #"<!--[\s\S]*?-->|<\s*(/?)\s*([a-zA-Z][a-zA-Z0-9-]*)(?=\s|/?>)(?:[^>\"']|\"[^\"]*\"|'[^']*')*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return (text, [])
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
                    range: lower..<upper,
                    anchor: source[nameRange].lowercased() == "a"
                        ? customAnchor(in: String(source[matchRange])) : nil
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
                if opening.style != nil || opening.anchor != nil { pending.append((opening, tag)) }
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
            if let style = opening.style {
                result[opening.range.upperBound..<closing.range.lowerBound].markdownInlineStyle = style
            }
        }
        let removals = pairs.flatMap { [$0.0.range, $0.1.range] }
            .sorted { $0.lowerBound > $1.lowerBound }
        for range in removals { result.removeSubrange(range) }
        let anchors = pairs.sorted { $0.0.range.lowerBound < $1.0.range.lowerBound }.compactMap { $0.0.anchor }
        return (result, anchors)
    }

    private static func customAnchor(in tag: String) -> String? {
        let pattern = #"(?<=\s)([a-zA-Z_:][a-zA-Z0-9_:.-]*)(?:\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+)))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        var anchor: String?
        for match in regex.matches(in: tag, range: NSRange(tag.startIndex..., in: tag)) {
            guard let nameRange = Range(match.range(at: 1), in: tag) else { continue }
            let name = tag[nameRange].lowercased()
            if name == "href" { return nil }
            if anchor == nil, name == "id" || name == "name" {
                for group in 2...4 {
                    if let range = Range(match.range(at: group), in: tag) { anchor = String(tag[range]); break }
                }
            }
        }
        return anchor
    }

    /// The bullet used at a given nesting depth, mirroring the usual Markdown convention.
    static func unorderedMarker(depth: Int) -> String {
        switch (depth - 1) % 3 {
        case 0: "\u{2022}"
        case 1: "\u{25E6}"
        default: "\u{25AA}"
        }
    }

    /// Removes the blank space blocks pick up from their separators.
    ///
    /// Inline code keeps every parser-normalized scalar, including boundary spaces.
    static func trimmed(_ text: AttributedString, keepingIndentation: Bool) -> AttributedString {
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
