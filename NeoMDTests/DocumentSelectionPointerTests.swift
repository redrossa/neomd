import Foundation
import CoreGraphics
import Testing
@testable import NeoMD

@MainActor struct DocumentSelectionPointerTests {
    private typealias Projection = DocumentTextProjection
    private let a = Projection.Key(leafID: 0)
    private let b = Projection.Key(leafID: 1)

    private func model() -> Projection {
        .init(presentation: UUID(), fragments: [.init(key: a, text: "Alpha bravo"), .init(key: b, text: "Delta echo")])
    }

    private func gesture(_ state: inout DocumentSelectionState, range: NSRange = NSRange(location: 6, length: 0),
                         shift: Bool = false, activation: DocumentLinkActivation = .ordinary) -> DocumentSelectionPointerState {
        let initial = Projection.Selection(anchor: .init(key: a, offset: range.location),
                                           extent: .init(key: a, offset: NSMaxRange(range)))
        return .init(operation: state.beginOperation(), origin: .zero, initial: initial, extending: shift,
                     activation: activation, link: URL(string: "https://example.com"))
    }

    @Test func stagedGeometryAndExtractionOracles() throws {
        struct Packet: Decodable {
            struct Geometry: Decodable {
                struct Candidate: Decodable { let key: [Int]; let order: Int; let bounds: [Double]; let visibleRect: [Double]; let clip: [Double] }
                let point: [Double]; let candidates: [Candidate]; let expectedKey: [Int]
            }
            struct Selection: Decodable { let fragments: [String]; let anchor: [Int]; let extent: [Int]; let expected: String }
            let geometry: [Geometry]; let selection: [Selection]
        }
        func rect(_ values: [Double]) -> CGRect { .init(x: values[0], y: values[1], width: values[2], height: values[3]) }
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/m1-p8-selection/pointer-cases.json")
        let packet = try JSONDecoder().decode(Packet.self, from: Data(contentsOf: url))
        #expect(packet.geometry.count == 4 && packet.selection.count == 3)
        for item in packet.geometry {
            let candidates = item.candidates.compactMap { value -> DocumentSelectionTargeting.Candidate? in
                guard let clipped = DocumentSelectionTargeting.clipped(bounds: rect(value.bounds), visible: rect(value.visibleRect), clips: [rect(value.clip)]) else { return nil }
                return .init(key: .init(leafID: value.key[0], part: value.key[1]), order: value.order, rect: clipped)
            }
            let point = CGPoint(x: item.point[0], y: item.point[1])
            let expected = Projection.Key(leafID: item.expectedKey[0], part: item.expectedKey[1])
            #expect(DocumentSelectionTargeting.resolve(point, candidates: candidates)?.key == expected)
            #expect(DocumentSelectionTargeting.resolve(point, candidates: candidates.reversed())?.key == expected)
        }
        for item in packet.selection {
            let projection = Projection(presentation: UUID(), fragments: item.fragments.enumerated().map { .init(key: .init(leafID: $0.offset), text: $0.element) })
            let selection = Projection.Selection(anchor: .init(key: .init(leafID: item.anchor[0]), offset: item.anchor[1]),
                extent: .init(key: .init(leafID: item.extent[0]), offset: item.extent[1]))
            #expect(projection.copiedText(for: selection) == item.expected)
        }
    }

    @Test func targetEligibilityActualHitAndFreshMounts() {
        let rect = CGRect(x: 0, y: 0, width: 20, height: 20)
        let first = DocumentSelectionTargeting.Candidate(key: a, order: 0, rect: rect)
        var second = DocumentSelectionTargeting.Candidate(key: b, order: 1, rect: rect, actualHit: true)
        #expect(DocumentSelectionTargeting.resolve(.zero, candidates: [first, second])?.key == b)
        second.eligible = false // Native adapter folds hidden/wrong-window/stale registrations into eligibility.
        #expect(DocumentSelectionTargeting.resolve(.zero, candidates: [second, first])?.key == a)
        #expect(DocumentSelectionTargeting.resolve(.zero, candidates: [second]) == nil)
        #expect(DocumentSelectionTargeting.resolve(CGPoint(x: CGFloat.nan, y: 0), candidates: [first]) == nil)
        #expect(DocumentSelectionTargeting.clipped(bounds: rect, visible: .infinite, clips: []) == nil)
        #expect(DocumentSelectionTargeting.clipped(bounds: rect, visible: rect, clips: [.zero]) == nil)
        #expect(DocumentSelectionTargeting.clamp(CGPoint(x: 40, y: -1), to: rect) == CGPoint(x: 20, y: 0))
        let fresh = DocumentSelectionTargeting.Candidate(key: b, order: 1, rect: CGRect(x: 0, y: 30, width: 20, height: 20))
        #expect(DocumentSelectionTargeting.resolve(CGPoint(x: 5, y: 40), candidates: [first, fresh])?.key == b)
    }

