import Foundation
import Testing
@testable import NeoMD

@MainActor struct DocumentFindSessionTests {
    private func prepared(_ text: String) -> PreparedReadingDocument {
        PreparedReadingDocument(text: text, fileURL: URL(fileURLWithPath: "/tmp/find-model.md"),
                                rendered: MarkdownBlockRenderer.render(from: text))
    }

    @Test func findCommandsAreConsumedOnceAndRequireAnOpenDocument() throws {
        let session = DocumentReadSession()
        session.requestFind(.show)
        #expect(session.takeFindCommand() == nil)
        #expect(session.commit(prepared("body"), fragment: nil, token: session.begin()))
        session.requestFind(.show)
        let first = try #require(session.takeFindCommand())
        #expect(first.kind == .show)
        #expect(session.takeFindCommand() == nil)
        session.requestFind(.previous)
        let second = try #require(session.takeFindCommand())
        #expect(second.kind == .previous && second.serial > first.serial)
        session.close()
        session.requestFind(.next)
        #expect(session.takeFindCommand() == nil)
    }

    @Test func findQueryAndPresentationSurviveRefreshButNotANewDocument() throws {
        let session = DocumentReadSession()
        let binding = UUID()
        session.binding = binding
        let first = prepared("needle")
        #expect(session.commit(first, fragment: nil, token: session.begin()))
        session.isFindPresented = true
        session.findQuery = "needle"
        session.requestFind(.next)
        let ticket = try #require(session.refreshTicket(binding: binding, revision: 1))
        let second = prepared("# Added\n\nneedle needle")
        #expect(session.commitRefresh(second, ticket: ticket, restoration: .top))
        #expect(session.isFindPresented && session.findQuery == "needle")
        #expect(session.takeFindCommand()?.kind == .next)
        let oldMatches = DocumentFindIndex(first.rendered).matches(for: session.findQuery)
        let newMatches = DocumentFindIndex(second.rendered).matches(for: session.findQuery)
        #expect(oldMatches.count == 1 && newMatches.count == 2)
        #expect(oldMatches.first?.leafID != newMatches.first?.leafID)
        #expect(session.commit(prepared("other"), fragment: nil, token: session.begin()))
        #expect(!session.isFindPresented && session.findQuery.isEmpty)
        #expect(session.findCommand == nil)
    }

    @Test func stepWrapsAndRefusesEmptyMatches() {
        #expect(DocumentFindIndex.step(from: nil, count: 0, reverse: false) == nil)
        #expect(DocumentFindIndex.step(from: nil, count: 3, reverse: true)?.index == 2)
        #expect(DocumentFindIndex.step(from: 2, count: 3, reverse: false)?.wrapped == true)
        #expect(DocumentFindIndex.step(from: 0, count: 3, reverse: true)?.index == 2)
        #expect(DocumentFindIndex.step(from: 2, count: 3, reverse: false, wrap: false) == nil)
        let matches = [DocumentFindMatch(leafID: 1, range: NSRange(location: 0, length: 1)),
                       DocumentFindMatch(leafID: 5, range: NSRange(location: 0, length: 1))]
        #expect(DocumentFindIndex.initialIndex(in: [], atOrAfterLeaf: 1) == nil)
        #expect(DocumentFindIndex.initialIndex(in: matches, atOrAfterLeaf: 3) == 1)
        #expect(DocumentFindIndex.initialIndex(in: matches, atOrAfterLeaf: 9) == 0)
    }
}
