import AppKit
import SwiftUI

/// Instance-local native measurements. Neither views nor windows are retained.
@MainActor
final class DocumentNavigationBridge {
    private struct Entry {
        weak var view: NSView?
        let generation: Int
    }
    private weak var root: NSView?
    private var destinations: [Int: Entry] = [:]
    private(set) var generation = 0
    private(set) var request = 0

    func replaceDocument() {
        generation += 1
        cancel()
        destinations.removeAll()
        root = nil
    }

    func cancel() { request += 1 }

    func register(_ view: NSView, id: Int?, generation: Int) {
        guard generation == self.generation else { return }
        if let id { destinations[id] = Entry(view: view, generation: generation) }
        else { root = view }
    }

    func unregister(_ view: NSView, id: Int?) {
        if let id {
            if destinations[id]?.view === view { destinations.removeValue(forKey: id) }
        } else if root === view { root = nil }
    }

    var owner: NSScrollView? {
        guard let root, let scroll = root.enclosingScrollView,
              scroll.hasVerticalScroller, !scroll.hasHorizontalScroller else { return nil }
        return scroll
    }

    func destination(_ id: Int) -> NSView? {
        guard let entry = destinations[id], entry.generation == generation,
              let view = entry.view, let owner,
              view.enclosingScrollView === owner else { return nil }
        return view
    }

    /// Returns nil until materialized, otherwise the remaining constrained error.
    func position(id: Int?, request: Int) -> CGFloat? {
        guard request == self.request, let owner, let document = owner.documentView else { return nil }
        let clip = owner.contentView
        var bounds = clip.bounds
        if let id {
            guard let target = destination(id) else { return nil }
            let frame = target.convert(target.bounds, to: clip)
            bounds.origin.y = clip.isFlipped ? frame.minY - owner.contentInsets.top
                : frame.maxY - bounds.height + owner.contentInsets.top
        } else {
            let frame = document.convert(document.bounds, to: clip)
            bounds.origin.y = clip.isFlipped ? frame.minY - owner.contentInsets.top
                : frame.maxY - bounds.height + owner.contentInsets.top
        }
        bounds = clip.constrainBoundsRect(bounds)
        let error = bounds.minY - clip.bounds.minY
        if abs(error) > 0.5 {
            clip.scroll(to: bounds.origin)
            owner.reflectScrolledClipView(clip)
        }
        return error
    }
}

struct DocumentNavigationMarker: NSViewRepresentable {
    let bridge: DocumentNavigationBridge
    let id: Int?
    let generation: Int

    final class Marker: NSView {
        weak var bridge: DocumentNavigationBridge?
        var id: Int?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> Marker {
        let view = Marker()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: Marker, context: Context) {
        view.bridge?.unregister(view, id: view.id)
        view.bridge = bridge
        view.id = id
        bridge.register(view, id: id, generation: generation)
    }

    static func dismantleNSView(_ view: Marker, coordinator: ()) {
        view.bridge?.unregister(view, id: view.id)
    }
}

extension EnvironmentValues {
    @Entry var documentNavigationBridge: DocumentNavigationBridge? = nil
    @Entry var documentNavigationGeneration = 0
}
