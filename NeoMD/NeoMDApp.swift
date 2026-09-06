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
            .focusedSceneValue(\.closeWindowTargetAvailable, true)
        }
        .defaultSize(width: 900, height: 720)
        // A viewer normally forces an Open panel at launch. The instruction scene is
        // the default instead; explicit Finder, Dock, menu, and keyboard opens still
        // create document scenes.
        .defaultLaunchBehavior(.suppressed)

        Window("NeoMD", id: DocumentOpeningCoordinator.noDocumentWindowSceneID) {
            NoDocumentView(openingCoordinator: applicationDelegate.openingCoordinator)
                .focusedSceneValue(\.closeWindowTargetAvailable, true)
        }
        .defaultSize(width: 900, height: 720)
        .defaultLaunchBehavior(.presented)
        .commands {
            ReadOnlyFileCommands()
        }
    }
}

private struct CloseWindowTargetKey: FocusedValueKey {
    typealias Value = Bool
}

private extension FocusedValues {
    var closeWindowTargetAvailable: Bool? {
        get { self[CloseWindowTargetKey.self] }
        set { self[CloseWindowTargetKey.self] = newValue }
    }
}

/// Removes saving while retaining a responder-chain Close command for the focused scene.
private struct ReadOnlyFileCommands: Commands {
    @FocusedValue(\.closeWindowTargetAvailable)
    private var closeWindowTargetAvailable

    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Close") {
                NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("w")
            .disabled(closeWindowTargetAvailable != true)
        }
    }
}

/// Prevents the last reader from reopening the instruction while the app is quitting.
final class NeoMDApplicationDelegate: NSObject, NSApplicationDelegate {
    let openingCoordinator = DocumentOpeningCoordinator()

    func applicationWillFinishLaunching(_ notification: Notification) {
#if DEBUG
        // Keep visual UI regressions deterministic without changing the user's system
        // appearance. Ordinary launches leave this unset and continue to follow macOS.
        switch ProcessInfo.processInfo.environment["NEOMD_UI_TEST_APPEARANCE"] {
        case "Light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "Dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            break
        }
#endif
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        openingCoordinator.applicationWillTerminate()
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
