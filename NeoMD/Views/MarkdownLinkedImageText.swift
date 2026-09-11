import AppKit
import SwiftUI

/// Selectable inline prose and linked images share the existing native text bridge.
/// Unlinked image-only leaves retain their image status/accessibility presentation.
/// No scroll view or layout-state publication.
struct MarkdownLinkedImageText: View {
    static func requiresNativeText(_ text: AttributedString) -> Bool {
        text.runs.contains {
            if $0.link != nil { return true }
            if $0.markdownImage != nil { return false }
            return !String(text.characters[$0.range]).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    struct Input: Equatable {
        var text: AttributedString
        var states: [URL: MarkdownImageStore.State]
        var dark: Bool
        var width: CGFloat
        var headingLevel: Int?
        var quoted = false
        var scale: CGFloat = 1
    }

    let input: Input

    var body: some View {
        MarkdownLinkedImageNativeText(input: input)
            // NSTextView remains selectable; do not install a second SwiftUI selection surface.
            .textSelection(.disabled)
            .alignmentGuide(.firstTextBaseline) { _ in MarkdownLinkedImageContent.firstBaseline(input) }
    }
}

private struct MarkdownLinkedImageNativeText: NSViewRepresentable {
    let input: MarkdownLinkedImageText.Input
    @Environment(\.openURL) private var openURL
    @Environment(\.documentPointerOpenURL) private var pointerOpenURL
    @Environment(\.documentNavigationBridge) private var bridge
    @Environment(\.documentNavigationGeneration) private var generation
    @Environment(\.documentLeafID) private var leafID

    func makeNSView(context: Context) -> MarkdownLinkedImageTextView {
        MarkdownLinkedImageTextView(frame: .zero)
    }

    func updateNSView(_ view: MarkdownLinkedImageTextView, context: Context) {
        view.open = { openURL($0) }
        view.pointerOpen = pointerOpenURL
        view.bindTraversal(bridge: bridge, id: leafID, generation: generation)
        view.update(input)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: MarkdownLinkedImageTextView, context: Context) -> CGSize? {
        view.measure(width: proposal.width ?? input.width)
    }

    static func dismantleNSView(_ view: MarkdownLinkedImageTextView, coordinator: ()) {
        view.detach()
    }
}

final class MarkdownLinkedImageTextView: NSTextView, NSTextViewDelegate {
    var open: (URL) -> Void = { _ in }
    var pointerOpen: ((URL, DocumentLinkActivation) -> Void)?
    private let pointerScope = DocumentLinkPointerScope()

    override func mouseDown(with event: NSEvent) {
        let activation = DocumentLinkActivation(pointer: event.type == .leftMouseDown,
            command: event.modifierFlags.contains(.command), control: event.modifierFlags.contains(.control))
        pointerScope.tracking(activation) { super.mouseDown(with: event) }
    }
    private(set) var input: MarkdownLinkedImageText.Input?
    private(set) var replacementCount = 0
    private var imageAccessibility: [MarkdownImageAccessibilityElement] = []
    private weak var traversalBridge: DocumentNavigationBridge?
    private var traversalID: Int?
    private var traversalGeneration = -1

    func bindTraversal(bridge: DocumentNavigationBridge?, id: Int?, generation: Int) {
        guard traversalBridge !== bridge || traversalID != id || traversalGeneration != generation else { return }
        if let traversalID { traversalBridge?.unregisterText(self, id: traversalID) }
        traversalBridge = bridge
        traversalID = id
        traversalGeneration = generation
        if let id { bridge?.registerText(self, id: id, generation: generation) }
    }

    static func traversalDirection(_ event: NSEvent) -> Bool? {
        guard event.keyCode == 48 else { return nil }
        let modifiers = event.modifierFlags.intersection([.option, .shift, .command, .control])
        if modifiers == .option { return false }
        if modifiers == [.option, .shift] { return true }
        return nil
    }

    override func keyDown(with event: NSEvent) {
        if let reverse = Self.traversalDirection(event), let id = traversalID,
           traversalBridge?.traverseText(self, id: id, generation: traversalGeneration,
                                         reverse: reverse) == true { return }
        super.keyDown(with: event)
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer? = nil) {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let nativeContainer = container ?? NSTextContainer(size: CGSize(width: 1, height: CGFloat.greatestFiniteMagnitude))
        if container == nil {
            storage.addLayoutManager(layout)
            layout.addTextContainer(nativeContainer)
        }
        super.init(frame: frameRect, textContainer: nativeContainer)
        minSize = .zero
        maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        isEditable = false
        isSelectable = true
        isRichText = true
        importsGraphics = false
        allowsImageEditing = false
        usesRuler = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isContinuousSpellCheckingEnabled = false
        drawsBackground = false
        textContainerInset = .zero
        textContainer?.lineFragmentPadding = 0
        textContainer?.widthTracksTextView = false
        textContainer?.heightTracksTextView = false
        isHorizontallyResizable = false
        isVerticallyResizable = false
        linkTextAttributes = [.foregroundColor: NSColor.linkColor, .underlineStyle: NSUnderlineStyle.single.rawValue,
                              .cursor: NSCursor.pointingHand]
        delegate = self
        unregisterDraggedTypes()
    }

    required init?(coder: NSCoder) { nil }

    func update(_ next: MarkdownLinkedImageText.Input) {
        guard input != next else { return }
        let selection = selectedRanges
        input = next
        textStorage?.setAttributedString(MarkdownLinkedImageContent.make(next))
        replacementCount += 1
        rebuildAccessibility()
        let length = textStorage?.length ?? 0
        selectedRanges = selection.filter { NSMaxRange($0.rangeValue) <= length }
    }

    /// Bounds of presentation-only swatches; indexes remain original native text indexes.
    func swatchBounds() -> [(NSRect, NSColor)] {
        guard let storage = textStorage, let layout = layoutManager, let container = textContainer,
              let input else { return [] }
        layout.ensureLayout(for: container)
        var result: [(NSRect, NSColor)] = []
        storage.enumerateAttribute(MarkdownColorSwatch.attribute, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard let color = value as? NSColor,
                  let font = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont else { return }
            let glyph = layout.glyphIndexForCharacter(at: range.location)
            let location = layout.location(forGlyphAt: glyph)
            let line = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let advance = font.advancement(forGlyph: layout.glyph(at: glyph)).width
            let side = MarkdownColorSwatch.side(scale: input.scale)
            let rect = NSRect(x: line.minX + location.x + advance + MarkdownColorSwatch.gap(scale: input.scale),
                              y: line.minY + location.y - side, width: side, height: side)
                .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
            result.append((rect, color))
        }
        return result
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        for (rect, color) in swatchBounds() where rect.intersects(dirtyRect) {
            color.setFill()
            NSBezierPath(rect: rect).fill()
            NSColor.secondaryLabelColor.setStroke()
            let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = 1
            border.stroke()
        }
    }

    override var firstBaselineOffsetFromTop: CGFloat {
        guard let layout = layoutManager, let container = textContainer, (textStorage?.length ?? 0) > 0 else { return 0 }
        layout.ensureLayout(for: container)
        return layout.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil).minY +
            layout.location(forGlyphAt: 0).y + textContainerOrigin.y
    }

    func measure(width proposed: CGFloat) -> CGSize {
        let width = proposed.isFinite && proposed > 0 ? proposed : 1
        guard let container = textContainer, let layout = layoutManager else { return CGSize(width: width, height: 0) }
        container.containerSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        let height = layout.usedRect(for: container).height
        return CGSize(width: width, height: height.isFinite ? ceil(max(0, height)) : 0)
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        let url = (link as? URL) ?? (link as? String).flatMap(URL.init(string:))
        if let url {
            if let activation = pointerScope.activation, let pointerOpen { pointerOpen(url, activation) }
            else { open(url) }
        }
        return true // Always consume; AppKit must never open a URL independently.
    }

    // The existing leaf menu monitor owns secondary clicks. Never expose AppKit's
    // independent URL-opening or attachment-editing menu commands.
    override func menu(for event: NSEvent) -> NSMenu? { nil }
    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool { false }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool { false }

    override func accessibilityChildren() -> [Any]? { imageAccessibility }

    private func rebuildAccessibility() {
        imageAccessibility = []
        guard let storage = textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.enumerateAttribute(.link, in: fullRange) { value, range, _ in
            guard let url = value as? URL else { return }
            let fragment = storage.attributedSubstring(from: range)
            let label = NSMutableString(string: fragment.string)
            fragment.enumerateAttribute(NSAttributedString.Key("NeoMD.ImageAlternative"),
                in: NSRange(location: 0, length: fragment.length), options: .reverse) { value, range, _ in
                if let alt = value as? String { label.replaceCharacters(in: range, with: alt) }
            }
            imageAccessibility.append(MarkdownImageAccessibilityElement(owner: self, range: range,
                                                                        label: label as String, url: url))
        }
        storage.enumerateAttribute(NSAttributedString.Key("NeoMD.ImageAlternative"), in: fullRange) { value, range, _ in
            guard let label = value as? String, storage.attribute(.link, at: range.location, effectiveRange: nil) == nil else { return }
            imageAccessibility.append(MarkdownImageAccessibilityElement(owner: self, range: range, label: label, url: nil))
        }
        imageAccessibility.sort { $0.range.location < $1.range.location }
    }

    func detach() {
        bindTraversal(bridge: nil, id: nil, generation: -1)
        delegate = nil
        open = { _ in }
        pointerOpen = nil
        pointerScope.clear()
        input = nil
        for child in imageAccessibility { child.owner = nil }
        imageAccessibility = []
        // Release attachment resources even if AppKit retains the native view.
        textStorage?.setAttributedString(NSAttributedString(string: ""))
    }
}

/// NSTextView's stock attachment links have no usable press action. These inline
/// children preserve text-view selection/prose while dispatching through its policy.
final class MarkdownImageAccessibilityElement: NSAccessibilityElement {
    weak var owner: MarkdownLinkedImageTextView?
    let range: NSRange
    let url: URL?
    let alternative: String

