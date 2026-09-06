//
//  MarkdownFileTypeTests.swift
//  NeoMDTests
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import NeoMD

struct MarkdownFileTypeTests {

    @Test func advertisesTheSystemMarkdownIdentifier() {
        #expect(MarkdownFileType.markdown.identifier == "net.daringfireball.markdown")
        #expect(MarkdownFileType.markdown.conforms(to: .plainText))
        #expect(MarkdownFileType.readableContentTypes == [MarkdownFileType.markdown])
    }

    @Test func claimsLowercaseMarkdownExtensions() {
        #expect(MarkdownFileType.claimsFile(at: URL(fileURLWithPath: "/tmp/notes.md")))
        #expect(MarkdownFileType.claimsFile(at: URL(fileURLWithPath: "/tmp/notes.markdown")))
    }

    @Test func claimsUppercaseExtensions() {
        #expect(MarkdownFileType.claimsFile(at: URL(fileURLWithPath: "/tmp/NOTES.MD")))
        #expect(MarkdownFileType.claimsFile(at: URL(fileURLWithPath: "/tmp/Notes.Md")))
    }

    @Test func claimsNamesWithSpacesAndUnicode() {
        #expect(MarkdownFileType.claimsFile(at: URL(fileURLWithPath: "/tmp/Meeting notes 2026.md")))
        #expect(MarkdownFileType.claimsFile(at: URL(fileURLWithPath: "/tmp/réunion été — résumé.MD")))
        #expect(MarkdownFileType.claimsFile(at: URL(fileURLWithPath: "/tmp/日本語のメモ.markdown")))
    }

    @Test func doesNotClaimOtherFiles() {
        #expect(!MarkdownFileType.claimsFile(at: URL(fileURLWithPath: "/tmp/notes.txt")))
        #expect(!MarkdownFileType.claimsFile(at: URL(fileURLWithPath: "/tmp/notes")))
        #expect(!MarkdownFileType.claimsFile(at: URL(fileURLWithPath: "/tmp/notes.mdx")))
    }
}
