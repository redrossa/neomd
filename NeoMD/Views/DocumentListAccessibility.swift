import AppKit
import SwiftUI

/// Flat, bounded ownership. Virtual lists/items reuse mounted text children rather
/// than synthesizing duplicate prose or mutable checkbox actions.
@MainActor final class DocumentListAccessibility {
    final class Element: NSAccessibilityElement {
        weak var store: DocumentListAccessibility?
        let id: Int
        let list: Bool
        init(store: DocumentListAccessibility, id: Int, list: Bool) {
            self.store = store; self.id = id; self.list = list
            super.init()
        }
        override func accessibilityRole() -> NSAccessibility.Role? { list ? .list : .group }
        override func isAccessibilityElement() -> Bool { true }
        override func accessibilityLabel() -> String? {
            guard let store else { return nil }
            let node = store.document[id]
            if list { return "List, \(store.items[id]?.count ?? 0) items" }
            guard case .listItem(let marker, let depth) = node.kind else { return nil }
            let status = node.task.map { $0 == .complete ? ", Completed task" : ", Incomplete task" } ?? ""
            return "Item \(marker), level \(depth)\(status)"
        }
        override func accessibilityParent() -> Any? {
            guard let store else { return nil }
            if !list, let listID = store.document[id].listID { return store.lists[listID] }
            return store.hosts[id]?.view
        }
        override func accessibilityChildren() -> [Any]? {
            guard let store else { return nil }
            if list { return (store.items[id] ?? []).compactMap { store.itemElements[$0] } }
            return store.document.leafIDs.compactMap { leaf -> NSView? in
                guard store.ownerItem(leaf) == id else { return nil }
                return store.leaves[leaf]?.view
            }
        }
        override func accessibilityFrame() -> NSRect {
            let children = accessibilityChildren() ?? []
            return children.compactMap { ($0 as? NSAccessibilityProtocol)?.accessibilityFrame() }
                .reduce(NSRect.null) { $0.union($1) }
        }
    }
    struct WeakView { weak var view: NSView? }
    let document: MarkdownRenderDocument
    private var items: [Int: [Int]] = [:]
    private var lists: [Int: Element] = [:]
    private var itemElements: [Int: Element] = [:]
    private var hosts: [Int: WeakView] = [:]
    private var leaves: [Int: WeakView] = [:]

    init(_ document: MarkdownRenderDocument) {
        self.document = document
        for node in document.nodes {
            if let list = node.listID {
                items[list, default: []].append(node.id)
                itemElements[node.id] = Element(store: self, id: node.id, list: false)
                if lists[list] == nil { lists[list] = Element(store: self, id: list, list: true) }
            }
        }
    }
    private func ownerItem(_ leaf: Int) -> Int? {
        var parent = document[leaf].parentID
        while let id = parent {
            if document[id].listID != nil { return id }
            parent = document[id].parentID
        }
        return nil
    }
    func bind(_ view: NSView, leaf: Int) -> Element? {
        guard document.nodes.indices.contains(leaf), let item = ownerItem(leaf) else { return nil }
        leaves[leaf] = WeakView(view: view)
        return itemElements[item]
    }
    func host(_ view: NSView, list: Int) -> Element? {
        hosts[list] = WeakView(view: view)
        return lists[list]
    }
}

struct DocumentListAccessibilityHost: NSViewRepresentable {
    let store: DocumentListAccessibility
    let list: Int
    final class Host: NSView {
        var list: DocumentListAccessibility.Element?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func isAccessibilityElement() -> Bool { false }
        override func accessibilityChildren() -> [Any]? { list.map { [$0] } }
    }
    func makeNSView(context: Context) -> Host { Host() }
    func updateNSView(_ view: Host, context: Context) { view.list = store.host(view, list: list) }
}
