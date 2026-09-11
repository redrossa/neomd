import CoreGraphics
import Foundation
import Testing
@testable import NeoMD

/// Passive production-policy tests only: no NSWindow, events or hosting probes.
@MainActor struct DocumentWindowPlacementTests {
    private struct Vectors: Decodable {
        struct Geometry: Decodable {
            let id: String
            let sourceFrame: [Double]
            let visibleFrame: [Double]
            let defaultFrameSize: [Double]
            let expectedFrame: [Double]
        }
        struct Selection: Decodable {
            struct Screen: Decodable {
                let id: UInt32
                let visibleFrame: [Double]
            }
            let id: String
            let capturedScreenID: UInt32?
            let sourceTopLeft: [Double]?
            let capturedVisibleFrame: [Double]?
            let currentScreens: [Screen]
            let expectedScreenID: UInt32?
            let expectedVisibleFrame: [Double]?
            let defaultFrameSize: [Double]?
            let expectedFrame: [Double]?
        }
        let geometryCases: [Geometry]
        let screenSelectionCases: [Selection]
    }

    private func vectors() throws -> Vectors {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: root.appendingPathComponent(
            "docs/fixtures/m1-p7-window-cascade/geometry-cases.json")))
    }

    private func rect(_ values: [Double]) -> CGRect {
        CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }

    @Test func allStagedFullFrameVectors() throws {
        let cases = try vectors().geometryCases
        #expect(cases.count == 12)
        for vector in cases {
            let source = rect(vector.sourceFrame)
            let visible = rect(vector.visibleFrame)
            let size = CGSize(width: vector.defaultFrameSize[0], height: vector.defaultFrameSize[1])
            let captured = DocumentWindowPlacement(sourceFrame: source, screenID: 2, capturedVisibleFrame: visible)
            let original = captured
            let output = captured.frame(defaultSize: size, screens: [.init(id: 2, visibleFrame: visible)])
            #expect(output == rect(vector.expectedFrame), "\(vector.id)")
            #expect(DocumentWindowPlacement.isUsable(output))
            #expect(visible.contains(output))
            #expect(output.width <= size.width && output.height <= size.height)
            #expect(output.width <= visible.width && output.height <= visible.height)
            #expect(captured == original && captured.sourceFrame == source)
        }
    }

    @Test func allStagedScreenSelectionVectors() throws {
        let cases = try vectors().screenSelectionCases
        #expect(cases.count == 6)
        for vector in cases {
            let source = vector.sourceTopLeft.map { CGRect(x: $0[0], y: $0[1] - 1, width: 1, height: 1) }
            let captured = DocumentWindowPlacement(sourceFrame: source, screenID: vector.capturedScreenID,
                                                    capturedVisibleFrame: vector.capturedVisibleFrame.map(rect))
            let screens = vector.currentScreens.map {
                DocumentWindowPlacement.Screen(id: $0.id, visibleFrame: rect($0.visibleFrame))
            }
            #expect(captured.selectedScreen(in: screens)?.id == vector.expectedScreenID, "\(vector.id)")
            if let expected = vector.expectedVisibleFrame {
                #expect(captured.visibleFrame(in: screens) == rect(expected), "\(vector.id)")
            }
            if source != nil {
                #expect(captured.selectedScreen(in: screens.reversed()) == captured.selectedScreen(in: screens))
            }
            if let size = vector.defaultFrameSize, let expected = vector.expectedFrame {
                #expect(captured.frame(defaultSize: CGSize(width: size[0], height: size[1]), screens: screens)
                        == rect(expected))
            }
        }
    }

    @Test func currentSourceDisplayBoundsOverrideCapturedBounds() {
        let captured = DocumentWindowPlacement(sourceFrame: CGRect(x: -1400, y: 150, width: 900, height: 742),
            screenID: 2, capturedVisibleFrame: CGRect(x: -1600, y: 40, width: 1600, height: 960))
        let current = CGRect(x: -1600, y: 200, width: 800, height: 600)
        let screens: [DocumentWindowPlacement.Screen] = [
            .init(id: 1, visibleFrame: CGRect(x: 0, y: 0, width: 2000, height: 1200)),
            .init(id: 2, visibleFrame: current)
        ]
        #expect(captured.frame(defaultSize: CGSize(width: 900, height: 742), screens: screens) == current)
        #expect(captured.capturedVisibleFrame?.minY == 40)
    }

    @Test func eachEdgeAndCornerKeepsFullFrameContained() {
        let visible = CGRect(x: -100, y: 50, width: 1000, height: 800)
        for x in [-200, 300, 1000] as [CGFloat] {
            for y in [-100, 300, 900] as [CGFloat] {
                let captured = DocumentWindowPlacement(sourceFrame: CGRect(x: x, y: y, width: 500, height: 300),
                                                        screenID: 1, capturedVisibleFrame: nil)
                let frame = captured.frame(defaultSize: CGSize(width: 400, height: 250),
                                           screens: [.init(id: 1, visibleFrame: visible)])
                #expect(visible.contains(frame))
                #expect(frame.minX == min(max(x + 24, -100), 500))
                #expect(frame.minY == min(max(y + 300 - 24 - 250, 50), 600))
            }
        }
    }

    @Test func invalidGeometryAndAbsentDisplaysHaveFiniteFallbacks() {
        let valid = CGRect(x: 10, y: 20, width: 1000, height: 800)
        let invalid = [CGRect.zero, CGRect(x: 0, y: 0, width: -1, height: 20),
                       CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100),
                       CGRect(x: 0, y: CGFloat.infinity, width: 100, height: 100),
                       CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 100),
                       CGRect(x: CGFloat.greatestFiniteMagnitude, y: 0,
                              width: CGFloat.greatestFiniteMagnitude, height: 100)]
        for bad in invalid {
            #expect(!DocumentWindowPlacement.isUsable(bad))
            let captured = DocumentWindowPlacement(sourceFrame: bad, screenID: 2, capturedVisibleFrame: bad)
            let screens: [DocumentWindowPlacement.Screen] = [.init(id: 2, visibleFrame: bad), .init(id: 1, visibleFrame: valid)]
            #expect(captured.selectedScreen(in: screens)?.id == 1)
            #expect(captured.frame(defaultSize: CGSize(width: 900, height: 742), screens: screens)
                    == CGRect(x: 60, y: 49, width: 900, height: 742))
            #expect(captured.frame(defaultSize: CGSize(width: 900, height: 742), screens: [])
                    == CGRect(x: 0, y: 0, width: 900, height: 742))
            #expect(captured.frame(defaultSize: CGSize(width: CGFloat.nan, height: -1), screens: [])
                    == CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let missing = DocumentWindowPlacement(sourceFrame: nil, screenID: nil, capturedVisibleFrame: valid)
        #expect(missing.frame(defaultSize: CGSize(width: 900, height: 742), screens: [])
                == CGRect(x: 60, y: 49, width: 900, height: 742))
    }

    @Test func scopedMinimumCapsConvertedContentWithoutChangingLegacyDefault() {
        // Synthetic actual-conversion outputs; the production caller uses contentRect(forFrameRect:).
        for content in [CGSize(width: 400, height: 258), CGSize(width: 900, height: 720),
                        CGSize(width: 200, height: 600), CGSize(width: 1000, height: 100), .zero] {
            let minimum = DocumentWindowPlacement.contentMinimum(available: content)
            #expect(minimum.width <= content.width && minimum.height <= content.height)
            #expect(minimum.width == min(480, content.width) && minimum.height == min(320, content.height))
        }
        #expect(DocumentWindowPlacement.readerMinimum == CGSize(width: 480, height: 320))
        #expect(DocumentWindowPlacement.contentMinimum(available: CGSize(width: CGFloat.infinity, height: -1)) == .zero)
    }
}
