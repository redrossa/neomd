//
//  MarkdownTableLayout.swift
//  NeoMD
//

import SwiftUI

/// Pure, finite table geometry.
///
/// Only the table's own internal document may exceed `viewportWidth`; the width the
/// surrounding reader sees is always the width it allotted, so a wide table never
/// widens the page. Every proposal is clamped, so an infinite or non-positive
/// proposal cannot produce an unbounded intrinsic size. Numeric constants are
/// tuning, not contract.
nonisolated struct MarkdownTableLayout: Equatable, Sendable {
    /// Readable bounds for one column's text, before padding, at scale 1.
    static let minimumCellWidth: CGFloat = 80
    static let maximumCellWidth: CGFloat = 320
    /// Padding applied on each side of a cell's content, at scale 1.
    static let cellPadding: CGFloat = 10
    /// A row keeps a visible shape even when every cell in it is empty.
    static let minimumCellHeight: CGFloat = 17

    let viewportWidth: CGFloat
    let scale: CGFloat
    let padding: CGFloat
    /// Total width of each column, content plus both paddings.
    let columnWidths: [CGFloat]

    /// The table's internal document width. This is the only width allowed to
    /// exceed the viewport.
    var contentWidth: CGFloat { columnWidths.reduce(0, +) }

    var overflows: Bool { contentWidth > viewportWidth + 0.5 }

    var maximumOffset: CGFloat { max(0, contentWidth - viewportWidth) }

    var minimumRowHeight: CGFloat { Self.minimumCellHeight * scale + padding * 2 }

    /// - Parameter preferredContentWidths: each column's natural content width,
    ///   measured without wrapping. Non-finite values fall back to the minimum.
    init(viewportWidth proposedViewport: CGFloat, preferredContentWidths: [CGFloat], scale proposedScale: CGFloat) {
        let resolvedScale = proposedScale.isFinite && proposedScale > 0 ? proposedScale : 1
        let viewport = proposedViewport.isFinite && proposedViewport > 0 ? proposedViewport : 1
        let resolvedPadding = Self.cellPadding * resolvedScale
        let minimum = Self.minimumCellWidth * resolvedScale
        let maximum = Self.maximumCellWidth * resolvedScale
        var widths = preferredContentWidths.map { value -> CGFloat in
            let content = value.isFinite && value > 0 ? value : minimum
            return min(maximum, max(minimum, content)) + resolvedPadding * 2
        }
        // A table narrower than its viewport shares the spare width rather than
        // leaving a ragged right edge; a wider one keeps its own document width.
        if !widths.isEmpty {
            var total: CGFloat = 0
            for value in widths { total += value }
            let share = max(0, viewport - total) / CGFloat(widths.count)
            for index in widths.indices { widths[index] += share }
        }
        scale = resolvedScale
        viewportWidth = viewport
        padding = resolvedPadding
        columnWidths = widths
    }

    /// The x origin of a column inside the table's internal document. The count
    /// itself is the exclusive trailing edge.
    func columnX(_ column: Int) -> CGFloat {
        guard column > 0 else { return 0 }
        var total: CGFloat = 0
        for index in 0..<min(column, columnWidths.count) { total += columnWidths[index] }
        return total
    }

    /// The width a cell's content is measured and wrapped at.
    func contentWidth(column: Int) -> CGFloat {
        guard columnWidths.indices.contains(column) else { return 1 }
        return max(1, columnWidths[column] - padding * 2)
    }

    /// Row height is the tallest cell plus padding, never a fixed clipping height.
    func rowHeight(cellHeights: [CGFloat]) -> CGFloat {
        let tallest = cellHeights.filter { $0.isFinite && $0 > 0 }.max() ?? 0
        return max(minimumRowHeight, tallest + padding * 2)
    }

    /// Local offsets stay inside the current extent, so a fitting table is pinned
    /// to its leading edge after a resize.
    func clampedOffset(_ offset: CGFloat) -> CGFloat {
        guard !offset.isNaN else { return 0 }
        return min(maximumOffset, max(0, offset))
    }
}

/// The keyboard intents a local table overflow stop accepts.
///
/// Modelled as values so the policy can be exercised without synthesising events.
nonisolated enum MarkdownTableKey: Equatable, Sendable {
    case left, right, home, end, pageUp, pageDown, escape, tab
}

/// What the reader should do for one intent at a table overflow stop.
nonisolated enum MarkdownTableOverflowAction: Equatable, Sendable {
    case scroll(CGFloat)
    case leadingEdge
    case trailingEdge
    case page(isUp: Bool)
    case returnToReader
    /// `true` traverses in reverse.
    case traverse(reverse: Bool)
    case ignored
}

extension MarkdownTableLayout {
    /// Mirrors the existing code-overflow conventions: Left/Right step, Option
    /// pages by viewport, Command and Home/End jump to an edge, PageUp/PageDown
    /// belong to the document, Escape returns to reading and Option-Tab traverses
    /// out without trapping focus. Shift and Control stay available to selection.
    static func action(for key: MarkdownTableKey, modifiers: EventModifiers,
                       offset: CGFloat, viewportWidth: CGFloat) -> MarkdownTableOverflowAction {
        let explicit = modifiers.intersection([.shift, .control, .command, .option])
        if key == .tab {
            if explicit == .option { return .traverse(reverse: false) }
            if explicit == [.option, .shift] { return .traverse(reverse: true) }
            return .ignored
        }
        guard explicit.intersection([.shift, .control]).isEmpty else { return .ignored }
        let step = modifiers.contains(.option) ? max(40, viewportWidth * 0.8) : 40
        let current = offset.isFinite ? offset : 0
        switch key {
        case .left: return modifiers.contains(.command) ? .leadingEdge : .scroll(current - step)
        case .right: return modifiers.contains(.command) ? .trailingEdge : .scroll(current + step)
        case .home: return .leadingEdge
        case .end: return .trailingEdge
        case .pageUp, .pageDown:
            guard explicit.isEmpty else { return .ignored }
            return .page(isUp: key == .pageUp)
        case .escape: return .returnToReader
        case .tab: return .ignored
        }
    }
}
