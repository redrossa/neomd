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
    private var textLeaves: [Int: Entry] = [:]
    private var codeViews: [Int: Entry] = [:]
    private var overflowValues: [Int: Bool] = [:]
    private var intentMonitor: Any?
    var traverse: ((DocumentReaderFocusTarget?, Bool) -> Void)?
    private(set) var traversalTarget: DocumentReaderFocusTarget?

    func prepareTraversal(to target: DocumentReaderFocusTarget) {
        traversalTarget = target
    }

    func registerCode(_ view: NSView, id: Int, generation: Int, overflow: Bool) {
        guard generation == self.generation else { return }
        codeViews[id] = Entry(view: view, generation: generation)
        overflowValues[id] = overflow
    }

    func unregisterCode(_ view: NSView, id: Int) {
        guard codeViews[id]?.view === view else { return }
        codeViews.removeValue(forKey: id)
        overflowValues.removeValue(forKey: id)
        if traversalTarget == .codeBlock(id) { cancel() }
    }

    func codeOverflow(_ id: Int) -> Bool? {
        guard let entry = codeViews[id], entry.generation == generation,
              let view = entry.view, let window = owner?.window,
              view.window === window else { return nil }
        return overflowValues[id]
    }

    /// Verify SwiftUI's native accessibility focus, not just its requested FocusState.
    func hasActionFocus(_ target: DocumentReaderFocusTarget) -> Bool {
        guard let window = owner?.window, window.firstResponder != nil else { return false }
        let identifier: String
        switch target {
        case .links(let id): identifier = "MarkdownLinkBlock-\(id)"
        case .codeBlock(let id): identifier = "MarkdownCodeBlock-\(id)"
        default: return false
        }
        var element = window.accessibilityFocusedUIElement as? any NSAccessibilityProtocol
        for _ in 0..<12 {
            guard let current = element else { return false }
            if current.accessibilityIdentifier() == identifier { return true }
            element = current.accessibilityParent() as? any NSAccessibilityProtocol
        }
        return false
    }

    private func installIntentMonitor() {
        guard intentMonitor == nil else { return }
        // A per-reader token, weak callback and exact window guard; never consumes events.
        intentMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self, let window = self.owner?.window, event.window === window else { return event }
            self.cancel()
            return event
        }
    }

    func detachTraversal() {
        if let intentMonitor { NSEvent.removeMonitor(intentMonitor) }
        intentMonitor = nil
        traverse = nil
        cancel()
    }

    deinit {
        if let intentMonitor { NSEvent.removeMonitor(intentMonitor) }
    }

    func registerText(_ view: NSView, id: Int, generation: Int) {
        guard generation == self.generation else { return }
        textLeaves[id] = Entry(view: view, generation: generation)
    }

    func unregisterText(_ view: NSView, id: Int) {
        if textLeaves[id]?.view === view {
            textLeaves.removeValue(forKey: id)
            // Lazy materialization may detach the origin or unrelated leaves.
            // Only loss of the requested target invalidates that acquisition.
            if traversalTarget == .text(id) { cancel() }
        }
    }

    func textLeaf(_ id: Int) -> NSView? {
        guard let entry = textLeaves[id], entry.generation == generation,
              let view = entry.view, let owner,
              view.enclosingScrollView === owner, view.window === owner.window else { return nil }
        return view
    }

    func traverseText(_ view: NSView, id: Int, generation: Int, reverse: Bool) -> Bool {
        guard generation == self.generation, textLeaf(id) === view,
              view.window?.firstResponder === view, let traverse else { return false }
        traverse(.text(id), reverse)
        return true
    }

    func focusText(_ id: Int) -> Bool {
        guard let view = textLeaf(id), let window = view.window else { return false }
        view.scrollToVisible(view.bounds)
        return window.makeFirstResponder(view) && window.firstResponder === view
    }

    func leaveDocument(reverse: Bool) -> Bool {
        guard let window = owner?.window else { return false }
        let kinds: [NSWindow.ButtonType] = reverse ? [.closeButton, .miniaturizeButton, .zoomButton]
            : [.zoomButton, .miniaturizeButton, .closeButton]
        for kind in kinds {
            if let button = window.standardWindowButton(kind), button.isEnabled,
               window.makeFirstResponder(button), window.firstResponder === button { return true }
        }
        return false
    }

    func replaceDocument() {
        generation += 1
        cancel()
        destinations.removeAll()
        textLeaves.removeAll()
        codeViews.removeAll()
        overflowValues.removeAll()
        detachTraversal()
        root = nil
    }

    func cancel() {
        request += 1
        traversalTarget = nil
    }

    func register(_ view: NSView, id: Int?, generation: Int) {
        guard generation == self.generation else { return }
        if let id { destinations[id] = Entry(view: view, generation: generation) }
        else { root = view; installIntentMonitor() }
    }

    func unregister(_ view: NSView, id: Int?) {
        if let id {
            if destinations[id]?.view === view { destinations.removeValue(forKey: id) }
        } else if root === view {
            detachTraversal()
            root = nil
        }
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
    var codeOverflow: Bool? = nil

    final class Marker: NSView {
        weak var bridge: DocumentNavigationBridge?
        var id: Int?
        var isCode = false
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> Marker {
        let view = Marker()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: Marker, context: Context) {
        if view.bridge !== bridge || view.id != id || view.isCode != (codeOverflow != nil) {
            if view.isCode, let oldID = view.id {
                view.bridge?.unregisterCode(view, id: oldID)
            } else {
                view.bridge?.unregister(view, id: view.id)
            }
        }
        view.bridge = bridge
        view.id = id
        view.isCode = codeOverflow != nil
        if let codeOverflow, let id {
            bridge.registerCode(view, id: id, generation: generation, overflow: codeOverflow)
        } else {
            bridge.register(view, id: id, generation: generation)
        }
    }

    static func dismantleNSView(_ view: Marker, coordinator: ()) {
        if view.isCode, let id = view.id {
            view.bridge?.unregisterCode(view, id: id)
        } else {
            view.bridge?.unregister(view, id: view.id)
        }
    }
}

extension EnvironmentValues {
    @Entry var documentNavigationBridge: DocumentNavigationBridge? = nil
    @Entry var documentNavigationGeneration = 0
    @Entry var documentLeafID: Int? = nil
}
