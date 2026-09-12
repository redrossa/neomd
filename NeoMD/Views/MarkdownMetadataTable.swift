import SwiftUI

/// One active layout per part, so hidden alternative layouts cannot steal registrations.
struct MarkdownMetadataTable: View {
    let content: MarkdownFrontMatter.Content
    let theme: ReaderTheme
    var highlight: DocumentFindHighlight? = nil

    private func text(_ string: String, part: Int, offset: Int, bold: Bool = false) -> some View {
        var value = AttributedString(string)
        if bold { value.inlinePresentationIntent = .stronglyEmphasized }
        return MarkdownLinkedImageText(input: .init(text: value, states: [:], dark: false,
            width: 300, headingLevel: nil, scale: theme.scale))
            .environment(\.documentTextPart, part)
            .environment(\.documentTextSourceOffset, offset)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch content {
            case .formatted(let metadata):
                ForEach(metadata.rows.indices, id: \.self) { index in
                    let row = metadata.rows[index]
                    let offset = metadata.rows.prefix(index).reduce(0) {
                        $0 + $1.key.utf16.count + 2 + $1.value.utf16.count + 1
                    }
                    HStack(alignment: .top, spacing: 16) {
                        text(row.key, part: index * 2, offset: offset, bold: true)
                            .frame(maxWidth: 200, alignment: .leading)
                        text(row.value, part: index * 2 + 1, offset: offset + row.key.utf16.count + 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(index.isMultiple(of: 2) ? ReaderTheme.codeBackground : Color.clear)
                    .accessibilityElement(children: .contain)
                    if index < metadata.rows.count - 1 { Divider().accessibilityHidden(true) }
                }
            case .literal(let source):
                text(MarkdownFrontMatter.Content.explanation, part: -1, offset: Int.max / 2)
                    .padding(.bottom, 8)
                text(String(source), part: 0, offset: 0)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(theme.font())
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
