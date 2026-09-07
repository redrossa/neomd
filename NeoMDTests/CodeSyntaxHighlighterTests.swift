import Foundation
import Testing
@testable import NeoMD

struct CodeSyntaxHighlighterTests {
    @Test func baselineLanguagesHaveExactSemanticRanges() throws {
        let cases: [(CodeLanguage, String, [(String, MarkdownCodeToken)])] = [
            (.swift, "let x = 42 // comment\n\"a\\\"b\"", [("let", .keyword), ("42", .number), ("// comment", .comment), ("\"a\\\"b\"", .string)]),
            (.python, "def f(): # comment\n return '''a\nb'''", [("def", .keyword), ("# comment", .comment), ("'''a\nb'''", .string)]),
            (.javascript, "const x = `hello ${name}`; /* note */", [("const", .keyword), ("`hello ${name}`", .string), ("/* note */", .comment)]),
            (.typescript, "interface X { readonly n: 12 }", [("interface", .keyword), ("readonly", .keyword), ("12", .number)]),
            (.json, "{\"key\": \"value\", \"n\": 2, \"b\": true}", [("\"key\"", .key), ("\"value\"", .string), ("2", .number), ("true", .keyword)]),
            (.shell, "if true; then\n echo \"hello\" # note\nfi", [("if", .keyword), ("then", .keyword), ("\"hello\"", .string), ("# note", .comment)]),
            (.markdown, "# Heading\n*emphasis* `code` [link](url)\n- item\n<!-- note -->", [("# Heading", .heading), ("*emphasis*", .emphasis), ("`code`", .codeSpan), ("[link](url)", .link), ("-", .marker), ("<!-- note -->", .comment)])
        ]
        for (language, source, expected) in cases {
            let text = CodeSyntaxHighlighter.highlight(AttributedString(source), language: language)
            #expect(text.unicodeScalars.elementsEqual(source.unicodeScalars))
            for (spelling, token) in expected {
                let range = try #require(text.range(of: spelling))
                #expect(text[range].markdownCodeToken == token)
                let run = try #require(text.runs.first { $0.range == range })
                #expect(run.markdownCodeToken == token)
            }
        }
    }

    @Test func aliasesAndPlainFallback() {
        for (aliases, language): ([String], CodeLanguage) in [
            (["swift", "Swift extra"], .swift), (["python", "py"], .python),
            (["javascript", "js"], .javascript), (["typescript", "ts"], .typescript),
            (["json"], .json), (["shell", "sh", "bash", "zsh"], .shell), (["markdown", "md"], .markdown)
        ] {
            for alias in aliases { #expect(CodeLanguage(infoString: alias) == language) }
        }
        for hint: String? in [nil, "", "rust", "{.swift}"] {
            #expect(CodeLanguage(infoString: hint) == nil)
            let blocks = MarkdownBlockRenderer.blocks(from: "```\(hint ?? "")\nlet x = 1\n```")
            #expect(blocks[0].text.runs.allSatisfy { $0.markdownCodeToken == nil })
        }
    }

    @Test func multilineEscapesUnicodeAndMalformedInputsKeepEveryScalar() {
        for language in CodeLanguage.allCases {
            for source in ["\"unterminated\\", "/* unterminated", "'''triple\nline'''", "\"\"\"Swift\nmultiline\"\"\"", "👩🏽‍💻e\u{0301} 日本語\n", String(repeating: "let x = 1; ", count: 10_000)] {
                let result = CodeSyntaxHighlighter.highlight(AttributedString(source), language: language)
                #expect(result.unicodeScalars.elementsEqual(source.unicodeScalars))
            }
        }
        let source = String(repeating: "x", count: 1_048_576)
        let result = CodeSyntaxHighlighter.highlight(AttributedString(source), language: .swift)
        #expect(result.unicodeScalars.elementsEqual(source.unicodeScalars))
        #expect(result.runs.allSatisfy { $0.markdownCodeToken == nil })
        let highlighted = CodeSyntaxHighlighter.highlight(AttributedString("let " + String(repeating: "x", count: 100_000)), language: .swift)
        #expect(highlighted.runs.first?.markdownCodeToken == .keyword)
    }
}
