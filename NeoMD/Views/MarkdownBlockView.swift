//
//  MarkdownBlockView.swift
//  NeoMD
//

import SwiftUI

/// Lays out a single rendered Markdown block.
struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let theme: ReaderTheme
    let keyboardFocus: FocusState<DocumentReaderFocusTarget?>.Binding
    let pageReader: (DocumentReaderPageDirection) -> Void
    var availableWidth: CGFloat = DocumentReaderLayout.maximumColumnWidth
    var quoted = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.documentKeyboardOpenURL) private var keyboardOpenURL
    @State private var selectedLink = 0
    @Environment(\.documentNavigationBridge) private var navigationBridge
    @Environment(\.documentNavigationGeneration) private var documentGeneration

    private var links: [(url: URL, range: Range<AttributedString.Index>, label: String)] {
        block.text.runs[\.link].compactMap { url, range in
            guard let url else { return nil }
            return (url, range, String(block.text.characters[range]))
        }
    }

    /// The block's text with the reader's appearance policy applied.
    private var text: AttributedString {
        let headingLevel: Int?
        if case .heading(let level) = block.kind {
            headingLevel = level
        } else {
            headingLevel = nil
        }
        var result = theme.presentationText(for: block.text, headingLevel: headingLevel)
        if keyboardFocus.wrappedValue == .links(block.id), !links.isEmpty {
            let range = links[selectedLink % links.count].range
            result[range].appKit.underlineStyle = .thick
            result[range].backgroundColor = Color.accentColor.opacity(0.2)
        }
        return result
    }

    var body: some View {
        blockContent
            .environment(\.documentLeafID, block.isLeaf ? block.id : nil)
            .background(alignment: .topLeading) {
                if let navigationBridge, !block.anchors.isEmpty {
                    DocumentNavigationMarker(bridge: navigationBridge, id: block.id,
                                             generation: documentGeneration)
                        .frame(width: 0, height: 0)
                        .allowsHitTesting(false)
                }
            }
            .background {
                let menuLinks = MarkdownLinkMenu.links(in: block.text)
                if block.isLeaf, !menuLinks.isEmpty {
                    MarkdownLinkContextMenuAttachment(links: menuLinks, open: { openURL($0) })
                }
            }
            .modifier(MarkdownLinkFocus(enabled: !links.isEmpty && block.isLeaf,
                id: block.id, keyboardFocus: keyboardFocus, handleKeyPress: handleLinkKeyPress))
            .modifier(MarkdownLinkAccessibility(
                id: block.id,
                value: links.isEmpty ? nil : "Link \(selectedLink % links.count + 1) of \(links.count): \(links[selectedLink % links.count].label)"
            ))
            .background {
                if block.isLeaf {
                    GeometryReader { geometry in
                        Color.clear.preference(key: DocumentBlockFramePreferenceKey.self, value: [
                            block.id: geometry.frame(in: .named(DocumentReaderCoordinateSpace.content))
                        ])
                    }
                    .accessibilityHidden(true)
                }
            }
    }

    private func handleLinkKeyPress(_ press: KeyPress) -> KeyPress.Result {
        guard !links.isEmpty, keyboardFocus.wrappedValue == .links(block.id) else { return .ignored }
        if let reverse = DocumentReaderTraversal.direction(press) {
            guard let traverse = navigationBridge?.traverse else { return .ignored }
            traverse(.links(block.id), reverse)
            return .handled
        }
        switch press.key {
        case .leftArrow: selectedLink = (selectedLink + links.count - 1) % links.count
        case .rightArrow: selectedLink = (selectedLink + 1) % links.count
        case .return, .space: (keyboardOpenURL ?? openURL)(links[selectedLink % links.count].url)
        case .escape: keyboardFocus.wrappedValue = .reader
        default: return .ignored
        }
        return .handled
    }

    @ViewBuilder
    private var blockContent: some View {
        switch block.kind {
        case .metadata(let content):
            MarkdownMetadataTable(content: content, theme: theme)

        case .paragraph:
            inlineContent
                .font(theme.font())
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .heading(let level):
            inlineContent
                .font(theme.font(headingLevel: level))
                .foregroundStyle(level >= 6 ? Color.secondary : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, level <= 2 ? 8 : 4)
                .accessibilityAddTraits(.isHeader)

        case .codeBlock:
            MarkdownCodeBlockView(
                block: block,
                theme: theme,
                keyboardFocus: keyboardFocus,
                pageReader: pageReader
            )

        case .blockQuote, .listItem, .footnote, .alert:
            // Container geometry/semantics are emitted by the flat root host.
            EmptyView()

        case .anchor:
            Color.clear.frame(height: 0).accessibilityHidden(true)

        case .thematicBreak:
            Divider()
                .padding(.vertical, 8)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var inlineContent: some View {
        if text.runs.contains(where: { $0.markdownImage != nil }) {
            MarkdownImageParagraph(id: block.id, text: text, availableWidth: availableWidth,
                                   headingLevel: imageHeadingLevel, quoted: quoted, scale: theme.scale)
        } else if MarkdownLinkedImageText.requiresNativeText(text) {
            MarkdownLinkedImageText(input: .init(text: text, states: [:], dark: colorScheme == .dark,
                width: availableWidth, headingLevel: imageHeadingLevel, quoted: quoted, scale: theme.scale))
        } else {
            Text(text)
        }
    }

    private var imageHeadingLevel: Int? {
        if case .heading(let level) = block.kind { return level }
        return nil
    }

}

/// Do not install a FocusState binding on containers: it would override the
/// binding of a link-bearing descendant (notably footnote return paragraphs).
private struct MarkdownLinkFocus: ViewModifier {
    let enabled: Bool
    let id: Int
    let keyboardFocus: FocusState<DocumentReaderFocusTarget?>.Binding
    let handleKeyPress: (KeyPress) -> KeyPress.Result

    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            DocumentFocusEffect { inheritedEffectEnabled in
                content.environment(\.isFocusEffectEnabled, inheritedEffectEnabled)
                    .focusable(true, interactions: .edit)
                    .focused(keyboardFocus, equals: .links(id))
                    .onKeyPress(keys: [.tab, .leftArrow, .rightArrow, .return, .space, .escape], action: handleKeyPress)
            }
        } else { content }
    }
}

