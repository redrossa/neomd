import SwiftUI

/// Plain native cells only. No Markdown initializer, URL actions or source mode.
/// A flat row list keeps nested YAML ownership and view depth bounded.
struct MarkdownMetadataTable: View {
    let content: MarkdownFrontMatter.Content
    let theme: ReaderTheme
    var highlight: DocumentFindHighlight? = nil

    private func text(_ string: String, offset: Int) -> Text {
        let local: NSRange?
        if let range = highlight?.range, range.location >= offset,
           NSMaxRange(range) <= offset + string.utf16.count {
            local = NSRange(location: range.location - offset, length: range.length)
        } else { local = nil }
        return Text(DocumentFindHighlight.applying(local, to: AttributedString(string)))
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
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            text(row.key, offset: offset).fontWeight(.semibold)
                                .frame(maxWidth: 200, alignment: .leading)
                            text(row.value, offset: offset + row.key.utf16.count + 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            text(row.key, offset: offset).fontWeight(.semibold)
                            text(row.value, offset: offset + row.key.utf16.count + 2)
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
                text(String(source), offset: 0)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(theme.font())
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
