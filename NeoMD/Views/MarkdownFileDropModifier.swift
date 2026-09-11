import SwiftUI

private struct MarkdownFileDropModifier: ViewModifier {
    let openDocuments: @MainActor ([URL]) -> Void
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .contentShape(.rect)
            .dropDestination(for: URL.self) { urls, _ in
                let accepted = MarkdownDropRouting.acceptedFileURLs(from: urls)
                guard !accepted.isEmpty else { return false }
                openDocuments(accepted)
                return true
            } isTargeted: { isTargeted = $0 }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .padding(8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}

extension View {
    func markdownFileDropDestination(openDocuments: @escaping @MainActor ([URL]) -> Void) -> some View {
        modifier(MarkdownFileDropModifier(openDocuments: openDocuments))
    }
}
