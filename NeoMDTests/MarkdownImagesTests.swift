import AppKit
import ImageIO
import Observation
import Testing
@testable import NeoMD

struct MarkdownImagesTests {
    private let documentURL = URL(fileURLWithPath: "/packet/readme.md")

    @Test func pictureBlockBecomesAnImageParagraph() throws {
        let document = MarkdownBlockRenderer.render(from: """
        <picture>
          <source media="(prefers-color-scheme: dark)" srcset="img/moon.png">
          <source media="(prefers-color-scheme: light)" srcset="img/sun.png">
          <img alt="Sun &amp; moon" src="img/fallback.png">
        </picture>
        """, documentURL: documentURL)
        let block = try #require(document.roots.first)
        #expect(block.kind == .paragraph)
        #expect(String(block.text.characters) == "Sun & moon")
        let image = try #require(block.text.runs.first?.markdownImage)
        #expect(image.darkSource?.path == "/packet/img/moon.png")
        #expect(image.lightSource?.path == "/packet/img/sun.png")
        #expect(image.source?.path == "/packet/img/fallback.png")
        #expect(block.text.runs.first?.inlinePresentationIntent?.contains(.blockHTML) != true)
    }

    @Test func pictureSourcesUseTheDocumentPathPolicy() throws {
        for (path, expected) in [("img/x.png", "/packet/img/x.png"), ("/img/x.png", "/packet/img/x.png"),
                                 ("../x.png", "/x.png"), ("https://example.com/x.png", "/x.png")] {
            let picture = try #require(MarkdownPictureParser.parse("<picture><img src=\"\(path)\"></picture>", documentURL: documentURL))
            #expect(picture.image.source?.path == expected)
            #expect(picture.image.source?.isFileURL == !path.hasPrefix("https"))
        }
    }

    @Test func pictureWithoutImgOrWithExtraContentStaysLiteral() {
        for html in ["<picture><source srcset='x'></picture>", "<picture><img src='x'></picture><p>extra</p>",
                     "Sentence <picture><img src='x'></picture>", "<picture><script>bad</script><img src='x'></picture>"] {
            #expect(MarkdownPictureParser.parse(html, documentURL: documentURL) == nil)
        }
    }

    @Test func malformedPicturesStayLiteralAndAdjacentImagesRemainSeparate() throws {
        for markup in ["<picture><img src='x' src='y'></picture>",
                       "<picture><img src='x></picture>",
                       "<picture><img src='x'><img src='y'></picture>",
                       "<picture><div><img src='x'></div></picture>",
                       "<picture><img src='x' broken></picture>"] {
            #expect(MarkdownPictureParser.parse(markup, documentURL: documentURL) == nil)
        }
        let document = MarkdownBlockRenderer.render(from: "![same](x.png)![same](x.png)", documentURL: documentURL)
        let text = try #require(document.roots.first?.text)
        let images = text.runs[\.markdownImage].compactMap { $0.0 }
        try #require(images.count == 2)
        #expect(images[0].source == images[1].source)
        #expect(images[0].occurrence != images[1].occurrence)
    }

    @Test func emptyAltImagesKeepACarrierRunAndContextsRetainImages() throws {
        let empty = MarkdownBlockRenderer.render(from: "![](x.png)", documentURL: documentURL)
        #expect(String(try #require(empty.roots.first).text.characters) == MarkdownPictureParser.emptyAltCarrier)
        #expect(empty.roots.first?.text.runs.first?.imageURL?.path == "/packet/x.png")
        let document = MarkdownBlockRenderer.render(from: """
        # ![Heading](x.png)

        > ![Quote](x.png)

        - ![List](x.png)

        | Column |
        | --- |
        | ![Cell](x.png) |

        Note[^1]

        [^1]: ![Footnote](x.png)
        """)
        #expect(document.nodes.filter { $0.text.runs.contains { $0.markdownImage != nil } }.count == 5)
        let badge = MarkdownBlockRenderer.render(from: "before [![**bold** alt](x.png)](https://example.com) after")
        #expect(badge.roots.first?.text.runs.contains { $0.markdownImage != nil && $0.link?.host == "example.com" } == true)
    }

    @Test func adjacentSameURLImagesRetainDistinctAttachmentRuns() throws {
        let document = MarkdownBlockRenderer.render(from: "![first](x.png)![second](x.png)")
        let text = try #require(document.roots.first?.text)
        #expect(text.runs[\.markdownImage].filter { $0.0 != nil }.count == 2)
    }

    @Test func malformedPictureAttributesRemainLiteral() {
        for html in ["<picture><img src='x' src='y'></picture>",
                     "<picture><img src='x' broken=></picture>",
                     "<picture><img src='x' garbage></picture>"] {
            #expect(MarkdownPictureParser.parse(html, documentURL: documentURL) == nil)
        }
    }

