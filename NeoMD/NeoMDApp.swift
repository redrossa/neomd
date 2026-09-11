//
//  NeoMDApp.swift
//  NeoMD
//
//  Created by Reno Raksi on 9/5/26.
//

import AppKit
import SwiftUI

@main
struct NeoMDApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = NeoMDApplicationDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { application.run() }
    }
}

/// Prevents the last reader from reopening the instruction while the app is quitting.
final class NeoMDApplicationDelegate: NSObject, NSApplicationDelegate {
    let documentController = MarkdownDocumentController()
    private var menus: NativeReaderMenus?
    var openingCoordinator: DocumentOpeningCoordinator { documentController.openingCoordinator }

#if DEBUG
    /// The channel a UI test uses to change this app's appearance while it runs.
    static let uiTestAppearanceNotification = Notification.Name("io.neomd.uitest.setAppearance")

    private var uiTestAppearanceObserver: (any NSObjectProtocol)?
#endif

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        menus = NativeReaderMenus(controller: documentController)
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
        observeUITestAppearanceChanges()
#endif
    }

#if DEBUG
    /// Lets a UI test repaint this app for a different appearance while a document is
    /// open, on machines where the test runner is not permitted to change the real
    /// system setting. It exercises the same repaint macOS triggers, but it is not
    /// evidence that the app follows the system: only an unpinned launch under a real
    /// system change shows that. The observer is never installed unless a test asks
    /// for it, and does not exist in a release build.
    private func observeUITestAppearanceChanges() {
        guard ProcessInfo.processInfo.environment["NEOMD_UI_TEST_APPEARANCE_CHANNEL"] == "1"
        else { return }

        uiTestAppearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.uiTestAppearanceNotification,
            object: nil,
            queue: .main
        ) { notification in
            MainActor.assumeIsolated {
                switch notification.object as? String {
                case "Light":
                    NSApp.appearance = NSAppearance(named: .aqua)
                case "Dark":
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                default:
                    NSApp.appearance = nil
                }
            }
        }
    }
#endif

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Hosted non-interaction unit runs must never present a document picker.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
           NSClassFromString("XCTestCase") == nil {
            documentController.scheduleStartupPicker()
        }
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { true }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        documentController.explicitFileIntent()
        let destination = openingCoordinator.destination()
        let token = destination.begin()
        let url: URL
        do { url = try MarkdownDropRouting.singleFile(from: filenames.map { URL(fileURLWithPath: $0) }) }
        catch {
            openingCoordinator.report(error.localizedDescription, in: destination)
            openingCoordinator.cancelReservation(destination, token: token)
            sender.reply(toOpenOrPrint: .failure)
            return
        }
        destination.task = Task { @MainActor in
            defer { destination.finish(token) }
            do {
                _ = try await openingCoordinator.open(url, in: destination, token: token)
                sender.reply(toOpenOrPrint: .success)
            } catch {
                if !(error is CancellationError), destination.accepts(token) {
                    openingCoordinator.report(DocumentOpeningCoordinator.failureMessage(url), in: destination)
                }
                sender.reply(toOpenOrPrint: error is CancellationError ? .cancel : .failure)
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        openingCoordinator.applicationWillTerminate()
        // A successful quit awaits the bounded reading-history writes already
        // scheduled, instead of dropping the last place read on the way out.
        Task { @MainActor in
            await openingCoordinator.drainReadingHistory()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
