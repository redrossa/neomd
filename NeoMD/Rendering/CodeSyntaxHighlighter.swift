import Foundation

nonisolated enum CodeLanguage: String, Sendable, CaseIterable {
    case swift, python, javascript, typescript, json, shell, markdown

    init?(infoString: String?) {
        switch infoString?.split(whereSeparator: \.isWhitespace).first?.lowercased() {
        case "swift": self = .swift
        case "python", "py": self = .python
        case "javascript", "js": self = .javascript
        case "typescript", "ts": self = .typescript
        case "json": self = .json
        case "shell", "sh", "bash", "zsh": self = .shell
        case "markdown", "md": self = .markdown
        default: return nil
        }
    }
}

nonisolated enum MarkdownCodeToken: String, Sendable, CaseIterable {
    case keyword, string, comment, number, key
    case heading, emphasis, codeSpan, link, marker
}

nonisolated enum MarkdownCodeTokenAttribute: AttributedStringKey {
    typealias Value = MarkdownCodeToken
    static let name = "NeoMD.CodeToken"
}

/// A deliberately small lexical baseline, not a compiler. Never executes or rewrites code.
/// Scanning is linear over Unicode scalars, with bounded lookahead. Blocks above 256 Ki
/// scalars remain plain: all content survives without allocating a token/index table.
nonisolated enum CodeSyntaxHighlighter {
    static let maximumHighlightedScalars = 262_144

    static func highlight(_ text: AttributedString, language: CodeLanguage) -> AttributedString {
        guard text.unicodeScalars.count <= maximumHighlightedScalars else { return text }
        let scalars = Array(text.unicodeScalars)
        var scanner = Scanner(scalars: scalars, language: language)
        let tokens = scanner.scan()
        var indices = Array(text.unicodeScalars.indices)
        indices.append(text.endIndex)
        var result = text
        for (range, token) in tokens {
            result[indices[range.lowerBound]..<indices[range.upperBound]].markdownCodeToken = token
        }
        return result
    }

    private struct Scanner {
        let scalars: [Unicode.Scalar]
        let language: CodeLanguage
        var cursor = 0
        var tokens: [(Range<Int>, MarkdownCodeToken)] = []

        var keywords: Set<String> {
            switch language {
            case .swift:
                Set("actor as async await break case catch class continue default defer deinit do else enum extension fallthrough false fileprivate for func guard if import in init inout internal is let nil nonisolated open operator private protocol public repeat rethrows return self some static struct subscript super switch throw throws true try typealias var weak where while".split(separator: " ").map(String.init))
            case .python:
                Set("and as assert async await break class continue def del elif else except False finally for from global if import in is lambda None nonlocal not or pass raise return True try while with yield".split(separator: " ").map(String.init))
            case .javascript, .typescript:
                Set("abstract as async await break case catch class const continue declare default delete do else enum export extends false finally for from function if implements import in instanceof interface let new null of private protected public readonly return static super switch this throw true try type typeof undefined var void while yield".split(separator: " ").map(String.init))
            case .json: ["true", "false", "null"]
            case .shell: ["if", "then", "else", "elif", "fi", "for", "in", "do", "done", "while", "case", "esac", "function", "export", "local", "return"]
            case .markdown: []
            }
        }

        mutating func scan() -> [(Range<Int>, MarkdownCodeToken)] {
            let words = keywords
            while cursor < scalars.count {
                let start = cursor
                if language == .markdown {
                    scanMarkdown()
                } else if starts("//") && [.swift, .javascript, .typescript].contains(language) {
                    line(); add(start, .comment)
                } else if starts("/*") && [.swift, .javascript, .typescript].contains(language) {
                    delimited("/*", closing: "*/"); add(start, .comment)
                } else if starts("#") && [.python, .shell].contains(language) {
                    line(); add(start, .comment)
                } else if scalars[cursor] == "\"" || (scalars[cursor] == "'" && language != .json)
                            || (scalars[cursor] == "`" && [.javascript, .typescript, .shell].contains(language)) {
                    let quote = String(scalars[cursor])
                    let triple = String(repeating: quote, count: 3)
                    let delimiter = [.swift, .python].contains(language) && starts(triple) ? triple : quote
                    delimited(delimiter, closing: delimiter, escaping: true)
                    var next = cursor
                    while next < scalars.count && CharacterSet.whitespacesAndNewlines.contains(scalars[next]) { next += 1 }
                    add(start, language == .json && next < scalars.count && scalars[next] == ":" ? .key : .string)
                } else if isDigit(scalars[cursor]) {
                    cursor += 1
                    while cursor < scalars.count && (isDigit(scalars[cursor]) || "._xXabcdefABCDEF".unicodeScalars.contains(scalars[cursor])) { cursor += 1 }
                    add(start, .number)
                } else if isWord(scalars[cursor]) {
                    cursor += 1
                    while cursor < scalars.count && (isWord(scalars[cursor]) || isDigit(scalars[cursor])) { cursor += 1 }
                    let word = String(String.UnicodeScalarView(scalars[start..<cursor]))
                    if words.contains(word) { add(start, .keyword) }
                } else {
                    cursor += 1
                }
                assert(cursor > start)
            }
            return tokens
        }

        mutating func scanMarkdown() {
            let start = cursor
            let atLineStart = cursor == 0 || scalars[cursor - 1] == "\n"
            if starts("<!--") {
                delimited("<!--", closing: "-->"); add(start, .comment)
            } else if atLineStart && starts("#") {
                line(); add(start, .heading)
            } else if atLineStart && (starts("```") || starts("~~~")) {
                line(); add(start, .marker)
            } else if atLineStart && (starts(">") || starts("- ") || starts("* ") || starts("+ ")) {
                cursor += 1; add(start, .marker)
            } else if atLineStart && isDigit(scalars[cursor]) {
                while cursor < scalars.count && isDigit(scalars[cursor]) { cursor += 1 }
                if cursor < scalars.count && scalars[cursor] == "." { cursor += 1; add(start, .marker) }
            } else if starts("`") {
                delimited("`", closing: "`", escaping: true); add(start, .codeSpan)
            } else if starts("*") || starts("_") {
                let delimiter = String(scalars[cursor])
                delimited(delimiter, closing: delimiter, escaping: true); add(start, .emphasis)
            } else if starts("[") {
                delimited("[", closing: "]", escaping: true)
                if starts("(") { delimited("(", closing: ")", escaping: true) }
                add(start, .link)
            } else { cursor += 1 }
        }

        func starts(_ text: String) -> Bool {
            let pattern = Array(text.unicodeScalars)
            guard cursor + pattern.count <= scalars.count else { return false }
            return scalars[cursor..<(cursor + pattern.count)].elementsEqual(pattern)
        }

        mutating func line() {
            while cursor < scalars.count && scalars[cursor] != "\n" { cursor += 1 }
        }

        mutating func delimited(_ opening: String, closing: String, escaping: Bool = false) {
            cursor += opening.unicodeScalars.count
            while cursor < scalars.count {
                if escaping && scalars[cursor] == "\\" { cursor = min(cursor + 2, scalars.count) }
                else if starts(closing) { cursor += closing.unicodeScalars.count; return }
                else { cursor += 1 }
            }
        }

        mutating func add(_ start: Int, _ token: MarkdownCodeToken) {
            tokens.append((start..<cursor, token))
        }

        func isDigit(_ scalar: Unicode.Scalar) -> Bool { scalar.value >= 48 && scalar.value <= 57 }
        func isWord(_ scalar: Unicode.Scalar) -> Bool {
            CharacterSet.letters.contains(scalar) || scalar == "_" || scalar == "$"
        }
    }
}
