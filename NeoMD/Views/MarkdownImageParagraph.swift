import SwiftUI

struct MarkdownImageParagraph: View {
    let id: Int
    let text: AttributedString
    let availableWidth: CGFloat
    var headingLevel: Int? = nil
    var quoted = false

    @Environment(MarkdownImageStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.documentImageAccess) private var requestAccess
    @FocusState private var accessIsFocused: Bool

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
            if text.runs.contains(where: { $0.markdownImage != nil && $0.link != nil }) {
                MarkdownLinkedImageText(input: .init(text: text,
                    states: store.states.filter { urls.contains($0.key) }, dark: colorScheme == .dark,
                    width: availableWidth, headingLevel: headingLevel, quoted: quoted))
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
            if let url = urls.first(where: { store.states[$0] == .unavailable(.inaccessible) }), requestAccess != nil {
                Button("Allow folder access") { requestFolderAccess(url) }
                .buttonStyle(.borderless)
                .focusable(true, interactions: .edit)
                .focused($accessIsFocused)
                .overlay {
                    if accessIsFocused {
                        RoundedRectangle(cornerRadius: 3).stroke(Color.accentColor, lineWidth: 2)
                            .padding(-3).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                .onKeyPress(keys: [.return, .space]) { _ in
                    requestFolderAccess(url)
                    return .handled
                }
                .font(.callout)
                .accessibilityIdentifier("MarkdownImageAccessButton-\(id)")
                .accessibilityHint("Choose the folder that contains this document's images; access lasts until you quit.")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: urls) { for url in urls { store.load(url) } }
    }

    private func requestFolderAccess(_ url: URL) {
        Task { await requestAccess?(url) }
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

extension EnvironmentValues {
    @Entry var documentImageAccess: ((URL) async -> Void)? = nil
}