    @Test func dragReversalPreservesInitialWordAndFinalEndpoint() {
        let projection = model()
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: projection)
        var pointer = gesture(&state, range: NSRange(location: 6, length: 5))
        let moved = pointer.sample(CGPoint(x: 4, y: 0), operation: state.operation)
        #expect(moved)
        let forward = pointer.selection(key: b, range: NSRange(location: 0, length: 5), projection: projection)
        #expect(projection.copiedText(for: forward) == "bravo\n\nDelta")
        let reverse = pointer.selection(key: a, range: NSRange(location: 0, length: 5), projection: projection)
        #expect(reverse.anchor.offset == 11)
        #expect(projection.copiedText(for: reverse) == "Alpha bravo")
        let final = pointer.selection(key: b, range: NSRange(location: 6, length: 4), projection: projection)
        _ = state.setSelection(final, scope: state.scope)
        #expect(state.copiedText == "bravo\n\nDelta echo")
        let link = pointer.finish(operation: state.operation, cancelled: false)
        #expect(link == nil && pointer.finished)
        let finished = state.finishOperation(pointer.operation)
        #expect(finished)
        #expect(state.operation == nil)
        var remapped = gesture(&state, range: NSRange(location: 6, length: 5))
        remapped.remap(key: a) { $0 - 5 }
        #expect(remapped.initial.anchor.offset == 1 && remapped.initial.extent.offset == 6)
        remapped.remap(key: b) { _ in 99 }
        #expect(remapped.initial.anchor.offset == 1 && remapped.initial.extent.offset == 6)
    }

    @Test func clickThresholdShiftCommandAndCancellationEffects() {
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: model())
        var click = gesture(&state, activation: .additionalReader)
        let small = click.sample(CGPoint(x: 2, y: 0), operation: state.operation)
        #expect(!small && click.activation == .additionalReader)
        let opened = click.finish(operation: state.operation, cancelled: false)
        #expect(opened == URL(string: "https://example.com"))
        let duplicate = click.finish(operation: state.operation, cancelled: false)
        #expect(duplicate == nil)
        var drag = gesture(&state)
        _ = drag.sample(CGPoint(x: 4, y: 0), operation: state.operation)
        _ = drag.sample(.zero, operation: state.operation)
        #expect(drag.moved)
        let draggedLink = drag.finish(operation: state.operation, cancelled: false)
        #expect(draggedLink == nil)
        var shift = gesture(&state, shift: true)
        let shiftedLink = shift.finish(operation: state.operation, cancelled: false)
        #expect(shiftedLink == nil)
        var cancelled = gesture(&state)
        let cancelledLink = cancelled.finish(operation: state.operation, cancelled: true)
        #expect(cancelledLink == nil && cancelled.finished)
    }

    @Test func unmountAndStaleTokensDoNotFinishSuccessor() throws {
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: model())
        let registered = state.register(a, scope: state.scope)
        let mount = try #require(registered)
        var old = gesture(&state)
        state.unregister(mount)
        let continued = old.sample(CGPoint(x: 9, y: 0), operation: state.operation)
        #expect(continued && state.operation == old.operation)
        let successor = state.beginOperation()
        let lateSample = old.sample(CGPoint(x: 20, y: 0), operation: state.operation)
        let lateLink = old.finish(operation: state.operation, cancelled: false)
        let staleFinish = state.finishOperation(old.operation)
        #expect(!lateSample && lateLink == nil && !staleFinish && state.operation == successor)
        let finished = state.finishOperation(successor)
        let duplicate = state.finishOperation(successor)
        #expect(finished && !duplicate && state.operation == nil)
    }

    @Test func paragraphShiftAndScrollAxesRemainIndependent() {
        let projection = model()
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: projection)
        let paragraph = gesture(&state, range: NSRange(location: 0, length: 11))
        let forward = paragraph.selection(key: b, range: NSRange(location: 0, length: 10), projection: projection)
        #expect(projection.copiedText(for: forward) == "Alpha bravo\n\nDelta echo")
        let secondParagraph = DocumentSelectionPointerState(operation: paragraph.operation, origin: .zero,
            initial: .init(anchor: .init(key: b, offset: 0), extent: .init(key: b, offset: 10)),
            extending: false, activation: .ordinary, link: nil)
        let backwards = secondParagraph.selection(key: a, range: NSRange(location: 6, length: 5), projection: projection)
        #expect(backwards.anchor == .init(key: b, offset: 10))
        #expect(projection.copiedText(for: backwards) == "bravo\n\nDelta echo")
        let shifted = gesture(&state, shift: true)
        let reverse = shifted.selection(key: a, range: NSRange(location: 0, length: 0), projection: projection)
        #expect(reverse.anchor.offset == 6 && reverse.extent.offset == 0)
        let owner = DocumentSelectionController(reader: UUID(), projection: projection, write: { _ in })
        owner.localSelection(NSRange(location: 5, length: 0), key: b, extending: true)
        #expect(owner.state.selection?.anchor == .init(key: b, offset: 5))
        owner.localSelection(NSRange(location: 0, length: 0), key: a, extending: true)
        #expect(owner.state.copiedText == "Alpha bravo\n\nDelta")
        let viewport = CGRect(x: 0, y: 0, width: 100, height: 100)
        let outside = CGPoint(x: 120, y: -10)
        #expect(DocumentSelectionTargeting.scrollDelta(point: outside, viewport: viewport, horizontal: false) == -24)
        #expect(DocumentSelectionTargeting.scrollDelta(point: outside, viewport: viewport, horizontal: true) == 20)
        #expect(DocumentSelectionPointerState.handles(primary: true, control: false))
        #expect(!DocumentSelectionPointerState.handles(primary: true, control: true))
        #expect(!DocumentSelectionPointerState.handles(primary: false, control: false))
    }

    @Test func ownerInvalidationAndBusySizeQueueAreTokenBound() {
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: model())
        let pointer = gesture(&state)
        #expect(pointer.isCurrent(operation: state.operation, ownerCurrent: true, windowCurrent: true))
        #expect(!pointer.isCurrent(operation: state.operation, ownerCurrent: false, windowCurrent: true))
        #expect(!pointer.isCurrent(operation: state.operation, ownerCurrent: true, windowCurrent: false))
        let preference = ReadingSizePreference()
        var reflow = ReadingSizeReflow(preference: preference)
        preference.apply(.increase)
        var preparations = 0
        reflow.reconcile(preference, eligible: state.operation == nil) { preparations += 1 }
        #expect(preparations == 0 && reflow.isQueued(preference))
        _ = state.finishOperation(pointer.operation)
        reflow.reconcile(preference, eligible: state.operation == nil) { preparations += 1 }
        #expect(preparations == 1 && !reflow.isQueued(preference))
    }

    @Test func sharedActivityRequiresCurrentSameReaderAndWindow() throws {
        let projection = model()
        var state = DocumentSelectionState(reader: UUID(), generation: 0, projection: projection)
        var other = DocumentSelectionState(reader: UUID(), generation: 0, projection: projection)
        let leaf = state.register(a, scope: state.scope)
        let responder = state.register(b, scope: state.scope)
        let foreign = other.register(b, scope: other.scope)
        func active(_ responder: DocumentSelectionState.Registration?, current: Bool = true, window: Bool = true, key: Bool = true) -> Bool {
            DocumentSelectionActivity.shared(leaf: leaf, responder: responder, leafCurrent: true,
                responderCurrent: current, sameWindow: window, keyWindow: key)
        }
        #expect(active(responder))
        #expect(!active(foreign) && !active(nil) && !active(responder, current: false))
        #expect(!active(responder, window: false) && !active(responder, key: false))
        let stale = try #require(responder)
        _ = state.register(b, scope: state.scope)
        #expect(!active(stale, current: state.accepts(stale)))
    }
}
