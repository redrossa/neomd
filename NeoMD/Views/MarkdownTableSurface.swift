//
//  MarkdownTableSurface.swift
//  NeoMD
//

import AppKit
import SwiftUI

/// Measured geometry the native table publishes back to the reader.
///
/// Cell rectangles are in the table's own unscrolled document space; the wrapper
/// converts them to reading coordinates. Nothing here is a live view reference.
nonisolated struct MarkdownTableMetrics: Equatable, Sendable {
    var contentWidth: CGFloat = 0
    var viewportWidth: CGFloat = 0
    var offset: CGFloat = 0
    var height: CGFloat = 0
    var rowHeights: [CGFloat] = []
    var cellFrames: [Int: CGRect] = [:]

    static let zero = MarkdownTableMetrics()

    var overflows: Bool { contentWidth > viewportWidth + 0.5 }
}

/// A local scroll instruction from the keyboard, applied once.
nonisolated struct MarkdownTableScrollCommand: Equatable, Sendable {
    nonisolated enum Target: Equatable, Sendable {
        case offset(CGFloat)
        case leadingEdge
        case trailingEdge
    }

    var target: Target
    var id: Int
}

/// Everything a hosted cell needs that does not cross an `NSHostingView` boundary
/// on its own. Each value is passed explicitly rather than assumed to be inherited.
@MainActor struct MarkdownTableCellEnvironment {
    var imageStore: MarkdownImageStore
    var bridge: DocumentNavigationBridge?
    var generation: Int
    var colorScheme: ColorScheme
    var focusEffectEnabled: Bool
    var openURL: OpenURLAction
    var keyboardOpenURL: OpenURLAction?
    var pointerOpenURL: ((URL, DocumentLinkActivation) -> Void)?
}

/// One table cell, hosted in its own native cell host.
struct MarkdownTableCellHost: View {
    let block: MarkdownBlock
    let theme: ReaderTheme
    let keyboardFocus: FocusState<DocumentReaderFocusTarget?>.Binding
    let pageReader: (DocumentReaderPageDirection) -> Void
    let width: CGFloat
    let quoted: Bool
    let presentation: MarkdownTableCellPresentation
    let environment: MarkdownTableCellEnvironment

    var body: some View {
        MarkdownBlockView(block: block, theme: theme, keyboardFocus: keyboardFocus,
                          pageReader: pageReader, availableWidth: width, quoted: quoted,
                          tableCell: presentation)
            .foregroundStyle(quoted ? Color.secondary : Color.primary)
            .frame(width: width, alignment: .topLeading)
            .textSelection(.enabled)
            .environment(environment.imageStore)
            .environment(\.documentNavigationBridge, environment.bridge)
            .environment(\.documentNavigationGeneration, environment.generation)
            .environment(\.colorScheme, environment.colorScheme)
            .environment(\.isFocusEffectEnabled, environment.focusEffectEnabled)
            .environment(\.openURL, environment.openURL)
            .environment(\.documentKeyboardOpenURL, environment.keyboardOpenURL)
            .environment(\.documentPointerOpenURL, environment.pointerOpenURL)
    }
}

/// The immutable per-update description of a table surface.
@MainActor struct MarkdownTableSurfaceInput {
    var document: MarkdownRenderDocument
    var tableID: Int
    var theme: ReaderTheme
    var width: CGFloat
    var quoted: Bool
    var dark: Bool
    var imageStates: [URL: MarkdownImageStore.State]
    var environment: MarkdownTableCellEnvironment
    var keyboardFocus: FocusState<DocumentReaderFocusTarget?>.Binding
    var pageReader: (DocumentReaderPageDirection) -> Void

    /// Only these values change measured geometry; presentation-only updates reuse
    /// the existing measurement and never rewrite cell text storage.
    struct Signature: Equatable {
        let tableID: Int
        let width: CGFloat
        let scale: CGFloat
        let quoted: Bool
        let dark: Bool
        let generation: Int
        let nodeCount: Int
        let states: [URL: MarkdownImageStore.State]
    }

