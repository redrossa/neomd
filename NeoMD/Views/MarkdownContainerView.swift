import SwiftUI

/// All semantic nodes are siblings, independent of Markdown nesting depth.
/// The same leaf view identity survives resizing and compression transitions.
struct MarkdownContainerView: View {
    let document: MarkdownRenderDocument
    let rootID: Int
    let width: CGFloat
    let theme: ReaderTheme
    let keyboardFocus: FocusState<DocumentReaderFocusTarget?>.Binding
    let pageReader: (DocumentReaderPageDirection) -> Void

    @State private var decoration = MarkdownQuoteDecoration()
    @Environment(\.documentNavigationBridge) private var navigationBridge
    @Environment(\.documentNavigationGeneration) private var documentGeneration

    var body: some View {
        let geometry = MarkdownContainerGeometry(document: document, rootID: rootID, width: width)
        MarkdownContainerLayout(geometry: geometry, decoration: decoration) {
            ForEach(geometry.viewEntries, id: \.id) { entry in
                let node = document[entry.id]
                nodeView(node, entry: entry, budget: geometry.budget)
                    .background(alignment: .topLeading) {
                        if !node.isLeaf, !node.anchors.isEmpty, let navigationBridge {
                            DocumentNavigationMarker(bridge: navigationBridge, id: node.id,
                                                     generation: documentGeneration)
                                .frame(width: 0, height: 0).allowsHitTesting(false)
                        }
                    }
            }
        }
        .background { MarkdownQuoteDecorationSurface(decoration: decoration).allowsHitTesting(false).accessibilityHidden(true) }
    }

    @ViewBuilder private func nodeView(_ node: MarkdownBlock,
                                      entry: MarkdownContainerGeometry.Entry, budget: CGFloat) -> some View {
        if node.isLeaf {
            MarkdownBlockView(block: node, theme: theme, keyboardFocus: keyboardFocus, pageReader: pageReader,
                              availableWidth: entry.width, quoted: entry.quoted)
                .foregroundStyle(entry.quoted ? Color.secondary : Color.primary)
        } else {
            switch node.kind {
            case .blockQuote:
                Group {
                    if let caption = entry.caption { depthLabel(caption).padding(.leading, 4) }
                    else { Color.clear.frame(height: 0) }
                }
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.caption ?? "Block quote")
                .accessibilityHint(entry.compressed ? "All nested quotes and text are retained in source order. Indentation is compressed to preserve readable text width." : "")
                .accessibilityIdentifier("MarkdownBlockQuote-\(node.id)")
                .accessibilityHidden(entry.compressed && entry.caption == nil)
            case .listItem(let marker, _):
                if let caption = entry.caption {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        MarkdownListMarker(block: node, marker: marker).frame(width: 28, alignment: .trailing)
                        depthLabel(caption)
                    }
                } else {
                    MarkdownListMarker(block: node, marker: marker).frame(width: 28, alignment: .trailing)
                }
            case .footnote(let ordinal):
                HStack(alignment: .top, spacing: 8) {
                    Text("\(ordinal).").accessibilityHidden(true).frame(width: 28, alignment: .trailing)
                    if let caption = entry.caption { depthLabel(caption) }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.caption ?? "Footnote \(ordinal)")
                .accessibilityIdentifier("MarkdownFootnote-\(node.id)")
            default:
                Color.clear.frame(height: 0).accessibilityHidden(true)
            }
        }
    }

    private func depthLabel(_ caption: String) -> some View {
        Text(caption).font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHint("Indentation is compressed to preserve readable text width. All content is retained in source order.")
    }
}

struct MarkdownListMarker: View {
    let block: MarkdownBlock
    let marker: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if block.task == nil || marker.hasSuffix(".") {
                Text(marker).font(.body).foregroundStyle(.secondary).accessibilityHidden(true)
            }
            if let task = block.task {
                Image(systemName: task == .complete ? "checkmark.square.fill" : "square")
                    .foregroundStyle(.primary)
                    .accessibilityLabel(task == .complete ? "Completed task" : "Incomplete task")
                    .accessibilityIdentifier("MarkdownTaskMarker-\(block.id)")
            }
        }
        .fixedSize()
    }
}
