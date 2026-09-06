//
//  NeoMDApp.swift
//  NeoMD
//
//  Created by Reno Raksi on 9/5/26.
//

import SwiftUI

@main
struct NeoMDApp: App {
    var body: some Scene {
        // A viewing document group gives NeoMD the standard macOS open path: Finder's
        // Open With, double-clicking a Markdown file whether or not the app is already
        // running, and File > Open — with no save prompt on close, because the group is
        // read-only.
        DocumentGroup(viewing: MarkdownDocument.self) { configuration in
            DocumentReaderView(document: configuration.document)
        }
        .defaultSize(width: 900, height: 720)
    }
}