    init(owner: MarkdownLinkedImageTextView, range: NSRange, label: String, url: URL?) {
        self.owner = owner
        self.range = range
        self.url = url
        self.alternative = label
        super.init()
    }

    override func accessibilityRole() -> NSAccessibility.Role? { url == nil ? .image : .link }
    override func accessibilityLabel() -> String? { alternative }
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityParent() -> Any? { owner }

    override func accessibilityFrame() -> NSRect {
        guard let owner, let window = owner.window, let layout = owner.layoutManager,
              let container = owner.textContainer else { return .zero }
        let glyphs = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
            .offsetBy(dx: owner.textContainerOrigin.x, dy: owner.textContainerOrigin.y)
        return window.convertToScreen(owner.convert(rect, to: nil))
    }

    override func accessibilityPerformPress() -> Bool {
        guard let owner, let url, owner.input != nil else { return false }
        owner.open(url)
        return true
    }
}

/// Converts only renderer-authored attributes; it never imports HTML/RTF or asks
/// AppKit to resolve attachment URLs. Decoded store bitmaps remain the sole source.
enum MarkdownLinkedImageContent {
    /// NSViewRepresentable does not propagate NSTextView's baseline to SwiftUI.
    /// Measure the same first line explicitly, without publishing layout state.
    static func firstBaseline(_ input: MarkdownLinkedImageText.Input) -> CGFloat {
        let storage = NSTextStorage(attributedString: make(input))
        guard storage.length > 0 else { return 0 }
        let layout = NSLayoutManager()
        let width = input.width.isFinite && input.width > 0 ? input.width : 1
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        return layout.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil).minY + layout.location(forGlyphAt: 0).y
    }

