//
//  MarkdownBlockView.swift
//  NeoMD
//

import SwiftUI

/// Lays out a single rendered Markdown block.
struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block.kind {
        case .paragraph:
            Text(block.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .heading(let level):
            Text(block.text)
                .font(Self.headingFont(level: level))
                .foregroundStyle(level >= 6 ? Color.secondary : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, level <= 2 ? 8 : 4)
                .accessibilityAddTraits(.isHeader)

        case .codeBlock:
            MarkdownCodeBlockView(block: block)

        case .blockQuote:
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(.tertiary)
                    .frame(width: 3)
                Text(block.text)
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
                Text(block.text)
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
        } action: { _, newMetrics in
            scrollMetrics = newMetrics
        }
        .focusable(scrollMetrics.canScrollHorizontally, interactions: .edit)
        .onKeyPress(keys: [.leftArrow, .rightArrow, .home, .end]) { keyPress in
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
        default:
            return .ignored
        }
        return .handled
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

#Preview {
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
                MarkdownBlockView(block: block)
            }
        }
        .padding(32)
    }
}
