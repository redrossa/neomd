//
//  DocumentReaderView.swift
//  NeoMD
//

import AppKit
import SwiftUI

/// The reading surface for an open Markdown document.
///
/// The native opening transaction supplies a fully prepared immutable presentation.
/// Replacement never clears this subtree until read/decode/render have succeeded.
struct DocumentReaderView: View {
    let prepared: PreparedReadingDocument
    let session: DocumentReadSession
    let openingCoordinator: DocumentOpeningCoordinator
    private var fileURL: URL? { prepared.fileURL }
    @Environment(\.openURL) private var systemOpenURL
    @State private var imageStore = MarkdownImageStore()
    private var renderedDocument: MarkdownRenderDocument { prepared.rendered }
    @State private var linkNotice: String?
    @State private var noticeGeneration = 0
    @State private var navigationGeneration = 0
    private let isRendered = true
    // Let ScrollView establish its initial viewport as rendered content arrives,
    // rather than requesting an edge while the loading placeholder is present.
    // The default Never ID type avoids continuous row-ID tracking; explicit
    // navigation and resize restoration still issue their point/ID requests.
    @State private var scrollPosition = ScrollPosition()
    @State private var scrollMetrics = DocumentReaderScrollMetrics.zero
    @State private var blockFrames: [Int: CGRect] = [:]
    @State private var navigationBridge = DocumentNavigationBridge()
    @State private var documentGeneration = 0
    @State private var readingAnchor: DocumentReadingAnchor?
    @State private var resizeRestoration = DocumentReaderResizeRestoration()
    @FocusState private var keyboardFocus: DocumentReaderFocusTarget?
    @State private var traversalTask: Task<Void, Never>?
    @State private var traversalStartID: Int?

    init(
        prepared: PreparedReadingDocument,
        session: DocumentReadSession,
        openingCoordinator: DocumentOpeningCoordinator
    ) {
        self.prepared = prepared
        self.session = session
        self.openingCoordinator = openingCoordinator
    }

