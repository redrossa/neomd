import SwiftUI

/// Plain native cells only. No Markdown initializer, URL actions or source mode.
/// A flat row list keeps nested YAML ownership and view depth bounded.
struct MarkdownMetadataTable: View {
    let content: MarkdownFrontMatter.Content
    let theme: ReaderTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch content {
            case .formatted(let metadata):
                ForEach(metadata.rows.indices, id: \.self) { index in
                    let row = metadata.rows[index]
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            Text(verbatim: row.key).fontWeight(.semibold)
                                .frame(maxWidth: 200, alignment: .leading)
                            Text(verbatim: row.value).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: row.key).fontWeight(.semibold)
                            Text(verbatim: row.value)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(index.isMultiple(of: 2) ? ReaderTheme.codeBackground : Color.clear)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: row.accessibilityLabel))
                    if index < metadata.rows.count - 1 { Divider().accessibilityHidden(true) }
                }
            case .literal(let source):
                Text(verbatim: MarkdownFrontMatter.Content.explanation)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                Text(verbatim: String(source))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(theme.font())
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
