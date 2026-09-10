//
//  DocumentOpeningTests.swift
//  NeoMDTests
//

import Foundation
import Testing
@testable import NeoMD

struct DocumentOpeningTests {
    @Test @MainActor func sectionRequestsAreKeyedByCanonicalURLAndConsumedOnce() throws {
        let coordinator = DocumentOpeningCoordinator()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("file.md")
        try Data().write(to: file)
        let alias = folder.appendingPathComponent("alias.md")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: file)
        let old = coordinator.requestSection("old", in: alias)
        let newer = coordinator.requestSection("café%20#?", in: file)
        coordinator.cancelSectionRequest(old, for: file)
        #expect(coordinator.sectionRequest(for: alias) == newer)
        #expect(coordinator.takeSectionRequest(for: alias) == newer)
        #expect(coordinator.takeSectionRequest(for: file) == nil)
        coordinator.requestSection("stale", in: file)
        coordinator.requestSection(nil, in: alias)
        #expect(coordinator.takeSectionRequest(for: file) == nil)
        let failed = coordinator.requestSection("failed", in: file)
        coordinator.cancelSectionRequest(failed, for: alias)
        #expect(coordinator.takeSectionRequest(for: file) == nil)
    }


    @Test func firstDocumentHidesTheInstructionAndLastCloseStaysWindowless() {
        var lifecycle = DocumentWindowLifecycle()
        let windowID = UUID()

        #expect(lifecycle.documentWindowDidAppear(id: windowID) == .hideNoDocumentWindow)
        #expect(!lifecycle.shouldShowNoDocumentWindow)
        #expect(lifecycle.documentWindowDidDisappear(id: windowID) == .none)
        #expect(lifecycle.openDocumentWindowIDs.isEmpty)
        #expect(!lifecycle.isTerminating)
    }

    @Test func closingOneOfMultipleDocumentsDoesNotShowTheInstruction() {
        var lifecycle = DocumentWindowLifecycle()
        let firstWindowID = UUID()
        let secondWindowID = UUID()

        _ = lifecycle.documentWindowDidAppear(id: firstWindowID)
        _ = lifecycle.documentWindowDidAppear(id: secondWindowID)

        #expect(lifecycle.documentWindowDidDisappear(id: firstWindowID) == .none)
        #expect(lifecycle.openDocumentWindowIDs == [secondWindowID])
        #expect(lifecycle.documentWindowDidDisappear(id: secondWindowID) == .none)
        #expect(lifecycle.openDocumentWindowIDs.isEmpty)
    }

    @Test func repeatedAppearanceCallbacksAreIdempotent() {
        var lifecycle = DocumentWindowLifecycle()
        let windowID = UUID()

        _ = lifecycle.documentWindowDidAppear(id: windowID)
        _ = lifecycle.documentWindowDidAppear(id: windowID)

        #expect(lifecycle.openDocumentWindowIDs.count == 1)
        #expect(lifecycle.documentWindowDidDisappear(id: windowID) == .none)
        #expect(lifecycle.documentWindowDidDisappear(id: windowID) == .none)
        #expect(lifecycle.openDocumentWindowIDs.isEmpty)
    }

    @Test func terminationSuppressesAReplacementWindow() {
        var lifecycle = DocumentWindowLifecycle()
        let windowID = UUID()

        _ = lifecycle.documentWindowDidAppear(id: windowID)
        #expect(lifecycle.applicationWillTerminate() == .hideNoDocumentWindow)
        #expect(lifecycle.documentWindowDidDisappear(id: windowID) == .none)
        #expect(!lifecycle.shouldShowNoDocumentWindow)
    }

    @Test func unknownClosesAndRepeatedReopenCyclesNeverRequestReplacementUI() {
        var lifecycle = DocumentWindowLifecycle()
        let windowID = UUID()
        #expect(lifecycle.documentWindowDidDisappear(id: UUID()) == .none)
        for _ in 0..<3 {
            #expect(lifecycle.documentWindowDidAppear(id: windowID) == .hideNoDocumentWindow)
            #expect(lifecycle.documentWindowDidDisappear(id: UUID()) == .none)
            #expect(lifecycle.openDocumentWindowIDs == [windowID])
            #expect(lifecycle.documentWindowDidDisappear(id: windowID) == .none)
            #expect(lifecycle.documentWindowDidDisappear(id: windowID) == .none)
            #expect(lifecycle.openDocumentWindowIDs.isEmpty)
            #expect(!lifecycle.isTerminating)
        }
        #expect(lifecycle.applicationWillTerminate() == .hideNoDocumentWindow)
        #expect(lifecycle.applicationWillTerminate() == .hideNoDocumentWindow)
        #expect(lifecycle.isTerminating)
    }

    @Test @MainActor func coordinatorForwardsWindowlessCloseReopenAndTermination() {
        let coordinator = DocumentOpeningCoordinator()
        let first = UUID()
        let second = UUID()
        #expect(coordinator.documentWindowDidDisappear(id: first) == .none)
        for _ in 0..<3 {
            #expect(coordinator.documentWindowDidAppear(id: first) == .hideNoDocumentWindow)
            #expect(coordinator.documentWindowDidAppear(id: first) == .hideNoDocumentWindow)
            #expect(coordinator.documentWindowDidAppear(id: second) == .hideNoDocumentWindow)
            #expect(coordinator.documentWindowDidDisappear(id: first) == .none)
            #expect(!coordinator.shouldShowNoDocumentWindow)
            #expect(coordinator.documentWindowDidDisappear(id: second) == .none)
            #expect(coordinator.documentWindowDidDisappear(id: second) == .none)
        }
        coordinator.applicationWillTerminate()
        #expect(!coordinator.shouldShowNoDocumentWindow)
        #expect(coordinator.documentWindowDidDisappear(id: first) == .none)
    }

    @Test func dropRoutingAcceptsOnlyClaimedFileURLsInOrder() {
        let first = URL(fileURLWithPath: "/tmp/Meeting notes.MD")
        let second = URL(fileURLWithPath: "/tmp/日本語.markdown")
        let unsupported = URL(fileURLWithPath: "/tmp/notes.txt")
        let remote = URL(string: "https://example.com/readme.md")!

        #expect(
            MarkdownDropRouting.acceptedFileURLs(
                from: [unsupported, first, remote, second]
            ) == [first, second]
        )
    }

    @Test func dropRoutingRejectsAnEmptyDrop() {
        #expect(MarkdownDropRouting.acceptedFileURLs(from: []).isEmpty)
    }
}
