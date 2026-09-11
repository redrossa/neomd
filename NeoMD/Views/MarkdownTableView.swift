//
//  MarkdownTableView.swift
//  NeoMD
//

import SwiftUI

/// A table is one atomic layout surface inside the reader.
///
/// It reports the width it was allotted and keeps any extra width inside its own
/// horizontal scroller, so a wide table never makes the document scroll sideways.
/// The reader's single vertical viewport is untouched: there is no nested vertical
/// scroller and no height cap.
struct MarkdownTableView: View {
    let document: MarkdownRenderDocument
    let tableID: Int
    let theme: ReaderTheme
    let keyboardFocus: FocusState<DocumentReaderFocusTarget?>.Binding
    let pageReader: (DocumentReaderPageDirection) -> Void
    let width: CGFloat
    var quoted = false

    @State private var metrics = MarkdownTableMetrics.zero
    @State private var command: MarkdownTableScrollCommand?
    @State private var commandCount = 0
    @Environment(MarkdownImageStore.self) private var imageStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.documentKeyboardOpenURL) private var keyboardOpenURL
    @Environment(\.documentPointerOpenURL) private var pointerOpenURL
    @Environment(\.documentNavigationBridge) private var navigationBridge
    @Environment(\.documentNavigationGeneration) private var documentGeneration

    var body: some View {
        DocumentFocusEffect { inheritedEffectEnabled in
            MarkdownTableRepresentable(input: input(focusEffectEnabled: inheritedEffectEnabled),
                                       command: command, onMetrics: publish)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("MarkdownTable-\(tableID)")
                .focusable(metrics.overflows, interactions: .edit)
                .focused(keyboardFocus, equals: .tableOverflow(tableID))
                .onKeyPress(
                    keys: [.tab, .leftArrow, .rightArrow, .home, .end, .pageUp, .pageDown, .escape]
                ) { keyPress in
                    handleKeyPress(keyPress)
                }
                .background {
                    if let navigationBridge {
                        DocumentNavigationMarker(bridge: navigationBridge, id: tableID,
                                                 generation: documentGeneration,
                                                 tableOverflow: metrics.overflows)
                            .frame(width: 0, height: 0).allowsHitTesting(false)
                    }
                }
                .background {
                    // Cell reading frames are published explicitly: SwiftUI
                    // preferences do not cross the cells' native hosting boundary.
                    GeometryReader { proxy in
                        Color.clear.preference(key: DocumentBlockFramePreferenceKey.self,
                                               value: readingFrames(in: proxy))
                    }
                    .accessibilityHidden(true)
                }
        }
    }

    private func input(focusEffectEnabled: Bool) -> MarkdownTableSurfaceInput {
        MarkdownTableSurfaceInput(
            document: document, tableID: tableID, theme: theme, width: width, quoted: quoted,
            dark: colorScheme == .dark, imageStates: imageStates,
            environment: MarkdownTableCellEnvironment(
                imageStore: imageStore, bridge: navigationBridge, generation: documentGeneration,
                colorScheme: colorScheme, focusEffectEnabled: focusEffectEnabled,
                openURL: openURL, keyboardOpenURL: keyboardOpenURL, pointerOpenURL: pointerOpenURL),
            keyboardFocus: keyboardFocus, pageReader: pageReader)
    }

    /// Only the states this table's own images need, so an unrelated load does not
    /// remeasure the table.
    private var imageStates: [URL: MarkdownImageStore.State] {
        let urls = Set(document.tableCells(in: tableID).flatMap { address -> [URL] in
            document[address.leafID].text.runs[\.markdownImage].compactMap { image, _ in
                image?.url(preferringDark: colorScheme == .dark)
            }
        })
        guard !urls.isEmpty else { return [:] }
        return imageStore.states.filter { urls.contains($0.key) }
    }

    /// The table's own frame plus each cell's vertical reading position. Local
    /// horizontal scrolling is the table's business, so cell frames stay inside the
    /// table's own column.
    private func readingFrames(in proxy: GeometryProxy) -> [Int: CGRect] {
        let frame = proxy.frame(in: .named(DocumentReaderCoordinateSpace.content))
        var result = [tableID: frame]
        for (leafID, rect) in metrics.cellFrames {
            result[leafID] = CGRect(x: frame.minX, y: frame.minY + rect.minY,
                                    width: min(rect.width, max(0, frame.width)), height: rect.height)
        }
        return result
    }

    private func publish(_ next: MarkdownTableMetrics) {
        guard next != metrics else { return }
        // The surface measures inside a SwiftUI update; never reflow synchronously
        // back into it.
        DispatchQueue.main.async {
            guard next != metrics else { return }
            if metrics.overflows, !next.overflows,
               keyboardFocus.wrappedValue == .tableOverflow(tableID) {
                keyboardFocus.wrappedValue = .reader
            }
            metrics = next
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard let key = Self.key(for: keyPress.key) else { return .ignored }
        switch MarkdownTableLayout.action(for: key, modifiers: keyPress.modifiers,
                                         offset: metrics.offset,
                                         viewportWidth: metrics.viewportWidth) {
        case .scroll(let offset): send(.offset(offset))
        case .leadingEdge: send(.leadingEdge)
        case .trailingEdge: send(.trailingEdge)
        case .page(let isUp):
            keyboardFocus.wrappedValue = .reader
            pageReader(isUp ? .up : .down)
        case .returnToReader:
            keyboardFocus.wrappedValue = .reader
        case .traverse(let reverse):
            guard let traverse = navigationBridge?.traverse else { return .ignored }
            traverse(.tableOverflow(tableID), reverse)
        case .ignored:
            return .ignored
        }
        return .handled
    }

    private func send(_ target: MarkdownTableScrollCommand.Target) {
        commandCount += 1
        command = MarkdownTableScrollCommand(target: target, id: commandCount)
    }

    static func key(for equivalent: KeyEquivalent) -> MarkdownTableKey? {
        switch equivalent {
        case .leftArrow: .left
        case .rightArrow: .right
        case .home: .home
        case .end: .end
        case .pageUp: .pageUp
        case .pageDown: .pageDown
        case .escape: .escape
        case .tab: .tab
        default: nil
        }
    }
}

private struct MarkdownTableRepresentable: NSViewRepresentable {
    let input: MarkdownTableSurfaceInput
    let command: MarkdownTableScrollCommand?
    let onMetrics: (MarkdownTableMetrics) -> Void

    func makeNSView(context: Context) -> MarkdownTableScrollView {
        MarkdownTableScrollView(frame: .zero)
    }

    func updateNSView(_ view: MarkdownTableScrollView, context: Context) {
        view.onMetrics = onMetrics
        view.update(input, command: command)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: MarkdownTableScrollView,
                      context: Context) -> CGSize? {
        view.measuredSize(width: proposal.width ?? input.width)
    }

    static func dismantleNSView(_ view: MarkdownTableScrollView, coordinator: ()) {
        view.detach()
    }
}
