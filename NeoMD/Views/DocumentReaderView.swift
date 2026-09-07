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
    let openingCoordinator: DocumentOpeningCoordinator?

    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openDocument) private var openDocument
    @Environment(\.openWindow) private var openWindow
    @State private var blocks: [MarkdownBlock] = []
    @State private var lazyAncestors: [Int: Int] = [:]
    @State private var anchorTargets: [String: Int] = [:]
    @State private var linkNotice: String?
    @State private var noticeGeneration = 0
    @State private var navigationGeneration = 0
    @State private var isRendered = false
    @State private var windowID = UUID()
    @State private var scrollPosition = ScrollPosition(idType: Int.self)
    @State private var scrollMetrics = DocumentReaderScrollMetrics.zero
    @State private var blockFrames: [Int: CGRect] = [:]
    @State private var navigationBridge = DocumentNavigationBridge()
    @State private var documentGeneration = 0
    @State private var readingAnchor: DocumentReadingAnchor?
    @State private var resizeRestoration = DocumentReaderResizeRestoration()
    @FocusState private var keyboardFocus: DocumentReaderFocusTarget?

    init(
        document: MarkdownDocument,
        openingCoordinator: DocumentOpeningCoordinator? = nil
    ) {
        self.document = document
        self.openingCoordinator = openingCoordinator
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                content
                    .frame(
                        width: DocumentReaderLayout.columnWidth(
                            for: geometry.size.width
                        ),
                        alignment: .leading
                    )
                    .padding(.vertical, DocumentReaderLayout.verticalMargin)
                    .coordinateSpace(name: DocumentReaderCoordinateSpace.content)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(alignment: .topLeading) {
                        DocumentNavigationMarker(bridge: navigationBridge, id: nil,
                                                 generation: documentGeneration)
                            .frame(width: 0, height: 0)
                            .allowsHitTesting(false)
                    }
            }
            .accessibilityIdentifier("DocumentReaderScrollView")
            .focusable(true, interactions: .edit)
            .focused($keyboardFocus, equals: .reader)
            .scrollPosition($scrollPosition)
            .onKeyPress(keys: [.pageUp, .pageDown]) { keyPress in
                handleVerticalPageKeyPress(keyPress)
            }
            .onScrollGeometryChange(for: DocumentReaderScrollMetrics.self) { geometry in
                DocumentReaderScrollMetrics(geometry)
            } action: { oldMetrics, newMetrics in
                handleScrollGeometryChange(from: oldMetrics, to: newMetrics)
            }
            .onScrollPhaseChange { _, newPhase in
                handleScrollPhaseChange(newPhase)
            }
            .onPreferenceChange(DocumentBlockFramePreferenceKey.self) { frames in
                handleBlockFrames(frames, viewportSize: geometry.size)
            }
        }
        .environment(\.documentNavigationBridge, navigationBridge)
        .environment(\.documentNavigationGeneration, documentGeneration)
        .environment(\.openURL, OpenURLAction { url in handleLink(url) })
        .environment(\.documentKeyboardOpenURL, OpenURLAction { url in handleLink(url, keyboardDriven: true) })
        .overlay(alignment: .bottom) {
            if let linkNotice {
                Text(linkNotice)
                    .padding(12)
                    .background(.regularMaterial, in: .capsule)
                    .padding()
                    .accessibilityIdentifier("DocumentLinkNotice")
            }
        }
        .frame(minWidth: 480, minHeight: 320)
        .task(id: document.text) {
            await render(document.text)
        }
        .onAppear {
            guard openingCoordinator?.documentWindowDidAppear(id: windowID)
                    == .hideNoDocumentWindow else { return }
            dismissWindow(id: DocumentOpeningCoordinator.noDocumentWindowSceneID)
        }
        .onDisappear {
            resizeRestoration.invalidate()
            navigationGeneration += 1
            navigationBridge.cancel()
            noticeGeneration += 1
            guard openingCoordinator?.documentWindowDidDisappear(id: windowID)
                    == .showNoDocumentWindow else { return }
            let openingCoordinator = openingCoordinator
            Task { @MainActor in
                await Task.yield()
                guard openingCoordinator?.shouldShowNoDocumentWindow == true else { return }
                openWindow(id: DocumentOpeningCoordinator.noDocumentWindowSceneID)
            }
        }
        .markdownFileDropDestination { url in
            try await openDocument(at: url)
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
        } else if blocks.allSatisfy({ $0.kind == .anchor }) {
            VStack(alignment: .leading, spacing: 0) {
                Text("This document is empty.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                ForEach(blocks) { block in
                    MarkdownBlockView(block: block, theme: theme,
                                      keyboardFocus: $keyboardFocus, pageReader: scrollReaderPage)
                        .id(block.id)
                }
            }
            .scrollTargetLayout()
        } else {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(blocks) { block in
                    if case .footnote(ordinal: 1) = block.kind { Divider() }
                    MarkdownBlockView(
                        block: block,
                        theme: theme,
                        keyboardFocus: $keyboardFocus,
                        pageReader: scrollReaderPage
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(block.id)
                }
            }
            .scrollTargetLayout()
            .textSelection(.enabled)
        }
    }

    /// The appearance policy the blocks are drawn with.
    ///
    /// Adaptive system styles already follow the Mac's light and dark appearance, so
    /// the theme only carries what a semantic style cannot express, and it applies the
    /// same way to every reader on every Mac.
    private var theme: ReaderTheme { ReaderTheme() }

    private func handleVerticalPageKeyPress(
        _ keyPress: KeyPress
    ) -> KeyPress.Result {
        let explicitModifiers: EventModifiers = [
            .shift,
            .control,
            .command,
            .option
        ]
        guard keyPress.modifiers.intersection(explicitModifiers).isEmpty else {
            return .ignored
        }

        switch keyPress.key {
        case .pageUp:
            scrollReaderPage(.up)
        case .pageDown:
            scrollReaderPage(.down)
        default:
            return .ignored
        }
        return .handled
    }

    private func scrollReaderPage(_ direction: DocumentReaderPageDirection) {
        navigationGeneration += 1
        navigationBridge.cancel()
        resizeRestoration.cancelForUserScroll()
        let pageDistance = max(40, scrollMetrics.viewportSize.height * 0.9)
        let offset = switch direction {
        case .up:
            scrollMetrics.visibleRect.minY - pageDistance
        case .down:
            scrollMetrics.visibleRect.minY + pageDistance
        }
        scrollPosition.scrollTo(y: scrollMetrics.clampedVerticalOffset(offset))
    }

    /// Renders `source` away from the main actor and publishes the result.
    private func render(_ source: String) async {
        isRendered = false
        navigationBridge.replaceDocument()
        documentGeneration = navigationBridge.generation
        navigationGeneration += 1
        noticeGeneration += 1
        linkNotice = nil
        let rendered = await Task.detached(priority: .userInitiated) {
            MarkdownBlockRenderer.blocks(from: source)
        }.value
        guard !Task.isCancelled else { return }
        blocks = rendered
        lazyAncestors = MarkdownBlock.lazyAncestors(in: rendered)
        anchorTargets = MarkdownBlock.anchorTargets(in: rendered)
        isRendered = true
    }

    private func handleScrollGeometryChange(
        from oldMetrics: DocumentReaderScrollMetrics,
        to newMetrics: DocumentReaderScrollMetrics
    ) {
        let viewportChanged = oldMetrics.viewportSize != newMetrics.viewportSize
        if viewportChanged {
            navigationGeneration += 1
            navigationBridge.cancel()
        }

        if viewportChanged, !resizeRestoration.isPending {
            resizeRestoration.beginIfNeeded(
                at: readingAnchor
                    ?? DocumentReaderLayout.readingAnchor(
                        in: blockFrames,
                        visibleRect: oldMetrics.visibleRect,
                        isAtTop: oldMetrics.isAtTop,
                        isAtBottom: oldMetrics.isAtBottom
                    )
            )
        }

        scrollMetrics = newMetrics

        if viewportChanged, let generation = resizeRestoration.schedule() {
            Task { @MainActor in
                try? await Task.sleep(for: Self.resizeRestorationDelay)
                await restoreReadingPosition(for: generation)
            }
        } else if !resizeRestoration.isPending {
            updateReadingAnchor()
        }
    }

    private func handleScrollPhaseChange(_ phase: ScrollPhase) {
        if phase == .interacting {
            navigationGeneration += 1
            navigationBridge.cancel()
            resizeRestoration.cancelForUserScroll()
        } else if phase == .idle, !resizeRestoration.isPending {
            updateReadingAnchor()
        }
    }

    private func handleLink(_ url: URL, keyboardDriven: Bool = false) -> OpenURLAction.Result {
        switch DocumentLinkDestination.resolve(url: url, anchors: anchorTargets) {
        case .external: return .systemAction
        case .missing(let name):
            let message = "No “\(name)” destination in this document"
            linkNotice = message
            noticeGeneration += 1
            let generation = noticeGeneration
            AccessibilityNotification.Announcement(message).post()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                if noticeGeneration == generation { linkNotice = nil }
            }
        case .top: navigate(to: nil, keyboardDriven: keyboardDriven)
        case .block(let id): navigate(to: id, keyboardDriven: keyboardDriven)
        }
        return .handled
    }

    private func navigate(to id: Int?, keyboardDriven: Bool) {
        resizeRestoration.invalidate()
        navigationGeneration += 1
        let generation = navigationGeneration
        navigationBridge.cancel()
        let request = navigationBridge.request
        keyboardFocus = .reader
        Task { @MainActor in
            guard generation == navigationGeneration else { return }
            if let id { scrollPosition.scrollTo(id: lazyAncestors[id] ?? id, anchor: .top) }
            else { scrollPosition.scrollTo(edge: .top) }
            try? await Task.sleep(for: .milliseconds(100))
            var stablePasses = 0
            for _ in 0..<12 {
                guard generation == navigationGeneration, !Task.isCancelled else { return }
                if let error = navigationBridge.position(id: id, request: request) {
                    stablePasses = abs(error) <= 1 ? stablePasses + 1 : 0
                    if stablePasses >= 3 { break }
                } else { stablePasses = 0 }
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard generation == navigationGeneration else { return }
            updateReadingAnchor()
            // A Tab press can already have moved focus while lazy layout settles.
            // Never overwrite that newer user choice with the initial reader focus.
            if keyboardDriven, keyboardFocus == .reader,
               let id, blocks.flatMap(\.leaves).contains(where: {
                   $0.id == id && $0.text.runs.contains(where: { $0.link != nil })
               }) { keyboardFocus = .links(id) }
        }
    }

    private static var resizeRestorationDelay: Duration {
#if DEBUG
        if let value = ProcessInfo.processInfo.environment[
            "NEOMD_UI_TEST_RESIZE_RESTORATION_DELAY_MILLISECONDS"
        ], let milliseconds = Int64(value), milliseconds >= 0 {
            return .milliseconds(milliseconds)
        }
#endif
        return .milliseconds(120)
    }

    private func handleBlockFrames(
        _ frames: [Int: CGRect],
        viewportSize: CGSize
    ) {
        guard frames != blockFrames else { return }
        blockFrames = frames

        // A width change can publish reflowed block frames before ScrollView reports
        // its new viewport. Keep the last stable semantic anchor until that callback
        // starts restoration, rather than pairing new frames with stale scroll metrics.
        guard viewportSize == scrollMetrics.viewportSize,
              !resizeRestoration.isPending else { return }
        updateReadingAnchor()
    }

    private func updateReadingAnchor() {
        readingAnchor = DocumentReaderLayout.readingAnchor(
            in: blockFrames,
            visibleRect: scrollMetrics.visibleRect,
            isAtTop: scrollMetrics.isAtTop,
            isAtBottom: scrollMetrics.isAtBottom
        )
    }

    /// Repositions the semantic point that was at the middle of the viewport before
    /// a resize. Waiting briefly coalesces live-resize and full-screen animation steps.
    private func restoreReadingPosition(for generation: Int) async {
        guard let anchor = resizeRestoration.pendingAnchor(
            for: generation
        ) else { return }

        // Lazy stacks initially place a distant target from estimated block heights.
        // Require consecutive measured corrections before accepting that layout as
        // settled, while bounding the work so restoration cannot form a feedback loop.
        var stablePassCount = 0
        for _ in 0..<12 {
            guard resizeRestoration.pendingAnchor(for: generation) == anchor else {
                return
            }

            switch anchor {
            case .top:
                scrollPosition.scrollTo(edge: .top)
                stablePassCount = scrollMetrics.isAtTop ? stablePassCount + 1 : 0
            case .bottom:
                scrollPosition.scrollTo(edge: .bottom)
                stablePassCount = scrollMetrics.isAtBottom ? stablePassCount + 1 : 0
            case .block(let id, _):
                guard let frame = blockFrames[id],
                      let offset = DocumentReaderLayout.verticalOffset(
                          for: anchor,
                          targetFrame: frame,
                          viewportHeight: scrollMetrics.viewportSize.height
                      ) else {
                    // First materialize a lazy target, then retain the pending anchor
                    // until a measured frame can be corrected precisely.
                    stablePassCount = 0
                    scrollPosition.scrollTo(id: lazyAncestors[id] ?? id, anchor: .center)
                    try? await Task.sleep(for: .milliseconds(50))
                    continue
                }

                let targetOffset = scrollMetrics.clampedVerticalOffset(offset)
                let error = targetOffset - scrollMetrics.visibleRect.minY
                if abs(error) <= 1 {
                    stablePassCount += 1
                } else {
                    stablePassCount = 0
                    scrollPosition.scrollTo(y: targetOffset)
                }
            }

            if stablePassCount >= 3 { break }
            try? await Task.sleep(for: .milliseconds(50))
        }

        guard resizeRestoration.complete(
            anchor: anchor,
            for: generation
        ) else { return }
        updateReadingAnchor()
    }
}