    var signature: Signature {
        Signature(tableID: tableID, width: width, scale: theme.scale, quoted: quoted, dark: dark,
                  generation: environment.generation, nodeCount: document.nodes.count, states: imageStates)
    }
}

/// Horizontal-only local overflow. The table never owns vertical scrolling, so the
/// surrounding reader keeps one vertical viewport and is never widened.
final class MarkdownTableScrollView: NSScrollView {
    let table = MarkdownTableDocumentView()
    var onMetrics: ((MarkdownTableMetrics) -> Void)?
    private var appliedCommand: Int?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
        borderType = .noBorder
        hasVerticalScroller = false
        hasHorizontalScroller = true
        autohidesScrollers = true
        scrollerStyle = .overlay
        verticalScrollElasticity = .none
        horizontalScrollElasticity = .allowed
        documentView = table
        contentView.drawsBackground = false
        table.onGeometryChange = { [weak self] in self?.publishMetrics() }
    }

    required init?(coder: NSCoder) { nil }

    /// Every local scroll, from the trackpad or the keyboard, reports its offset.
    override func reflectScrolledClipView(_ clipView: NSClipView) {
        super.reflectScrolledClipView(clipView)
        publishMetrics()
    }

    func update(_ input: MarkdownTableSurfaceInput, command: MarkdownTableScrollCommand?) {
        table.apply(input)
        if let command, appliedCommand != command.id {
            appliedCommand = command.id
            apply(command.target)
        }
        clampOffset()
        publishMetrics()
    }

    /// The outer width reported to the reader is always the width it allotted.
    func measuredSize(width proposed: CGFloat) -> CGSize {
        let width = proposed.isFinite && proposed > 0 ? proposed : table.layout?.viewportWidth ?? 1
        return CGSize(width: width, height: table.contentHeight)
    }

    private func apply(_ target: MarkdownTableScrollCommand.Target) {
        guard let layout = table.layout else { return }
        let value: CGFloat
        switch target {
        case .offset(let proposed): value = proposed
        case .leadingEdge: value = 0
        case .trailingEdge: value = layout.maximumOffset
        }
        scroll(to: layout.clampedOffset(value))
    }

    /// A resize from overflow to fitting must not leave the table scrolled away.
    private func clampOffset() {
        guard let layout = table.layout else { return }
        let current = contentView.bounds.origin.x
        let clamped = layout.clampedOffset(current)
        if abs(clamped - current) > 0.5 { scroll(to: clamped) }
    }

    private func scroll(to x: CGFloat) {
        var origin = contentView.bounds.origin
        origin.x = x
        contentView.scroll(to: origin)
        reflectScrolledClipView(contentView)
    }

    private func publishMetrics() {
        guard let layout = table.layout else { return }
        let metrics = MarkdownTableMetrics(
            contentWidth: layout.contentWidth,
            viewportWidth: contentView.bounds.width > 0 ? contentView.bounds.width : layout.viewportWidth,
            offset: contentView.bounds.origin.x,
            height: table.contentHeight,
            rowHeights: table.rowHeights,
            cellFrames: table.cellFrames
        )
        onMetrics?(metrics)
    }

    func detach() {
        onMetrics = nil
        table.detach()
    }
}

/// The table's internal document: stable per-cell hosts, drawn rules and surfaces,
/// and the real accessibility table/row/column/cell relations.
final class MarkdownTableDocumentView: NSView {
    override var isFlipped: Bool { true }

    private(set) var layout: MarkdownTableLayout?
    private(set) var contentHeight: CGFloat = 0
    private(set) var rowHeights: [CGFloat] = []
    private(set) var cellFrames: [Int: CGRect] = [:]
    var onGeometryChange: (() -> Void)?

    private var hosts: [Int: NSHostingView<MarkdownTableCellHost>] = [:]
    private var cellElements: [MarkdownTableCellAddress: MarkdownTableCellElement] = [:]
    private var rowElements: [MarkdownTableRowElement] = []
    private var columnElements: [MarkdownTableColumnElement] = []
    private var structure = MarkdownTableStructure(alignments: [], rows: [])
    private var addresses: [MarkdownTableCellAddress] = []
    private var grid: [[MarkdownTableCellAddress?]] = []
    private var signature: MarkdownTableSurfaceInput.Signature?
    private var scale: CGFloat = 1

