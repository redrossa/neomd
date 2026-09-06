//
//  MarkdownBlockRenderer.swift
//  NeoMD
//

import Foundation

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
        options.failurePolicy = .returnPartiallyParsedIfPossible

        let parsed: AttributedString
        do {
            parsed = try AttributedString(markdown: markdown, options: options)
        } catch {
            return [MarkdownBlock(id: 0, kind: .paragraph, text: AttributedString(markdown))]
        }

        var blocks: [MarkdownBlock] = []
        for (intent, range) in parsed.runs[\.presentationIntent] {
            let kind = kind(for: intent)
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
