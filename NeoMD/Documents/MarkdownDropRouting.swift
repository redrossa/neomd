//
//  MarkdownDropRouting.swift
//  NeoMD
//

import Foundation

/// Selects the file URLs that a Markdown drop is allowed to open.
nonisolated enum MarkdownDropRouting {
    static func acceptedFileURLs(from urls: [URL]) -> [URL] {
        urls.filter { url in
            url.isFileURL && MarkdownFileType.claimsFile(at: url)
        }
    }
}
