//
//  MarkdownDropRouting.swift
//  NeoMD
//

import Foundation

/// Selects the file URLs that a Markdown drop is allowed to open.
nonisolated enum MarkdownDropRouting {
    enum Failure: LocalizedError, Equatable {
        case empty, multiple
        var errorDescription: String? {
            switch self {
            case .empty: "Choose a Markdown file."
            case .multiple: "Open one Markdown file at a time. Use Command-N for another window."
            }
        }
    }

    static func singleFile(from urls: [URL]) throws -> URL {
        let accepted = acceptedFileURLs(from: urls)
        guard let first = accepted.first else { throw Failure.empty }
        guard accepted.count == 1 else { throw Failure.multiple }
        return first
    }

    static func acceptedFileURLs(from urls: [URL]) -> [URL] {
        urls.filter { url in
            url.isFileURL && MarkdownFileType.claimsFile(at: url)
        }
    }
}
