import SwiftUI
import Testing
@testable import NeoMD

@MainActor
struct DocumentFocusEffectTests {
    @Test func enabledIncomingPolicyIsRestoredForOrdinaryControl() throws {
        try checkBoundary(incoming: true, nested: false)
    }

    @Test func disabledIncomingPolicyIsNotForcedOnForOrdinaryControl() throws {
        try checkBoundary(incoming: false, nested: false)
    }

    @Test func nestedTargetsRemainQuietWithEnabledControlPolicy() throws {
        try checkBoundary(incoming: true, nested: true)
    }

    @Test func nestedTargetsPreserveDisabledControlPolicy() throws {
        try checkBoundary(incoming: false, nested: true)
    }

    private func checkBoundary(incoming: Bool, nested: Bool) throws {
        let observations = FocusEffectObservations()
        let renderer = ImageRenderer(content:
            DocumentFocusEffect { inherited in
                VStack {
                    FocusEffectProbe(name: "outerTarget", observations: observations)
                    Group {
                        if nested {
                            DocumentFocusEffect { innerInherited in
                                VStack {
                                    FocusEffectProbe(name: "innerTarget", observations: observations)
                                    control(observations)
                                        .environment(\.isFocusEffectEnabled, innerInherited)
                                }
                                .focusable(true, interactions: .edit)
                            }
                        } else {
                            control(observations)
                        }
                    }
                    .environment(\.isFocusEffectEnabled, inherited)
                }
                .focusable(true, interactions: .edit)
            }
            .environment(\.isFocusEffectEnabled, incoming)
            .frame(width: 200, height: 100)
        )
        // Passive SwiftUI environment evaluation only: no host/window or action.
        // The probe measures the Button boundary's incoming policy, not its
        // native style/ring, which requires deferred interactive validation.
        _ = try #require(renderer.cgImage)
        #expect(observations.values["outerTarget"] == [false])
        #expect(observations.values["control"] == [incoming])
        if nested {
            #expect(observations.values["innerTarget"] == [false])
        } else {
            #expect(observations.values["innerTarget"] == nil)
        }
    }

    private func control(_ observations: FocusEffectObservations) -> some View {
        Button("Ordinary control") { Issue.record("Passive test must not activate a control") }
            .background(FocusEffectProbe(name: "control", observations: observations))
    }

    @Test func fixtureReadRenderPreservesBytesModificationTimeAndLinkCandidates() throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/m1-p5-focus-outlines/focus.md")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeoMD-focus-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let copy = directory.appendingPathComponent("focus.md")
        try FileManager.default.copyItem(at: fixture, to: copy)
        let before = try Data(contentsOf: copy)
        let modificationTime = try copy.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let source = try MarkdownTextDecoder.text(from: Data(contentsOf: copy))
        let document = MarkdownBlockRenderer.render(from: source)
        let candidates = DocumentReaderTraversal.candidates(in: document)
        #expect(!document.roots.isEmpty)
        let linkIDs = document.leafIDs.filter { id in
            document[id].text.runs.contains { $0.link != nil }
        }
        #expect(!linkIDs.isEmpty)
        for id in linkIDs {
            #expect(candidates.contains(.links(id)))
            #expect(candidates.contains(.text(id)))
        }
        #expect(candidates.contains { if case .codeBlock = $0 { true } else { false } })
        #expect(try Data(contentsOf: copy) == before)
        #expect(modificationTime != nil)
        #expect(try copy.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == modificationTime)
    }
}

@MainActor
private final class FocusEffectObservations {
    var values: [String: Set<Bool>] = [:]

    func record(_ name: String, _ value: Bool) {
        values[name, default: []].insert(value)
    }
}

private struct FocusEffectProbe: View {
    @Environment(\.isFocusEffectEnabled) private var enabled
    let name: String
    let observations: FocusEffectObservations

    var body: some View {
        observations.record(name, enabled)
        return Text(name)
    }
}