/// Pure sizing and semantic-anchor calculations for the reader.
nonisolated enum DocumentReaderLayout {
    static let maximumColumnWidth: CGFloat = 760
    static let horizontalMargin: CGFloat = 40
    static let verticalMargin: CGFloat = 32
    static let readingLineFraction: CGFloat = 0.5

    static func columnWidth(for viewportWidth: CGFloat) -> CGFloat {
        min(
            maximumColumnWidth,
            max(0, viewportWidth - (horizontalMargin * 2))
        )
    }

    static func readingAnchor(
        in blockFrames: [Int: CGRect],
        visibleRect: CGRect,
        isAtTop: Bool,
        isAtBottom: Bool
    ) -> DocumentReadingAnchor? {
        if isAtTop { return .top }
        if isAtBottom { return .bottom }
        guard visibleRect.height > 0 else { return nil }

        let readingLine = visibleRect.minY
            + (visibleRect.height * readingLineFraction)
        let candidates = blockFrames
            .filter { $0.value.height > 0 }
            .sorted { lhs, rhs in
                if lhs.value.minY == rhs.value.minY {
                    return lhs.key < rhs.key
                }
                return lhs.value.minY < rhs.value.minY
            }
        guard let candidate = candidates.min(by: { lhs, rhs in
            distance(from: readingLine, to: lhs.value)
                < distance(from: readingLine, to: rhs.value)
        }) else { return nil }

        let fraction = min(
            1,
            max(0, (readingLine - candidate.value.minY) / candidate.value.height)
        )
        return .block(id: candidate.key, fraction: fraction)
    }

    static func verticalOffset(
        for anchor: DocumentReadingAnchor,
        targetFrame: CGRect,
        viewportHeight: CGFloat
    ) -> CGFloat? {
        guard case .block(_, let fraction) = anchor,
              targetFrame.height > 0,
              viewportHeight > 0 else { return nil }
        let targetY = targetFrame.minY + (targetFrame.height * fraction)
        return targetY - (viewportHeight * readingLineFraction)
    }

    private static func distance(from point: CGFloat, to rect: CGRect) -> CGFloat {
        if point < rect.minY { return rect.minY - point }
        if point > rect.maxY { return point - rect.maxY }
        return 0
    }
}

