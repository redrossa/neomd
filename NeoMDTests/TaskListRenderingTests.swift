import Foundation
import SwiftUI
import Testing
@testable import NeoMD

struct TaskListRenderingTests {
    @Test(arguments: ["- [ ] Open", "- [x] Open", "- [X] Open", "+ [x] Open", "* [ ] Open"])
    func basicMarkers(_ source: String) {
        let item = MarkdownBlockRenderer.blocks(from: source)[0]
        #expect(item.task == (source.contains("[ ]") ? .incomplete : .complete))
        #expect(String(item.children[0].text.characters) == "Open")
    }

    @Test func hierarchyIdentityAndOrdinals() {
        let blocks = MarkdownBlockRenderer.blocks(from: "- [ ] Parent\n  - [x] Child\n    - [X] Grand")
        let parent = blocks[0]
        let child = parent.children[1]
        let grand = child.children[1]
        #expect(parent.task == .incomplete)
        #expect(child.task == .complete)
        #expect(grand.task == .complete)
        #expect(parent.leaves.map { String($0.text.characters) } == ["Parent", "Child", "Grand"])
        #expect(parent.leaves.map(\.id) == [1, 3, 5])
        #expect(MarkdownBlock.lazyAncestors(in: blocks) == [0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0])
        let ordered = MarkdownBlockRenderer.blocks(from: "5. [x] a\n6. [ ] b")
        #expect(ordered.map(\.kind) == [.listItem(marker: "5.", depth: 1), .listItem(marker: "6.", depth: 1)])
        #expect(ordered.map(\.task) == [.complete, .incomplete])
        let quote = MarkdownBlockRenderer.blocks(from: "> - [ ] q")[0]
        #expect(quote.kind == .blockQuote)
        #expect(quote.children[0].task == .incomplete)
    }

    @Test func attributedDescriptionsSurvive() {
        let item = MarkdownBlockRenderer.blocks(from: "- [x] Ship **v1** with [docs](https://example.com) and `code`")[0]
        let text = item.children[0].text
        #expect(String(text.characters) == "Ship v1 with docs and code")
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
        #expect(text.runs.contains { $0.link == URL(string: "https://example.com") })
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.code) == true })
        let presented = ReaderTheme().presentationText(for: text)
        #expect(presented.runs.contains { $0.link != nil && $0.underlineStyle == .single })
        let script = MarkdownBlockRenderer.blocks(from: "- [ ] *Pending* <sub>sub</sub>")[0].children[0].text
        #expect(script.runs.contains { $0.markdownInlineStyle == .subscriptText })
        #expect(script.runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true })
    }

    @Test(arguments: [
        "- \\[ \\] a", "- \\[x\\] a", "- `[ ]` a", "- `[x]` a",
        "- [ ]no space", "- [ ]`  x  `", "- [x]<ins> a</ins>", "- [] a", "- text [ ] a", "[ ] outside list",
        "- **[x] bold**", "- *[ ]* a", "- ~~[x]~~ a",
        "- [[x]](https://example.com) a", "- <ins>[x]</ins> a", "- > [ ] q"
    ])
    func literalLookalikes(_ source: String) {
        let blocks = MarkdownBlockRenderer.blocks(from: source)
        func assertLiteral(_ block: MarkdownBlock) {
            #expect(block.task == nil)
            for child in block.children { assertLiteral(child) }
        }
        blocks.forEach(assertLiteral)
        #expect(blocks.flatMap(\.leaves).contains { String($0.text.characters).contains("[") })
    }

    @Test func onlyFirstDirectParagraphOwnsMarker() {
        let item = MarkdownBlockRenderer.blocks(from: "- Ordinary first\n\n  [ ] second\n\n  - [x] nested")[0]
        #expect(item.task == nil)
        #expect(String(item.children[1].text.characters) == "[ ] second")
        #expect(item.children[2].task == .complete)
        let task = MarkdownBlockRenderer.blocks(from: "- [x] first\n\n  [ ] second")[0]
        #expect(task.task == .complete)
        #expect(String(task.children[1].text.characters) == "[ ] second")
    }

    @Test(arguments: [
        ("- [ ]", ""), ("- [x]", ""), ("- [ ]\tTabbed", "Tabbed"),
        ("-   [x]   Spaced", "Spaced"), ("- [ ] `  x  `", " x "),
        ("- [x] `   `", "   "), ("- [ ] `  x  ` after", " x  after")
    ])
    func separatorsPreserveExactDescriptionScalars(_ source: String, _ expected: String) {
        let item = MarkdownBlockRenderer.blocks(from: source)[0]
        #expect(item.task != nil)
        #expect(Array(item.children[0].text.unicodeScalars) == Array(expected.unicodeScalars))
    }

    @Test func softContinuationSurvives() {
        let item = MarkdownBlockRenderer.blocks(from: "- [ ] one\n  two")[0]
        #expect(String(item.children[0].text.characters) == "one two")
        #expect(item.children[0].text.runs.contains { $0.inlinePresentationIntent?.contains(.softBreak) == true })
    }
}