    func apply(_ input: MarkdownTableSurfaceInput) {
        guard let owned = input.document.tableStructure(input.tableID) else { return }
        let cellAddresses = input.document.tableCells(in: input.tableID)
        let structureChanged = owned != structure || cellAddresses != addresses
        structure = owned
        addresses = cellAddresses
        grid = owned.rows.indices.map { row in
            (0..<owned.columnCount).map { input.document.tableCell(tableID: input.tableID, row: row, column: $0) }
        }
        scale = input.theme.scale

        // Presentation-only updates reuse hosts and measurements; unchanged inputs
        // never rewrite a cell's native text storage.
        refreshHosts(input)
        if structureChanged { rebuildAccessibility() }
        if structureChanged || signature != input.signature {
            signature = input.signature
            measureAndPlace(input)
        }
        needsDisplay = true
    }

    private func refreshHosts(_ input: MarkdownTableSurfaceInput) {
        var retained = Set<Int>()
        for address in addresses {
            retained.insert(address.leafID)
            let presentation = MarkdownTableCellPresentation(
                alignment: structure.alignment(column: address.columnIndex),
                header: structure.rows[address.rowIndex].isHeader)
            let width = layout?.contentWidth(column: address.columnIndex)
                ?? MarkdownTableLayout.minimumCellWidth * input.theme.scale
            let root = MarkdownTableCellHost(
                block: input.document[address.leafID], theme: input.theme,
                keyboardFocus: input.keyboardFocus, pageReader: input.pageReader,
                width: width, quoted: input.quoted, presentation: presentation,
                environment: input.environment)
            if let host = hosts[address.leafID] {
                host.rootView = root
            } else {
                let host = NSHostingView(rootView: root)
                host.translatesAutoresizingMaskIntoConstraints = true
                hosts[address.leafID] = host
                addSubview(host)
            }
        }
        for (id, host) in hosts where !retained.contains(id) {
            host.removeFromSuperview()
            hosts.removeValue(forKey: id)
        }
    }

    private func measureAndPlace(_ input: MarkdownTableSurfaceInput) {
        let columns = structure.columnCount
        guard columns > 0 else {
            layout = MarkdownTableLayout(viewportWidth: input.width, preferredContentWidths: [], scale: input.theme.scale)
            contentHeight = 0
            rowHeights = []
            cellFrames = [:]
            frame = CGRect(x: 0, y: 0, width: max(1, input.width), height: 0)
            onGeometryChange?()
            return
        }
        // Natural widths are measured without wrapping, then bounded by policy.
        var preferred = [CGFloat](repeating: 0, count: columns)
        let naturalWidth = MarkdownTableLayout.maximumCellWidth * max(1, input.theme.scale)
        for address in addresses {
            let content = cellContent(input, address: address, width: naturalWidth)
            preferred[address.columnIndex] = max(preferred[address.columnIndex],
                                                 MarkdownTableCellMeasurement.naturalWidth(content))
        }
        let policy = MarkdownTableLayout(viewportWidth: input.width,
                                         preferredContentWidths: preferred, scale: input.theme.scale)
        layout = policy

        // Remeasure each cell at its final finite column width; rows take the
        // tallest cell, and no row is clipped to a fixed height.
        var heights = [CGFloat](repeating: 0, count: structure.rowCount)
        for address in addresses {
            let width = policy.contentWidth(column: address.columnIndex)
            let content = cellContent(input, address: address, width: width)
            var height = MarkdownTableCellMeasurement.size(content, width: width).height
            if let host = hosts[address.leafID] {
                host.rootView = MarkdownTableCellHost(
                    block: input.document[address.leafID], theme: input.theme,
                    keyboardFocus: input.keyboardFocus, pageReader: input.pageReader,
                    width: width, quoted: input.quoted,
                    presentation: MarkdownTableCellPresentation(
                        alignment: structure.alignment(column: address.columnIndex),
                        header: structure.rows[address.rowIndex].isHeader),
                    environment: input.environment)
                // Auxiliary cell content such as an image retry control can be
                // taller than the text alone; never clip it away.
                height = max(height, host.fittingSize.height)
            }
            heights[address.rowIndex] = max(heights[address.rowIndex], height)
        }
        var frames: [Int: CGRect] = [:]
        var rows: [CGFloat] = []
        var y: CGFloat = 0
        for row in structure.rows.indices {
            let height = policy.rowHeight(cellHeights: [heights[row]])
            rows.append(height)
            for column in 0..<columns {
                guard let address = input.document.tableCell(tableID: input.tableID, row: row, column: column)
                else { continue }
                let rect = CGRect(x: policy.columnX(column), y: y,
                                  width: policy.columnWidths[column], height: height)
                frames[address.leafID] = rect
                let content = CGRect(x: rect.minX + policy.padding, y: rect.minY + policy.padding,
                                     width: policy.contentWidth(column: column),
                                     height: max(0, height - policy.padding * 2))
                hosts[address.leafID]?.frame = content
                cellElements[address]?.localFrame = rect
            }
            y += height
        }
        rowHeights = rows
        cellFrames = frames
        contentHeight = y
        frame = CGRect(x: 0, y: 0, width: max(policy.contentWidth, 1), height: y)
        onGeometryChange?()
    }