nonisolated enum DocumentReaderFocusTarget: Hashable {
    case reader
    case codeBlock(Int)
    case links(Int)
}

nonisolated enum DocumentReaderPageDirection {
    case up
    case down
}

nonisolated enum DocumentReadingAnchor: Equatable, Sendable {
    case top
    case bottom
    case block(id: Int, fraction: CGFloat)
}

/// Tracks one coalesced resize restoration and invalidates stale asynchronous passes.
nonisolated struct DocumentReaderResizeRestoration: Equatable, Sendable {
    private(set) var pendingAnchor: DocumentReadingAnchor?
    private(set) var generation = 0

    var isPending: Bool {
        pendingAnchor != nil
    }

    mutating func beginIfNeeded(at anchor: DocumentReadingAnchor?) {
        guard pendingAnchor == nil else { return }
        pendingAnchor = anchor
    }

    mutating func schedule() -> Int? {
        guard pendingAnchor != nil else { return nil }
        generation += 1
        return generation
    }

    func pendingAnchor(for generation: Int) -> DocumentReadingAnchor? {
        guard generation == self.generation else { return nil }
        return pendingAnchor
    }

    mutating func cancelForUserScroll() {
        guard isPending else { return }
        invalidate()
    }

    mutating func invalidate() {
        generation += 1
        pendingAnchor = nil
    }

    mutating func complete(
        anchor: DocumentReadingAnchor,
        for generation: Int
    ) -> Bool {
        guard pendingAnchor(for: generation) == anchor else { return false }
        pendingAnchor = nil
        return true
    }
}

