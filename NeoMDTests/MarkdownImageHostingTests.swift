import AppKit
import SwiftUI
import Testing
@testable import NeoMD

struct MarkdownImageHostingTests {
    /// Owned-host probe: unavailable image text plus its retry button, without
    /// reader restoration, document geometry preferences, or custom container layout.
    @Test @MainActor func unavailableParagraphsHaveStableHeightWhileScrolling() async throws {
        let url = URL(fileURLWithPath: "/unavailable/probe.png")
        let document = MarkdownBlockRenderer.render(from: "![Unavailable diagram](probe.png)",
                                                    documentURL: url.deletingLastPathComponent().appendingPathComponent("readme.md"))
        let text = try #require(document.roots.first?.text)
        let store = MarkdownImageStore(loader: { _ in .unavailable(.inaccessible) })
        store.load(url)
        for _ in 0..<1000 {
            if store.states[url] == .unavailable(.inaccessible) { break }
            await Task.yield()
        }
        #expect(store.states[url] == .unavailable(.inaccessible))
        let content = VStack {
            ForEach(0..<30) { id in
                MarkdownImageParagraph(id: id, text: text, availableWidth: 500)
            }
        }
        .environment(store)
        // #43 removed the obsolete folder-access callback. Scrolling assertions remain unchanged.
        let host = NSHostingView(rootView: content)
        host.frame = CGRect(x: 0, y: 0, width: 500, height: 3000)
        let scroll = NSScrollView(frame: CGRect(x: 0, y: 0, width: 500, height: 400))
        scroll.documentView = host
        let height = host.fittingSize.height
        for index in 0..<40 {
            scroll.contentView.scroll(to: CGPoint(x: 0, y: index.isMultiple(of: 2) ? 0 : height - 400))
            host.layoutSubtreeIfNeeded()
            #expect(host.fittingSize.height == height)
        }
        #expect(height > 400)
        store.reset()
    }
}
