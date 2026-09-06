//
//  MarkdownFileType.swift
//  NeoMD
//

import Foundation
import UniformTypeIdentifiers

/// The document types NeoMD can open.
///
/// The identifier and its filename extensions are declared as an imported type in
/// the app's `Info.plist`, which is what lets Finder offer NeoMD in Open With and
/// launch the app when a Markdown file is double-clicked.
nonisolated enum MarkdownFileType {

    /// The Daring Fireball Markdown type, the identifier macOS already uses for `.md` files.
    static let markdown = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)

    /// Every content type NeoMD advertises as readable.
    static let readableContentTypes: [UTType] = [markdown]

    /// Filename extensions the app claims, lowercased.
    ///
    /// Kept in sync with the `UTTypeTagSpecification` entry in `Info.plist`.
    static let filenameExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mdtext"]

    /// Whether `url` names a file NeoMD claims, ignoring extension case so that
    /// `Notes.MD` is recognized exactly like `notes.md`.
    static func claimsFile(at url: URL) -> Bool {
        filenameExtensions.contains(url.pathExtension.lowercased())
    }
}