    @Test func appearanceSelectionPrefersMatchingSourceThenFallback() {
        let fallback = URL(string: "https://example.com/base")!
        let dark = URL(string: "https://example.com/dark")!
        let image = MarkdownImage(source: fallback, lightSource: nil, darkSource: dark)
        #expect(image.url(preferringDark: true) == dark)
        #expect(image.url(preferringDark: false) == fallback)
    }

    @Test func displaySizeClampsToWidthPreservingAspectRatio() {
        #expect(MarkdownImageLayout.displaySize(natural: CGSize(width: 1200, height: 300), availableWidth: 680) == CGSize(width: 680, height: 170))
        #expect(MarkdownImageLayout.displaySize(natural: CGSize(width: 64, height: 32), availableWidth: 680) == CGSize(width: 64, height: 32))
        #expect(MarkdownImageLayout.displaySize(natural: .zero, availableWidth: 680) == .zero)
        #expect(MarkdownImageLayout.displaySize(natural: CGSize(width: 64, height: 32), availableWidth: -1) == .zero)
    }

    @Test func loaderClassifiesMissingInaccessibleUndecodableAndUnavailable() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("bad.png")
        try Data("not image".utf8).write(to: file)
        #expect(await failure(file) == .undecodable)
        chmod(file.path, 0)
        #expect(await failure(file) == .inaccessible)
        chmod(file.path, 0o644)
        #expect(await failure(directory.appendingPathComponent("absent.png")) == .missing)
        #expect(await failure(directory) == .undecodable)
        #expect(await failure(URL(string: "http://127.0.0.1:1/x.png")!) == .unavailable)
        for scheme in ["data:image/png;base64,AA==", "ftp://example.com/x.png"] {
            #expect(await failure(URL(string: scheme)!) == .unavailable)
        }
    }

    @Test func systemFormatsDecodeConcurrentlyAndVectorsKeepNaturalSize() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/m1-12-images/img")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<4 {
                for (name, size) in [("wide.png", CGSize(width: 1200, height: 300)), ("small.png", CGSize(width: 64, height: 32)),
                                     ("vector.svg", CGSize(width: 200, height: 100))] {
                    group.addTask {
                        let data = try Data(contentsOf: root.appendingPathComponent(name))
                        if name == "vector.svg", let source = CGImageSourceCreateWithData(data as CFData, nil) {
                            #expect(CGImageSourceCreateImageAtIndex(source, 0, nil) == nil)
                        }
                        let result = await Task.detached { MarkdownImageLoader.decode(data) }.value
                        guard case .loaded(let bitmap, let natural) = result else { Issue.record("Decode failed: \(name)"); return }
                        #expect(natural == size)
                        #expect(bitmap.width > 0 && bitmap.height > 0)
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    private func failure(_ url: URL) async -> MarkdownImageFailure? {
        let result = await Task.detached { await MarkdownImageLoader.load(url) }.value
        if case .unavailable(let failure) = result { return failure }
        return nil
    }

    @Test @MainActor func resetRejectsOldSameURLLoadsAndReleasesStore() async {
        let gate = ImageLoadGate()
        var store: MarkdownImageStore? = MarkdownImageStore { _ in await gate.wait() }
        weak var weakStore = store
        let url = URL(string: "https://example.com/image")!
        store?.load(url)
        await gate.waitForCount(1)
        store?.load(url)
        #expect(await gate.count == 1)
        store?.reset()
        store?.load(url)
        await gate.waitForCount(2)
        await gate.finish(0, failure: .missing)
        for _ in 0..<20 { await Task.yield() }
        #expect(store?.states[url] == .loading)
        await gate.finish(1, failure: .undecodable)
        if let store { await waitForState(.unavailable(.undecodable), of: store, url: url) }
        #expect(store?.states[url] == .unavailable(.undecodable))
        store?.reset()
        store?.load(url)
        await gate.waitForCount(3)
        store = nil
        #expect(weakStore == nil)
        await gate.finish(2, failure: .missing)
    }
    @MainActor private func waitForState(_ expected: MarkdownImageStore.State, of store: MarkdownImageStore, url: URL) async {
        while store.states[url] != expected {
            await withCheckedContinuation { continuation in
                withObservationTracking {
                    _ = store.states[url]
                } onChange: {
                    Task { @MainActor in continuation.resume() }
                }
            }
        }
    }
}

private actor ImageLoadGate {
    private var continuations: [CheckedContinuation<MarkdownImageLoadResult, Never>] = []
    var count: Int { continuations.count }
    func wait() async -> MarkdownImageLoadResult {
        await withCheckedContinuation { continuations.append($0) }
    }
    func waitForCount(_ expected: Int) async {
        while count < expected { await Task.yield() }
    }
    func finish(_ index: Int, failure: MarkdownImageFailure) {
        continuations[index].resume(returning: .unavailable(failure))
    }
}
