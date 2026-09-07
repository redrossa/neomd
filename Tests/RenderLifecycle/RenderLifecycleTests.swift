import Foundation
import XCTest

/// Compiles the real rendering sources in an unhosted bundle. The outer script
/// selects exactly one method/depth in each process and checks the result bundle.
nonisolated final class RenderLifecycleTests: XCTestCase {
    private var depth: Int {
        Int(ProcessInfo.processInfo.environment["NEOMD_LIFECYCLE_DEPTH"] ?? "1000")!
    }

    private static func quote(_ depth: Int) -> MarkdownRenderDocument {
        MarkdownBlockRenderer.render(from: String(repeating: "> ", count: depth) + "text\n")
    }

    private static func validate(_ document: MarkdownRenderDocument, depth: Int) {
        XCTAssertEqual(document.nodes.count, depth + 1)
        XCTAssertEqual(document.rootIDs, [0])
        XCTAssertEqual(document.leafIDs, [depth])
        XCTAssertEqual(String(document[depth].text.characters), "text")
        XCTAssertEqual(document[depth].kind, .paragraph)
        for node in document.nodes {
            XCTAssertEqual(node.parentID, node.id == 0 ? nil : node.id - 1)
            XCTAssertEqual(node.childIDs, node.id == depth ? [] : [node.id + 1])
            XCTAssertEqual(document.lazyRootIDs[node.id], 0)
            XCTAssertEqual(document.subtreeEnds[node.id], depth + 1)
            XCTAssertEqual(document.firstLeafIDs[node.id], depth)
            XCTAssertEqual(document.lastLeafIDs[node.id], depth)
            if node.id < depth { XCTAssertEqual(node.kind, .blockQuote) }
        }
    }

    private static func renderUseRelease(_ depth: Int) {
        autoreleasepool {
            let document = quote(depth)
            validate(document, depth: depth)
            withExtendedLifetime(document) {}
        }
        // After the scope has released the entire document, not before deinit.
    }

    private func completed() { print("NEOMD_LIFECYCLE_RELEASED depth=\(depth)") }

    func testSynchronousRelease() {
        Self.renderUseRelease(depth)
        completed()
    }

    func testDetachedRelease() async {
        let depth = depth
        await Task.detached { Self.renderUseRelease(depth) }.value
        completed()
    }

    @MainActor func testDetachedReturnMainRelease() async {
        var document: MarkdownRenderDocument? = await Task.detached { [depth] in Self.quote(depth) }.value
        Self.validate(document!, depth: depth)
        document = nil
        completed()
    }

    @MainActor func testCancelledDiscard() async {
        let gate = LifecycleGate()
        let depth = depth
        let parent = Task { @MainActor in
            let document = await Task.detached {
                let result = Self.quote(depth)
                await gate.arriveAndWait()
                return result
            }.value
            Self.validate(document, depth: depth)
            XCTAssertTrue(Task.isCancelled)
            // Matches DocumentReaderView's cancelled completed-result guard.
            guard !Task.isCancelled else { return }
            XCTFail("Cancelled result must not publish")
        }
        await gate.waitUntilArrived()
        parent.cancel()
        await gate.release()
        await parent.value
        completed()
    }

    @MainActor func testReplacementAndAliases() {
        var current: MarkdownRenderDocument? = Self.quote(depth)
        var alias = current
        current = Self.quote(1)
        Self.validate(alias!, depth: depth)
        Self.validate(current!, depth: 1)
        alias = nil
        current = Self.quote(depth)
        alias = current
        current = Self.quote(depth)
        Self.validate(alias!, depth: depth)
        Self.validate(current!, depth: depth)
        current = nil
        alias = nil
        completed()
    }

    func testRepeatedIndependentSnapshots() {
        for _ in 0..<8 { Self.renderUseRelease(depth) }
        completed()
    }

    func testMixedAndAnnotated() {
        autoreleasepool {
            // Practical mixed input: pinned cmark does not recognize list
            // starts at arbitrary quote depth. Deep ownership is tested below.
            let depth = 40
            let quote = String(repeating: "> ", count: depth)
            let document = MarkdownBlockRenderer.render(from: """
            # Hello *café*
            # Hello café
            [jump](#hello-café-1) <a id="custom"></a>text[^note]

            \(quote)- [ ] task
            \(quote)  > nested

            [^note]: note
            """)
            XCTAssertEqual(document.nodes.count, depth + 9)
            XCTAssertEqual(document.nodes.map(\.id), Array(document.nodes.indices))
            XCTAssertEqual(document.anchorTargets["hello-café"], 0)
            XCTAssertEqual(document.anchorTargets["hello-café-1"], 1)
            XCTAssertEqual(document.anchorTargets["custom"], 2)
            XCTAssertEqual(document.anchorTargets["fnref-note"], 2)
            XCTAssertEqual(document.anchorTargets["fn-note"], depth + 7)
            XCTAssertEqual(document.leaves.map { String($0.text.characters) },
                           ["Hello café", "Hello café", "jump text1", "task", "nested", "note ↩"])
            XCTAssertEqual(document[depth + 3].task, .incomplete)
            XCTAssertEqual(document.nodes.filter { $0.kind == .blockQuote }.count, depth + 1)
            XCTAssertEqual(document[depth + 7].kind, .footnote(ordinal: 1))
            for node in document.nodes {
                for child in node.childIDs { XCTAssertEqual(document[child].parentID, node.id) }
                for run in node.text.runs where run.markdownGeneratedReference != nil {
                    let fragment = run.link?.fragment?.removingPercentEncoding
                    XCTAssertNotNil(fragment.flatMap { document.anchorTargets[$0] })
                }
            }
            withExtendedLifetime(document) {}
        }
        autoreleasepool {
            let document = MarkdownBlockRenderer.render(from:
                String(repeating: "> ", count: depth) + "<a id='deep'></a>retained[^n]\n\n[^n]: note")
            XCTAssertEqual(document.nodes.count, depth + 3)
            XCTAssertEqual(document.nodes.map(\.id), Array(document.nodes.indices))
            XCTAssertEqual(document.anchorTargets["deep"], depth)
            XCTAssertEqual(document.anchorTargets["fnref-n"], depth)
            XCTAssertEqual(document.anchorTargets["fn-n"], depth + 1)
            XCTAssertEqual(document.leaves.map { String($0.text.characters) }, ["retained1", "note ↩"])
            XCTAssertEqual(document[depth + 1].kind, .footnote(ordinal: 1))
            withExtendedLifetime(document) {}
        }
        // A deep mixed ownership graph with two adjacent leaves, no ancestor copies.
        autoreleasepool {
            let count = depth
            let nodes = (0..<count).map { id in
                MarkdownBlock(id: id, kind: id.isMultiple(of: 2) ? .blockQuote : .listItem(marker: "•", depth: id + 1),
                    text: "", childIDs: id == count - 1 ? [count, count + 1] : [id + 1],
                    parentID: id == 0 ? nil : id - 1)
            } + [MarkdownBlock(id: count, kind: .paragraph, text: "first", parentID: count - 1),
                 MarkdownBlock(id: count + 1, kind: .paragraph, text: "second", parentID: count - 1)]
            let mixed = MarkdownRenderDocument(nodes: nodes, rootIDs: [0])
            XCTAssertEqual(mixed.leafIDs, [count, count + 1])
            XCTAssertEqual(mixed.firstLeafIDs[0], count)
            XCTAssertEqual(mixed.lastLeafIDs[0], count + 1)
            XCTAssertEqual(mixed.subtreeEnds[0], count + 2)
            withExtendedLifetime(mixed) {}
        }
        completed()
    }

    func testHarnessNegativeControl() {
        // The orchestrator explicitly selects this expected-failure control.
        XCTFail("Intentional failure: outer harness must reject this run")
    }
}

private actor LifecycleGate {
    private var arrived = false
    private var arrival: CheckedContinuation<Void, Never>?
    private var completion: CheckedContinuation<Void, Never>?

    func arriveAndWait() async {
        arrived = true
        arrival?.resume()
        arrival = nil
        await withCheckedContinuation { completion = $0 }
    }

    func waitUntilArrived() async {
        if !arrived { await withCheckedContinuation { arrival = $0 } }
    }

    func release() {
        completion?.resume()
        completion = nil
    }
}
