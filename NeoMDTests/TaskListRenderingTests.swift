import Foundation
import SwiftUI
import Testing
@testable import NeoMD

struct TaskListRenderingTests {
    @Test(arguments: ["- [ ] Open", "- [x] Open", "- [X] Open", "+ [x] Open", "* [ ] Open"])
    func basicMarkers(_ source: String) {
        let document = MarkdownBlockRenderer.render(from: source)
        let item = document.roots[0]
        #expect(item.task == (source.contains("[ ]") ? .incomplete : .complete))
        #expect(String(document[item.childIDs[0]].text.characters) == "Open")
    }

    @Test func hierarchyIdentityAndOrdinals() {
        let document = MarkdownBlockRenderer.render(from: "- [ ] Parent\n  - [x] Child\n    - [X] Grand")
        let parent = document.roots[0]
        let child = document[parent.childIDs[1]]
        let grand = document[child.childIDs[1]]
        #expect(parent.task == .incomplete)
        #expect(child.task == .complete)
        #expect(grand.task == .complete)
        #expect(document.leaves(in: parent.id).map { String($0.text.characters) } == ["Parent", "Child", "Grand"])
        #expect(document.leaves(in: parent.id).map(\.id) == [1, 3, 5])
        #expect(document.lazyRootIDs == [0, 0, 0, 0, 0, 0])
        let ordered = MarkdownBlockRenderer.render(from: "5. [x] a\n6. [ ] b").roots
        #expect(ordered.map(\.kind) == [.listItem(marker: "5.", depth: 1), .listItem(marker: "6.", depth: 1)])
        #expect(ordered.map(\.task) == [.complete, .incomplete])
        let quoted = MarkdownBlockRenderer.render(from: "> - [ ] q")
        let quote = quoted.roots[0]
        #expect(quote.kind == .blockQuote)
        #expect(quoted[quote.childIDs[0]].task == .incomplete)
    }

    @Test func attributedDescriptionsSurvive() {
        let document = MarkdownBlockRenderer.render(from: "- [x] Ship **v1** with [docs](https://example.com) and `code`")
        let item = document.roots[0]
        let text = document[item.childIDs[0]].text
        #expect(String(text.characters) == "Ship v1 with docs and code")
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
        #expect(text.runs.contains { $0.link == URL(string: "https://example.com") })
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.code) == true })
        let presented = ReaderTheme().presentationText(for: text)
        #expect(presented.runs.contains { $0.link != nil && $0.underlineStyle == .single })
        let script = MarkdownBlockRenderer.render(from: "- [ ] *Pending* <sub>sub</sub>").leaves[0].text
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
        let document = MarkdownBlockRenderer.render(from: source)
        for block in document.nodes { #expect(block.task == nil) }
        #expect(document.leaves.contains { String($0.text.characters).contains("[") })
    }

    @Test func onlyFirstDirectParagraphOwnsMarker() {
        let document = MarkdownBlockRenderer.render(from: "- Ordinary first\n\n  [ ] second\n\n  - [x] nested")
        let item = document.roots[0]
        #expect(item.task == nil)
        #expect(String(document[item.childIDs[1]].text.characters) == "[ ] second")
        #expect(document[item.childIDs[2]].task == .complete)
        let taskDocument = MarkdownBlockRenderer.render(from: "- [x] first\n\n  [ ] second")
        let task = taskDocument.roots[0]
        #expect(task.task == .complete)
        #expect(String(taskDocument[task.childIDs[1]].text.characters) == "[ ] second")
    }

    @Test(arguments: [
        ("- [ ]", ""), ("- [x]", ""), ("- [ ]\tTabbed", "Tabbed"),
        ("-   [x]   Spaced", "Spaced"), ("- [ ] `  x  `", " x "),
        ("- [x] `   `", "   "), ("- [ ] `  x  ` after", " x  after")
    ])
    func separatorsPreserveExactDescriptionScalars(_ source: String, _ expected: String) {
        let document = MarkdownBlockRenderer.render(from: source)
        let item = document.roots[0]
        #expect(item.task != nil)
        #expect(Array(document[item.childIDs[0]].text.unicodeScalars) == Array(expected.unicodeScalars))
    }

    @Test func softContinuationSurvives() {
        let document = MarkdownBlockRenderer.render(from: "- [ ] one\n  two")
        let item = document.roots[0]
        #expect(String(document[item.childIDs[0]].text.characters) == "one two")
        #expect(document[item.childIDs[0]].text.runs.contains { $0.inlinePresentationIntent?.contains(.softBreak) == true })
    }
}
