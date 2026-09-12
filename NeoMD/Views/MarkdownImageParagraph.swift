import SwiftUI

struct MarkdownImageParagraph: View {
    let id: Int
    let text: AttributedString
    let availableWidth: CGFloat
    var headingLevel: Int? = nil
    var quoted = false
    var scale: CGFloat = 1
    var tableCell: MarkdownTableCellPresentation? = nil

    @Environment(MarkdownImageStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var retryIsFocused: Bool

    private var segments: [(MarkdownImage?, AttributedString)] {
        text.runs[\.markdownImage].map { image, range in (image, AttributedString(text[range])) }
    }

    private var urls: [URL] {
        segments.compactMap { $0.0?.url(preferringDark: colorScheme == .dark) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MarkdownLinkedImageText(input: .init(text: text,
                states: store.states.filter { urls.contains($0.key) }, dark: colorScheme == .dark,
                width: availableWidth, headingLevel: headingLevel, quoted: quoted, scale: scale,
                tableCell: tableCell))
            if urls.contains(where: { store.states[$0] == .unavailable(.inaccessible) }) {
                Text("Check file permissions in Finder and NeoMD’s access in System Settings > Privacy & Security.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Retry image") { store.retryInaccessible() }
                .buttonStyle(.borderless)
                .focusable(true, interactions: .edit)
                .focused($retryIsFocused)
                .overlay {
                    if retryIsFocused {
                        RoundedRectangle(cornerRadius: 3).stroke(Color.accentColor, lineWidth: 2)
                            .padding(-3).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                .onKeyPress(keys: [.return, .space]) { _ in
                    store.retryInaccessible()
                    return .handled
                }
                .font(.callout)
                .accessibilityIdentifier("MarkdownImageRetryButton-\(id)")
                .accessibilityHint("Retry reading the image after checking access in macOS. No folder picker is opened.")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: urls) { for url in urls { store.load(url) } }
    }

}
