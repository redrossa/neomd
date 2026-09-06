//
//  DocumentOpeningCoordinator.swift
//  NeoMD
//

import Foundation

/// Shares document-window lifecycle state between independent SwiftUI scenes.
final class DocumentOpeningCoordinator {
    static let noDocumentWindowSceneID = "no-document"

    private var lifecycle = DocumentWindowLifecycle()

    var shouldShowNoDocumentWindow: Bool {
        lifecycle.shouldShowNoDocumentWindow
    }

    @discardableResult
    func documentWindowDidAppear(id: UUID) -> DocumentWindowLifecycle.Directive {
        lifecycle.documentWindowDidAppear(id: id)
    }

    @discardableResult
    func documentWindowDidDisappear(id: UUID) -> DocumentWindowLifecycle.Directive {
        lifecycle.documentWindowDidDisappear(id: id)
    }

    func applicationWillTerminate() {
        _ = lifecycle.applicationWillTerminate()
    }
}
