//
//  DocumentContentLocator.swift
//  NeoMD
//

import CoreGraphics
import Foundation

/// Copied reading-order identity for one immutable rendering.
///
/// Render-local integer IDs are contiguous preorder indices: inserting metadata or a
/// paragraph shifts every later ID. The index therefore keeps a stable content digest,
/// its section context and a bounded excerpt for each restoration-eligible leaf, so a
/// position captured in one rendering can be found again in the next one.
///
/// The index holds values only — no parser pointers, views, callbacks or source ranges —
/// and is built with the rendering, off the main actor.
nonisolated struct DocumentContentIndex: Sendable {

    /// One restoration-eligible leaf, in reading order.
    struct Entry: Equatable, Sendable {
        let id: Int
        let digest: UInt64
        /// Digest of the nearest preceding heading, or the heading's own digest.
        let section: UInt64
        /// Bounded normalized prefix used when content was edited rather than moved.
        let excerpt: String
    }

    static let empty = DocumentContentIndex(.empty)

    private(set) var entries: [Entry]
    /// Render node ID to reading-order offset, including containers via their first leaf.
    private var offsets: [Int: Int]
    private var digests: [UInt64: [Int]]

    var isEmpty: Bool { entries.isEmpty }

    init(_ document: MarkdownRenderDocument) {
        var entries: [Entry] = []
        var offsets: [Int: Int] = [:]
        var digests: [UInt64: [Int]] = [:]
        var section: UInt64 = 0
        for id in document.leafIDs {
            let block = document[id]
            // A zero-height anchor carries no visible content and is never a target.
            guard block.kind != .anchor else { continue }
            let content = DocumentContentDigest.content(of: block)
            let digest = DocumentContentDigest.value(content)
            if case .heading = block.kind { section = digest }
            let offset = entries.count
            entries.append(Entry(id: id, digest: digest, section: section,
                                 excerpt: DocumentContentDigest.excerpt(content)))
            offsets[id] = offset
            digests[digest, default: []].append(offset)
        }
        // A container frame resolves to the first eligible leaf it contains, so a
        // future nested layout does not need its own identity scheme here.
        for node in document.nodes where !node.isLeaf {
            guard let offset = offsets[document.firstLeafIDs[node.id]] else { continue }
            offsets[node.id] = offset
        }
        self.entries = entries
        self.offsets = offsets
        self.digests = digests
    }

    func offset(forTarget id: Int) -> Int? { offsets[id] }
    func offsets(for digest: UInt64) -> [Int] { digests[digest] ?? [] }

    /// Bounded prefix matching for content that was edited in place.
    func offsets(matchingExcerpt excerpt: String) -> [Int] {
        guard !excerpt.isEmpty else { return [] }
        return entries.indices.filter { entries[$0].excerpt == excerpt }
    }
}

/// Stable content hashing. `Hasher` is seeded per process and cannot be compared
/// across renderings of the same document in principle, let alone across launches.
nonisolated enum DocumentContentDigest {
    static let excerptLimit = 96

    /// The visible content of a block, tagged by presentation kind.
    ///
    /// Generated ordinals (footnote numbers, list numbering, image occurrence keys)
    /// are deliberately excluded: they renumber when unrelated content changes.
    static func content(of block: MarkdownBlock) -> String {
        var result = kind(of: block) + "\u{1}"
        for run in block.text.runs {
            result += String(String.UnicodeScalarView(block.text.unicodeScalars[run.range]))
            if let image = run.markdownImage {
                let source = image.source ?? image.lightSource ?? image.darkSource
                result += "\u{1}image:" + (source?.absoluteString ?? "")
            }
        }
        return normalized(result, preservingWhitespace: isCode(block))
    }

    static func value(_ content: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in content.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return hash
    }

    static func excerpt(_ content: String) -> String {
        String(content.prefix(excerptLimit))
    }

    private static func isCode(_ block: MarkdownBlock) -> Bool {
        if case .codeBlock = block.kind { return true }
        return false
    }

    private static func kind(of block: MarkdownBlock) -> String {
        switch block.kind {
        case .paragraph: "p"
        case .metadata: "meta"
        // A table is a container, never an entry; its cells carry their own kinds.
        case .table: "table"
        case .heading(let level): "h\(level)"
        case .codeBlock: "code"
        case .blockQuote: "quote"
        case .alert: "alert"
        case .listItem(_, let depth): "li\(depth)"
        case .thematicBreak: "hr"
        case .footnote: "fn"
        case .anchor: "anchor"
        }
    }

    /// Code keeps every literal scalar; prose ignores rewrapping.
    private static func normalized(_ content: String, preservingWhitespace: Bool) -> String {
        guard !preservingWhitespace else { return content }
        var result = ""
        var pendingSpace = false
        for character in content {
            if character.isWhitespace {
                pendingSpace = !result.isEmpty
                continue
            }
            if pendingSpace { result.append(" ") }
            pendingSpace = false
            result.append(character)
        }
        return result
    }
}

