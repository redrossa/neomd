import CoreGraphics
import Foundation
import Testing
@testable import NeoMD

struct AlertCueTests {
    private struct Vector: Decodable {
        let id: String
        let markdown: String
        let expected_alert_types: [String]
    }

    @Test func allApprovedAlertVectors() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("docs/fixtures/m1-13-cues/alert-cases.json"))
        let vectors = try JSONDecoder().decode([Vector].self, from: data)
        #expect(vectors.count == 31)
        for vector in vectors {
            let document = MarkdownBlockRenderer.render(from: vector.markdown)
            #expect(document.nodes.compactMap { $0.kind.alert?.rawValue } == vector.expected_alert_types, "\(vector.id)")
        }
    }

    @Test func markerOnlyAlertsAndMultiblockBodiesKeepTheirArena() throws {
        let empty = MarkdownBlockRenderer.render(from: "> [!IMPORTANT]\r")
        let alert = try #require(empty.roots.first)
        #expect(alert.kind == .alert(.important) && !alert.isLeaf && alert.childIDs.isEmpty)
        let document = MarkdownBlockRenderer.render(from: "> [!NOTE]\n> Body :smile: `#FFFFFF`.\n>\n> - [x] Done\n>\n> > [!WARNING]\n> > Ordinary nested quote.\n>\n> ## :smile: heading\n>\n> ```\n> literal\n> ```")
        #expect(document.nodes.compactMap { $0.kind.alert }.count == 1)
        #expect(document.nodes.contains { $0.kind == .blockQuote })
        #expect(document.nodes.contains { $0.task == .complete })
        #expect(document.nodes.contains { String($0.text.characters) == "Body 😄 #FFFFFF." })
        #expect(!document.nodes.contains { String($0.text.characters).contains("[!NOTE]") })
        #expect(document.nodes.contains { String($0.text.characters).contains("[!WARNING]") })
        #expect(document.nodes.map(\.id) == Array(document.nodes.indices))
        #expect(document.nodes.contains { $0.kind == .heading(level: 2) && String($0.text.characters) == "😄 heading" })
    }

    @Test func measuredHeaderPrecedesBodyAndEmptyAlertHasHeight() throws {
        for scale in [CGFloat(1), 1.5, 2] {
            for source in ["> [!NOTE]", "> [!NOTE]\n> body\n>\n> second"] {
                let document = MarkdownBlockRenderer.render(from: source)
                let geometry = MarkdownContainerGeometry(document: document, rootID: 0, width: 400, scale: scale)
                let measurements = geometry.entries.map { _ in
                    MarkdownContainerGeometry.Measurement(size: CGSize(width: 350, height: 20 * scale), baseline: 15 * scale)
                }
                let result = geometry.place(measurements)
                #expect(result.size.height >= 20 * scale)
                #expect(result.alertBars.count == 1 && result.quoteBars.isEmpty)
                #expect(result.alertBars[0].rect.height == result.size.height)
                if result.frames.count > 1 {
                    #expect(result.frames[1].minY >= result.frames[0].maxY + 8 * scale)
                }
                #expect(result.operations < document.nodes.count * 12)
            }
        }
    }
}
