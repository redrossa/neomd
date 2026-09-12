import AppKit
import SwiftUI

/// One logical selection for one presentation; weak mounts are only geometry adapters.
@MainActor final class DocumentSelectionController {
    typealias Key = DocumentTextProjection.Key
    private struct Mount { weak var view: MarkdownLinkedImageTextView?; let token: DocumentSelectionState.Registration }
    private(set) var state: DocumentSelectionState
    let accessibility: DocumentListAccessibility?
    weak var bridge: DocumentNavigationBridge?
    private var mounts: [Key: Mount] = [:]
    private var imageProjections: [Key: MarkdownCellDisplayProjection] = [:]
    var write: (String) -> Void
    var changed: ((DocumentTextProjection.RefreshDescriptor?) -> Void)?
    var interaction: ((Bool) -> Void)?
    var acquire: ((Key) -> Void)?
    private(set) var dragging = false

    init(reader: UUID, projection: DocumentTextProjection, document: MarkdownRenderDocument? = nil, write: @escaping (String) -> Void = { text in
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }) {
        state = DocumentSelectionState(reader: reader, generation: 0, projection: projection)
        self.write = write
        accessibility = document.map(DocumentListAccessibility.init)
    }

    func bind(_ view: MarkdownLinkedImageTextView, key: Key) {
        if mounts[key]?.view === view { return }
        guard let token = state.register(key, scope: state.scope) else { return }
        mounts[key] = Mount(view: view, token: token)
        view.semanticParent = accessibility?.bind(view, leaf: key.leafID)
        sync()
    }

    func unbind(_ view: MarkdownLinkedImageTextView, key: Key) {
        guard let mount = mounts[key], mount.view === view else { return }
        state.unregister(mount.token)
        mounts.removeValue(forKey: key)
        if dragging { finish() }
    }

    func update(_ view: MarkdownLinkedImageTextView, key: Key, projection: MarkdownCellDisplayProjection,
                previous: MarkdownCellDisplayProjection?) {
        guard let mount = mounts[key], mount.view === view,
              let old = state.projection.fragment(for: key) else { return }
        if old.text == projection.content.string && old.sourceSegments == projection.segments { sync(); return }
        let fragment = DocumentTextProjection.Fragment(key: key, text: projection.content.string,
            attachments: projection.segments.filter { $0.kind == .attachment }.map(\.display),
            identity: old.identity, separator: old.separator, sourceSegments: projection.segments)
        _ = state.replace(fragment, registration: mount.token) { offset in
            guard let previous else { return min(offset, projection.content.length) }
            return projection.remap(NSRange(location: offset, length: 0), from: previous).location
        }
        sync()
    }

    func restore(_ descriptor: DocumentTextProjection.RefreshDescriptor?) {
        guard let descriptor else { return }
        _ = state.setSelection(state.projection.resolve(descriptor), scope: state.scope)
        sync()
    }

    func select(_ selection: DocumentTextProjection.Selection?) {
        _ = state.setSelection(selection, scope: state.scope)
        sync()
    }

    func selectAll() { select(state.projection.entireSelection) }
    func copy() { if !state.copiedText.isEmpty { write(state.copiedText) } }

    func localSelection(_ range: NSRange, key: Key, extending: Bool) {
        let anchor = extending ? state.selection?.anchor : nil
        let extent = anchor?.key == key && range.location < (anchor?.offset ?? 0) ? range.location : NSMaxRange(range)
        select(.init(anchor: anchor ?? .init(key: key, offset: range.location),
                     extent: .init(key: key, offset: extent)))
    }

    func begin(key: Key, range: NSRange, extending: Bool) {
        if !dragging { dragging = true; interaction?(true) }
        localSelection(range, key: key, extending: extending)
    }

    func finish() {
        guard dragging else { return }
        dragging = false
        interaction?(false)
    }