private nonisolated struct DocumentReaderScrollMetrics: Equatable, Sendable {
    static let zero = DocumentReaderScrollMetrics(
        contentHeight: 0,
        viewportSize: .zero,
        visibleRect: .zero,
        topInset: 0,
        bottomInset: 0,
        isAtTop: true,
        isAtBottom: true
    )

    let contentHeight: CGFloat
    let viewportSize: CGSize
    let visibleRect: CGRect
    let topInset: CGFloat
    let bottomInset: CGFloat
    let isAtTop: Bool
    let isAtBottom: Bool

    init(_ geometry: ScrollGeometry) {
        contentHeight = geometry.contentSize.height
        viewportSize = geometry.containerSize
        visibleRect = geometry.visibleRect
        topInset = geometry.contentInsets.top
        bottomInset = geometry.contentInsets.bottom
        isAtTop = geometry.visibleRect.minY <= 1
        isAtBottom = geometry.visibleRect.maxY >= geometry.contentSize.height - 1
    }

    private init(
        contentHeight: CGFloat,
        viewportSize: CGSize,
        visibleRect: CGRect,
        topInset: CGFloat,
        bottomInset: CGFloat,
        isAtTop: Bool,
        isAtBottom: Bool
    ) {
        self.contentHeight = contentHeight
        self.viewportSize = viewportSize
        self.visibleRect = visibleRect
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.isAtTop = isAtTop
        self.isAtBottom = isAtBottom
    }

    func clampedVerticalOffset(_ proposedOffset: CGFloat) -> CGFloat {
        let minimum = -topInset
        let maximum = max(
            minimum,
            contentHeight - viewportSize.height + bottomInset
        )
        return min(maximum, max(minimum, proposedOffset))
    }
}

extension EnvironmentValues {
    @Entry var documentKeyboardOpenURL: OpenURLAction? = nil
}

enum DocumentReaderCoordinateSpace {
    static let content = "DocumentReaderContent"
}

struct DocumentBlockFramePreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]

    static func reduce(
        value: inout [Int: CGRect],
        nextValue: () -> [Int: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
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
