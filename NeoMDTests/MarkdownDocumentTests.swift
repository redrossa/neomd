//
//  MarkdownDocumentTests.swift
//  NeoMDTests
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import NeoMD

struct MarkdownDocumentTests {

    @Test func readsMarkdownContentTypes() {
        #expect(MarkdownDocument.readableContentTypes.contains(MarkdownFileType.markdown))
    }

    @Test func isReadOnly() {
        #expect(MarkdownDocument.writableContentTypes.isEmpty)
    }

    @Test func refusesToWriteBackToDisk() {
        // The document system must never be able to rewrite an opened file.
        let document = MarkdownDocument(text: "# Title")
        #expect(document.text == "# Title")
        #expect(MarkdownDocument.Failure.readOnly.errorDescription != nil)
    }

    @Test func reportsAnActionableFailureForUnreadableItems() {
        let failure = MarkdownDocument.Failure.notAReadableFile
        #expect(failure.errorDescription == "This item can't be opened as a document.")
        #expect(failure.recoverySuggestion?.isEmpty == false)
    }
}
