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

    private var imageOnly: Bool {
        segments.allSatisfy { $0.0 != nil || String($0.1.characters).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var label: String {
        let alt = String(text.characters).replacingOccurrences(of: MarkdownPictureParser.emptyAltCarrier, with: "")
        return alt.isEmpty ? "Image" : alt
    }

    private var status: String {
        if urls.isEmpty { return "Image unavailable" }
        if urls.contains(where: { store.states[$0] == nil || store.states[$0] == .loading }) { return "Image loading" }
        if urls.contains(where: { if case .unavailable = store.states[$0] { return true }; return false }) { return "Image unavailable" }
        return "Image displayed"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if tableCell != nil || MarkdownLinkedImageText.requiresNativeText(text) {
                MarkdownLinkedImageText(input: .init(text: text,
                    states: store.states.filter { urls.contains($0.key) }, dark: colorScheme == .dark,
                    width: availableWidth, headingLevel: headingLevel, quoted: quoted, scale: scale,
                    tableCell: tableCell))
            } else if imageOnly {
                composedText
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityLabel(label)
                    .accessibilityValue(status)
                    .accessibilityIdentifier("MarkdownImageBlock-\(id)")
            } else {
                composedText
            }
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

    private var composedText: Text {
        segments.reduce(Text("")) { result, segment in
            guard let image = segment.0 else { return Text("\(result)\(Text(segment.1))") }
            let alt = String(segment.1.characters).replacingOccurrences(of: MarkdownPictureParser.emptyAltCarrier, with: "")
            let attachment: Text
            if let url = image.url(preferringDark: colorScheme == .dark),
               case .loaded(let original, let natural) = store.states[url],
               let fitted = original.copy() as? NSImage {
                fitted.size = MarkdownImageLayout.displaySize(natural: natural, availableWidth: availableWidth)
                attachment = Text(Image(nsImage: fitted)).accessibilityLabel(Text(alt.isEmpty ? "Image" : alt))
            } else {
                attachment = Text("\(Image(systemName: "photo")) \(alt)").foregroundColor(.secondary)
            }
            return Text("\(result)\(attachment)")
        }
    }
}
