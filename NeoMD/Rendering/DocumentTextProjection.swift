import Foundation

/// One presentation's ordered selectable text. Offscreen fragments are values, not
/// native views. Display offsets and clipboard offsets deliberately differ for images.
nonisolated struct DocumentTextProjection: Sendable {
    struct Key: Hashable, Sendable {
        let leafID: Int
        /// Zero is the ordinary leaf; metadata and visible labels use distinct parts.
        var part: Int = 0
    }

    struct Fragment: Equatable, Sendable {
        let key: Key
        let text: String
        /// Native attachment positions participate in selection, but never invent alt
        /// text in Copy. Fallback labels are ordinary text, not attachments.
        var attachments: [NSRange] = []
        var sourceSegments: [MarkdownCellDisplayProjection.Segment] = []
        /// Exact underlying content and structural context, without presentation IDs.
        let identity: Identity
        /// The separator *before* this fragment; ignored for the first fragment.
        var separator: String = "\n\n"

        init(key: Key, text: String, attachments: [NSRange] = [],
             identity: Identity? = nil, separator: String = "\n\n",
             sourceSegments: [MarkdownCellDisplayProjection.Segment] = []) {
            self.key = key
            self.text = text
            self.attachments = attachments
            self.identity = identity ?? Identity(source: text, role: "text", context: [])
            self.separator = separator
            self.sourceSegments = sourceSegments
        }

        func copiedText(in range: NSRange) -> String {
            let normalized = DocumentTextProjection.normalized(range, in: text)
            let result = NSMutableString(string: (text as NSString).substring(with: normalized))
            // Clip, sort and merge before deleting: callers cannot accidentally
            // remove an overlapping attachment twice or shift another range.
            var intervals: [NSRange] = []
            for attachment in attachments.sorted(by: { $0.location < $1.location }) {
                let clipped = NSIntersectionRange(normalized, DocumentTextProjection.clamped(attachment, length: text.utf16.count))
                guard clipped.length > 0 else { continue }
                if let last = intervals.last, NSMaxRange(last) >= clipped.location {
                    intervals[intervals.count - 1] = NSUnionRange(last, clipped)
                } else { intervals.append(clipped) }
            }
            for interval in intervals.reversed() {
                result.deleteCharacters(in: NSRange(location: interval.location - normalized.location,
                                                    length: interval.length))
            }
            return result as String
        }
    }

    /// Exact data only; never a render ID, table address, history locator or parser pointer.
    struct Identity: Equatable, Sendable {
        let source: String
        let role: String
        let context: [String]
    }

    struct Endpoint: Equatable, Sendable {
        let key: Key
        let offset: Int
    }

    struct Selection: Equatable, Sendable {
        let anchor: Endpoint
        let extent: Endpoint
    }

    struct Slice: Equatable, Sendable {
        let key: Key
        let range: NSRange
    }

    let presentation: UUID
    let fragments: [Fragment]
    private let indices: [Key: Int]

    init(presentation: UUID, fragments: [Fragment]) {
        self.presentation = presentation
        self.fragments = fragments
        var indices: [Key: Int] = [:]
        for (index, fragment) in fragments.enumerated() {
            precondition(indices.updateValue(index, forKey: fragment.key) == nil,
                         "Selectable fragment keys must be unique within a presentation")
        }
        self.indices = indices
    }

    func fragment(for key: Key) -> Fragment? { indices[key].map { fragments[$0] } }

    var entireSelection: Selection? {
        guard let first = fragments.first, let last = fragments.last else { return nil }
        return Selection(anchor: Endpoint(key: first.key, offset: 0),
                         extent: Endpoint(key: last.key, offset: last.text.utf16.count))
    }

    /// A collapsed caret snaps backward; nonempty bounds expand to complete graphemes.
    /// No Unicode normalization, trimming or Markdown stripping takes place here.
    static func normalized(_ range: NSRange, in text: String) -> NSRange {
        let string = text as NSString
        let bounded = clamped(range, length: string.length)
        if bounded.length > 0 { return string.rangeOfComposedCharacterSequences(for: bounded) }
        guard bounded.location < string.length else { return bounded }
        return NSRange(location: string.rangeOfComposedCharacterSequence(at: bounded.location).location, length: 0)
    }

    private static func clamped(_ range: NSRange, length: Int) -> NSRange {
        let start = min(max(0, range.location), length)
        return NSRange(location: start, length: min(max(0, range.length), length - start))
    }

    func slices(for selection: Selection) -> [Slice] {
        guard let a = indices[selection.anchor.key], let b = indices[selection.extent.key] else { return [] }
        let forward = a < b || (a == b && selection.anchor.offset <= selection.extent.offset)
        let lower = forward ? selection.anchor : selection.extent
        let upper = forward ? selection.extent : selection.anchor
        let start = min(a, b), end = max(a, b)
        return (start...end).map { index in
            let fragment = fragments[index]
            let length = fragment.text.utf16.count
            let lowerOffset = index == start ? min(max(0, lower.offset), length) : 0
            let upperOffset = index == end ? min(max(0, upper.offset), length) : length
            return Slice(key: fragment.key, range: Self.normalized(
                NSRange(location: lowerOffset, length: max(0, upperOffset - lowerOffset)), in: fragment.text))
        }
    }

    func copiedText(for selection: Selection) -> String {
        let slices = slices(for: selection)
        guard let first = slices.first, let last = slices.last else { return "" }
        // Endpoint-only empty slices do not cross a separator. Interior empty cells
        // do: their TAB/LF positions are essential to row-major serialization.
        var start = 0, end = slices.count
        if slices.count > 1, first.range.length == 0,
           fragment(for: first.key)?.text.isEmpty == false { start += 1 }
        if end > start, slices.count > 1, last.range.length == 0,
           fragment(for: last.key)?.text.isEmpty == false { end -= 1 }
        guard start < end else { return "" }
        var result = ""
        for index in start..<end {
            let slice = slices[index]
            guard let fragment = fragment(for: slice.key) else { continue }
            if index > start { result += fragment.separator }
            result += fragment.copiedText(in: slice.range)
        }
        return result
    }

    /// Native mount/unmount never enters this calculation. A new fragment display
    /// should supply its own source/display remap before replacing endpoint offsets.
    func replacing(_ fragment: Fragment) -> Self {
        guard let index = indices[fragment.key] else { return self }
        var updated = fragments
        updated[index] = fragment
        return Self(presentation: presentation, fragments: updated)
    }

    /// A one-shot refresh payload. Offsets refer to exact display text, not normalized
    /// reading-position digests. Changed/ambiguous endpoints clear rather than guess.
    struct RefreshDescriptor: Equatable, Sendable {
        struct Boundary: Equatable, Sendable {
            let identity: Identity
            let displayText: String
            let attachments: [NSRange]
            let offset: Int
            let sourceOffset: Int?
            let previous: Identity?
            let next: Identity?
        }
        let anchor: Boundary
        let extent: Boundary
    }

    func refreshDescriptor(for selection: Selection) -> RefreshDescriptor? {
        func boundary(_ endpoint: Endpoint) -> RefreshDescriptor.Boundary? {
            guard let index = indices[endpoint.key] else { return nil }
            let fragment = fragments[index]
            return .init(identity: fragment.identity, displayText: fragment.text,
                         attachments: fragment.attachments,
                         offset: min(max(0, endpoint.offset), fragment.text.utf16.count),
                         sourceOffset: fragment.sourceSegments.isEmpty ? nil : MarkdownCellDisplayProjection(
                            source: fragment.identity.source, content: NSAttributedString(string: fragment.text),
                            segments: fragment.sourceSegments).sourceRange(for: NSRange(location: endpoint.offset, length: 0)).location,
                         previous: index > 0 ? fragments[index - 1].identity : nil,
                         next: index + 1 < fragments.count ? fragments[index + 1].identity : nil)
        }
        guard let anchor = boundary(selection.anchor), let extent = boundary(selection.extent) else { return nil }
        return RefreshDescriptor(anchor: anchor, extent: extent)
    }

    func resolve(_ descriptor: RefreshDescriptor) -> Selection? {
        func endpoint(_ boundary: RefreshDescriptor.Boundary) -> Endpoint? {
            var candidates = fragments.indices.filter {
                fragments[$0].identity == boundary.identity &&
                    ((fragments[$0].text == boundary.displayText && fragments[$0].attachments == boundary.attachments) ||
                     (boundary.sourceOffset != nil && !fragments[$0].sourceSegments.isEmpty))
            }
            if candidates.count > 1 {
                candidates = candidates.filter { index in
                    let previous = index > 0 ? fragments[index - 1].identity : nil
                    let next = index + 1 < fragments.count ? fragments[index + 1].identity : nil
                    return previous == boundary.previous && next == boundary.next
                }
            }
            guard candidates.count == 1, let index = candidates.first else { return nil }
            let fragment = fragments[index]
            let offset: Int
            if fragment.text != boundary.displayText, let sourceOffset = boundary.sourceOffset {
                offset = MarkdownCellDisplayProjection(source: fragment.identity.source,
                    content: NSAttributedString(string: fragment.text), segments: fragment.sourceSegments)
                    .displayRange(for: NSRange(location: sourceOffset, length: 0)).location
            } else { offset = boundary.offset }
            return Endpoint(key: fragment.key, offset: offset)
        }
        guard let anchor = endpoint(descriptor.anchor), let extent = endpoint(descriptor.extent) else { return nil }
        return Selection(anchor: anchor, extent: extent)
    }
}
