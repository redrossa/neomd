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

    /// The block's text with the reader's appearance policy applied.
    private var text: AttributedString {
        theme.presentationText(for: block.text)
    }

    var body: some View {
        switch block.kind {
        case .paragraph:
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .heading(let level):
            Text(text)
                .font(Self.headingFont(level: level))
                .foregroundStyle(level >= 6 ? Color.secondary : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, level <= 2 ? 8 : 4)
                .accessibilityAddTraits(.isHeader)

        case .codeBlock:
            MarkdownCodeBlockView(
                block: block,
                keyboardFocus: keyboardFocus,
                pageReader: pageReader
            )

        case .blockQuote:
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(.tertiary)
                    .frame(width: 3)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

        case .listItem(let marker, let depth):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(marker)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 18, alignment: .trailing)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, CGFloat(depth - 1) * 22)

        case .thematicBreak:
            Divider()
                .padding(.vertical, 8)
                .accessibilityHidden(true)
        }
    }

    /// The type scale used for each heading level.
    private static func headingFont(level: Int) -> Font {
        switch level {
        case 1: .system(.largeTitle, weight: .semibold)
        case 2: .system(.title, weight: .semibold)
        case 3: .system(.title2, weight: .semibold)
        case 4: .system(.title3, weight: .semibold)
        case 5: .system(.headline)
        default: .system(.subheadline, weight: .semibold)
        }
    }
}

/// Keeps wide code keyboard-accessible without moving the surrounding reader.
private struct MarkdownCodeBlockView: View {
    let block: MarkdownBlock
    let keyboardFocus: FocusState<DocumentReaderFocusTarget?>.Binding
    let pageReader: (DocumentReaderPageDirection) -> Void

    @State private var scrollPosition = ScrollPosition(edge: .leading)
    @State private var scrollMetrics = CodeBlockScrollMetrics.zero

    var body: some View {
        ScrollView(.horizontal) {
            Text(block.text)
                .font(.system(.callout, design: .monospaced))
                .fixedSize(horizontal: true, vertical: true)
                .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))
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
        .focusable(scrollMetrics.canScrollHorizontally, interactions: .edit)
        .focused(keyboardFocus, equals: .codeBlock(block.id))
        .onKeyPress(
            keys: [
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

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(MarkdownBlockRenderer.blocks(from: """
                    # Release notes

                    A short paragraph with **bold**, *italic*, and `inline code`.

                    - First item
                    - Second item

                    > A quoted aside.

                    ```
                    print("hello")
                    ```
                    """)) { block in
                    MarkdownBlockView(
                        block: block,
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
