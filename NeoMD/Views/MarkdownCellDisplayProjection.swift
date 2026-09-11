import Foundation

/// Source/native UTF-16 correspondence for one cell, not a document selection owner.
struct MarkdownCellDisplayProjection {
    enum Kind: Equatable { case text, attachment, fallback }
    struct Segment: Equatable {
        let source: NSRange
        let display: NSRange
        let occurrence: String?
        let kind: Kind
    }
    let source: String
    let content: NSAttributedString
    let segments: [Segment]

    func sourceRange(for display: NSRange) -> NSRange {
        mapped(display, toSource: true)
    }

    func displayRange(for source: NSRange) -> NSRange {
        mapped(source, toSource: false)
    }

    func remap(_ range: NSRange, from previous: Self) -> NSRange {
        displayRange(for: previous.sourceRange(for: range))
    }

    private func mapped(_ range: NSRange, toSource: Bool) -> NSRange {
        let inputLength = toSource ? content.length : source.utf16.count
        let start = min(max(0, range.location), inputLength)
        let end = start + min(max(0, range.length), inputLength - start)
        func boundary(_ offset: Int, upper: Bool) -> Int {
            for segment in segments {
                let from = toSource ? segment.display : segment.source
                let to = toSource ? segment.source : segment.display
                if offset < NSMaxRange(from) || (offset == NSMaxRange(from) && upper) {
                    if segment.kind == .text { return to.location + min(from.length, max(0, offset - from.location)) }
                    if offset <= from.location { return to.location }
                    return upper ? NSMaxRange(to) : to.location
                }
            }
            return toSource ? source.utf16.count : content.length
        }
        let lower = boundary(start, upper: false)
        let upper = boundary(end, upper: end > start)
        let string = (toSource ? source : content.string) as NSString
        let result = NSRange(location: lower, length: max(0, upper - lower))
        guard result.length > 0 else { return result }
        return string.rangeOfComposedCharacterSequences(for: result)
    }
}

struct MarkdownTableCellPresentation: Equatable {
    let alignment: MarkdownTableStructure.Alignment
    let header: Bool
}