    func drag(at point: NSPoint, window: NSWindow) {
        guard let anchor = state.selection?.anchor else { return }
        if let scroll = bridge?.owner, scroll.window === window {
            let local = scroll.contentView.convert(point, from: nil)
            var bounds = scroll.contentView.bounds
            if local.y < bounds.minY { bounds.origin.y -= 24 }
            if local.y > bounds.maxY { bounds.origin.y += 24 }
            scroll.contentView.scroll(to: scroll.contentView.constrainBoundsRect(bounds).origin)
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        let candidates = mounts.compactMap { key, mount -> (Key, MarkdownLinkedImageTextView, CGFloat)? in
            guard let view = mount.view, view.window === window, !view.visibleRect.isEmpty else { return nil }
            let rect = view.convert(view.visibleRect, to: nil)
            let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
            let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
            return (key, view, dx * dx + dy * dy)
        }
        guard let nearest = candidates.min(by: { $0.2 < $1.2 }) else { return }
        let offset = nearest.1.characterIndexForInsertion(at: nearest.1.convert(point, from: nil))
        select(.init(anchor: anchor, extent: .init(key: nearest.0, offset: offset)))
        if let scroll = nearest.1.enclosingScrollView {
            let local = scroll.contentView.convert(point, from: nil)
            var bounds = scroll.contentView.bounds
            if local.x < bounds.minX { bounds.origin.x -= 20 }
            if local.x > bounds.maxX { bounds.origin.x += 20 }
            scroll.contentView.scroll(to: scroll.contentView.constrainBoundsRect(bounds).origin)
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }

    func extendBeyond(key: Key, forward: Bool) {
        let fragments = state.projection.fragments
        guard let index = fragments.firstIndex(where: { $0.key == key }) else { return }
        let next = index + (forward ? 1 : -1)
        guard fragments.indices.contains(next) else { return }
        let target = fragments[next]
        let anchor = state.selection?.anchor ?? .init(key: key, offset: forward ? fragments[index].text.utf16.count : 0)
        select(.init(anchor: anchor, extent: .init(key: target.key, offset: forward ? min(1, target.text.utf16.count) : target.text.utf16.count)))
        if let view = mounts[target.key]?.view {
            view.window?.makeFirstResponder(view)
            view.scrollRangeToVisible(NSRange(location: forward ? 0 : target.text.utf16.count, length: 0))
        } else { acquire?(target.key) }
    }

    private func sync() {
        for (key, mount) in mounts {
            guard mount.view?.string == state.projection.fragment(for: key)?.text else { continue }
            mount.view?.applyDocumentSelection(state.slice(for: mount.token))
        }
        changed?(state.selection.flatMap { state.projection.refreshDescriptor(for: $0) })
    }

    func updateLabels(_ document: MarkdownRenderDocument, width: CGFloat, scale: CGFloat) {
        var fragments = state.projection.fragments.filter { $0.key.part != -10 }
        for root in document.rootIDs {
            let geometry = MarkdownContainerGeometry(document: document, rootID: root, width: width, scale: scale)
            for entry in geometry.viewEntries {
                if let caption = entry.caption {
                    fragments.append(.init(key: .init(leafID: entry.id, part: -10), text: caption,
                        identity: .init(source: caption, role: "depth-caption", context: [])))
                }
            }
        }
        fragments.sort { $0.key.leafID == $1.key.leafID ? $0.key.part < $1.key.part : $0.key.leafID < $1.key.leafID }
        state.replaceProjection(.init(presentation: state.scope.presentation, fragments: fragments))
        sync()
    }

    func updateImages(_ document: MarkdownRenderDocument, states: [URL: MarkdownImageStore.State], dark: Bool) {
        for node in document.leaves where node.text.runs.contains(where: { $0.markdownImage != nil }) {
            let key = Key(leafID: node.id)
            guard let fragment = state.projection.fragment(for: key) else { continue }
            var text = "", segments: [MarkdownCellDisplayProjection.Segment] = []
            var sourceOffset = 0
            for (image, range) in node.text.runs[\.markdownImage] {
                let source = String(node.text.characters[range])
                let start = text.utf16.count
                var kind = MarkdownCellDisplayProjection.Kind.text
                if let image {
                    let alt = source.replacingOccurrences(of: MarkdownPictureParser.emptyAltCarrier, with: "")
                    let value = image.url(preferringDark: dark).flatMap { states[$0] }
                    if case .loaded = value { text += "\u{FFFC}"; kind = .attachment }
                    else {
                        let unavailable = image.url(preferringDark: dark) == nil || (value != nil && value != .loading)
                        text += "\(alt.isEmpty ? "Image" : alt) (\(unavailable ? "Image unavailable" : "Image loading"))"
                        kind = .fallback
                    }
                } else { text += source }
                segments.append(.init(source: NSRange(location: sourceOffset, length: source.utf16.count),
                    display: NSRange(location: start, length: text.utf16.count - start), occurrence: image?.occurrence, kind: kind))
                sourceOffset += source.utf16.count
            }
            let projection = MarkdownCellDisplayProjection(source: String(node.text.characters), content: NSAttributedString(string: text), segments: segments)
            let previous = imageProjections[key]
            imageProjections[key] = projection
            if fragment.text == text && fragment.sourceSegments == segments { continue }
            let next = DocumentTextProjection.Fragment(key: key, text: text,
                attachments: segments.filter { $0.kind == .attachment }.map(\.display), identity: fragment.identity, separator: fragment.separator, sourceSegments: segments)
            state.replaceDisplay(next, scope: state.scope) { offset in
                previous.map { projection.remap(NSRange(location: offset, length: 0), from: $0).location } ?? min(offset, text.utf16.count)
            }
        }
        sync()
    }

    func detach() {
        finish()
        changed = nil; interaction = nil; acquire = nil
        mounts.removeAll()
    }
}

extension EnvironmentValues {
    @Entry var documentSelection: DocumentSelectionController? = nil
    @Entry var documentTextPart = 0
    @Entry var documentTextSourceOffset = 0
}

/// Cheap string projection: no native storage, font layout or image decoding for lazy leaves.
extension DocumentTextProjection {
    static func rendered(_ document: MarkdownRenderDocument, presentation: UUID) -> Self {
        var fragments: [Fragment] = []
        var section = ""
        for node in document.nodes {
            if case .heading = node.kind { section = String(node.text.characters) }
            var context = [section]
            if let cell = document.tableCell(for: node.id) {
                context += document.tableCells(in: cell.tableID).filter { $0.rowIndex == 0 || $0.rowIndex == cell.rowIndex }
                    .map { String(document[$0.leafID].text.characters) }
                context.append("column \(cell.columnIndex)")
            }
            let identity = Identity(source: String(node.text.characters), role: String(describing: node.kind), context: context)
            if case .metadata(let content) = node.kind {
                switch content {
                case .formatted(let metadata):
                    for (row, value) in metadata.rows.enumerated() {
                        fragments.append(.init(key: .init(leafID: node.id, part: row * 2), text: value.key,
                            identity: .init(source: value.key, role: "metadata-key", context: [value.key, value.value]), separator: row == 0 ? "\n\n" : "\n"))
                        fragments.append(.init(key: .init(leafID: node.id, part: row * 2 + 1), text: value.value,
                            identity: .init(source: value.value, role: "metadata-value", context: [value.key, value.value]), separator: "\t"))
                    }
                case .literal(let source):
                    fragments.append(.init(key: .init(leafID: node.id, part: -1), text: MarkdownFrontMatter.Content.explanation))
                    fragments.append(.init(key: .init(leafID: node.id), text: String(source), identity: identity))
                }
                continue
            }
            if case .alert(let alert) = node.kind {
                fragments.append(.init(key: .init(leafID: node.id), text: alert.label, identity: identity))
                continue
            }
            guard node.isLeaf, node.kind != .anchor, node.kind != .thematicBreak else { continue }
            var text = ""
            for (image, range) in node.text.runs[\.markdownImage] {
                let value = String(node.text.characters[range])
                if let image {
                    let alt = value.replacingOccurrences(of: MarkdownPictureParser.emptyAltCarrier, with: "")
                    text += "\(alt.isEmpty ? "Image" : alt) (\(image.url(preferringDark: false) == nil ? "Image unavailable" : "Image loading"))"
                } else { text += value }
            }
            var separator = "\n\n"
            if let cell = document.tableCell(for: node.id) { separator = cell.columnIndex == 0 ? (cell.rowIndex == 0 ? "\n\n" : "\n") : "\t" }
            else if let parent = node.parentID, case .listItem = document[parent].kind { separator = "\n" }
            fragments.append(.init(key: .init(leafID: node.id), text: text, identity: identity, separator: separator))
        }
        return Self(presentation: presentation, fragments: fragments)
    }
}
