import AppKit
import SwiftUI

/// Transient actions in authored document order; destinations are never resolved for display.
nonisolated struct MarkdownLinkMenu {
    enum Entry: Equatable {
        case destination(URL)
        case openLink(URL)
        case copyLink(URL)
        case separator

        var title: String {
            switch self {
            case .destination(let url): url.absoluteString
            case .openLink: "Open Link"
            case .copyLink: "Copy Link"
            case .separator: ""
            }
        }
    }

    let entries: [Entry]

    init(links: [(label: String, url: URL)]) {
        entries = links.enumerated().flatMap { index, link in
            (index == 0 ? [] : [Entry.separator]) + [
                .destination(link.url), .openLink(link.url), .copyLink(link.url)
            ]
        }
    }

    static func links(in text: AttributedString) -> [(label: String, url: URL)] {
        var links: [(label: String, url: URL)] = []
        var previousEnd: AttributedString.Index?
        for run in text.runs {
            guard let url = run.link, run.markdownGeneratedReference == nil else {
                previousEnd = nil
                continue
            }
            let label = String(text.characters[run.range])
            if previousEnd == run.range.lowerBound, links.last?.url == url {
                links[links.count - 1].label += label
            } else {
                links.append((label, url))
            }
            previousEnd = run.range.upperBound
        }
        return links
    }
}

/// Releasing this owner removes the local monitor, including when its view deallocates.
final class MarkdownLinkMenuMonitor {
    private let token: Any?

    init(handler: @escaping (NSEvent) -> NSEvent?) {
        token = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown], handler: handler)
    }

    deinit {
        if let token { NSEvent.removeMonitor(token) }
    }
}

struct MarkdownLinkContextMenuAttachment: NSViewRepresentable {
    let links: [(label: String, url: URL)]
    let open: (URL) -> Void

    func makeNSView(context: Context) -> MarkdownLinkContextMenuView {
        MarkdownLinkContextMenuView()
    }

    static func dismantleNSView(_ view: MarkdownLinkContextMenuView, coordinator: ()) {
        view.detach()
    }

    func updateNSView(_ view: MarkdownLinkContextMenuView, context: Context) {
        view.entries = MarkdownLinkMenu(links: links).entries
        view.open = open
    }
}

/// A background attachment, never a hit target. Native selectable Text stays foremost.
final class MarkdownLinkContextMenuView: NSView {
    var entries: [MarkdownLinkMenu.Entry] = []
    var open: (URL) -> Void = { _ in }

    override var acceptsFirstResponder: Bool { false }
    override func isAccessibilityElement() -> Bool { false }

    private(set) var monitor: MarkdownLinkMenuMonitor?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        monitor = nil
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, monitor == nil else { return }
        monitor = MarkdownLinkMenuMonitor { [weak self] event in
            guard let self, self.owns(event) else { return event }
            self.showMenu(with: event)
            return nil
        }
    }

    /// Only this leaf's visible document area owns the secondary event, not another
    /// window, a native control (including scrollbars), or a window blocked by a sheet.
    func owns(_ event: NSEvent) -> Bool {
        guard let window, event.window === window, window.attachedSheet == nil,
              !entries.isEmpty, !isHiddenOrHasHiddenAncestor,
              event.type == .rightMouseDown ||
                (event.type == .leftMouseDown && event.modifierFlags.contains(.control)) else { return false }
        let point = convert(event.locationInWindow, from: nil)
        // SwiftUI-backed visibleRect can extend beyond bounds; neither check alone suffices.
        guard bounds.contains(point), visibleRect.contains(point) else { return false }
        var hit = window.contentView?.hitTest(event.locationInWindow)
        while let view = hit {
            // Selectable SwiftUI Text can be backed by a noneditable NSTextField.
            if let field = view as? NSTextField {
                if field.isEditable { return false }
            } else if view is NSControl {
                return false
            }
            hit = view.superview
        }
        return true
    }

    func detach() {
        monitor = nil
        open = { _ in }
        entries = []
    }

    private func showMenu(with event: NSEvent) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for entry in entries {
            if entry == .separator { menu.addItem(.separator()); continue }
            let item = NSMenuItem(title: entry.title, action: #selector(activate(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry
            if case .destination = entry { item.isEnabled = false }
            menu.addItem(item)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func activate(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? MarkdownLinkMenu.Entry else { return }
        switch entry {
        case .openLink(let url): open(url)
        case .copyLink(let url):
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(url.absoluteString, forType: .string)
            if url.scheme != nil { pasteboard.writeObjects([url as NSURL]) }
        case .destination, .separator: break
        }
    }
}
