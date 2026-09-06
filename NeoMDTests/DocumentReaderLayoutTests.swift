//
//  DocumentReaderLayoutTests.swift
//  NeoMDTests
//

import CoreGraphics
import Foundation
import Testing
@testable import NeoMD

struct DocumentReaderLayoutTests {

    @Test func readingColumnUsesMarginsUntilItReachesItsMaximumWidth() {
        #expect(DocumentReaderLayout.columnWidth(for: 480) == 400)
        #expect(DocumentReaderLayout.columnWidth(for: 840) == 760)
        #expect(DocumentReaderLayout.columnWidth(for: 1_200) == 760)
        #expect(DocumentReaderLayout.columnWidth(for: 60) == 0)
    }

    @Test func anchorTracksThePositionInsideTheBlockAtTheReadingLine() {
        let frames = [
            4: CGRect(x: 40, y: 800, width: 400, height: 1_000),
            5: CGRect(x: 40, y: 1_816, width: 400, height: 40)
        ]

        let anchor = DocumentReaderLayout.readingAnchor(
            in: frames,
            visibleRect: CGRect(x: 0, y: 1_000, width: 480, height: 600),
            isAtTop: false,
            isAtBottom: false
        )

        #expect(anchor == .block(id: 4, fraction: 0.5))
    }

    @Test func anchorUsesTheNearestBlockWhenTheReadingLineFallsInSpacing() {
        let frames = [
            10: CGRect(x: 40, y: 1_100, width: 400, height: 100),
            11: CGRect(x: 40, y: 1_240, width: 400, height: 100)
        ]

        let anchor = DocumentReaderLayout.readingAnchor(
            in: frames,
            visibleRect: CGRect(x: 0, y: 1_000, width: 480, height: 440),
            isAtTop: false,
            isAtBottom: false
        )

        #expect(anchor == .block(id: 10, fraction: 1))
    }

    @Test func documentEdgesTakePriorityOverBlockAnchors() {
        let frames = [0: CGRect(x: 40, y: 32, width: 400, height: 40)]

        #expect(
            DocumentReaderLayout.readingAnchor(
                in: frames,
                visibleRect: CGRect(x: 0, y: 0, width: 480, height: 600),
                isAtTop: true,
                isAtBottom: false
            ) == .top
        )
        #expect(
            DocumentReaderLayout.readingAnchor(
                in: frames,
                visibleRect: CGRect(x: 0, y: 0, width: 480, height: 600),
                isAtTop: false,
                isAtBottom: true
            ) == .bottom
        )
    }

    @Test func restorationOffsetPreservesTheWithinBlockFraction() {
        let offset = DocumentReaderLayout.verticalOffset(
            for: .block(id: 7, fraction: 0.65),
            targetFrame: CGRect(x: 40, y: 900, width: 400, height: 800),
            viewportHeight: 600
        )

        #expect(offset == 1_120)
        #expect(
            DocumentReaderLayout.verticalOffset(
                for: .top,
                targetFrame: .zero,
                viewportHeight: 600
            ) == nil
        )
    }
}
