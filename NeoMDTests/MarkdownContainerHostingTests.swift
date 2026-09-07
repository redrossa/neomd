import SwiftUI
import XCTest
@testable import NeoMD

/// Select each method in a separate xcodebuild invocation: a framework crash
/// must not be confused with a zero-test success or hide subsequent cases.
final class MarkdownContainerHostingTests: XCTestCase {
    @MainActor func testDeepQuoteHostRelease() async throws {
        try await hostAndRelease(MarkdownBlockRenderer.render(
            from: String(repeating: "> ", count: 50000) + "retained [link](#target) <a id='target'></a>"))
    }

    @MainActor func testDeepBranchingHostRelease() async throws {
        let depth = 1000
        var nodes: [MarkdownBlock] = []
        for level in 0..<depth {
            let id = level * 2
            nodes.append(MarkdownBlock(id: id, kind: .blockQuote, text: "",
                childIDs: level == depth - 1 ? [id + 1] : [id + 1, id + 2], parentID: level == 0 ? nil : id - 2))
            nodes.append(MarkdownBlock(id: id + 1, kind: .paragraph, text: "retained", parentID: id))
        }
        try await hostAndRelease(MarkdownRenderDocument(nodes: nodes, rootIDs: [0]))
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

    @MainActor private func hostAndRelease(_ document: MarkdownRenderDocument) async throws {
        weak var weakHost: NSHostingView<LifecycleSurface>?
        let start = ContinuousClock.now
        let evidence = HostingGeometryEvidence()
        var host: NSHostingView<LifecycleSurface>? = NSHostingView(rootView:
            LifecycleSurface(document: document, width: 320, evidence: evidence))
        weakHost = host
        // With sizingOptions=[] AppKit fittingSize is intentionally zero; assert
        // actual named-coordinate leaf frames instead of that disabled intrinsic size.
        host!.sizingOptions = []
        host!.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
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
        }
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
        host!.rootView = LifecycleSurface(document: .empty, width: 760, evidence: evidence)
        host!.layoutSubtreeIfNeeded()
        window.contentView = nil
        window.close()
        host = nil
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(weakHost)
        print("NATIVE_HOST_RELEASED nodes=\(document.nodes.count) duration=\(start.duration(to: .now))")
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
        if let root = document.rootIDs.first {
            MarkdownContainerView(document: document, rootID: root, width: width,
                                  theme: ReaderTheme(), keyboardFocus: $focus, pageReader: { _ in })
                .frame(width: width, alignment: .topLeading)
                .coordinateSpace(name: DocumentReaderCoordinateSpace.content)
                .onPreferenceChange(DocumentBlockFramePreferenceKey.self) { evidence.frames = $0 }
        } else { Color.clear.frame(height: 1) }
    }
}
