import SwiftUI
import XCTest
@testable import NeoMD

/// Select each method in a separate xcodebuild invocation: a framework crash
/// must not be confused with a zero-test success or hide subsequent cases.
final class MarkdownContainerHostingTests: XCTestCase {
    @MainActor func testDeepQuoteHostRelease() async throws {
        try await hostAndRelease {
            MarkdownBlockRenderer.render(from:
                String(repeating: "> ", count: 50000) + "retained [link](#target) <a id='target'></a>")
        }
    }

    @MainActor func testDeepBranchingHostRelease() async throws {
        try await hostAndRelease {
            let depth = 1000
            var nodes: [MarkdownBlock] = []
            for level in 0..<depth {
                let id = level * 2
                nodes.append(MarkdownBlock(id: id, kind: .blockQuote, text: "",
                    childIDs: level == depth - 1 ? [id + 1] : [id + 1, id + 2], parentID: level == 0 ? nil : id - 2))
                nodes.append(MarkdownBlock(id: id + 1, kind: .paragraph, text: "retained", parentID: id))
            }
            return MarkdownRenderDocument(nodes: nodes, rootIDs: [0])
        }
    }

    @MainActor func testMixedContainerHostRelease() async throws {
        try await hostAndRelease {
            // Twenty quotes cross the width budget: 300 > 128 at320, < 520 at760.
            // Both main text and the structured footnote must be hosted, not just root0.
            let quote = String(repeating: "> ", count: 20)
            let lines = [quote + "7. [x] Mixed completed [jump](#target)", quote,
                         quote + "   Mixed adjacent.", quote, quote + "8. [ ] Mixed pending.",
                         "", "# Target", "", "Reference[^m].", "",
                         "[^m]: Note first.", "", "    " + quote + "- [ ] Note task.",
                         "    " + quote, "    " + quote + "  Note adjacent.", "", "    Note last."]
            let document = MarkdownBlockRenderer.render(from: lines.joined(separator: "\n"))
            XCTAssertEqual(document.nodes.filter { $0.kind == .blockQuote }.count, 40)
            let items = document.nodes.filter { if case .listItem = $0.kind { return true }; return false }
            XCTAssertEqual(items.map { node -> String in
                guard case .listItem(let marker, _) = node.kind else { return "invalid" }
                return marker
            }, ["7.", "8.", "•"])
            XCTAssertEqual(items.map(\.task), [.complete, .incomplete, .incomplete])
            XCTAssertEqual(document.nodes.filter { if case .footnote = $0.kind { return true }; return false }.count, 1)
            XCTAssertEqual(document.leafIDs.map { String(document[$0].text.characters) },
                           ["Mixed completed jump", "Mixed adjacent.", "Mixed pending.", "Target",
                            "Reference1.", "Note first.", "Note task.", "Note adjacent.", "Note last. ↩"])
            XCTAssertNotNil(document.anchorTargets["target"])
            XCTAssertEqual(Set(document.nodes.map(\.id)).count, document.nodes.count)
            return document
        }
    }

