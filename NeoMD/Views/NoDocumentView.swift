//
//  NoDocumentView.swift
//  NeoMD
//

import SwiftUI

/// The quiet opening instruction shown while NeoMD has no document window.
struct NoDocumentView: View {
    let openingCoordinator: DocumentOpeningCoordinator?

    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openDocument) private var openDocument

    init(openingCoordinator: DocumentOpeningCoordinator? = nil) {
        self.openingCoordinator = openingCoordinator
    }

    var body: some View {
        Text("Open a Markdown file with ⌘O, or drop one here.")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minWidth: 480, minHeight: 320)
            .accessibilityIdentifier("NoDocumentInstruction")
            .markdownFileDropDestination { url in
                try await openDocument(at: url)
            }
            .onAppear {
                if openingCoordinator?.shouldShowNoDocumentWindow == false {
                    dismissWindow()
                }
            }
    }
}

#Preview {
    NoDocumentView()
}
