import CMarkGFM
import Foundation

/// The entire adapter is parser-local. Iterative walks copy owned Swift values;
/// definition and occurrence pointers are identities only while the document lives.
nonisolated final class CMarkBlockAdapter {
    private struct Draft {
        var kind: MarkdownBlock.Kind
        var text = AttributedString()
        var anchors: [String] = []
        var children: [Int] = []
        var task: MarkdownTaskState?
        var node: OpaquePointer?
    }

    private let document: CMarkDocument
    private let documentURL: URL?
    private let metadata: MarkdownFrontMatter.Content?
    private var notes: [OpaquePointer] = []
    private var ordinals: [OpaquePointer: Int] = [:]
    private var occurrences: [OpaquePointer] = []
    private var references: [OpaquePointer: [OpaquePointer]] = [:]
    private var noteAnchors: [OpaquePointer: String] = [:]
    private var referenceAnchors: [OpaquePointer: String] = [:]
    private var drafts: [Draft] = []
    private var roots: [Int] = []
    private var taskDescriptions: Set<Int> = []
    private var tableCells: Set<Int> = []
    private var listOrdinals: [OpaquePointer: Int] = [:]
    private var alertMarkerNodes: [OpaquePointer: Int] = [:]
    private var filteredHTMLBlocks: [OpaquePointer: String] = [:]

    init(document: CMarkDocument, documentURL: URL? = nil, metadata: MarkdownFrontMatter.Content? = nil) {
        self.document = document
        self.documentURL = documentURL
        self.metadata = metadata
    }

    func render() -> MarkdownRenderDocument {
        if let metadata {
            append(Draft(kind: .metadata(metadata), text: AttributedString(metadata.plainText)), parent: nil)
        }
        discoverFootnotes()
        appendBlocks(CMarkDocument.children(document.root).filter {
            CMarkDocument.typeName($0) != "footnote_definition"
        }, parent: nil)
        for note in notes {
            let index = append(Draft(kind: .footnote(ordinal: ordinals[note]!), node: note), parent: nil)
            appendBlocks(CMarkDocument.children(note), parent: index)
        }
        prepareHTMLBlocks()
        var slugger = MarkdownAnchorSlugger()
        for index in drafts.indices {
            guard let node = drafts[index].node, drafts[index].children.isEmpty else { continue }
            let rendered = leaf(node)
            drafts[index].text = rendered.text
            drafts[index].anchors = rendered.anchors
            if case .heading = drafts[index].kind {
                drafts[index].anchors.insert(slugger.slug(for: rendered.text), at: 0)
            }
        }
        allocateAnchors()
        // Re-render using the exact allocations. Never reconstruct a generated URL.
        for index in drafts.indices {
            guard let node = drafts[index].node else { continue }
            if case .footnote = drafts[index].kind {
                drafts[index].anchors.append(noteAnchors[node]!)
            } else if drafts[index].children.isEmpty {
                drafts[index].text = leaf(node).text
                drafts[index].anchors.append(contentsOf: eligibleReferences(in: [node]).compactMap { referenceAnchors[$0] })
            }
        }
        appendReturns()
        return materialize()
    }

    private func discoverFootnotes() {
        let body = CMarkDocument.children(document.root).filter { CMarkDocument.typeName($0) != "footnote_definition" }
        var queue = eligibleReferences(in: body)
        var cursor = 0
        while cursor < queue.count {
            let occurrence = queue[cursor]
            cursor += 1
            guard let definition = cmark_node_parent_footnote_def(occurrence) else { continue }
            occurrences.append(occurrence)
            references[definition, default: []].append(occurrence)
            if ordinals[definition] == nil {
                notes.append(definition)
                ordinals[definition] = notes.count
                queue.append(contentsOf: eligibleReferences(in: CMarkDocument.children(definition)))
            }
        }
    }

    private func eligibleReferences(in nodes: [OpaquePointer]) -> [OpaquePointer] {
        var result: [OpaquePointer] = []
        var stack = Array(nodes.reversed())
        while let node = stack.popLast() {
            let type = CMarkDocument.typeName(node)
            if type == "link" || type == "image" { continue }
            if type == "footnote_reference" { result.append(node) }
            else { stack.append(contentsOf: CMarkDocument.children(node).reversed()) }
        }
        return result
    }

    private func allocateAnchors() {
        var candidates: [(OpaquePointer, Bool, String)] = []
        for note in notes {
            candidates.append((note, true, "fn-" + CMarkDocument.literal(note)))
        }
        var counts: [OpaquePointer: Int] = [:]
        for occurrence in occurrences {
            guard let note = cmark_node_parent_footnote_def(occurrence) else { continue }
            counts[note, default: 0] += 1
            let count = counts[note]!
            candidates.append((occurrence, false, "fnref-" + CMarkDocument.literal(note) + (count == 1 ? "" : "-\(count)")))
        }
        var allocator = MarkdownGeneratedAnchorAllocator(
            authored: drafts.flatMap(\.anchors), preferred: candidates.map { $0.2 }
        )
        for (identity, isNote, preferred) in candidates {
            let allocated = allocator.allocate(preferred)
            if isNote { noteAnchors[identity] = allocated }
            else { referenceAnchors[identity] = allocated }
        }
    }

    @discardableResult
    private func append(_ draft: Draft, parent: Int?) -> Int {
        let index = drafts.count
        drafts.append(draft)
        if let parent {
            if drafts[parent].task != nil, drafts[parent].children.isEmpty, draft.kind == .paragraph {
                taskDescriptions.insert(index)
            }
            drafts[parent].children.append(index)
        }
        else { roots.append(index) }
        return index
    }

    private func appendBlocks(_ nodes: [OpaquePointer], parent: Int?) {
        var stack = nodes.reversed().map { ($0, parent, 0) }
        while let (node, parent, depth) = stack.popLast() {
            let type = CMarkDocument.typeName(node)
            let children = CMarkDocument.children(node)
            var childParent = parent
            var childDepth = depth
            switch type {
            case "table":
                appendTable(node, rows: children, parent: parent)
                continue
            case "block_quote":
                var kind = MarkdownBlock.Kind.blockQuote
                if let (alert, paragraph, count) = document.alert(node) {
                    kind = .alert(alert)
                    alertMarkerNodes[paragraph] = count
                }
                childParent = append(Draft(kind: kind, node: node), parent: parent)
            case "item", "tasklist":
                childDepth += 1
                let list = cmark_node_parent(node)!
                let ordinal = listOrdinals[list] ?? Int(cmark_node_get_list_start(list))
                listOrdinals[list] = ordinal + 1
                let marker = cmark_node_get_list_type(list) == CMARK_ORDERED_LIST
                    ? "\(ordinal)." : MarkdownBlockRenderer.unorderedMarker(depth: childDepth)
                let task: MarkdownTaskState? = type == "tasklist"
                    ? (cmark_gfm_extensions_get_tasklist_item_checked(node) ? .complete : .incomplete) : nil
                childParent = append(Draft(kind: .listItem(marker: marker, depth: childDepth), task: task, node: node), parent: parent)
                if task != nil, children.isEmpty {
                    append(Draft(kind: .paragraph), parent: childParent)
                }
            case "paragraph", "heading", "code_block", "html_block", "thematic_break", "table_cell", "custom_block":
                let kind: MarkdownBlock.Kind
                switch type {
                case "heading": kind = .heading(level: min(6, max(1, Int(cmark_node_get_heading_level(node)))))
                case "code_block":
                    let hint = cmark_node_get_fence_info(node).map { String(cString: $0) } ?? ""
                    kind = .codeBlock(language: hint.split(whereSeparator: \.isWhitespace).first.map { $0.lowercased() })
                case "thematic_break": kind = .thematicBreak
                default: kind = .paragraph
                }
                append(Draft(kind: kind, node: node), parent: parent)
                continue
            case "footnote_definition": continue
            default: break
            }
            stack.append(contentsOf: children.reversed().map { ($0, childParent, childDepth) })
        }
    }

    /// Copies the parser's own column/alignment/header values while C ownership is
    /// live, then appends the parser-produced cells in row-major order. Cells are
    /// ordinary attributed leaves of the table; their nodes are never revisited by
    /// the block walk, and empty cells are deliberately retained.
    private func appendTable(_ node: OpaquePointer, rows: [OpaquePointer], parent: Int?) {
        let count = Int(cmark_gfm_extensions_get_table_columns(node))
        let values = cmark_gfm_extensions_get_table_alignments(node)
        let alignments = (0..<count).map { column in
            MarkdownTableStructure.Alignment(cmarkValue: values?[column] ?? 0)
        }
        // The table itself never owns an inline payload or parser leaf pointer.
        let table = append(Draft(kind: .table(.init(alignments: alignments, rows: []))), parent: parent)
        var descriptors: [MarkdownTableStructure.Row] = []
        for row in rows {
            let start = drafts[table].children.count
            for cell in CMarkDocument.children(row) {
                tableCells.insert(append(Draft(kind: .paragraph, node: cell), parent: table))
            }
            descriptors.append(.init(isHeader: cmark_gfm_extensions_get_table_row_is_header(row) != 0,
                                     cells: start..<drafts[table].children.count))
        }
        drafts[table].kind = .table(.init(alignments: alignments, rows: descriptors))
    }

    private func prepareHTMLBlocks() {
        var comments = MarkdownHTMLComments()
        var previousParent: OpaquePointer?
        for draft in drafts where draft.children.isEmpty {
            guard let node = draft.node else { continue }
            if CMarkDocument.typeName(node) == "html_block" {
                let parent = cmark_node_parent(node)
                if parent != previousParent { comments = MarkdownHTMLComments() }
                previousParent = parent
                filteredHTMLBlocks[node] = comments.filter(CMarkDocument.literal(node), inline: false).map(\.text).joined()
            } else {
                comments = MarkdownHTMLComments()
                previousParent = nil
            }
        }
    }

    private func leaf(_ node: OpaquePointer) -> (text: AttributedString, anchors: [String]) {
        let type = CMarkDocument.typeName(node)
        if type == "code_block" {
            var text = AttributedString(CMarkDocument.literal(node))
            let hint = cmark_node_get_fence_info(node).map { String(cString: $0) }
            if let language = CodeLanguage(infoString: hint) {
                text = CodeSyntaxHighlighter.highlight(text, language: language)
            }
            return (text, [])
        }
        if type == "html_block" {
            if let picture = MarkdownPictureParser.parse(CMarkDocument.literal(node), documentURL: documentURL) {
                var text = AttributedString(picture.alt.isEmpty ? MarkdownPictureParser.emptyAltCarrier : picture.alt)
                text.markdownImage = picture.image
                text.imageURL = picture.image.source
                return (text, [])
            }
            var text = AttributedString(filteredHTMLBlocks[node] ?? CMarkDocument.literal(node))
            text.inlinePresentationIntent = .blockHTML
            return (MarkdownBlockRenderer.trimmed(text, keepingIndentation: false), [])
        }
        if type == "thematic_break" { return (AttributedString(), []) }
        let children = CMarkDocument.children(node).dropFirst(alertMarkerNodes[node] ?? 0)
        let styled = MarkdownBlockRenderer.inlineHTML(inline(Array(children)))
        return (MarkdownBlockRenderer.trimmed(styled.text, keepingIndentation: false), styled.anchors)
    }

    private func inline(_ nodes: [OpaquePointer]) -> AttributedString {
        var result = AttributedString()
        var comments = MarkdownHTMLComments()
        var tokenID = 0
        var stack = nodes.reversed().map { ($0, AttributeContainer(), false, false, Optional<Int>.none) }
        while let (node, inherited, ineligible, imageAlternative, imageStart) = stack.popLast() {
            if let imageStart {
                if result.unicodeScalars.count == imageStart {
                    result.append(AttributedString(MarkdownPictureParser.emptyAltCarrier, attributes: inherited))
                }
                continue
            }
            let type = CMarkDocument.typeName(node)
            var attributes = inherited
            var literal: String?
            var blocked = ineligible
            var imageBlocked = imageAlternative
            var intent = attributes.inlinePresentationIntent ?? []
            switch type {
            case "custom_inline": literal = CMarkEmojiExtension.text(node, imageAlternative: imageAlternative)
            case "text": literal = CMarkDocument.literal(node)
            case "softbreak": literal = " "; intent.insert(.softBreak)
            case "linebreak": literal = "\n"; intent.insert(.lineBreak)
            case "code":
                literal = CMarkDocument.literal(node)
                intent.insert(.code)
                if !imageAlternative { attributes.markdownColorReference = literal.flatMap(MarkdownColorReference.parse) }
            case "html_inline":
                for piece in comments.filter(CMarkDocument.literal(node), inline: true) {
                    var pieceAttributes = attributes
                    var pieceIntent = intent
                    if piece.eligibleTag { pieceIntent.insert(.inlineHTML) }
                    pieceAttributes.inlinePresentationIntent = pieceIntent.isEmpty ? nil : pieceIntent
                    pieceAttributes[MarkdownHTMLTokenAttribute.self] = tokenID
                    tokenID += 1
                    result.append(AttributedString(piece.text, attributes: pieceAttributes))
                }
                continue
            case "emph": intent.insert(.emphasized)
            case "strong": intent.insert(.stronglyEmphasized)
            case "strikethrough": intent.insert(.strikethrough)
            case "link", "image":
                blocked = true
                imageBlocked = imageBlocked || type == "image"
                let destination = cmark_node_get_url(node).map { String(cString: $0) } ?? ""
                if !destination.isEmpty, let url = URL(string: destination) {
                    if type == "link" { attributes.link = url }
                    else {
                        attributes.imageURL = documentURL.flatMap {
                            DocumentLocalPath.resolve(url, relativeTo: $0)?.fileURL
                        } ?? url
                        attributes.markdownImage = MarkdownImage(source: attributes.imageURL, lightSource: nil, darkSource: nil,
                            occurrence: "\(cmark_node_get_start_line(node)):\(cmark_node_get_start_column(node))")
                        if CMarkDocument.children(node).isEmpty { literal = MarkdownPictureParser.emptyAltCarrier }
                    }
                }
            case "footnote_reference":
                if !ineligible, let note = cmark_node_parent_footnote_def(node), let ordinal = ordinals[note] {
                    literal = String(ordinal)
                    attributes.markdownInlineStyle = .superscriptText
                    attributes.markdownGeneratedReference = .footnoteReference
                    if let anchor = noteAnchors[note] { attributes.link = MarkdownGeneratedAnchorAllocator.url(for: anchor) }
                } else {
                    let spelling = cmark_node_get_user_data(node).map { String(cString: $0.assumingMemoryBound(to: CChar.self)) }
                        ?? CMarkDocument.literal(node)
                    literal = "[^\(spelling)]"
                }
            default: break
            }
            attributes.inlinePresentationIntent = intent.isEmpty ? nil : intent
            if let literal { result.append(AttributedString(literal, attributes: attributes)) }
            else {
                if type == "image", attributes.markdownImage != nil {
                    stack.append((node, attributes, blocked, imageBlocked, result.unicodeScalars.count))
                }
                stack.append(contentsOf: CMarkDocument.children(node).reversed().map { ($0, attributes, blocked, imageBlocked, nil) })
            }
        }
        return result
    }

    private func appendReturns() {
        for root in roots {
            guard case .footnote = drafts[root].kind, let note = drafts[root].node else { continue }
            var returns = AttributedString()
            for (index, occurrence) in references[note, default: []].enumerated() {
                if !returns.characters.isEmpty { returns.append(AttributedString(" ")) }
                var link = AttributedString(index == 0 ? "↩" : "↩ \(index + 1)")
                link.link = MarkdownGeneratedAnchorAllocator.url(for: referenceAnchors[occurrence]!)
                link.markdownGeneratedReference = .footnoteReturn
                returns.append(link)
            }
            if let last = drafts[root].children.last, drafts[last].kind == .paragraph {
                drafts[last].text.append(AttributedString(" "))
                drafts[last].text.append(returns)
            } else {
                append(Draft(kind: .paragraph, text: returns), parent: root)
            }
        }
    }

    private func materialize() -> MarkdownRenderDocument {
        // Remove empty containers/leaves before assigning contiguous pre-order IDs.
        var keep = Set<Int>()
        for index in drafts.indices.reversed() {
            let draft = drafts[index]
            let container: Bool
            switch draft.kind {
            case .blockQuote, .listItem, .footnote, .alert, .table: container = true
            default: container = false
            }
            if container {
                if draft.kind.alert != nil || draft.children.contains(where: keep.contains) { keep.insert(index) }
            } else if !draft.text.characters.isEmpty || draft.kind == .thematicBreak ||
                        (draft.node == nil) || taskDescriptions.contains(index) || tableCells.contains(index) {
                keep.insert(index)
            }
        }
        var order: [Int] = []
        var pending: [String] = []
        var stack = Array(roots.reversed())
        while let index = stack.popLast() {
            if keep.contains(index) {
                drafts[index].anchors.insert(contentsOf: pending, at: 0)
                pending.removeAll()
                order.append(index)
            } else { pending.append(contentsOf: drafts[index].anchors) }
            stack.append(contentsOf: drafts[index].children.reversed())
        }
        if !pending.isEmpty {
            let index = append(Draft(kind: .anchor, anchors: pending), parent: nil)
            keep.insert(index)
            order.append(index)
        }
        let ids = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
        var parents = [Int?](repeating: nil, count: order.count)
        for index in order {
            for child in drafts[index].children {
                if let childID = ids[child] { parents[childID] = ids[index] }
            }
        }
        let nodes = order.enumerated().map { id, index in
            let draft = drafts[index]
            return MarkdownBlock(id: id, kind: draft.kind, text: draft.text,
                childIDs: draft.children.compactMap { ids[$0] }, parentID: parents[id],
                task: draft.task, anchors: draft.anchors)
        }
        return MarkdownRenderDocument(nodes: nodes, rootIDs: roots.compactMap { ids[$0] })
    }

}
