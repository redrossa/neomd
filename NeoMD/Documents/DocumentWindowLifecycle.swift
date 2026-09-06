//
//  DocumentWindowLifecycle.swift
//  NeoMD
//

import Foundation

/// Pure state for coordinating document windows with the no-file instruction window.
///
/// A set makes repeated SwiftUI appearance callbacks harmless and lets the coordinator
/// distinguish closing one reader from closing the final reader.
nonisolated struct DocumentWindowLifecycle {
    enum Directive: Equatable {
        case none
        case showNoDocumentWindow
        case hideNoDocumentWindow
    }

    private(set) var openDocumentWindowIDs: Set<UUID> = []
    private(set) var isTerminating = false

    var shouldShowNoDocumentWindow: Bool {
        openDocumentWindowIDs.isEmpty && !isTerminating
    }

    mutating func documentWindowDidAppear(id: UUID) -> Directive {
        openDocumentWindowIDs.insert(id)
        return .hideNoDocumentWindow
    }

    mutating func documentWindowDidDisappear(id: UUID) -> Directive {
        guard openDocumentWindowIDs.remove(id) != nil else { return .none }
        return shouldShowNoDocumentWindow ? .showNoDocumentWindow : .none
    }

    mutating func applicationWillTerminate() -> Directive {
        isTerminating = true
        return .hideNoDocumentWindow
    }
}
