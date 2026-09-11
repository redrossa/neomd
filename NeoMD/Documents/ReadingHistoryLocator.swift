//
//  ReadingHistoryLocator.swift
//  NeoMD
//

import CoreGraphics
import Foundation

/// The persisted projection of a copied reading position.
///
/// `DocumentContentLocator` is the single shared capture/remap implementation; this
/// type only makes one of its values durable and reconstructs it later. Nothing
/// rendering-local is stored: no node ID, parser handle, block kind, table address or
/// native view identity — only content digests, bounded context, reading progress and
/// the within-block fraction.
nonisolated struct ReadingHistoryLocator: Codable, Equatable, Sendable {

    nonisolated enum Edge: String, Codable, Sendable {
        case top
        case bottom
    }

    let edge: Edge?
    let digest: UInt64?
    let section: UInt64?
    let previous: UInt64?
    let next: UInt64?
    let excerpt: String
    let ordinal: Int
    let total: Int
    let fraction: Double

    private enum CodingKeys: String, CodingKey {
        case edge, digest, section, previous, next, excerpt, ordinal, total, fraction
    }

    init(edge: Edge? = nil, digest: UInt64? = nil, section: UInt64? = nil,
         previous: UInt64? = nil, next: UInt64? = nil, excerpt: String = "",
         ordinal: Int = 0, total: Int = 0, fraction: Double = 0) {
        self.edge = edge
        self.digest = digest
        self.section = section
        self.previous = previous
        self.next = next
        self.excerpt = excerpt
        self.ordinal = ordinal
        self.total = total
        self.fraction = fraction
    }

    static func edge(_ edge: Edge) -> ReadingHistoryLocator {
        ReadingHistoryLocator(edge: edge)
    }

    /// Projects a live locator into its durable form.
    init(_ locator: DocumentContentLocator) {
        switch locator.place {
        case .top:
            self.init(edge: .top)
        case .bottom:
            self.init(edge: .bottom)
        case .content(let content):
            self.init(digest: content.digest, section: content.section,
                      previous: content.previous, next: content.next,
                      excerpt: String(content.excerpt.prefix(DocumentContentDigest.excerptLimit)),
                      ordinal: content.ordinal, total: content.total,
                      fraction: content.fraction)
        }
    }

    /// Reconstructs the shared locator so the merged remapper does the matching.
    /// Returns nil for a value that failed validation.
    var restored: DocumentContentLocator? {
        guard isWellFormed else { return nil }
        if let edge { return DocumentContentLocator(place: edge == .top ? .top : .bottom) }
        guard let digest else { return nil }
        return DocumentContentLocator(place: .content(DocumentContentLocator.Content(
            digest: digest, section: section ?? 0, previous: previous, next: next,
            excerpt: excerpt, ordinal: ordinal, total: total, fraction: fraction)))
    }

    /// Rejects unsupported, malformed and non-finite stored values, so corrupt history
    /// never blocks a readable document.
    var isWellFormed: Bool {
        guard fraction.isFinite, fraction >= 0, fraction <= 1 else { return false }
        guard excerpt.count <= DocumentContentDigest.excerptLimit else { return false }
        if edge != nil { return digest == nil }
        guard digest != nil, total >= 1, ordinal >= 0, ordinal < total else { return false }
        return true
    }
}
