//
//  MarkdownFileDropModifier.swift
//  NeoMD
//

import SwiftUI

/// A shared drop target that accepts only file URLs claimed by NeoMD.
private struct MarkdownFileDropModifier: ViewModifier {
    let openDocument: @MainActor (URL) async throws -> Void

    @State private var isTargeted = false
    @State private var openingErrorMessage: String?

    func body(content: Content) -> some View {
        content
            .contentShape(.rect)
            .dropDestination(for: URL.self) { urls, _ in
                let acceptedURLs = MarkdownDropRouting.acceptedFileURLs(from: urls)
                guard !acceptedURLs.isEmpty else { return false }

                // Acquire any drag-provided sandbox extensions before the drop callback
                // returns. Keep them alive until the document system finishes opening.
                let securedURLs = acceptedURLs.map { url in
                    (url: url, didStartAccess: url.startAccessingSecurityScopedResource())
                }

                Task { @MainActor in
                    defer {
                        for securedURL in securedURLs where securedURL.didStartAccess {
                            securedURL.url.stopAccessingSecurityScopedResource()
                        }
                    }

                    do {
                        for securedURL in securedURLs {
                            try await openDocument(securedURL.url)
                        }
                    } catch {
                        openingErrorMessage = Self.message(for: error)
                    }
                }
                return true
            } isTargeted: { isTargeted in
                self.isTargeted = isTargeted
            }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .padding(8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .alert(
                "Couldn’t Open Document",
                isPresented: Binding(
                    get: { openingErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            openingErrorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    openingErrorMessage = nil
                }
            } message: {
                Text(openingErrorMessage ?? "The file could not be opened.")
            }
    }

    private static func message(for error: Error) -> String {
        let error = error as NSError
        if let recoverySuggestion = error.localizedRecoverySuggestion,
           !recoverySuggestion.isEmpty {
            return "\(error.localizedDescription) \(recoverySuggestion)"
        }
        return error.localizedDescription
    }
}

extension View {
    func markdownFileDropDestination(
        openDocument: @escaping @MainActor (URL) async throws -> Void
    ) -> some View {
        modifier(MarkdownFileDropModifier(openDocument: openDocument))
    }
}
