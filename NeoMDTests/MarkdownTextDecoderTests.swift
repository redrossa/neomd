//
//  MarkdownTextDecoderTests.swift
//  NeoMDTests
//

import Foundation
import Testing
@testable import NeoMD

struct MarkdownTextDecoderTests {

    @Test func decodesUTF8() throws {
        let data = Data("# Title\n\nBody".utf8)
        #expect(try MarkdownTextDecoder.text(from: data) == "# Title\n\nBody")
    }

    @Test func decodesUnicodeContent() throws {
        let source = "# Réunion — été 2026\n\n日本語のメモ 🎉"
        let decoded = try MarkdownTextDecoder.text(from: Data(source.utf8))
        #expect(decoded == source)
    }

    @Test func stripsUTF8ByteOrderMark() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("# Title".utf8))
        #expect(try MarkdownTextDecoder.text(from: data) == "# Title")
    }

    @Test func decodesUTF16WithByteOrderMark() throws {
        let source = "# Título\n\nCuerpo"
        let data = try #require(source.data(using: .utf16))
        #expect(try MarkdownTextDecoder.text(from: data) == source)
    }

    @Test func normalizesWindowsAndClassicMacLineEndings() throws {
        let data = Data("# Title\r\n\r\nBody\rMore".utf8)
        #expect(try MarkdownTextDecoder.text(from: data) == "# Title\n\nBody\nMore")
    }

    @Test func decodesEmptyDataAsEmptyText() throws {
        #expect(try MarkdownTextDecoder.text(from: Data()) == "")
    }

    @Test func fallsBackRatherThanFailingOnNonUTF8Bytes() throws {
        // Latin-1 "café" is not valid UTF-8, but the document should still open.
        let data = Data([0x63, 0x61, 0x66, 0xE9])
        let decoded = try MarkdownTextDecoder.text(from: data)
        #expect(decoded.hasPrefix("caf"))
        #expect(decoded.count == 4)
    }

    @Test func describesAnUnreadableEncodingWithoutImplementationDetail() {
        let failure = MarkdownTextDecoder.Failure.unrecognizedTextEncoding
        #expect(failure.errorDescription == "This file isn't readable as text.")
        #expect(failure.recoverySuggestion?.isEmpty == false)
    }
}
