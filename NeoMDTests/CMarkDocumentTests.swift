import CMarkGFM
import Testing
@testable import NeoMD

struct CMarkDocumentTests {
    @Test(arguments: [
        "- [ ] Open", "- [x] Open", "- [X] Open", "+ [x] Open", "* [ ] Open",
        "5. [x] a", "6. [ ] b", "> - [ ] q", "- [ ] Parent",
        "- parent\n  - [x] Child", "- parent\n  - child\n    - [X] Grand",
        "- [ ]", "- [x]", "- [ ]\tTabbed", "-   [x]   Spaced", "- [ ] `  x  `",
        "- Ordinary first\n\n  [ ] second\n\n  - [x] nested"
    ])
    func taskParityPositive(_ source: String) {
        let document = CMarkDocument(markdown: source)
        #expect(nodes(document.root).filter { CMarkDocument.typeName($0) == "tasklist" }.count == 1)
    }

    @Test(arguments: [
        "- [ ]no space", "- [ ]`  x  `", "- [x]<ins> a</ins>", "- [] a",
        "- \\[ \\] a", "- `[ ]` a", "- **[x] bold**", "- text [ ] a",
        "- [[x]](https://example.com) a", "- Ordinary first\n\n  [ ] second",
        "- *[ ]* a", "- ~~[x]~~ a", "- > [ ] q"
    ])
    func taskParityNegative(_ source: String) {
        let document = CMarkDocument(markdown: source)
        #expect(!nodes(document.root).contains { CMarkDocument.typeName($0) == "tasklist" })
    }

    @Test func retainsOriginalReferenceSpellingAndDefinitionIdentity() throws {
        let document = CMarkDocument(markdown:
            "[a[^N] b[^n]](u) ![c[^É] d[^é]](image)\n\n[^n]: note\n[^é]: accent")
        let references = nodes(document.root).filter {
            CMarkDocument.typeName($0) == "footnote_reference"
        }
        try #require(references.count == 4)
        let spelling = try references.map {
            let data = try #require(cmark_node_get_user_data($0))
            return String(cString: data.assumingMemoryBound(to: CChar.self))
        }
        #expect(spelling == ["N", "n", "É", "é"])
        #expect(cmark_node_parent_footnote_def(references[0]) == cmark_node_parent_footnote_def(references[1]))
        #expect(cmark_node_parent_footnote_def(references[2]) == cmark_node_parent_footnote_def(references[3]))
    }

    private func nodes(_ root: OpaquePointer) -> [OpaquePointer] {
        var stack = [root]
        var result: [OpaquePointer] = []
        while let node = stack.popLast() {
            result.append(node)
            stack.append(contentsOf: CMarkDocument.children(node).reversed())
        }
        return result
    }

    @Test func parserOwnershipAndModuleImport() {
        for _ in 0..<100 {
            let document = CMarkDocument(markdown: "# x")
            let headings = CMarkDocument.children(document.root)
            #expect(headings.count == 1)
            #expect(CMarkDocument.typeName(headings[0]) == "heading")
            let text = CMarkDocument.children(headings[0])
            #expect(CMarkDocument.literal(text[0]) == "x")
        }
    }
}
