import Foundation
import Testing
@testable import NeoMD

@MainActor struct DocumentSelectionStateTests {
    private typealias Projection = DocumentTextProjection
    // Evaluate mutating value operations before entering Swift Testing's expression
    // expansion, which otherwise captures a struct receiver as an immutable value.
    private func check(_ value: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(value, sourceLocation: sourceLocation)
    }
    private func unwrap<T>(_ value: T?, sourceLocation: SourceLocation = #_sourceLocation) throws -> T {
        try #require(value, sourceLocation: sourceLocation)
    }
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
        check(state.setSelection(selected, scope: state.scope))
        let first = try unwrap(state.register(.init(leafID: 1), scope: state.scope))
        let last = try unwrap(state.register(.init(leafID: 254), scope: state.scope))
        check(state.registrations.count == 2)
        check(state.copiedText == strings[1...254].joined(separator: "\n\n"))
        check(state.slice(for: first)?.length == strings[1].utf16.count)
        check(state.slice(for: last)?.length == strings[254].utf16.count)
        state.unregister(first)
        let remount = try unwrap(state.register(first.key, scope: state.scope))
        check(state.slice(for: remount)?.length == strings[1].utf16.count)
        check(state.copiedText == strings[1...254].joined(separator: "\n\n"))
    }

    @Test func staleDetachAndTwoReadersCannotReleaseReplacementRegistrations() throws {
        let model = projection(["Alpha", "Beta"])
        var first = DocumentSelectionState(reader: UUID(), generation: 0, projection: model)
        var second = DocumentSelectionState(reader: UUID(), generation: 0, projection: model)
        let old = try unwrap(first.register(.init(leafID: 0), scope: first.scope))
        let replacement = try unwrap(first.register(old.key, scope: first.scope))
        first.unregister(old)
        check(first.accepts(replacement))
        check(!first.accepts(old))
        check(second.register(old.key, scope: first.scope) == nil)
        check(!second.setSelection(model.entireSelection, scope: first.scope))
        check(first.setSelection(model.entireSelection, scope: first.scope))
        check(second.selection == nil)
        check(second.copiedText.isEmpty)
        let later = DocumentSelectionState(reader: first.scope.reader, generation: 0,
                                           projection: projection(["Alpha", "Beta"]))
        check(later.scope.presentation != first.scope.presentation)
        check(!later.accepts(replacement))
    }

    @Test func cancelledOperationCannotEndSuccessorOrClearSelection() {
        let model = projection(["Alpha", "Beta"])
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: model)
        check(state.setSelection(model.entireSelection, scope: state.scope))
        let old = state.beginOperation()
        let current = state.beginOperation()
        check(!state.finishOperation(old))
        check(state.operation == current)
        check(state.finishOperation(current))
        check(state.operation == nil)
        check(state.selection == model.entireSelection)
    }

    @Test func genuineReplacementRemapsOnlyItsEndpointsAndRejectsStaleToken() throws {
        let model = projection(["alt (Image loading)", "Tail"])
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: model)
        check(state.setSelection(model.entireSelection, scope: state.scope))
        let old = try unwrap(state.register(.init(leafID: 0), scope: state.scope))
        let active = try unwrap(state.register(old.key, scope: state.scope))
        let loaded = Projection.Fragment(key: old.key, text: "\u{FFFC}", attachments: [NSRange(location: 0, length: 1)])
        check(!state.replace(loaded, registration: old, remap: { _ in 0 }))
        check(state.replace(loaded, registration: active, remap: { $0 == 0 ? 0 : 1 }))
        check(state.selection?.extent == model.entireSelection?.extent)
        check(state.copiedText == "\n\nTail")
    }

    @Test func refreshResolvesFreshIDsAndNewInteriorWithoutReadingPositionFallback() throws {
        let before = projection(["Start endpoint alpha.", "Old interior.", "Cell endpoint omega."])
        let descriptor = try unwrap(before.refreshDescriptor(for: try unwrap(before.entireSelection)))
        let after = projection(["Inserted prefix.", "Start endpoint alpha.", "New interior.", "Old interior.", "Cell endpoint omega."], idOffset: 10)
        let restored = try unwrap(after.resolve(descriptor))
        check(restored.anchor.key.leafID == 11)
        check(restored.extent.key.leafID == 14)
        check(after.copiedText(for: restored) == "Start endpoint alpha.\n\nNew interior.\n\nOld interior.\n\nCell endpoint omega.")
        check(projection(["Start endpoint alpha.", "Old interior."]).resolve(descriptor) == nil)
        check(projection(["Start endpoint ALPHA.", "Old interior.", "Cell endpoint omega."]).resolve(descriptor) == nil)
    }

    @Test func ambiguousRefreshClearsAndTransferIsConsumedOnceByMatchingHost() throws {
        let before = projection(["prefix", "duplicate", "suffix"])
        let selected = Projection.Selection(anchor: .init(key: .init(leafID: 1), offset: 1),
                                            extent: .init(key: .init(leafID: 1), offset: 4))
        let descriptor = try unwrap(before.refreshDescriptor(for: selected))
        let ambiguous = projection(["prefix", "duplicate", "suffix", "prefix", "duplicate", "suffix"])
        check(ambiguous.resolve(descriptor) == nil)
        let presentation = UUID()
        var transfer = DocumentSelectionTransfer(presentation: presentation, descriptor: descriptor)
        check(transfer.take(for: UUID()) == nil)
        check(transfer.descriptor == descriptor)
        check(transfer.take(for: presentation) == descriptor)
        check(transfer.take(for: presentation) == nil)
    }

    @Test func findStateAndSelectionRemainIndependentValues() throws {
        let model = projection(["Lantern text"])
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: model)
        check(state.setSelection(model.entireSelection, scope: state.scope))
        let session = DocumentReadSession()
        let rendered = MarkdownBlockRenderer.render(from: "Lantern text")
        let prepared = PreparedReadingDocument(text: "Lantern text", fileURL: URL(fileURLWithPath: "/tmp/selection-value.md"), rendered: rendered)
        check(session.commit(prepared, fragment: nil, token: session.begin()))
        session.isFindPresented = true
        session.findQuery = "lantern"
        let matches = DocumentFindIndex(rendered).matches(for: session.findQuery)
        session.requestFind(.next)
        check(session.takeFindCommand()?.kind == .next)
        session.isFindPresented = false
        check(state.selection == model.entireSelection)
        check(state.copiedText == "Lantern text")
        check(state.setSelection(nil, scope: state.scope))
        check(matches.count == 1)
        check(session.findQuery == "lantern")
    }
}
