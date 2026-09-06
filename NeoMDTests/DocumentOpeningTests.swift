//
//  DocumentOpeningTests.swift
//  NeoMDTests
//

import Foundation
import Testing
@testable import NeoMD

struct DocumentOpeningTests {

    @Test func firstDocumentHidesTheInstructionAndLastCloseReturnsIt() {
        var lifecycle = DocumentWindowLifecycle()
        let windowID = UUID()

        #expect(lifecycle.documentWindowDidAppear(id: windowID) == .hideNoDocumentWindow)
        #expect(!lifecycle.shouldShowNoDocumentWindow)
        #expect(lifecycle.documentWindowDidDisappear(id: windowID) == .showNoDocumentWindow)
        #expect(lifecycle.shouldShowNoDocumentWindow)
    }

    @Test func closingOneOfMultipleDocumentsDoesNotShowTheInstruction() {
        var lifecycle = DocumentWindowLifecycle()
        let firstWindowID = UUID()
        let secondWindowID = UUID()

        _ = lifecycle.documentWindowDidAppear(id: firstWindowID)
        _ = lifecycle.documentWindowDidAppear(id: secondWindowID)

        #expect(lifecycle.documentWindowDidDisappear(id: firstWindowID) == .none)
        #expect(lifecycle.openDocumentWindowIDs == [secondWindowID])
        #expect(lifecycle.documentWindowDidDisappear(id: secondWindowID) == .showNoDocumentWindow)
    }

    @Test func repeatedAppearanceCallbacksAreIdempotent() {
        var lifecycle = DocumentWindowLifecycle()
        let windowID = UUID()

        _ = lifecycle.documentWindowDidAppear(id: windowID)
        _ = lifecycle.documentWindowDidAppear(id: windowID)

        #expect(lifecycle.openDocumentWindowIDs.count == 1)
        #expect(lifecycle.documentWindowDidDisappear(id: windowID) == .showNoDocumentWindow)
        #expect(lifecycle.documentWindowDidDisappear(id: windowID) == .none)
    }

    @Test func terminationSuppressesAReplacementWindow() {
        var lifecycle = DocumentWindowLifecycle()
        let windowID = UUID()

        _ = lifecycle.documentWindowDidAppear(id: windowID)
        #expect(lifecycle.applicationWillTerminate() == .hideNoDocumentWindow)
        #expect(lifecycle.documentWindowDidDisappear(id: windowID) == .none)
        #expect(!lifecycle.shouldShowNoDocumentWindow)
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
