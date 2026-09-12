import SwiftUI

/// Authority is independent of the aggregate busy flag: pending commands themselves
/// hold that flag. A token never becomes current again just because scrolling ends.
nonisolated struct DocumentReaderScrollPolicy {
    private(set) var generation = 0
    private(set) var userOwnsViewport = false

    @discardableResult
    mutating func observe(_ phase: ScrollPhase) -> Bool {
        let userPhase = phase == .tracking || phase == .interacting || phase == .decelerating
        let takeover = userPhase && !userOwnsViewport
        if takeover { generation += 1 }
        userOwnsViewport = userPhase
        return takeover
    }

    @discardableResult
    mutating func explicitIntent() -> Int {
        generation += 1
        userOwnsViewport = false
        return generation
    }

    mutating func invalidate() { generation += 1 }

    func permits(_ token: Int, selectionDragging: Bool, presentationCurrent: Bool) -> Bool {
        token == generation && !userOwnsViewport && !selectionDragging && presentationCurrent
    }

    func permitsAutomatic(viewportChanged: Bool, selectionDragging: Bool) -> Bool {
        viewportChanged && !userOwnsViewport && !selectionDragging
    }
}
