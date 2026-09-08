//
//  DocumentOpeningCoordinator.swift
//  NeoMD
//

import Foundation
import Observation

/// Shares document-window lifecycle state between independent SwiftUI scenes.
@Observable final class DocumentOpeningCoordinator {
    static let noDocumentWindowSceneID = "no-document"

    private var lifecycle = DocumentWindowLifecycle()
    let folderAccess = FolderAccessSession()
    private var sectionRequests: [URL: SectionRequest] = [:]
    private var requestSerial = 0

    struct SectionRequest: Equatable {
        let serial: Int
        let fragment: String
    }

    /// A no-fragment open explicitly supersedes any unconsumed section request.
    @discardableResult
    func requestSection(_ fragment: String?, in fileURL: URL) -> SectionRequest? {
        requestSerial += 1
        let request = fragment.map { SectionRequest(serial: requestSerial, fragment: $0) }
        sectionRequests[canonical(fileURL)] = request
        return request
    }

    func sectionRequest(for fileURL: URL) -> SectionRequest? {
        sectionRequests[canonical(fileURL)]
    }

    func takeSectionRequest(for fileURL: URL) -> SectionRequest? {
        sectionRequests.removeValue(forKey: canonical(fileURL))
    }

    func cancelSectionRequest(_ request: SectionRequest?, for fileURL: URL) {
        let key = canonical(fileURL)
        guard let request, sectionRequests[key] == request else { return }
        sectionRequests.removeValue(forKey: key)
    }

    private func canonical(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

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
        folderAccess.endSession()
    }
}
