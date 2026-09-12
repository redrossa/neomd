import Foundation
import Testing
@testable import NeoMD

@MainActor struct DocumentSelectionStateTests {
    private typealias Projection = DocumentTextProjection

    private func projection(_ strings: [String], idOffset: Int = 0) -> Projection {
        Projection(presentation: UUID(), fragments: strings.enumerated().map {
            .init(key: .init(leafID: $0.offset + idOffset), text: $0.element)
        })
    }

    @Test func fakeMountsNeverLimitLogicalOffscreenCopy() throws {
        let strings = (1...256).map { "Passage \($0): selectable alpha, beta and gamma." }
        let model = projection(strings)
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: model)
        let selected = Projection.Selection(anchor: .init(key: .init(leafID: 1), offset: 0),
            extent: .init(key: .init(leafID: 254), offset: strings[254].utf16.count))
        #expect(state.setSelection(selected, scope: state.scope))
        let first = try #require(state.register(.init(leafID: 1), scope: state.scope))
        let last = try #require(state.register(.init(leafID: 254), scope: state.scope))
        #expect(state.registrations.count == 2)
        #expect(state.copiedText == strings[1...254].joined(separator: "\n\n"))
        #expect(state.slice(for: first)?.length == strings[1].utf16.count)
        #expect(state.slice(for: last)?.length == strings[254].utf16.count)
        state.unregister(first)
        let remount = try #require(state.register(first.key, scope: state.scope))
        #expect(state.slice(for: remount)?.length == strings[1].utf16.count)
        #expect(state.copiedText == strings[1...254].joined(separator: "\n\n"))
    }

    @Test func staleDetachAndTwoReadersCannotReleaseReplacementRegistrations() throws {
        let model = projection(["Alpha", "Beta"])
        var first = DocumentSelectionState(reader: UUID(), generation: 0, projection: model)
        var second = DocumentSelectionState(reader: UUID(), generation: 0, projection: model)
        let old = try #require(first.register(.init(leafID: 0), scope: first.scope))
        let replacement = try #require(first.register(old.key, scope: first.scope))
        first.unregister(old)
        #expect(first.accepts(replacement))
        #expect(!first.accepts(old))
        #expect(second.register(old.key, scope: first.scope) == nil)
        #expect(!second.setSelection(model.entireSelection, scope: first.scope))
        #expect(first.setSelection(model.entireSelection, scope: first.scope))
        #expect(second.selection == nil)
        #expect(second.copiedText.isEmpty)
        let later = DocumentSelectionState(reader: first.scope.reader, generation: 0,
                                           projection: projection(["Alpha", "Beta"]))
        #expect(later.scope.presentation != first.scope.presentation)
        #expect(!later.accepts(replacement))
    }

    @Test func cancelledOperationCannotEndSuccessorOrClearSelection() {
        let model = projection(["Alpha", "Beta"])
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: model)
        #expect(state.setSelection(model.entireSelection, scope: state.scope))
        let old = state.beginOperation()
        let current = state.beginOperation()
        #expect(!state.finishOperation(old))
        #expect(state.operation == current)
        #expect(state.finishOperation(current))
        #expect(state.operation == nil)
        #expect(state.selection == model.entireSelection)
    }

    @Test func genuineReplacementRemapsOnlyItsEndpointsAndRejectsStaleToken() throws {
        let model = projection(["alt (Image loading)", "Tail"])
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: model)
        #expect(state.setSelection(model.entireSelection, scope: state.scope))
        let old = try #require(state.register(.init(leafID: 0), scope: state.scope))
        let active = try #require(state.register(old.key, scope: state.scope))
        let loaded = Projection.Fragment(key: old.key, text: "\u{FFFC}", attachments: [NSRange(location: 0, length: 1)])
        #expect(!state.replace(loaded, registration: old, remap: { _ in 0 }))
        #expect(state.replace(loaded, registration: active, remap: { $0 == 0 ? 0 : 1 }))
        #expect(state.selection?.extent == model.entireSelection?.extent)
        #expect(state.copiedText == "\n\nTail")
    }

    @Test func refreshResolvesFreshIDsAndNewInteriorWithoutReadingPositionFallback() throws {
        let before = projection(["Start endpoint alpha.", "Old interior.", "Cell endpoint omega."])
        let descriptor = try #require(before.refreshDescriptor(for: try #require(before.entireSelection)))
        let after = projection(["Inserted prefix.", "Start endpoint alpha.", "New interior.", "Old interior.", "Cell endpoint omega."], idOffset: 10)
        let restored = try #require(after.resolve(descriptor))
        #expect(restored.anchor.key.leafID == 11)
        #expect(restored.extent.key.leafID == 14)
        #expect(after.copiedText(for: restored) == "Start endpoint alpha.\n\nNew interior.\n\nOld interior.\n\nCell endpoint omega.")
        #expect(projection(["Start endpoint alpha.", "Old interior."]).resolve(descriptor) == nil)
        #expect(projection(["Start endpoint ALPHA.", "Old interior.", "Cell endpoint omega."]).resolve(descriptor) == nil)
    }

    @Test func ambiguousRefreshClearsAndTransferIsConsumedOnceByMatchingHost() throws {
        let before = projection(["prefix", "duplicate", "suffix"])
        let selected = Projection.Selection(anchor: .init(key: .init(leafID: 1), offset: 1),
                                            extent: .init(key: .init(leafID: 1), offset: 4))
        let descriptor = try #require(before.refreshDescriptor(for: selected))
        let ambiguous = projection(["prefix", "duplicate", "suffix", "prefix", "duplicate", "suffix"])
        #expect(ambiguous.resolve(descriptor) == nil)
        let presentation = UUID()
        var transfer = DocumentSelectionTransfer(presentation: presentation, descriptor: descriptor)
        #expect(transfer.take(for: UUID()) == nil)
        #expect(transfer.descriptor == descriptor)
        #expect(transfer.take(for: presentation) == descriptor)
        #expect(transfer.take(for: presentation) == nil)
    }

    @Test func findStateAndSelectionRemainIndependentValues() throws {
        let model = projection(["Lantern text"])
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: model)
        #expect(state.setSelection(model.entireSelection, scope: state.scope))
        let session = DocumentReadSession()
        let rendered = MarkdownBlockRenderer.render(from: "Lantern text")
        let prepared = PreparedReadingDocument(text: "Lantern text", fileURL: URL(fileURLWithPath: "/tmp/selection-value.md"), rendered: rendered)
        #expect(session.commit(prepared, fragment: nil, token: session.begin()))
        session.isFindPresented = true
        session.findQuery = "lantern"
        let matches = DocumentFindIndex(rendered).matches(for: session.findQuery)
        session.requestFind(.next)
        #expect(session.takeFindCommand()?.kind == .next)
        session.isFindPresented = false
        #expect(state.selection == model.entireSelection)
        #expect(state.copiedText == "Lantern text")
        #expect(state.setSelection(nil, scope: state.scope))
        #expect(matches.count == 1)
        #expect(session.findQuery == "lantern")
    }
}