private struct MarkdownLinkAccessibility: ViewModifier {
    let id: Int
    let value: String?

    @ViewBuilder func body(content: Content) -> some View {
        if let value {
            content.accessibilityElement(children: .contain)
                .accessibilityIdentifier("MarkdownLinkBlock-\(id)")
                .accessibilityValue(value)
                .accessibilityLabel(value)
                .accessibilityHint("Left and Right select a link. Return or Space opens it. Escape returns to reading.")
        } else { content }
    }
}

/// Keeps wide code keyboard-accessible without moving the surrounding reader.
private struct MarkdownCodeBlockView: View {
    let block: MarkdownBlock
    let theme: ReaderTheme
    let keyboardFocus: FocusState<DocumentReaderFocusTarget?>.Binding
    let pageReader: (DocumentReaderPageDirection) -> Void

    @State private var scrollPosition = ScrollPosition(edge: .leading)
    @State private var scrollMetrics = CodeBlockScrollMetrics.zero
    @Environment(\.documentNavigationBridge) private var navigationBridge
    @Environment(\.documentNavigationGeneration) private var documentGeneration

    var body: some View {
        DocumentFocusEffect { inheritedEffectEnabled in
            ScrollView(.horizontal) {
                Text(theme.presentationText(for: block.text))
                    .font(.system(size: NSFont.preferredFont(forTextStyle: .callout).pointSize * theme.scale, design: .monospaced))
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(12)
                    .environment(\.isFocusEffectEnabled, inheritedEffectEnabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.primary)
            .background(ReaderTheme.codeBackground, in: .rect(cornerRadius: 6))
            .accessibilityIdentifier("MarkdownCodeBlock-\(block.id)")
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: CodeBlockScrollMetrics.self) { geometry in
                CodeBlockScrollMetrics(geometry)
            } action: { oldMetrics, newMetrics in
                if oldMetrics.canScrollHorizontally,
                   !newMetrics.canScrollHorizontally,
                   keyboardFocus.wrappedValue == .codeBlock(block.id) {
                    keyboardFocus.wrappedValue = .reader
                }
                scrollMetrics = newMetrics

            }
            .background {
                if let navigationBridge {
                    DocumentNavigationMarker(bridge: navigationBridge, id: block.id,
                        generation: documentGeneration, codeOverflow: scrollMetrics.canScrollHorizontally)
                        .frame(width: 0, height: 0).allowsHitTesting(false)
                }
            }
            .focusable(scrollMetrics.canScrollHorizontally, interactions: .edit)
            .focused(keyboardFocus, equals: .codeBlock(block.id))
            .onKeyPress(
                keys: [
                    .tab,
                    .leftArrow,
                    .rightArrow,
                    .home,
                    .end,
                    .pageUp,
                    .pageDown,
                    .escape
                ]
            ) { keyPress in
                handleKeyPress(keyPress)
            }
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        if let reverse = DocumentReaderTraversal.direction(keyPress) {
            guard let traverse = navigationBridge?.traverse else { return .ignored }
            traverse(.codeBlock(block.id), reverse)
            return .handled
        }
        let selectionModifiers: EventModifiers = [.shift, .control]
        guard keyPress.modifiers.intersection(selectionModifiers).isEmpty else {
            return .ignored
        }

        switch keyPress.key {
        case .leftArrow:
            if keyPress.modifiers.contains(.command) {
                scrollPosition.scrollTo(edge: .leading)
            } else {
                scrollPosition.scrollTo(
                    x: max(0, scrollMetrics.horizontalOffset - scrollIncrement(for: keyPress))
                )
            }
        case .rightArrow:
            if keyPress.modifiers.contains(.command) {
                scrollPosition.scrollTo(edge: .trailing)
            } else {
                scrollPosition.scrollTo(
                    x: scrollMetrics.horizontalOffset + scrollIncrement(for: keyPress)
                )
            }
        case .home:
            scrollPosition.scrollTo(edge: .leading)
        case .end:
            scrollPosition.scrollTo(edge: .trailing)
        case .pageUp:
            guard hasNoExplicitModifiers(keyPress) else { return .ignored }
            keyboardFocus.wrappedValue = .reader
            pageReader(.up)
        case .pageDown:
            guard hasNoExplicitModifiers(keyPress) else { return .ignored }
            keyboardFocus.wrappedValue = .reader
            pageReader(.down)
        case .escape:
            keyboardFocus.wrappedValue = .reader
        default:
            return .ignored
        }
        return .handled
    }

    private func hasNoExplicitModifiers(_ keyPress: KeyPress) -> Bool {
        let explicitModifiers: EventModifiers = [
            .shift,
            .control,
            .command,
            .option
        ]
        return keyPress.modifiers.intersection(explicitModifiers).isEmpty
    }

    private func scrollIncrement(for keyPress: KeyPress) -> CGFloat {
        if keyPress.modifiers.contains(.option) {
            return max(40, scrollMetrics.viewportWidth * 0.8)
        }
        return 40
    }
}

private nonisolated struct CodeBlockScrollMetrics: Equatable, Sendable {
    static let zero = CodeBlockScrollMetrics(
        horizontalOffset: 0,
        viewportWidth: 0,
        canScrollHorizontally: false
    )

    let horizontalOffset: CGFloat
    let viewportWidth: CGFloat
    let canScrollHorizontally: Bool

    init(_ geometry: ScrollGeometry) {
        horizontalOffset = geometry.contentOffset.x
        viewportWidth = geometry.containerSize.width
        canScrollHorizontally = geometry.contentSize.width > geometry.containerSize.width + 1
    }

    private init(
        horizontalOffset: CGFloat,
        viewportWidth: CGFloat,
        canScrollHorizontally: Bool
    ) {
        self.horizontalOffset = horizontalOffset
        self.viewportWidth = viewportWidth
        self.canScrollHorizontally = canScrollHorizontally
    }
}

private struct MarkdownBlockViewPreview: View {
    @FocusState private var keyboardFocus: DocumentReaderFocusTarget?

    var body: some View {
        let document = MarkdownBlockRenderer.render(from: """
                    # Release notes

                    A short paragraph with **bold**, *italic*, and `inline code`.

                    - First item
                    - Second item
                    - [ ] Pending **review**
                      - [x] Nested completed task

                    5. [x] Shipped with [notes](https://example.com)
                    6. [ ] Next release

                    > A quoted aside.
                    >
                    > > A nested quotation with `inline code`.

                    ```swift
                    print("hello")
                    ```
                    """)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(document.roots) { block in
                    MarkdownContainerView(
                        document: document,
                        rootID: block.id,
                        width: 640,
                        theme: ReaderTheme(),
                        keyboardFocus: $keyboardFocus,
                        pageReader: { _ in }
                    )
                }
            }
            .padding(32)
        }
    }
}

#Preview {
    MarkdownBlockViewPreview()
}