    /// The same attributed payload the hosted cell presents, used for measurement.
    private func cellContent(_ input: MarkdownTableSurfaceInput,
                             address: MarkdownTableCellAddress, width: CGFloat) -> NSAttributedString {
        let block = input.document[address.leafID]
        let presentation = MarkdownTableCellPresentation(
            alignment: structure.alignment(column: address.columnIndex),
            header: structure.rows[address.rowIndex].isHeader)
        let text = input.theme.presentationText(for: block.text)
        let urls = text.runs[\.markdownImage].compactMap { image, _ in
            image?.url(preferringDark: input.dark)
        }
        let states = input.imageStates.filter { urls.contains($0.key) }
        return MarkdownLinkedImageContent.make(.init(
            text: text, states: states, dark: input.dark, width: width,
            headingLevel: nil, quoted: input.quoted, scale: input.theme.scale,
            tableCell: presentation))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let layout, !rowHeights.isEmpty, !layout.columnWidths.isEmpty else { return }
        let border = ReaderTheme.tableBorder
        let width = ReaderTheme.tableBorderWidth(scale: scale)
        var y: CGFloat = 0
        for (index, height) in rowHeights.enumerated() {
            let rect = CGRect(x: 0, y: y, width: layout.contentWidth, height: height)
            if rect.intersects(dirtyRect) {
                if structure.rows.indices.contains(index), structure.rows[index].isHeader {
                    ReaderTheme.tableHeaderBackground.setFill()
                    rect.fill()
                } else if index % 2 == 1 {
                    ReaderTheme.tableAlternateRowBackground.setFill()
                    rect.fill()
                }
            }
            y += height
        }
        border.setFill()
        // Explicit rules keep every cell boundary visible in both appearances,
        // independently of the background difference.
        y = 0
        for height in rowHeights.dropLast() {
            y += height
            CGRect(x: 0, y: y - width / 2, width: layout.contentWidth, height: width).fill()
        }
        var x: CGFloat = 0
        for column in layout.columnWidths.dropLast() {
            x += column
            CGRect(x: x - width / 2, y: 0, width: width, height: contentHeight).fill()
        }
        let outline = NSBezierPath(rect: CGRect(x: width / 2, y: width / 2,
                                                width: max(0, layout.contentWidth - width),
                                                height: max(0, contentHeight - width)))
        outline.lineWidth = width
        border.setStroke()
        outline.stroke()
    }

    // MARK: - Accessibility