    static func make(_ input: MarkdownLinkedImageText.Input) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        for (image, range) in input.text.runs[\.markdownImage] {
            let source = AttributedString(input.text[range])
            guard let image else {
                for run in source.runs {
                    let fragment = AttributedString(source[run.range])
                    let content = NSMutableAttributedString(string: String(fragment.characters),
                        attributes: attributes(for: fragment, headingLevel: input.headingLevel, quoted: input.quoted, scale: input.scale))
                    if let color = run.markdownColorReference, content.length > 0 {
                        let end = NSRange(location: content.length - 1, length: 1)
                        content.addAttribute(MarkdownColorSwatch.attribute, value: MarkdownColorSwatch.color(color), range: end)
                        content.addAttribute(.kern, value: MarkdownColorSwatch.side(scale: input.scale) +
                            2 * MarkdownColorSwatch.gap(scale: input.scale), range: end)
                    }
                    result.append(content)
                }
                continue
            }
            let attributes = attributes(for: source, headingLevel: input.headingLevel, quoted: input.quoted, scale: input.scale)
            let alt = String(source.characters).replacingOccurrences(of: MarkdownPictureParser.emptyAltCarrier, with: "")
            let label = alt.isEmpty ? "Image" : alt
            let state = image.url(preferringDark: input.dark).flatMap { input.states[$0] }
            if case .loaded(let original, let natural) = state, let bitmap = original.copy() as? NSImage {
                let size = MarkdownImageLayout.displaySize(natural: natural, availableWidth: input.width)
                bitmap.size = size
                bitmap.accessibilityDescription = "\(label), Image displayed"
                let attachment = NSTextAttachment()
                attachment.image = bitmap
                attachment.bounds = CGRect(origin: .zero, size: size)
                let content = NSMutableAttributedString(attachment: attachment)
                content.addAttributes(attributes, range: NSRange(location: 0, length: content.length))
                content.addAttribute(NSAttributedString.Key("NeoMD.ImageAlternative"), value: "\(label), Image displayed",
                                     range: NSRange(location: 0, length: content.length))
                result.append(content)
            } else {
                let status: String
                if state == nil || state == .loading { status = "Image loading" }
                else { status = "Image unavailable" }
                var fallback = attributes
                fallback[.foregroundColor] = NSColor.secondaryLabelColor
                result.append(NSAttributedString(string: "\(label) (\(status))", attributes: fallback))
            }
        }
        return result
    }

    private static func attributes(for text: AttributedString, headingLevel: Int?, quoted: Bool, scale: CGFloat) -> [NSAttributedString.Key: Any] {
        var attributes = NSAttributedString(text).attributes(at: 0, effectiveRange: nil)
        let intent = text.inlinePresentationIntent ?? []
        let heading = headingLevel != nil
        let style: NSFont.TextStyle
        switch headingLevel {
        case 1: style = .largeTitle
        case 2: style = .title1
        case 3: style = .title2
        case 4: style = .title3
        case 5: style = .headline
        case 6: style = .subheadline
        default: style = .body
        }
        var font = NSFont.preferredFont(forTextStyle: style)
        if heading { font = NSFont.systemFont(ofSize: font.pointSize, weight: .semibold) }
        if intent.contains(.code) {
            // Preserve the baseline semantic headline's resolved bold weight.
            let weight: NSFont.Weight = headingLevel == 5 ? .bold : (heading ? .semibold : .regular)
            font = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: weight)
        }
        if let script = text.markdownInlineStyle, script == .subscriptText || script == .superscriptText {
            let scriptStyle: NSFont.TextStyle
            switch headingLevel {
            case 1: scriptStyle = .title3
            case 2: scriptStyle = .headline
            case 3, 4: scriptStyle = .subheadline
            case 5, 6: scriptStyle = .caption1
            default: scriptStyle = .footnote
            }
            font = NSFont.preferredFont(forTextStyle: scriptStyle)
            if heading { font = NSFont.systemFont(ofSize: font.pointSize, weight: .semibold) }
            attributes[.baselineOffset] = (script == .subscriptText ? -3 : 5) * scale
        }
        if intent.contains(.stronglyEmphasized) { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
        if intent.contains(.emphasized) { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
        if intent.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        font = NSFontManager.shared.convert(font, toSize: font.pointSize * scale)
        attributes[.font] = font
        let secondary = headingLevel == 6 || (headingLevel == nil && quoted)
        attributes[.foregroundColor] = text.foregroundColor.map(NSColor.init) ?? (secondary ? NSColor.secondaryLabelColor : NSColor.labelColor)
        if let background = text.backgroundColor { attributes[.backgroundColor] = NSColor(background) }
        if let link = text.link { attributes[.link] = link; attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        return attributes
    }
}