/// A reading position expressed as copied content identity instead of a render-local ID.
///
/// Captured before a successful replacement and resolved against the new rendering.
/// Surviving content wins; a deleted target falls back to a surviving neighbour and
/// then to clamped reading-order progress. An empty rendering resolves to the top.
nonisolated struct DocumentContentLocator: Equatable, Sendable {

    /// Copied evidence for one leaf, plus the reader's position inside it.
    struct Content: Equatable, Sendable {
        let digest: UInt64
        let section: UInt64
        let previous: UInt64?
        let next: UInt64?
        let excerpt: String
        let ordinal: Int
        let total: Int
        let fraction: Double
    }

    enum Place: Equatable, Sendable {
        case top
        case bottom
        case content(Content)
    }

    let place: Place

    /// Converts a render-local anchor into copied identity. Returns nil when the
    /// anchor points at content that is not a restoration target.
    static func capture(anchor: DocumentReadingAnchor, in index: DocumentContentIndex) -> DocumentContentLocator? {
        switch anchor {
        case .top: return DocumentContentLocator(place: .top)
        case .bottom: return DocumentContentLocator(place: .bottom)
        case .block(let id, let fraction):
            guard let offset = index.offset(forTarget: id) else { return nil }
            let entry = index.entries[offset]
            let previous = offset > 0 ? index.entries[offset - 1].digest : nil
            let next = offset + 1 < index.entries.count ? index.entries[offset + 1].digest : nil
            return DocumentContentLocator(place: .content(Content(
                digest: entry.digest, section: entry.section, previous: previous, next: next,
                excerpt: entry.excerpt, ordinal: offset, total: index.entries.count,
                fraction: clamped(Double(fraction)))))
        }
    }

    /// Resolves into a valid anchor for `index`. Never returns an invalid target.
    func resolve(in index: DocumentContentIndex) -> DocumentReadingAnchor {
        guard !index.isEmpty else { return .top }
        switch place {
        case .top: return .top
        case .bottom: return .bottom
        case .content(let content):
            if let match = Self.match(content, in: index) {
                return .block(id: index.entries[match.offset].id,
                              fraction: CGFloat(Self.clamped(match.fraction)))
            }
            let offset = Self.projected(content, count: index.entries.count)
            return .block(id: index.entries[offset].id, fraction: CGFloat(Self.clamped(content.fraction)))
        }
    }

    /// Surviving content, then edited content, then a surviving neighbour.
    private static func match(_ content: Content, in index: DocumentContentIndex) -> (offset: Int, fraction: Double)? {
        if let offset = choose(index.offsets(for: content.digest), content, index) {
            return (offset, content.fraction)
        }
        if let offset = choose(index.offsets(matchingExcerpt: content.excerpt), content, index) {
            return (offset, content.fraction)
        }
        // The content that moved up into the deleted passage is read first, so the
        // following neighbour wins the documented tie break before the preceding one.
        if let next = content.next, let offset = choose(index.offsets(for: next), content, index) {
            return (offset, 0)
        }
        if let previous = content.previous, let offset = choose(index.offsets(for: previous), content, index) {
            return (offset, 1)
        }
        return nil
    }

    /// Deterministic scoring: identical words alone never decide between duplicates.
    private static func choose(_ candidates: [Int], _ content: Content,
                               _ index: DocumentContentIndex) -> Int? {
        guard !candidates.isEmpty else { return nil }
        let expected = projected(content, count: index.entries.count)
        var best: (offset: Int, score: Int, distance: Int)?
        for offset in candidates {
            var score = 0
            if index.entries[offset].section == content.section { score += 3 }
            if let previous = content.previous, offset > 0,
               index.entries[offset - 1].digest == previous { score += 4 }
            if let next = content.next, offset + 1 < index.entries.count,
               index.entries[offset + 1].digest == next { score += 4 }
            let distance = abs(offset - expected)
            guard let current = best else {
                best = (offset, score, distance)
                continue
            }
            if score > current.score || (score == current.score && distance < current.distance) {
                best = (offset, score, distance)
            }
        }
        return best?.offset
    }

    /// Old reading-order progress clamped into the new rendering.
    private static func projected(_ content: Content, count: Int) -> Int {
        guard count > 1 else { return 0 }
        guard content.total > 1, content.ordinal > 0 else { return 0 }
        let progress = Double(content.ordinal) / Double(content.total - 1)
        guard progress.isFinite else { return 0 }
        let scaled = (clamped(progress) * Double(count - 1)).rounded()
        return min(count - 1, max(0, Int(scaled)))
    }

    private static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}