    @MainActor func testLiveMarkerIdentityAcrossCompressionAndGenerations() async throws {
        let document = MarkdownBlockRenderer.render(from:
            String(repeating: "> ", count: 20) + "<a id='target'></a>retained [link](#target)")
        let target = try XCTUnwrap(document.anchorTargets["target"])
        XCTAssertEqual(target, 20)
        let bridge = DocumentNavigationBridge()
        let evidence = HostingGeometryEvidence()
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 760, height: 400),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: window.contentLayoutRect)
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        var host: NSHostingView<RegisteredLifecycleSurface>? = NSHostingView(rootView:
            RegisteredLifecycleSurface(document: document, width: 760, evidence: evidence,
                                       bridge: bridge, generation: 0))
        host!.sizingOptions = []
        host!.frame = CGRect(x: 0, y: 0, width: 760, height: 1200)
        scroll.documentView = host
        window.contentView = scroll
        window.orderFront(nil)
        defer { window.contentView = nil; window.close() }
        host!.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(bridge.owner === scroll)
        weak var original = bridge.destination(target)
        XCTAssertNotNil(original)
        XCTAssertNil(bridge.destination(99999), "Unmaterialized destination must stay unresolved")
        XCTAssertNil(bridge.position(id: 99999, request: bridge.request))
        for width: CGFloat in [320, 760, 320, 760] {
            host!.rootView = RegisteredLifecycleSurface(document: document, width: width, evidence: evidence,
                                                       bridge: bridge, generation: bridge.generation)
            host!.frame.size.width = width
            host!.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertTrue(bridge.destination(target) === original,
                          "Actual marker identity must survive both compression boundaries")
            XCTAssertNotNil(bridge.position(id: target, request: bridge.request))
        }
        for _ in 0..<3 {
            let staleRequest = bridge.request
            bridge.replaceDocument()
            XCTAssertNil(bridge.owner)
            XCTAssertNil(bridge.destination(target))
            XCTAssertNil(bridge.position(id: target, request: staleRequest))
            host!.rootView = RegisteredLifecycleSurface(document: document, width: 760, evidence: evidence,
                                                       bridge: bridge, generation: bridge.generation)
            host!.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertTrue(bridge.owner === scroll)
            XCTAssertNotNil(bridge.destination(target))
            XCTAssertNotNil(bridge.position(id: target, request: bridge.request))
        }
        weak var finalMarker = bridge.destination(target)
        host!.rootView = RegisteredLifecycleSurface(document: .empty, width: 760, evidence: evidence,
                                                   bridge: bridge, generation: bridge.generation)
        host!.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(bridge.destination(target))
        scroll.documentView = nil
        host = nil
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(original)
        XCTAssertNil(finalMarker)
        XCTAssertNil(bridge.owner)
    }

    @MainActor private func hostAndRelease(_ makeDocument: () -> MarkdownRenderDocument) async throws {
        // The async callee owns the snapshot and every strong native reference.
        // Its return ends those scopes before cleanup checks and the completion sentinel.
        let ownership = try await exerciseNativeHost(makeDocument)
        for _ in 0..<40 {
            if ownership.isReleased { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertNil(ownership.host)
        XCTAssertFalse(ownership.surfaces.isEmpty, "Must observe actual production drawing objects")
        for surface in ownership.surfaces {
            XCTAssertNil(surface.view, "Actual QuotePathView must be released")
            XCTAssertNil(surface.decoration, "Actual MarkdownQuoteDecoration storage must be released")
        }
        XCTAssertTrue(ownership.isReleased)
        if ownership.isReleased { print("NATIVE_HOST_RELEASED") }
    }

    @MainActor private func exerciseNativeHost(_ makeDocument: () -> MarkdownRenderDocument) async throws
        -> NativeOwnershipEvidence {
        let document = makeDocument()
        let ownership = NativeOwnershipEvidence()
        let start = ContinuousClock.now
        let evidence = HostingGeometryEvidence()
        var host: NSHostingView<LifecycleSurface>? = NSHostingView(rootView:
            LifecycleSurface(document: document, width: 320, evidence: evidence))
        ownership.host = host
        // With sizingOptions=[] AppKit fittingSize is intentionally zero; assert
        // actual named-coordinate leaf frames instead of that disabled intrinsic size.
        host!.sizingOptions = []
        let height: CGFloat = document.rootIDs.count > 1 ? 1600 : 200
        host!.frame = CGRect(x: 0, y: 0, width: 320, height: height)
        let window = NSWindow(contentRect: host!.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        host!.layoutSubtreeIfNeeded()
        print("HOST_INITIAL_LAYOUT nodes=\(document.nodes.count) elapsed=\(start.duration(to: .now))")
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(Set(evidence.frames.keys), Set(document.leafIDs))
        for frame in evidence.frames.values {
            XCTAssertGreaterThan(frame.height, 0)
            XCTAssertGreaterThanOrEqual(frame.width, 192)
            XCTAssertGreaterThanOrEqual(frame.minX, 0)
            XCTAssertLessThanOrEqual(frame.maxX, 320)
            if document.rootIDs.count > 1 {
                XCTAssertGreaterThanOrEqual(frame.minY, 0)
                XCTAssertLessThanOrEqual(frame.maxY, height, "Mixed leaves must lie inside the drawn bitmap")
            }
        }
        var pending: [NSView] = [host!]
        while let view = pending.popLast() {
            if let surface = view as? QuotePathView {
                XCTAssertNotNil(surface.decoration)
                ownership.surfaces.append(WeakQuoteSurface(surface))
            }
            pending.append(contentsOf: view.subviews)
        }
        XCTAssertEqual(ownership.surfaces.count, document.rootIDs.count,
                       "Observe each actual root surface, including structured footnotes")
        XCTAssertTrue(ownership.surfaces.contains { !($0.decoration?.bars.isEmpty ?? true) })
        let compressedCounts = document.rootIDs.map {
            MarkdownContainerGeometry(document: document, rootID: $0, width: 320).entries.filter { $0.compressed }.count
        }
        let wideCounts = document.rootIDs.map {
            MarkdownContainerGeometry(document: document, rootID: $0, width: 760).entries.filter { $0.compressed }.count
        }
        XCTAssertGreaterThan(compressedCounts.reduce(0, +), wideCounts.reduce(0, +))
        let drawStart = ContinuousClock.now
        if let image = host!.bitmapImageRepForCachingDisplay(in: host!.bounds) {
            host!.cacheDisplay(in: host!.bounds, to: image)
        } else { XCTFail("Native host must produce a drawable surface") }
        print("HOST_DRAW nodes=\(document.nodes.count) elapsed=\(drawStart.duration(to: .now))")
        let resizeStart = ContinuousClock.now
        host!.rootView = LifecycleSurface(document: document, width: 760, evidence: evidence)
        host!.frame.size.width = 760
        host!.layoutSubtreeIfNeeded()
        print("HOST_RESIZE nodes=\(document.nodes.count) elapsed=\(resizeStart.duration(to: .now))")
        try await Task.sleep(for: .milliseconds(100))
        for surface in ownership.surfaces {
            XCTAssertNotNil(surface.view)
            XCTAssertNotNil(surface.decoration)
            XCTAssertTrue(surface.view?.decoration === surface.decoration)
        }
        if let image = host!.bitmapImageRepForCachingDisplay(in: host!.bounds) {
            host!.cacheDisplay(in: host!.bounds, to: image)
        } else { XCTFail("Resized native host must draw") }
        host!.rootView = LifecycleSurface(document: .empty, width: 760, evidence: evidence)
        host!.layoutSubtreeIfNeeded()
        window.contentView = nil
        window.close()
        host = nil
        return ownership
    }
}

@MainActor private final class WeakQuoteSurface {
    weak var view: QuotePathView?
    weak var decoration: MarkdownQuoteDecoration?

    init(_ view: QuotePathView) {
        self.view = view
        decoration = view.decoration
    }
}

@MainActor private final class NativeOwnershipEvidence {
    weak var host: NSView?
    var surfaces: [WeakQuoteSurface] = []
    var isReleased: Bool {
        host == nil && !surfaces.isEmpty && surfaces.allSatisfy { $0.view == nil && $0.decoration == nil }
    }
}

@MainActor private final class HostingGeometryEvidence {
    var frames: [Int: CGRect] = [:]
}

private struct RegisteredLifecycleSurface: View {
    let document: MarkdownRenderDocument
    let width: CGFloat
    let evidence: HostingGeometryEvidence
    let bridge: DocumentNavigationBridge
    let generation: Int

    var body: some View {
        LifecycleSurface(document: document, width: width, evidence: evidence)
            .background(alignment: .topLeading) {
                DocumentNavigationMarker(bridge: bridge, id: nil, generation: generation)
                    .frame(width: 0, height: 0).allowsHitTesting(false)
            }
            .environment(\.documentNavigationBridge, bridge)
            .environment(\.documentNavigationGeneration, generation)
    }
}

private struct LifecycleSurface: View {
    let document: MarkdownRenderDocument
    let width: CGFloat
    let evidence: HostingGeometryEvidence
    @FocusState private var focus: DocumentReaderFocusTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(document.rootIDs, id: \.self) { root in
                MarkdownContainerView(document: document, rootID: root, width: width,
                                      theme: ReaderTheme(), keyboardFocus: $focus, pageReader: { _ in })
            }
        }
        .frame(width: width, alignment: .topLeading)
        .coordinateSpace(name: DocumentReaderCoordinateSpace.content)
        .onPreferenceChange(DocumentBlockFramePreferenceKey.self) { evidence.frames = $0 }
    }
}
