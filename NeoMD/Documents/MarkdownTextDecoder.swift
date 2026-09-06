//
//  MarkdownTextDecoder.swift
//  NeoMD
//

import Foundation

/// Turns the bytes of a Markdown file into text.
///
/// Decoding never writes to the source file; it only reads data the document system
/// has already handed to the app.
nonisolated enum MarkdownTextDecoder {

    /// A failure that leaves the reader with nothing to display.
    nonisolated enum Failure: LocalizedError, Equatable {
        /// The bytes did not match any text encoding the app understands.
        case unrecognizedTextEncoding

        var errorDescription: String? {
            switch self {
            case .unrecognizedTextEncoding:
                "This file isn't readable as text."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .unrecognizedTextEncoding:
                "It may be a binary file or use a text encoding NeoMD doesn't recognize."
            }
        }
    }

    /// Decodes `data` as Markdown source text.
    ///
    /// A leading byte order mark decides the encoding when one is present. Otherwise
    /// UTF-8 is tried first, then the encoding Foundation infers from the bytes, then a
    /// single-byte fallback so a mostly readable document still opens.
    static func text(from data: Data) throws -> String {
        guard !data.isEmpty else { return "" }

        if let decoded = decodeUsingByteOrderMark(data) {
            return normalizingLineEndings(decoded)
        }
        if let decoded = String(data: data, encoding: .utf8) {
            return normalizingLineEndings(decoded)
        }
        if let decoded = decodeUsingInferredEncoding(data) {
            return normalizingLineEndings(decoded)
        }
        if let decoded = String(data: data, encoding: .isoLatin1) {
            return normalizingLineEndings(decoded)
        }
        throw Failure.unrecognizedTextEncoding
    }

    /// Decodes `data` when it starts with a byte order mark, stripping the mark itself.
    private static func decodeUsingByteOrderMark(_ data: Data) -> String? {
        let marks: [(bytes: [UInt8], encoding: String.Encoding)] = [
            ([0x00, 0x00, 0xFE, 0xFF], .utf32BigEndian),
            ([0xFF, 0xFE, 0x00, 0x00], .utf32LittleEndian),
            ([0xEF, 0xBB, 0xBF], .utf8),
            ([0xFE, 0xFF], .utf16BigEndian),
            ([0xFF, 0xFE], .utf16LittleEndian),
        ]
        for mark in marks where data.starts(with: mark.bytes) {
            if let decoded = String(data: data.dropFirst(mark.bytes.count), encoding: mark.encoding) {
                return decoded
            }
        }
        return nil
    }

    /// Asks Foundation to infer an encoding from the bytes themselves.
    private static func decodeUsingInferredEncoding(_ data: Data) -> String? {
        var converted: NSString?
        let encoding = NSString.stringEncoding(
            for: data,
            encodingOptions: nil,
            convertedString: &converted,
            usedLossyConversion: nil
        )
        guard encoding != 0, let converted else { return nil }
        return converted as String
    }

    /// Presents Windows and classic Mac line endings as newlines so stray carriage
    /// returns never reach the reader. The file on disk is untouched.
    private static func normalizingLineEndings(_ text: String) -> String {
        guard text.contains("\r") else { return text }
        return text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
