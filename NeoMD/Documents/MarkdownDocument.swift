//
//  MarkdownDocument.swift
//  NeoMD
//

import SwiftUI
import UniformTypeIdentifiers

/// A Markdown file opened for reading.
///
/// The type is deliberately read-only: it advertises no writable content types and
/// refuses to produce a file wrapper, so opening, reading, and closing a document can
/// never rewrite its bytes or touch its modification date.
nonisolated struct MarkdownDocument: FileDocument {

    /// A failure encountered while opening a document.
    nonisolated enum Failure: LocalizedError, Equatable {
        /// The item handed to the app was a folder or an unreadable file.
        case notAReadableFile
        /// Something asked NeoMD to write a document back to disk.
        case readOnly

        var errorDescription: String? {
            switch self {
            case .notAReadableFile: "This item can't be opened as a document."
            case .readOnly: "NeoMD opens documents for reading only."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .notAReadableFile: "Choose a Markdown file such as notes.md."
            case .readOnly: nil
            }
        }
    }

    static let readableContentTypes: [UTType] = MarkdownFileType.readableContentTypes

    /// Empty on purpose. NeoMD never saves.
    static let writableContentTypes: [UTType] = []

    /// The document's source text, decoded once when the file is opened.
    let text: String

    init(text: String = "") {
        self.text = text
    }

    /// Reads the file's bytes. SwiftUI performs this off the main thread, so the
    /// reading view is only ever handed decoded text and never renders raw source
    /// while a document is loading.
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw Failure.notAReadableFile
        }
        text = try MarkdownTextDecoder.text(from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw Failure.readOnly
    }
}
