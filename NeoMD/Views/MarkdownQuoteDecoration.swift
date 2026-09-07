import SwiftUI

/// Presentation-only storage. Layout writes scalar rectangles directly to one
/// passive native drawing surface, without publishing SwiftUI state during layout.
/// Neither this storage nor its surface owns semantic nodes or navigation markers.
nonisolated final class MarkdownQuoteDecoration: @unchecked Sendable {
    @MainActor weak var surface: QuotePathView?
    private let lock = NSLock()
    private var storedBars: [CGRect] = []

    var bars: [CGRect] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedBars
        }
        set {
            lock.lock()
            let changed = storedBars != newValue
            storedBars = newValue
            lock.unlock()
            guard changed else { return }
            Task { @MainActor [weak self] in self?.surface?.needsDisplay = true }
        }
    }
}

struct MarkdownQuoteDecorationSurface: NSViewRepresentable {
    let decoration: MarkdownQuoteDecoration

    func makeNSView(context: Context) -> QuotePathView {
        let view = QuotePathView()
        view.decoration = decoration
        decoration.surface = view
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: QuotePathView, context: Context) {
        view.decoration = decoration
        decoration.surface = view
        view.needsDisplay = true
    }

    static func dismantleNSView(_ view: QuotePathView, coordinator: ()) {
        if view.decoration?.surface === view { view.decoration?.surface = nil }
        view.decoration = nil
    }
}

final class QuotePathView: NSView {
    weak var decoration: MarkdownQuoteDecoration?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let decoration else { return }
        let path = NSBezierPath()
        // One winding-filled path: coincident projected rules do not accumulate
        // alpha. Every segment comes from the same linear scalar geometry pass.
        for bar in decoration.bars where bar.intersects(dirtyRect) {
            path.appendRect(bar)
        }
        NSColor.tertiaryLabelColor.setFill()
        path.fill()
    }
}