    var body: some View {
        GeometryReader { geometry in
            DocumentFocusEffect { inheritedEffectEnabled in
                ScrollView(.vertical) {
                    content(width: DocumentReaderLayout.columnWidth(for: geometry.size.width))
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
                        .environment(\.isFocusEffectEnabled, inheritedEffectEnabled)
                }
                .accessibilityIdentifier("DocumentReaderScrollView")
                .focusable(true, interactions: .edit)
                .focused($keyboardFocus, equals: .reader)
                .scrollPosition($scrollPosition)
                .onKeyPress(keys: [.tab]) { press in
                    guard let reverse = DocumentReaderTraversal.direction(press),
                          keyboardFocus == .reader else { return .ignored }
                    traverse(from: .reader, reverse: reverse)
                    return .handled
                }
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
        }
        .environment(imageStore)
        .environment(\.documentNavigationBridge, navigationBridge)
        .environment(\.documentNavigationGeneration, documentGeneration)
        .environment(\.openURL, OpenURLAction { url in handleLink(url) })
        .environment(\.documentKeyboardOpenURL, OpenURLAction { url in handleLink(url, keyboardDriven: true) })
        .environment(\.documentPointerOpenURL, { url, activation in
            _ = handleLink(url, pointerActivation: activation)
        })
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
        .onChange(of: session.section) { consumeSectionRequest() }
        .onChange(of: session.notice) {
            if let notice = session.notice { showNotice(notice); session.notice = nil }
        }
        .onAppear {
            bindTraversal()
            consumeSectionRequest()
        }
        .onDisappear {
            traversalTask?.cancel()
            navigationBridge.detachTraversal()
            imageStore.reset()
            resizeRestoration.invalidate()
            navigationGeneration += 1
            navigationBridge.cancel()
            noticeGeneration += 1
        }
        .markdownFileDropDestination { urls in
            openingCoordinator.request(urls, in: session)
        }
    }

    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        let blocks = renderedDocument.roots
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
                    MarkdownContainerView(
                        document: renderedDocument,
                        rootID: block.id,
                        width: width,
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
    private var theme: ReaderTheme {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["NEOMD_TEST_READING_SCALE"],
           let scale = Double(value), [1, 1.5, 2].contains(scale) {
            return ReaderTheme(scale: scale)
        }
        #endif
        return ReaderTheme()
    }

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
        traversalTask?.cancel()
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

    private func handleScrollGeometryChange(
        from oldMetrics: DocumentReaderScrollMetrics,
        to newMetrics: DocumentReaderScrollMetrics
    ) {
        let viewportChanged = oldMetrics.viewportSize != newMetrics.viewportSize
        if viewportChanged {
            traversalTask?.cancel()
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
            traversalTask?.cancel()
            traversalStartID = nil
            navigationGeneration += 1
            navigationBridge.cancel()
            resizeRestoration.cancelForUserScroll()
        } else if phase == .idle, !resizeRestoration.isPending {
            updateReadingAnchor()
        }
    }

    private func handleLink(_ url: URL, keyboardDriven: Bool = false,
                            pointerActivation: DocumentLinkActivation? = nil) -> OpenURLAction.Result {
        guard session.isOpen, session.prepared?.id == prepared.id, !openingCoordinator.isTerminating else {
            return .handled
        }
        let activation = pointerActivation ?? .ordinary
        let destination = DocumentLinkDestination.resolve(
            url: url, anchors: renderedDocument.anchorTargets, documentURL: fileURL)
        switch destination {
        case .external:
            if url.isFileURL {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let fragment = components?.fragment
                components?.fragment = nil
                components?.query = nil
                openLocalTarget(DocumentLocalTarget(fileURL: components?.url ?? url, fragment: fragment),
                                activation: activation)
                return .handled
            }
            return DocumentLinkActivation.external(url,
                customAction: keyboardDriven || pointerActivation != nil) { systemOpenURL($0) }
        case .local(let target):
            openLocalTarget(target, activation: activation)
        default:
            _ = session.begin()
            followSection(destination, keyboardDriven: keyboardDriven)
        }
        return .handled
    }

    private func followSection(_ destination: DocumentLinkDestination, keyboardDriven: Bool) {
        switch destination {
        case .missing(let name): showNotice("No “\(name)” destination in this document")
        case .top: navigate(to: nil, keyboardDriven: keyboardDriven)
        case .block(let id): navigate(to: id, keyboardDriven: keyboardDriven)
        case .external, .local: break
        }
    }

    private func consumeSectionRequest() {
        guard let request = session.takeSection(for: prepared.id) else { return }
        followSection(.resolve(fragment: request.fragment, anchors: renderedDocument.anchorTargets),
                      keyboardDriven: false)
    }

    private func showNotice(_ message: String) {
        linkNotice = message
        noticeGeneration += 1
        let generation = noticeGeneration
        AccessibilityNotification.Announcement(message).post()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if noticeGeneration == generation { linkNotice = nil }
        }
    }

    private func openLocalTarget(_ target: DocumentLocalTarget, activation: DocumentLinkActivation) {
        let request = DocumentLocalLinkRequest(source: session, presentation: prepared.id,
            target: target, activation: activation, coordinator: openingCoordinator)
        request.destination.task = Task { @MainActor in await request.run() }
    }

    private func navigate(to id: Int?, keyboardDriven: Bool) {
        traversalTask?.cancel()
        traversalStartID = id.flatMap {
            renderedDocument.nodes.indices.contains($0) ? renderedDocument.firstLeafIDs[$0] : nil
        }
        resizeRestoration.invalidate()
        navigationGeneration += 1
        let generation = navigationGeneration
        navigationBridge.cancel()
        let request = navigationBridge.request
        keyboardFocus = .reader
        Task { @MainActor in
            guard generation == navigationGeneration else { return }
            if let id { scrollPosition.scrollTo(id: lazyRoot(for: id), anchor: .top) }
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
               let id, renderedDocument.nodes.indices.contains(id), renderedDocument[id].isLeaf,
               renderedDocument[id].text.runs.contains(where: { $0.link != nil }) {
                keyboardFocus = .links(id)
            }
        }
    }

    private func bindTraversal() {
        let generation = documentGeneration
        navigationBridge.traverse = { [weak bridge = navigationBridge] origin, reverse in
            guard bridge?.generation == generation, bridge?.traverse != nil else { return }
            traverse(from: origin, reverse: reverse)
        }
    }

    private func traverse(from origin: DocumentReaderFocusTarget?, reverse: Bool) {
        traversalTask?.cancel()
        navigationGeneration += 1
        navigationBridge.cancel()
        resizeRestoration.invalidate()
        let generation = documentGeneration
        let request = navigationBridge.request
        let candidates = DocumentReaderTraversal.candidates(in: renderedDocument)
        let start: Int
        if let origin, let index = candidates.firstIndex(of: origin) {
            start = index + (reverse ? -1 : 1)
        } else if let id = traversalStartID,
                  let index = candidates.firstIndex(where: { $0.leafID == id }) {
            start = index
        } else {
            start = reverse ? candidates.count - 1 : 0
        }
        traversalTask = Task { @MainActor in
            var index = start
            while candidates.indices.contains(index) {
                guard !Task.isCancelled, documentGeneration == generation,
                      navigationBridge.request == request else { return }
                let target = candidates[index]
                navigationBridge.prepareTraversal(to: target)
                guard let id = target.leafID else { return }
                if blockFrames[id] == nil {
                    scrollPosition.scrollTo(id: lazyRoot(for: id), anchor: .center)
                }
                // A bounded acquisition wait, not a success inferred from FocusState.
                for _ in 0..<12 {
                    guard !Task.isCancelled, documentGeneration == generation,
                          navigationBridge.request == request else { return }
                    if case .text = target, navigationBridge.textLeaf(id) != nil { break }
                    if case .links = target, blockFrames[id] != nil { break }
                    if case .codeBlock = target, navigationBridge.codeOverflow(id) != nil { break }
                    try? await Task.sleep(for: .milliseconds(50))
                }
                guard !Task.isCancelled, documentGeneration == generation,
                      navigationBridge.request == request else { return }
                if case .codeBlock = target, navigationBridge.codeOverflow(id) == false {
                    index += reverse ? -1 : 1
                    continue
                }
                if case .text = target {
                    keyboardFocus = nil
                    await Task.yield()
                    guard !Task.isCancelled, navigationBridge.request == request else { return }
                    if navigationBridge.focusText(id) {
                        traversalStartID = id
                    } else {
                        restoreTraversalOrigin(origin)
                        showNotice("Keyboard focus could not reach this block. Try selecting it again.")
                    }
                } else if let frame = blockFrames[id] {
                    if !scrollMetrics.visibleRect.contains(frame) {
                        scrollPosition.scrollTo(y: scrollMetrics.clampedVerticalOffset(frame.minY))
                    }
                    keyboardFocus = target
                    for _ in 0..<12 {
                        guard !Task.isCancelled, navigationBridge.request == request else { return }
                        if navigationBridge.hasActionFocus(target) {
                            traversalStartID = id
                            return
                        }
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                    restoreTraversalOrigin(origin)
                    showNotice("Keyboard focus could not reach this block. Try selecting it again.")
                } else {
                    restoreTraversalOrigin(origin)
                    showNotice("Keyboard focus could not reach this block. Try selecting it again.")
                }
                return
            }
            guard !Task.isCancelled, navigationBridge.request == request else { return }
            keyboardFocus = nil
            await Task.yield()
            guard !Task.isCancelled, navigationBridge.request == request else { return }
            if !navigationBridge.leaveDocument(reverse: reverse) {
                // A failed native-control handoff must not silently wrap into the document.
                restoreTraversalOrigin(origin)
                showNotice("No window control is available for keyboard focus.")
            }
        }
    }

    private func restoreTraversalOrigin(_ origin: DocumentReaderFocusTarget?) {
        if case .text(let id) = origin {
            // Text has a native responder, not a SwiftUI .focused binding.
            keyboardFocus = nil
            if !navigationBridge.focusText(id) { keyboardFocus = .reader }
        } else {
            keyboardFocus = origin ?? .reader
        }
    }

    private func lazyRoot(for id: Int) -> Int {
        renderedDocument.nodes.indices.contains(id) ? renderedDocument.lazyRootIDs[id] : id
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
                    scrollPosition.scrollTo(id: lazyRoot(for: id), anchor: .center)
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
    case text(Int)

    var leafID: Int? {
        switch self {
        case .reader: nil
        case .codeBlock(let id), .links(let id), .text(let id): id
        }
    }
}

enum DocumentReaderTraversal {
    static func direction(_ press: KeyPress) -> Bool? {
        guard press.key == .tab else { return nil }
        let modifiers = press.modifiers.intersection([.option, .shift, .control, .command])
        if modifiers == .option { return false }
        if modifiers == [.option, .shift] { return true }
        return nil
    }

    static func candidates(in document: MarkdownRenderDocument) -> [DocumentReaderFocusTarget] {
        document.leafIDs.flatMap { id -> [DocumentReaderFocusTarget] in
            let block = document[id]
            if case .codeBlock = block.kind { return [.codeBlock(id)] }
            var targets: [DocumentReaderFocusTarget] = []
            if MarkdownLinkedImageText.requiresNativeText(block.text) { targets.append(.text(id)) }
            if block.text.runs.contains(where: { $0.link != nil }) { targets.append(.links(id)) }
            return targets
        }
    }
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