    private func rebuildAccessibility() {
        for element in cellElements.values { element.detach() }
        cellElements = [:]
        rowElements = []
        columnElements = []
        guard structure.columnCount > 0 else { return }
        for address in addresses {
            let element = MarkdownTableCellElement(owner: self, address: address)
            element.host = hosts[address.leafID]
            hosts[address.leafID]?.setAccessibilityParent(element)
            cellElements[address] = element
        }
        // One canonical element per coordinate, shared by the row and the column,
        // so a cell is never announced as two separate reading subtrees.
        for row in structure.rows.indices {
            rowElements.append(MarkdownTableRowElement(owner: self, index: row, cells: elements(row: row)))
        }
        for column in 0..<structure.columnCount {
            let cells = structure.rows.indices.compactMap { element(row: $0, column: column) }
            let header = structure.headerRowIndex.flatMap { element(row: $0, column: column) }
            columnElements.append(MarkdownTableColumnElement(
                owner: self, index: column, cells: cells, header: header))
            // Every body cell associates the same column's header element, even
            // when two headers share a label or a header cell is empty.
            for cell in cells { cell.columnHeader = header }
        }
    }

    private func address(row: Int, column: Int) -> MarkdownTableCellAddress? {
        guard grid.indices.contains(row), grid[row].indices.contains(column) else { return nil }
        return grid[row][column]
    }

    private func element(row: Int, column: Int) -> MarkdownTableCellElement? {
        address(row: row, column: column).flatMap { cellElements[$0] }
    }

    private func elements(row: Int) -> [MarkdownTableCellElement] {
        (0..<structure.columnCount).compactMap { element(row: row, column: $0) }
    }

    /// Local table coordinates converted to screen space, clipped to what the local
    /// scroller actually shows.
    func screenFrame(_ rect: CGRect) -> NSRect {
        guard let window else { return .zero }
        var visible = rect
        if let clip = enclosingScrollView?.contentView {
            let converted = convert(rect, to: clip).intersection(clip.bounds)
            guard !converted.isNull, !converted.isEmpty else { return .zero }
            visible = convert(converted, from: clip)
        }
        return window.convertToScreen(convert(visible, to: nil))
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .table }
    override func accessibilityLabel() -> String? { nil }
    override func accessibilityChildren() -> [Any]? { rowElements }
    override func accessibilityRows() -> [Any]? { rowElements }
    override func accessibilityColumns() -> [Any]? { columnElements }
    override func accessibilityRowCount() -> Int { rowElements.count }
    override func accessibilityColumnCount() -> Int { columnElements.count }
    override func accessibilityHeader() -> Any? {
        structure.headerRowIndex.flatMap { rowElements.indices.contains($0) ? rowElements[$0] : nil }
    }

    override func accessibilityColumnHeaderUIElements() -> [Any]? {
        guard let header = structure.headerRowIndex else { return nil }
        let cells = (0..<structure.columnCount).compactMap { address(row: header, column: $0) }
            .compactMap { cellElements[$0] }
        return cells.isEmpty ? nil : cells
    }

    override func accessibilityVisibleCells() -> [Any]? {
        addresses.compactMap { cellElements[$0] }.filter { $0.accessibilityFrame() != .zero }
    }

    override func accessibilityCell(forColumn column: Int, row: Int) -> Any? {
        guard let address = address(row: row, column: column) else { return nil }
        return cellElements[address]
    }

    func detach() {
        onGeometryChange = nil
        for element in cellElements.values { element.detach() }
        cellElements = [:]
        rowElements = []
        columnElements = []
        for host in hosts.values {
            host.setAccessibilityParent(nil)
            host.removeFromSuperview()
        }
        hosts = [:]
        signature = nil
    }
}

/// A row of the native table. Rows are the table's children, in source order.
final class MarkdownTableRowElement: NSAccessibilityElement {
    private weak var owner: MarkdownTableDocumentView?
    private let index: Int
    private let cells: [MarkdownTableCellElement]

