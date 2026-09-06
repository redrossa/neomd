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

        case .heading(let level):
            Text(block.text)
                .font(Self.headingFont(level: level))
                .foregroundStyle(level >= 6 ? Color.secondary : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, level <= 2 ? 8 : 4)
                .accessibilityAddTraits(.isHeader)

        case .codeBlock:
            ScrollView(.horizontal) {
                Text(block.text)
                    .font(.system(.callout, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
            }
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))

        case .blockQuote:
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(.tertiary)
                    .frame(width: 3)
                Text(block.text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)

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
            }
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
