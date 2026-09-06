//
//  DocumentReaderView.swift
//  NeoMD
//

import SwiftUI

/// The reading surface for an open Markdown document.
///
/// The view is handed already-decoded text by ``MarkdownDocument`` and renders it into
/// blocks off the main thread, so raw Markdown source is never on screen — not while a
/// document is loading and not if rendering fails.
struct DocumentReaderView: View {
    let document: MarkdownDocument

    @State private var blocks: [MarkdownBlock] = []
    @State private var isRendered = false

    var body: some View {
        ScrollView(.vertical) {
            content
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(minWidth: 480, minHeight: 320)
        .task(id: document.text) {
            await render(document.text)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !isRendered {
            // Deliberately blank: a document's first visible content is its rendered
            // form, never its source.
            Color.clear
                .frame(height: 1)
                .accessibilityHidden(true)
        } else if blocks.isEmpty {
            Text("This document is empty.")
                .font(.body)
                .foregroundStyle(.secondary)
        } else {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(blocks) { block in
                    MarkdownBlockView(block: block)
                }
            }
            .textSelection(.enabled)
        }
    }

    /// Renders `source` away from the main actor and publishes the result.
    private func render(_ source: String) async {
        isRendered = false
        let rendered = await Task.detached(priority: .userInitiated) {
            MarkdownBlockRenderer.blocks(from: source)
        }.value
        guard !Task.isCancelled else { return }
        blocks = rendered
        isRendered = true
    }
}

#Preview {
    DocumentReaderView(
        document: MarkdownDocument(text: """
            # Quarterly summary

            Opened straight from Finder, no import step.

            1. Revenue held steady.
            2. Churn fell slightly.
            """)
    )
}