    init(owner: MarkdownTableDocumentView, index: Int, cells: [MarkdownTableCellElement]) {
        self.owner = owner
        self.index = index
        self.cells = cells
        super.init()
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .row }
    override func accessibilityIndex() -> Int { index }
    override func accessibilityChildren() -> [Any]? { cells }
    override func accessibilityParent() -> Any? { owner }
    override func accessibilityFrame() -> NSRect {
        let frames = cells.map { $0.localFrame }.filter { !$0.isEmpty }
        guard let first = frames.first, let owner else { return .zero }
        return owner.screenFrame(frames.dropFirst().reduce(first) { $0.union($1) })
    }
}

/// A column of the native table, carrying its own header reference.
final class MarkdownTableColumnElement: NSAccessibilityElement {
    private weak var owner: MarkdownTableDocumentView?
    private let index: Int
    private let cells: [MarkdownTableCellElement]
    private weak var header: MarkdownTableCellElement?

    init(owner: MarkdownTableDocumentView, index: Int,
         cells: [MarkdownTableCellElement], header: MarkdownTableCellElement?) {
        self.owner = owner
        self.index = index
        self.cells = cells
        self.header = header
        super.init()
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .column }
    override func accessibilityIndex() -> Int { index }
    override func accessibilityChildren() -> [Any]? { cells }
    override func accessibilityParent() -> Any? { owner }
    override func accessibilityHeader() -> Any? { header }
    override func accessibilityFrame() -> NSRect {
        let frames = cells.map { $0.localFrame }.filter { !$0.isEmpty }
        guard let first = frames.first, let owner else { return .zero }
        return owner.screenFrame(frames.dropFirst().reduce(first) { $0.union($1) })
    }
}

/// One canonical cell element per coordinate.
///
/// The cell owns the real rendered text, links and image descendants rather than a
/// flattened summary, so inline content stays reachable once in document order.
final class MarkdownTableCellElement: NSAccessibilityElement {
    private weak var owner: MarkdownTableDocumentView?
    let address: MarkdownTableCellAddress
    var localFrame: CGRect = .zero
    weak var host: NSView?
    weak var columnHeader: MarkdownTableCellElement?

    init(owner: MarkdownTableDocumentView, address: MarkdownTableCellAddress) {
        self.owner = owner
        self.address = address
        super.init()
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .cell }
    override func accessibilityParent() -> Any? { owner }
    override func accessibilityChildren() -> [Any]? { host.map { [$0] } }
    override func accessibilityRowIndexRange() -> NSRange { NSRange(location: address.rowIndex, length: 1) }
    override func accessibilityColumnIndexRange() -> NSRange { NSRange(location: address.columnIndex, length: 1) }
    override func accessibilityColumnHeaderUIElements() -> [Any]? { columnHeader.map { [$0] } }
    override func accessibilityFrame() -> NSRect { owner?.screenFrame(localFrame) ?? .zero }

    func detach() {
        host?.setAccessibilityParent(nil)
        host = nil
        columnHeader = nil
        owner = nil
    }
}

/// Width and height of one cell's attributed payload, with no view or window.
enum MarkdownTableCellMeasurement {
    static func size(_ content: NSAttributedString, width proposed: CGFloat) -> CGSize {
        let width = proposed.isFinite && proposed > 0 ? proposed : 1
        guard content.length > 0 else { return CGSize(width: width, height: 0) }
        let (layout, container) = textSystem(for: content, width: width)
        layout.ensureLayout(for: container)
        let height = layout.usedRect(for: container).height
        return CGSize(width: width, height: height.isFinite ? ceil(max(0, height)) : 0)
    }

    /// The width the cell would take without wrapping, bounded by the caller.
    static func naturalWidth(_ content: NSAttributedString) -> CGFloat {
        guard content.length > 0 else { return 0 }
        let (layout, container) = textSystem(for: content, width: CGFloat.greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        let width = layout.usedRect(for: container).width
        return width.isFinite ? ceil(max(0, width)) : 0
    }

    private static func textSystem(for content: NSAttributedString,
                                   width: CGFloat) -> (NSLayoutManager, NSTextContainer) {
        let storage = NSTextStorage(attributedString: content)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        return (layout, container)
    }
}
