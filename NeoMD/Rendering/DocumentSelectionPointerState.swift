import Foundation
import CoreGraphics

/// Copied geometry only: never retains a native leaf or caches layout across reflow.
nonisolated enum DocumentSelectionTargeting {
    struct Candidate {
        let key: DocumentTextProjection.Key
        let order: Int
        let rect: CGRect
        var eligible = true
        var actualHit = false
    }

    static func valid(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isEmpty && [rect.minX, rect.minY, rect.maxX, rect.maxY].allSatisfy(\.isFinite)
    }

    static func clipped(bounds: CGRect, visible: CGRect, clips: [CGRect]) -> CGRect? {
        guard valid(bounds), valid(visible), clips.allSatisfy(valid) else { return nil }
        let result = clips.reduce(bounds.intersection(visible)) { $0.intersection($1) }
        return valid(result) ? result : nil
    }

    static func scrollDelta(point: CGPoint, viewport: CGRect, horizontal: Bool) -> CGFloat {
        let coordinate = horizontal ? point.x : point.y
        let lower = horizontal ? viewport.minX : viewport.minY
        let upper = horizontal ? viewport.maxX : viewport.maxY
        guard coordinate.isFinite, valid(viewport) else { return 0 }
        let step: CGFloat = horizontal ? 20 : 24
        return coordinate < lower ? -step : coordinate > upper ? step : 0
    }

    static func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, rect.minX), rect.maxX), y: min(max(point.y, rect.minY), rect.maxY))
    }

    static func resolve(_ point: CGPoint, candidates: [Candidate]) -> Candidate? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        func distance(_ candidate: Candidate) -> CGFloat {
            let clamped = clamp(point, to: candidate.rect)
            return hypot(point.x - clamped.x, point.y - clamped.y)
        }
        return candidates.filter { $0.eligible && valid($0.rect) }.min {
            let lhs = distance($0), rhs = distance($1)
            if lhs != rhs { return lhs < rhs }
            if lhs == 0, $0.actualHit != $1.actualHit { return $0.actualHit }
            if $0.order != $1.order { return $0.order < $1.order }
            if $0.key.leafID != $1.key.leafID { return $0.key.leafID < $1.key.leafID }
            return $0.key.part < $1.key.part
        }
    }
}

/// Gesture intent outlives its origin mount; the owner operation gates every sample.
nonisolated struct DocumentSelectionPointerState {
    let operation: DocumentSelectionState.Operation
    let origin: CGPoint
    let initial: DocumentTextProjection.Selection
    let extending: Bool
    let activation: DocumentLinkActivation
    let link: URL?
    private(set) var moved = false
    private(set) var finished = false

    static func handles(primary: Bool, control: Bool) -> Bool { primary && !control }

    func isCurrent(operation: DocumentSelectionState.Operation?, ownerCurrent: Bool, windowCurrent: Bool) -> Bool {
        !finished && self.operation == operation && ownerCurrent && windowCurrent
    }

    mutating func sample(_ point: CGPoint, operation: DocumentSelectionState.Operation?) -> Bool {
        guard !finished, self.operation == operation, point.x.isFinite, point.y.isFinite else { return false }
        moved = moved || hypot(point.x - origin.x, point.y - origin.y) > 3
        return moved
    }

    mutating func finish(operation: DocumentSelectionState.Operation?, cancelled: Bool) -> URL? {
        guard !finished, self.operation == operation else { return nil }
        finished = true
        return !cancelled && !moved && !extending ? link : nil
    }

    func selection(key: DocumentTextProjection.Key, range: NSRange,
                   projection: DocumentTextProjection) -> DocumentTextProjection.Selection {
        let order = projection.fragments.map(\.key)
        let start = initial.anchor
        let backwards = (order.firstIndex(of: key) ?? 0) < (order.firstIndex(of: start.key) ?? 0) ||
            (key == start.key && range.location < start.offset)
        return .init(anchor: extending ? start : (backwards ? initial.extent : start),
                     extent: .init(key: key, offset: backwards ? range.location : NSMaxRange(range)))
    }
}

/// A responder may lend activity only to current registrations in its own reader/window.
nonisolated enum DocumentSelectionActivity {
    static func shared(leaf: DocumentSelectionState.Registration?, responder: DocumentSelectionState.Registration?,
                       leafCurrent: Bool, responderCurrent: Bool, sameWindow: Bool, keyWindow: Bool) -> Bool {
        guard let leaf, let responder else { return false }
        return leafCurrent && responderCurrent && sameWindow && keyWindow && leaf.scope == responder.scope
    }
}
