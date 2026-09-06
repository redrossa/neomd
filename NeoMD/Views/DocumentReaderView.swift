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
    @State private var isRendered = false
    @State private var windowID = UUID()
    @State private var scrollPosition = ScrollPosition(idType: Int.self)
    @State private var scrollMetrics = DocumentReaderScrollMetrics.zero
    @State private var blockFrames: [Int: CGRect] = [:]
    @State private var readingAnchor: DocumentReadingAnchor?
    @State private var pendingResizeAnchor: DocumentReadingAnchor?
    @State private var resizeGeneration = 0

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
            }
            .accessibilityIdentifier("DocumentReaderScrollView")
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: DocumentReaderScrollMetrics.self) { geometry in
                DocumentReaderScrollMetrics(geometry)
            } action: { oldMetrics, newMetrics in
                handleScrollGeometryChange(from: oldMetrics, to: newMetrics)
            }
            .onPreferenceChange(DocumentBlockFramePreferenceKey.self) { frames in
                handleBlockFrames(frames)
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
            resizeGeneration += 1
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
        } else if blocks.isEmpty {
            Text("This document is empty.")
                .font(.body)
                .foregroundStyle(.secondary)
        } else {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(blocks) { block in
                    MarkdownBlockView(block: block)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(block.id)
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: DocumentBlockFramePreferenceKey.self,
                                    value: [
                                        block.id: geometry.frame(
                                            in: .named(DocumentReaderCoordinateSpace.content)
                                        )
                                    ]
                                )
                            }
                            .accessibilityHidden(true)
                        }
                }
            }
            .scrollTargetLayout()
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

    private func handleScrollGeometryChange(
        from oldMetrics: DocumentReaderScrollMetrics,
        to newMetrics: DocumentReaderScrollMetrics
    ) {
        let viewportChanged = oldMetrics.viewportSize != newMetrics.viewportSize

        if viewportChanged, pendingResizeAnchor == nil {
            pendingResizeAnchor = readingAnchor
                ?? DocumentReaderLayout.readingAnchor(
                    in: blockFrames,
                    visibleRect: oldMetrics.visibleRect,
                    isAtTop: oldMetrics.isAtTop,
                    isAtBottom: oldMetrics.isAtBottom
                )
        }

        scrollMetrics = newMetrics

        if viewportChanged, pendingResizeAnchor != nil {
            resizeGeneration += 1
            let generation = resizeGeneration
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                await restoreReadingPosition(for: generation)
            }
        } else if pendingResizeAnchor == nil {
            updateReadingAnchor()
        }
    }

    private func handleBlockFrames(_ frames: [Int: CGRect]) {
        guard frames != blockFrames else { return }
        blockFrames = frames
        if pendingResizeAnchor == nil {
            updateReadingAnchor()
        }
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
        guard generation == resizeGeneration,
              let anchor = pendingResizeAnchor else { return }

        switch anchor {
        case .top:
            scrollPosition.scrollTo(edge: .top)
        case .bottom:
            scrollPosition.scrollTo(edge: .bottom)
        case .block(let id, _):
            if let frame = blockFrames[id],
               let offset = DocumentReaderLayout.verticalOffset(
                   for: anchor,
                   targetFrame: frame,
                   viewportHeight: scrollMetrics.viewportSize.height
               ) {
                scrollPosition.scrollTo(
                    y: scrollMetrics.clampedVerticalOffset(offset)
                )
            } else {
                // A large reflow can move a lazy block outside the instantiated range.
                scrollPosition.scrollTo(id: id, anchor: .center)
            }
        }

        guard generation == resizeGeneration else { return }
        pendingResizeAnchor = nil
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

nonisolated enum DocumentReadingAnchor: Equatable, Sendable {
    case top
    case bottom
    case block(id: Int, fraction: CGFloat)
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

private enum DocumentReaderCoordinateSpace {
    static let content = "DocumentReaderContent"
}

private struct DocumentBlockFramePreferenceKey: PreferenceKey {
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
