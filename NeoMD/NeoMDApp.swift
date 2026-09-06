//
//  NeoMDApp.swift
//  NeoMD
//
//  Created by Reno Raksi on 9/5/26.
//

import AppKit
import SwiftUI

@main
struct NeoMDApp: App {
    @NSApplicationDelegateAdaptor(NeoMDApplicationDelegate.self)
    private var applicationDelegate

    var body: some Scene {
        // A viewing document group gives NeoMD the standard macOS open path: Finder's
        // Open With, double-clicking a Markdown file whether or not the app is already
        // running, and File > Open — with no save prompt on close, because the group is
        // read-only.
        DocumentGroup(viewing: MarkdownDocument.self) { configuration in
            DocumentReaderView(
                document: configuration.document,
                openingCoordinator: applicationDelegate.openingCoordinator
            )
        }
        .defaultSize(width: 900, height: 720)
        // A viewer normally forces an Open panel at launch. The instruction scene is
        // the default instead; explicit Finder, Dock, menu, and keyboard opens still
        // create document scenes.
        .defaultLaunchBehavior(.suppressed)

        Window("NeoMD", id: DocumentOpeningCoordinator.noDocumentWindowSceneID) {
            NoDocumentView(openingCoordinator: applicationDelegate.openingCoordinator)
        }
        .defaultSize(width: 900, height: 720)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(replacing: .saveItem) { }
        }
    }
}

/// Prevents the last reader from reopening the instruction while the app is quitting.
final class NeoMDApplicationDelegate: NSObject, NSApplicationDelegate {
    let openingCoordinator = DocumentOpeningCoordinator()

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        openingCoordinator.applicationWillTerminate()
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
