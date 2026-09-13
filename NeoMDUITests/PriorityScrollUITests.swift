import AppKit
import XCTest

/// Generic XCUI scrolling only. Neither method claims physical trackpad momentum.
final class PriorityScrollUITests: XCTestCase {
    private func require(_ condition: Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) throws {
        guard condition else { throw PriorityInteractionSupport.Failure(description: "\(file):\(line): \(message)") }
    }

    private func unwrap<T>(_ value: T?, _ message: String, file: StaticString = #filePath, line: UInt = #line) throws -> T {
        try require(value != nil, message, file: file, line: line)
        return value!
    }

    @MainActor
    private func prepare(delay: Int? = nil) async throws -> (PriorityInteractionSupport, PriorityInteractionSupport.Window) {
        continueAfterFailure = false
        let support = try PriorityInteractionSupport(test: self)
        addTeardownBlock { @MainActor in try await support.cleanup() }
        try support.launch(delay: delay)
        let reopened = try await position(support, preceding: nil, trial: 0)
        support.record("eventKind=XCUI generic scroll; native phase/momentumPhase/content-height/NSClipView-offset and pending-generation channels unavailable; instrumentation=off. Linked unchanged native glyph displacement is semantic travel, NOT absolute offset. Scrollbar fractions are setup gates/diagnostics only. Owned screenshots require visual inspection, not automated pixel proof or momentum physics.", name: "scroll-evidence-limits")
        return (support, reopened)
    }

    @MainActor
    private func fraction(_ support: PriorityInteractionSupport, _ window: PriorityInteractionSupport.Window) throws -> Double {
        var notes: [String] = []
        defer { support.record(notes.joined(separator: "\n"), name: "raw-scrollbar") }
        let scrolls = try boundedTree(window.ax, &notes).filter {
            support.attribute($0, kAXIdentifierAttribute) as? String == "DocumentReaderScrollView"
                && support.attribute($0, kAXRoleAttribute) as? String == kAXScrollAreaRole
        }
        try require(scrolls.count == 1, "Unique owned reader unavailable")
        let scroll = scrolls[0]
        let bar = try unwrap(support.axElement(support.attribute(scroll, kAXVerticalScrollBarAttribute)), "Vertical scrollbar unavailable")
        let parent = try unwrap(support.axElement(support.attribute(bar, kAXParentAttribute)), "Scrollbar parent unavailable")
        try require(CFEqual(parent, scroll), "Vertical scrollbar escaped reader")
        for name in [kAXRoleAttribute, kAXOrientationAttribute, kAXMinValueAttribute, kAXMaxValueAttribute, kAXValueAttribute] {
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(bar, name as CFString, &value)
            notes.append("bar=\(bar) \(name) error=\(error.rawValue) value=\(String(describing: value)); unavailable is not zero")
        }
        let contents = support.attribute(scroll, kAXContentsAttribute) as? [AXUIElement]
        notes.append("AXContents count=\(String(describing: contents?.count)); NOT full document/offset/range telemetry")
        for content in contents ?? [] {
            let rect = observedRect(content, &notes)
            notes.append("content=\(content) rect=\(String(describing: rect))")
        }
        let value = try unwrap(support.attribute(bar, kAXValueAttribute) as? NSNumber, "Scrollbar value unavailable").doubleValue
        try require(value.isFinite, "Nonfinite scrollbar fraction")
        return value
    }

    @MainActor
    private func reconcile(_ support: PriorityInteractionSupport, _ old: PriorityInteractionSupport.Window, _ new: PriorityInteractionSupport.Window) throws {
        try support.verifyProcess()
        let windows = try support.windows()
        let oldMember = windows.contains { CFEqual($0, old.ax) }
        let newMember = windows.contains { CFEqual($0, new.ax) }
        let equal = CFEqual(old.ax, new.ax)
        support.record("old=\(old.ax) new=\(new.ax) CFEqual=\(equal) oldMember=\(oldMember) newMember=\(newMember) currentWindows=\(windows.count) oldXCUI=\(old.element.frame) newXCUI=\(new.element.frame) key=\(try support.isKey(new))", name: "reopen-identity")
        try require(oldMember && newMember && equal, "Both open results must prove same current owned AX window")
        try support.checkpoint(old, "old-open-current")
        try support.checkpoint(new, "new-open-current")
        let unique = try support.axWindow(document: new.document, frame: new.element.frame)
        try require(CFEqual(unique, new.ax), "New open must match unique current document window")
    }

    @MainActor
    private func observedRect(_ element: AXUIElement, _ notes: inout [String]) -> CGRect? {
        var position: CFTypeRef?, sizeValue: CFTypeRef?
        let pError = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        let sError = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        var point = CGPoint.zero, size = CGSize.zero
        guard pError == .success, sError == .success,
              let position, let sizeValue,
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID(),
              AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            notes.append("rectUnavailable AX=\(element) positionError=\(pError.rawValue) sizeError=\(sError.rawValue) position=\(String(describing: position)) size=\(String(describing: sizeValue))")
            return nil
        }
        guard point.x.isFinite, point.y.isFinite, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else {
            notes.append("nonfinite/empty rectangle AX=\(element) point=\(point) size=\(size)")
            return nil
        }
        return CGRect(origin: point, size: size)
    }

    @MainActor
    private func boundedTree(_ root: AXUIElement, _ notes: inout [String]) throws -> [AXUIElement] {
        var rootPID: pid_t = 0
        try require(AXUIElementGetPid(root, &rootPID) == .success && rootPID > 0, "Invalid owned traversal root")
        var queue = [root], result: [AXUIElement] = []
        while result.count < 4096, let current = queue.popLast() {
            var pid: pid_t = 0
            try require(AXUIElementGetPid(current, &pid) == .success && pid == rootPID, "Traversal element escaped owned root PID")
            result.append(current)
            var children: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(current, kAXChildrenAttribute as CFString, &children)
            if error == .noValue || error == .attributeUnsupported {
                var roleValue: CFTypeRef?
                let roleError = AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleValue)
                try require(roleError == .success, "Childless element role unavailable: \(roleError.rawValue)")
                let role = try unwrap(roleValue as? String, "Childless element role is not a string")
                try require(!role.isEmpty, "Childless element role is empty")
                var advertised = "not queried: noValue means this attribute has no value"
                if error == .attributeUnsupported {
                    var names: CFArray?
                    let namesError = AXUIElementCopyAttributeNames(current, &names)
                    try require(namesError == .success, "Childless attribute names unavailable: \(namesError.rawValue)")
                    let attributes = try unwrap(names as? [String], "Attribute names are not a string array")
                    try require(!attributes.contains(kAXChildrenAttribute), "Unsupported children attribute is nevertheless advertised")
                    advertised = attributes.joined(separator: ",")
                }
                notes.append("emptyChildren error=\(error.rawValue) pid=\(pid) AX=\(current) role=\(role) attributes=\(advertised); no geometry inferred")
                continue
            }
            try require(error == .success, "Incomplete AX traversal childrenError=\(error.rawValue) AX=\(current)")
            let items = try unwrap(children as? [AXUIElement], "AX children unavailable/nonarray on successful read")
            queue += items.reversed()
        }
        notes.append("traversal visited=\(result.count) limit=4096 pending=\(queue.count) boundReached=\(result.count == 4096)")
        try require(queue.isEmpty, "Capped AX traversal; ambiguous evidence")
        return result
    }

    private let initialParagraph = "AMBER is the top sentinel. This is a read-only, local, mixed-height scrolling corpus. End sentinel is an explicit navigation control, not a scrolling trigger. The document contains no images or background network activity."
    private let fifthParagraph = "AMBER P9-FIFTH-ONLY is the top sentinel. This is a read-only, local, mixed-height scrolling corpus. End sentinel is an explicit navigation control, not a scrolling trigger. The document contains no images or background network activity."

    private struct Baseline {
        let clip: CGRect
        let heading: CGRect
        let glyph: CGRect
        var expectedHeading: CGFloat { heading.minY - clip.minY - 32 }
        var expectedGlyph: CGFloat { glyph.minY - clip.minY - 32 }
    }
    private var baseline: Baseline?

    private func agrees(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2
            && abs(a.width - b.width) <= 2 && abs(a.height - b.height) <= 2
    }

    @MainActor
    private func glyph(_ support: PriorityInteractionSupport, _ leaf: AXUIElement, length: Int) throws -> CGRect {
        do {
            let rect = try support.bounds(NSRange(location: 0, length: length), leaf: leaf)
            try require(rect.minX.isFinite && rect.minY.isFinite && rect.width.isFinite && rect.height.isFinite
                        && rect.width > 0 && rect.height > 0, "Nonfinite/empty AX glyph rectangle")
            return rect
        } catch { throw PriorityInteractionSupport.Failure(description: "Required glyph evidence: \(error)") }
    }

    @MainActor
    private func readerTree(_ support: PriorityInteractionSupport, _ window: PriorityInteractionSupport.Window,
                            _ notes: inout [String]) throws -> (CGRect, [AXUIElement]) {
        try support.checkpoint(window, "setup-current-window")
        try require(try support.isKey(window), "Owned reader is not key")
        try require(try support.windows().count == 1, "Expected exactly one owned window")
        let readers = try boundedTree(window.ax, &notes).filter {
            support.attribute($0, kAXIdentifierAttribute) as? String == "DocumentReaderScrollView"
        }
        let query = window.element.scrollViews.matching(identifier: "DocumentReaderScrollView")
        try require(readers.count == 1 && query.count == 1, "Reader missing/ambiguous AX=\(readers.count) XCUI=\(query.count)")
        let clip = query.element.frame
        let native = try unwrap(observedRect(readers[0], &notes), "Reader rectangle unavailable")
        notes.append("readerAX=\(native) readerXCUI=\(clip)")
        try require(agrees(native, clip), "Native/XCUI reader geometry disagrees")
        return (clip, try boundedTree(readers[0], &notes))
    }

    @MainActor
    private func pair(_ support: PriorityInteractionSupport, _ tree: [AXUIElement], paragraph: AXUIElement,
                      notes: inout [String]) throws -> AXUIElement {
        let p = try unwrap(observedRect(paragraph, &notes), "Paragraph rectangle unavailable")
        let leaves = tree.filter {
            let role = support.attribute($0, kAXRoleAttribute) as? String
            return role == "AXHeading" || role == kAXTextAreaRole
        }
        let index = try unwrap(leaves.firstIndex { CFEqual($0, paragraph) }, "Paragraph not in reader")
        try require(index > 0, "Missing immediately preceding heading")
        let heading = leaves[index - 1]
        try require(support.attribute(heading, kAXRoleAttribute) as? String == "AXHeading"
                    && support.attribute(heading, kAXValueAttribute) as? String == "P9 top", "Adjacent leaf is not P9 top")
        let h = try unwrap(observedRect(heading, &notes), "Heading rectangle unavailable")
        let candidates = try leaves.filter { leaf in
            guard support.attribute(leaf, kAXRoleAttribute) as? String == "AXHeading",
                  support.attribute(leaf, kAXValueAttribute) as? String == "P9 top" else { return false }
            let rect = try unwrap(observedRect(leaf, &notes), "Candidate heading rectangle unavailable")
            return abs(p.minY - rect.maxY - 16) <= 2
        }
        notes.append("paragraph=\(p) adjacentHeading=\(h) gap=\(p.minY - h.maxY) pairCount=\(candidates.count)")
        try require(candidates.count == 1 && CFEqual(candidates[0], heading), "No-fit/ambiguous adjacent heading: expected gap16 +/-2")
        return heading
    }

    @MainActor
    private func reacquire(_ support: PriorityInteractionSupport, _ window: PriorityInteractionSupport.Window) throws -> PriorityInteractionSupport.Window {
        let query = support.app.windows.matching(identifier: window.document.lastPathComponent)
        try require(query.count == 1, "Current XCUI document window missing/ambiguous")
        let element = query.element
        let current = PriorityInteractionSupport.Window(element: element,
            ax: try support.axWindow(document: window.document, frame: element.frame), document: window.document)
        try reconcile(support, window, current)
        return current
    }

    @MainActor
    private func position(_ support: PriorityInteractionSupport, preceding: PriorityInteractionSupport.Window?, trial: Int) async throws -> PriorityInteractionSupport.Window {
        let start = ProcessInfo.processInfo.systemUptime
        var actions = 0
        func deadline(_ stage: String) throws {
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            support.record("trial=\(trial) stage=\(stage) elapsed=\(elapsed) actions=\(actions) limitSeconds=10; synchronous calls measured, not preemptible", name: "setup-duration")
            try require(elapsed <= 10 && actions <= 8, "Setup bound exceeded at \(stage): elapsed=\(elapsed) actions=\(actions)")
        }
        defer { support.record("trial=\(trial) total=\(ProcessInfo.processInfo.systemUptime - start) actions=\(actions); fresh URL repeated corpus, not warm lazy reuse", name: "setup-total") }
        if let preceding { try support.checkpoint(preceding, "before-document-replacement") }
        try deadline("before-fixture")
        let url = try support.fixture("m1-priority-e2e/priority-scroll-navigation.md", name: "priority-scroll-\(trial).md", copies: 1)
        let bytes = try Data(contentsOf: url)
        try require(bytes.count == 33234 && PriorityInteractionSupport.hash(bytes) == "88f03d5174bff5835947df57964fbad1bffe23c471427520f3bf1ae83adfde09", "Static fixture byte/hash mismatch")
        try deadline("before-bare-open")
        actions += 1
        let opened = try await support.open(url)
        try deadline("after-bare-open")
        if let preceding {
            try require(CFEqual(preceding.ax, opened.ax), "Fresh URL replaced owned window instead of document")
            try require(try support.windows().count == 1, "Fresh URL added a window")
        }
        if abs(opened.element.frame.width - 900) >= 3 || abs(opened.element.frame.height - 720) >= 3 {
            try deadline("before-resize")
            actions += 1
            try await support.resize(opened, to: CGSize(width: 900, height: 720))
            try deadline("after-resize")
        }
        let window = try reacquire(support, opened)
        try deadline("after-reacquire")
        var notes: [String] = []
        defer { support.record(notes.joined(separator: "\n"), name: "pre-click-baseline") }
        let (clip, tree) = try readerTree(support, window, &notes)
        try require(try fraction(support, window) == 0, "Fresh document is not at exact top0")
        let blocks = tree.filter {
            support.attribute($0, kAXRoleAttribute) as? String == kAXGroupRole
                && support.attribute($0, kAXIdentifierAttribute) as? String == "MarkdownLinkBlock-1"
                && support.attribute($0, kAXDescriptionAttribute) as? String == "Link 1 of 2: AMBER"
        }
        try require(blocks.count == 1, "Initial authored AMBER link block missing/ambiguous count=\(blocks.count)")
        let paragraphs = try boundedTree(blocks[0], &notes).filter {
            support.attribute($0, kAXRoleAttribute) as? String == kAXTextAreaRole
                && support.attribute($0, kAXValueAttribute) as? String == initialParagraph
        }
        try require(paragraphs.count == 1, "Initial exact link paragraph missing/ambiguous")
        let blockChildren = try unwrap(support.attribute(blocks[0], kAXChildrenAttribute) as? [AXUIElement], "Initial block children unavailable")
        let paragraphParent = try unwrap(support.axElement(support.attribute(paragraphs[0], kAXParentAttribute)), "Paragraph parent unavailable")
        try require(blockChildren.count == 1 && CFEqual(blockChildren[0], paragraphs[0]) && CFEqual(paragraphParent, blocks[0]), "Initial paragraph must be sole reciprocal block child")
        let links = try unwrap(support.attribute(paragraphs[0], kAXChildrenAttribute) as? [AXUIElement], "Native links unavailable")
        try require(links.count == 2, "Expected exactly AMBER and End sentinel links")
        for (index, label) in ["AMBER", "End sentinel"].enumerated() {
            let parent = try unwrap(support.axElement(support.attribute(links[index], kAXParentAttribute)), "Link parent unavailable")
            try require(support.attribute(links[index], kAXRoleAttribute) as? String == "AXLink"
                        && support.attribute(links[index], kAXDescriptionAttribute) as? String == label
                        && CFEqual(parent, paragraphs[0]), "Exact native link order/reciprocal ancestry unavailable")
        }
        let heading = try pair(support, tree, paragraph: paragraphs[0], notes: &notes)
        let root = try unwrap(support.axElement(support.attribute(blocks[0], kAXParentAttribute)), "Root list unavailable")
        let roots = try unwrap(support.attribute(root, kAXChildrenAttribute) as? [AXUIElement], "Root ordering unavailable")
        let headingParent = try unwrap(support.axElement(support.attribute(heading, kAXParentAttribute)), "Heading parent unavailable")
        try require(roots.count >= 2 && CFEqual(roots[0], heading) && CFEqual(roots[1], blocks[0])
                    && CFEqual(headingParent, root) && tree.contains { CFEqual($0, root) }, "Initial first heading/block root ordering unavailable")
        var amberRange = CFRange(location: 0, length: 5)
        let amberInput = try unwrap(AXValueCreate(.cfRange, &amberRange), "AMBER range unavailable")
        var amberString: CFTypeRef?
        let amberError = AXUIElementCopyParameterizedAttributeValue(paragraphs[0], kAXStringForRangeParameterizedAttribute as CFString, amberInput, &amberString)
        try require(amberError == .success && amberString as? String == "AMBER", "Parent native string UTF16[0,5) must equal AMBER")
        let h = try unwrap(observedRect(heading, &notes), "Initial heading rectangle unavailable")
        let g = try glyph(support, heading, length: 6)
        let link = try glyph(support, paragraphs[0], length: 5)
        try require(clip.contains(g) && clip.contains(link), "Initial heading/link glyphs clipped; no guessed click")
        let calibration = Baseline(clip: clip, heading: h, glyph: g)
        baseline = calibration
        notes.append("topFraction=0 H0=\(h) G0=\(g) C0=\(clip) expectedHeading=\(calibration.expectedHeading) expectedGlyph=\(calibration.expectedGlyph) inferredMarker=\(calibration.expectedHeading - 8); source margin32/padding8; marker/inset not directly observed")
        var point = CGPoint(x: link.midX, y: link.midY)
        let input = try unwrap(AXValueCreate(.cgPoint, &point), "Link point unavailable")
        var output: CFTypeRef?
        let error = AXUIElementCopyParameterizedAttributeValue(paragraphs[0], kAXRangeForPositionParameterizedAttribute as CFString, input, &output)
        var range = CFRange()
        try require(error == .success && output != nil, "Link range-for-position unavailable error=\(error.rawValue)")
        try require(CFGetTypeID(output!) == AXValueGetTypeID() && AXValueGetValue(output as! AXValue, .cfRange, &range), "Invalid link point range")
        try require(range.location >= 0 && range.length > 0 && range.location + range.length <= 5, "Click does not resolve inside AMBER UTF16[0,5)")
        notes.append("label=AMBER glyph=\(link) point=\(point) range=\(range) sourceBackedFragment=#p9-top-4 (hashed fixture plus prior pure parser regression; NOT observed URL); runtime AXURL unavailable/not required for setup selection; reciprocal AMBER AXLink=\(links[0])")
        try deadline("before-native-link")
        actions += 1
        try support.coordinate(point, in: window).click()
        let clicked = ProcessInfo.processInfo.systemUptime
        try deadline("after-native-link")
        let current = try reacquire(support, window)
        try deadline("after-click-reacquire")
        let remaining = max(0, 0.7 - (ProcessInfo.processInfo.systemUptime - clicked))
        try await Task.sleep(for: .seconds(remaining))
        let sampleStart = ProcessInfo.processInfo.systemUptime
        do {
            _ = try middleSentinel(support, current)
            support.record("original700msGate=passed sampleStart=\(sampleStart - clicked) sampleEnd=\(ProcessInfo.processInfo.systemUptime - clicked)", name: "original-setup-gate")
        } catch {
            support.record("original700msGate=failed sampleStart=\(sampleStart - clicked) sampleEnd=\(ProcessInfo.processInfo.systemUptime - clicked) error=\(error); no scroll permitted; no retry", name: "original-setup-gate")
            throw error
        }
        try deadline("after-original-gate")
        return current
    }

    @MainActor
    private func middleSentinel(_ support: PriorityInteractionSupport, _ window: PriorityInteractionSupport.Window) throws -> AXUIElement {
        var notes: [String] = []
        defer { support.record(notes.joined(separator: "\n"), name: "setup-numeric-observation") }
        let base = try unwrap(baseline, "No pre-input baseline; no target fitting allowed")
        let (clip, tree) = try readerTree(support, window, &notes)
        let paragraphs = tree.filter {
            support.attribute($0, kAXRoleAttribute) as? String == kAXTextAreaRole
                && support.attribute($0, kAXValueAttribute) as? String == fifthParagraph
        }
        try require(paragraphs.count == 1, "Fifth paragraph missing/ambiguous count=\(paragraphs.count)")
        let heading = try pair(support, tree, paragraph: paragraphs[0], notes: &notes)
        let h = try unwrap(observedRect(heading, &notes), "Fifth heading rectangle unavailable")
        let g = try glyph(support, heading, length: 6)
        let p = try glyph(support, paragraphs[0], length: 19)
        let raw = h.minY - clip.minY
        let hr = raw - base.expectedHeading
        let gr = g.minY - clip.minY - base.expectedGlyph
        let number = try fraction(support, window)
        notes.append("uniqueFifth=true H1=\(h) G1=\(g) C1=\(clip) rawDelta=\(raw) originalRawLT40=\(abs(raw) < 40) headingResidual=\(hr) glyphResidual=\(gr) residualLimit=2 fraction=\(number) expectedHeading=\(base.expectedHeading) expectedGlyph=\(base.expectedGlyph)")
        try require(agrees(base.clip, clip) && abs(h.width - base.heading.width) <= 2 && abs(h.height - base.heading.height) <= 2, "Geometry transfer unavailable: heading/reader changed")
        try require(clip.contains(g) && clip.contains(p), "Fifth heading/paragraph glyphs not visible")
        try require(abs(hr) <= 2 && abs(gr) <= 2, "Source-calibrated geometry no-fit; no oracle adaptation")
        try require(abs(raw) < 40, "Original raw abs(topDelta)<40 failed; residual cannot override")
        try require(number.isFinite && number > 0.3 && number < 0.7, "Middle fraction actual=\(number) expected strictly >0.3 <0.7")
        return heading
    }

    private struct StableText {
        let element: AXUIElement
        let chain: [AXUIElement] // leaf through the same owned window, inclusive
        let reader: AXUIElement
        let pid: pid_t
        let document: URL
        let text: String
        let role: String
        let length: Int
    }

    private struct TextSample {
        let leaf: CGRect
        let glyph: CGRect
        let clip: CGRect
        var point: CGFloat { glyph.minY - clip.minY }
    }

    @MainActor
    private func retain(_ support: PriorityInteractionSupport, _ window: PriorityInteractionSupport.Window,
                        _ element: AXUIElement, length: Int) throws -> StableText {
        var chain = [element]
        while !CFEqual(chain.last!, window.ax) && chain.count < 32 {
            let parent = try unwrap(support.axElement(support.attribute(chain.last!, kAXParentAttribute)), "Retained text ancestry unavailable")
            try require(!chain.contains { CFEqual($0, parent) }, "Cyclic retained ancestry")
            chain.append(parent)
        }
        try require(CFEqual(chain.last!, window.ax), "Retained text does not reach owned window within32")
        let readers = chain.filter { support.attribute($0, kAXIdentifierAttribute) as? String == "DocumentReaderScrollView" }
        try require(readers.count == 1, "Retained text must reach exactly the owned reader")
        var pid: pid_t = 0
        try require(AXUIElementGetPid(window.ax, &pid) == .success && pid > 0, "Owned window PID unavailable")
        let text = try unwrap(support.attribute(element, kAXValueAttribute) as? String, "Retained exact text unavailable")
        let role = try unwrap(support.attribute(element, kAXRoleAttribute) as? String, "Retained role unavailable")
        try require((role == "AXHeading" || role == kAXTextAreaRole) && length > 0 && length <= text.utf16.count, "Invalid native text/range")
        return StableText(element: element, chain: chain, reader: readers[0], pid: pid,
                          document: window.document, text: text, role: role, length: length)
    }

    // Retained-object reads only: no text rematch, full-tree walk, XCUI snapshot or
    // screenshot between gestures. Every link in the ancestry is reciprocal.
    @MainActor
    private func sample(_ support: PriorityInteractionSupport, _ text: StableText, visible: Bool = true,
                        reference: TextSample? = nil, resized: Bool = false,
                        trace: ((String) -> Void)? = nil) throws -> TextSample {
        let sampleStart = ProcessInfo.processInfo.systemUptime
        defer { trace?("sample start=\(sampleStart) end=\(ProcessInfo.processInfo.systemUptime)") }
        for (index, element) in text.chain.enumerated() {
            var pid: pid_t = 0
            try require(AXUIElementGetPid(element, &pid) == .success && pid == text.pid, "Retained AX PID changed")
            if index + 1 < text.chain.count {
                let parent = text.chain[index + 1]
                let actual = try unwrap(support.axElement(support.attribute(element, kAXParentAttribute)), "Retained parent missing")
                let children = try unwrap(support.attribute(parent, kAXChildrenAttribute) as? [AXUIElement], "Retained parent children missing")
                try require(CFEqual(actual, parent) && children.filter { CFEqual($0, element) }.count == 1, "Retained reciprocal ancestry changed")
            }
        }
        try require((support.attribute(text.chain.last!, kAXDocumentAttribute) as? String).flatMap(URL.init(string:))?.standardizedFileURL == text.document.standardizedFileURL, "Retained window document changed")
        try require(support.attribute(text.element, kAXValueAttribute) as? String == text.text
                    && support.attribute(text.element, kAXRoleAttribute) as? String == text.role, "Retained native text/role changed")
        var range = CFRange(location: 0, length: text.length)
        let input = try unwrap(AXValueCreate(.cfRange, &range), "Retained range unavailable")
        var value: CFTypeRef?
        let error = AXUIElementCopyParameterizedAttributeValue(text.element, kAXStringForRangeParameterizedAttribute as CFString, input, &value)
        try require(error == .success && value as? String == (text.text as NSString).substring(to: text.length), "Retained native string-for-range changed/unavailable")
        var notes: [String] = []
        let leafStart = ProcessInfo.processInfo.systemUptime
        let leaf = try unwrap(observedRect(text.element, &notes), "Retained leaf rectangle unavailable: \(notes)")
        trace?("leaf start=\(leafStart) end=\(ProcessInfo.processInfo.systemUptime) value=\(leaf)")
        let clipStart = ProcessInfo.processInfo.systemUptime
        let clip = try unwrap(observedRect(text.reader, &notes), "Retained reader rectangle unavailable: \(notes)")
        trace?("clip start=\(clipStart) end=\(ProcessInfo.processInfo.systemUptime) value=\(clip)")
        let glyphStart = ProcessInfo.processInfo.systemUptime
        let glyph = try glyph(support, text.element, length: text.length)
        trace?("glyph start=\(glyphStart) end=\(ProcessInfo.processInfo.systemUptime) value=\(glyph)")
        try require(leaf.insetBy(dx: -2, dy: -2).contains(glyph), "Native glyph outside retained leaf")
        if visible { try require(clip.contains(glyph), "Retained native glyph clipped; no survivor substitution") }
        let result = TextSample(leaf: leaf, glyph: glyph, clip: clip)
        if let reference {
            try require(abs(leaf.width - reference.leaf.width) <= 2 && abs(leaf.height - reference.leaf.height) <= 2
                        && abs(glyph.width - reference.glyph.width) <= 2 && abs(glyph.height - reference.glyph.height) <= 2
                        && abs(glyph.minX - leaf.minX - (reference.glyph.minX - reference.leaf.minX)) <= 2
                        && abs(glyph.minY - leaf.minY - (reference.glyph.minY - reference.leaf.minY)) <= 2
                        && abs(leaf.minX - reference.leaf.minX) <= 2, "Retained native layout changed; displacement not comparable")
            try require(abs(clip.minX - reference.clip.minX) <= 2 && abs(clip.minY - reference.clip.minY) <= 2
                        && abs(clip.width - reference.clip.width) <= 2
                        && (resized || abs(clip.height - reference.clip.height) <= 2), "Retained clip changed")
        }
        return result
    }

    @MainActor
    private func diagnoseMismatch(_ support: PriorityInteractionSupport, _ window: PriorityInteractionSupport.Window,
                                  texts: [StableText], notes: inout [String]) {
        do {
            try support.checkpoint(window, "mismatch-diagnostic-owned")
            let tree = try boundedTree(window.ax, &notes)
            for text in texts {
                let start = ProcessInfo.processInfo.systemUptime
                let current = try sample(support, text, visible: false)
                var visible: CFTypeRef?
                let visibilityError = AXUIElementCopyAttributeValue(text.element, kAXVisibleCharacterRangeAttribute as CFString, &visible)
                let matches = tree.filter { support.attribute($0, kAXValueAttribute) as? String == text.text && support.attribute($0, kAXRoleAttribute) as? String == text.role }
                notes.append("diagnostic AX=\(text.element) text=\(text.text.debugDescription) range=[0,\(text.length)) start=\(start) readEnd=\(ProcessInfo.processInfo.systemUptime) glyph=\(current.glyph) clip=\(current.clip) intersection=\(current.glyph.intersection(current.clip)) visibleError=\(visibilityError.rawValue) visibleValue=\(String(describing: visible)) sameTextCFEqual=\(matches.map { CFEqual($0, text.element) }); comparisons only, never substitute; unsupported visibility is unknown, not painted proof")
                var point = CGPoint(x: current.glyph.midX, y: current.glyph.midY)
                if current.clip.contains(point), let input = AXValueCreate(.cgPoint, &point) {
                    var output: CFTypeRef?
                    let readStart = ProcessInfo.processInfo.systemUptime
                    let error = AXUIElementCopyParameterizedAttributeValue(text.element, kAXRangeForPositionParameterizedAttribute as CFString, input, &output)
                    notes.append("rangeForPosition AX=\(text.element) point=\(point) start=\(readStart) end=\(ProcessInfo.processInfo.systemUptime) error=\(error.rawValue) value=\(String(describing: output))")
                } else { notes.append("rangeForPosition unqueried: claimed glyph center offclip; no reveal action") }
            }
        } catch { notes.append("mismatch diagnostic unavailable: \(error); original failure retained") }
    }

    @MainActor
    private func inputTarget(_ support: PriorityInteractionSupport, _ window: PriorityInteractionSupport.Window,
                             reader: AXUIElement, notes: inout [String]) throws {
        let began = ProcessInfo.processInfo.systemUptime
        let frame = try unwrap(observedRect(reader, &notes), "Input reader frame unavailable")
        var hit: AXUIElement?
        var ownedPID: pid_t = 0
        try require(AXUIElementGetPid(window.ax, &ownedPID) == .success && ownedPID > 0, "Hit root PID unavailable")
        let application = AXUIElementCreateApplication(ownedPID)
        try require(AXUIElementSetMessagingTimeout(application, 0.25) == .success, "Hit root messaging bound unavailable")
        let error = AXUIElementCopyElementAtPosition(application, Float(frame.midX), Float(frame.midY), &hit)
        notes.append("preInput nominalReaderCenter=\(CGPoint(x: frame.midX, y: frame.midY)) reader=\(reader) frame=\(frame) hitError=\(error.rawValue); XCUI public scroll API does not expose delivered event location")
        var seen: [AXUIElement] = []
        while let node = hit, seen.count < 32 {
            try require(!seen.contains { CFEqual($0, node) }, "Input hit ancestry cycle")
            var pid: pid_t = 0
            try require(AXUIElementGetPid(node, &pid) == .success && pid == ownedPID
                        && AXUIElementSetMessagingTimeout(node, 0.25) == .success, "Hit ancestry PID/timeout mismatch")
            seen.append(node)
            notes.append("hitPath node=\(node) role=\(String(describing: support.attribute(node, kAXRoleAttribute))) value=\(String(describing: support.attribute(node, kAXValueAttribute))) identifier=\(String(describing: support.attribute(node, kAXIdentifierAttribute)))")
            if CFEqual(node, window.ax) { break }
            if support.attribute(node, kAXRoleAttribute) as? String == kAXWindowRole {
                throw PriorityInteractionSupport.Failure(description: "Input hit belongs to wrong window")
            }
            hit = support.axElement(support.attribute(node, kAXParentAttribute))
        }
        let owned = seen.last.map { CFEqual($0, window.ax) } == true && seen.contains { CFEqual($0, reader) }
        notes.append("hitOwnedWindow=\(seen.last.map { CFEqual($0, window.ax) } == true) hitIncludesReader=\(seen.contains { CFEqual($0, reader) }) duration=\(ProcessInfo.processInfo.systemUptime - began); nominal point only, NOT actual XCUI event point")
        try require(error == .success && owned, "Nominal hit diagnostic cannot prove exact reader/window ancestry")
    }

    /// XCUI input return is not a synchronous cross-process geometry completion contract.
    /// One deadline includes every packet, yield, and diagnostic; no input is retried.
    @MainActor
    private func completedMovement(_ support: PriorityInteractionSupport,
                                   texts: [StableText], references: [TextSample],
                                   returned: TimeInterval, priorTravel: CGFloat,
                                   notes: inout [String]) async throws -> [TextSample] {
        let deadline = returned + 0.25
        var highWater = references.map(\.point)
        for text in texts {
            try require(text.pid == texts[0].pid && text.document == texts[0].document
                        && CFEqual(text.reader, texts[0].reader)
                        && CFEqual(text.chain.last!, texts[0].chain.last!), "Completion identities have different owners")
            notes.append("completion retainedAX=\(text.element) pid=\(text.pid) window=\(text.chain.last!) document=\(text.document) text=\(text.text.debugDescription) range=[0,\(text.length)) returned=\(returned) deadline=\(deadline)")
        }
        var attempt = 0
        while true {
            try require(ProcessInfo.processInfo.systemUptime < deadline, "Completion budget250ms exhausted before packet")
            attempt += 1
            var packet: [TextSample] = []
            // A-H-P-P-H-A: retain every identity; require agreement across the
            // entire bracket rather than selecting favorable asynchronous reads.
            for index in Array(texts.indices) + Array(texts.indices.reversed()) {
                try require(ProcessInfo.processInfo.systemUptime < deadline, "Completion budget250ms exhausted during packet")
                var trace: [String] = []
                defer { notes.append(contentsOf: trace) }
                let value = try sample(support, texts[index], visible: index == 0,
                                       reference: references[index], trace: {
                    trace.append("completion attempt=\(attempt) identity=\(index) elapsed=\(ProcessInfo.processInfo.systemUptime - returned) \($0)")
                })
                try require(value.point >= highWater[index] - 2, "Reverse movement during completion packet")
                highWater[index] = max(highWater[index], value.point)
                packet.append(value)
            }
            let count = texts.count
            let first = Array(packet.prefix(count))
            let delta = first[0].point - references[0].point
            let coherent = first.indices.allSatisfy { index in
                let closing = packet[packet.count - 1 - index]
                return agrees(first[index].glyph, closing.glyph)
                    && agrees(first[index].leaf, closing.leaf)
                    && agrees(first[0].clip, first[index].clip)
                    && abs(first[index].point - references[index].point - delta) <= 2
                    && first[index].leaf.minY - references[index].leaf.minY > 20
            }
            let elapsed = ProcessInfo.processInfo.systemUptime - returned
            notes.append("completion attempt=\(attempt) elapsed=\(elapsed) coherent=\(coherent) delta=\(delta) linkedOriginalTravel=\(priorTravel + delta)")
            try require(ProcessInfo.processInfo.systemUptime <= deadline, "Completion packet exceeded250ms; no late acceptance")
            if coherent && delta > 20 && priorTravel + delta > 20 { return first }
            // Cooperative asynchronous observation, not a fixed delay or reset deadline.
            await Task.yield()
        }
    }

    @MainActor
    func testGenericUpwardScrollDoesNotSnapBack() async throws {
        var (support, window) = try await prepare()
        var failureTexts: [StableText] = []
        do {
        for trial in 0..<2 {
            if trial == 1 {
                // Repeated corpus region in a fresh presentation, NOT warm lazy reuse.
                window = try await position(support, preceding: window, trial: trial)
            }
            let reader = window.element.scrollViews["DocumentReaderScrollView"]
            let sentinel = try middleSentinel(support, window)
            var notes: [String] = []
            defer { support.record(notes.joined(separator: "\n"), name: "linked-semantic-trial-\(trial)") }
            let (clip, tree) = try readerTree(support, window, &notes)
            let heading = try retain(support, window, sentinel, length: 6)
            let paragraphElements = tree.filter { support.attribute($0, kAXValueAttribute) as? String == fifthParagraph }
            try require(paragraphElements.count == 1, "Unique fifth paragraph required for independent first-input correlation")
            let paragraph = try retain(support, window, paragraphElements[0], length: 19)
            failureTexts = [heading, paragraph]
            let beforeHeading = try sample(support, heading)
            let beforeParagraph = try sample(support, paragraph)
            // Declare realized preceding identities BEFORE input. Intended delta240
            // only selects possible overlaps; measured motion alone passes assertions.
            let headingIndex = try unwrap(tree.firstIndex { CFEqual($0, sentinel) }, "Heading absent from reader")
            var candidates: [(StableText, TextSample)] = []
            for element in tree.prefix(headingIndex) {
                let role = support.attribute(element, kAXRoleAttribute) as? String
                guard role == "AXHeading" || role == kAXTextAreaRole else { continue }
                let rect = try unwrap(observedRect(element, &notes), "Predeclared overlap geometry unavailable")
                guard rect.minY >= clip.minY - 240 && rect.minY < beforeHeading.leaf.minY else { continue }
                let value = try unwrap(support.attribute(element, kAXValueAttribute) as? String, "Overlap text unavailable")
                let retained = try retain(support, window, element, length: min(12, value.utf16.count))
                let initial = try sample(support, retained, visible: false)
                candidates.append((retained, initial))
            }
            candidates.sort { $0.1.glyph.minY < $1.1.glyph.minY }
            try require(!candidates.isEmpty && candidates.count <= 8, "No bounded predeclared realized overlap candidates; no rematch/fallback")
            for (text, initial) in candidates {
                notes.append("predeclared AX=\(text.element) text=\(text.text.debugDescription) range=[0,\(text.length)) leaf=\(initial.leaf) glyph=\(initial.glyph) clip=\(initial.clip)")
            }
            let beforeFraction = try fraction(support, window)
            _ = try support.capture(window, name: "generic-before-\(trial)")
            try inputTarget(support, window, reader: heading.reader, notes: &notes)
            let firstStart = ProcessInfo.processInfo.systemUptime
            reader.scroll(byDeltaX: 0, deltaY: 240)
            var lastEnd = ProcessInfo.processInfo.systemUptime
            notes.append("gesture=1 start=\(firstStart) end=\(lastEnd) duration=\(lastEnd - firstStart)")
            let firstHeading: TextSample, firstParagraph: TextSample
            do {
                try require(CFEqual(heading.reader, paragraph.reader) && CFEqual(heading.chain.last!, paragraph.chain.last!), "First pair reader/window identities differ")
                let completion = try await completedMovement(support, texts: [heading, paragraph],
                    references: [beforeHeading, beforeParagraph], returned: lastEnd,
                    priorTravel: 0, notes: &notes)
                firstHeading = completion[0]
                firstParagraph = completion[1]
            } catch {
                failureGlyphs(support, texts: failureTexts, phase: "before-image")
                support.captureFailure(window, error: error)
                failureGlyphs(support, texts: failureTexts, phase: "after-image")
                failureTexts = []
                diagnoseMismatch(support, window, texts: [heading, paragraph] + candidates.map(\.0), notes: &notes)
                throw error
            }
            let firstDelta = firstHeading.point - beforeHeading.point
            var overlap: (StableText, TextSample)?
            for (text, initial) in candidates {
                let current = try sample(support, text, visible: false, reference: initial)
                guard current.clip.contains(current.glyph), current.clip.maxY - current.glyph.maxY >= 480 else { continue }
                try require(abs(current.point - initial.point - firstDelta) <= 2, "Predeclared overlap does not translate with fifth pair")
                overlap = (text, current)
                break // deterministic topmost predeclared realized glyph, never text rematched
            }
            let (anchor, overlapSample) = try unwrap(overlap, "No realized visible overlap with room for remaining inputs; stop once")
            failureTexts = [anchor, heading, paragraph]
            // Bracket handoff with the OLD identities in the same no-input snapshot.
            let handoffHeading = try sample(support, heading, reference: firstHeading)
            let handoffParagraph = try sample(support, paragraph, reference: firstParagraph)
            try require(abs(handoffHeading.point - firstHeading.point) <= 2 && abs(handoffParagraph.point - firstParagraph.point) <= 2, "Old identities moved during overlap handoff")
            notes.append("overlap oldAX=\(heading.element) paragraphAX=\(paragraph.element) newAX=\(anchor.element) glyph=\(overlapSample.glyph) signedOriginalTravel=\(firstDelta); both old/new visible, same clip, stable translation verified")
            var previous = overlapSample
            var correlationHeading = handoffHeading
            var correlationParagraph = handoffParagraph
            var travel = firstDelta
            for index in 2...3 {
                // Original cadence is measured from input RETURN, including completion.
                try await Task.sleep(for: .seconds(max(0, lastEnd + 0.1 - ProcessInfo.processInfo.systemUptime)))
                try inputTarget(support, window, reader: heading.reader, notes: &notes)
                let start = ProcessInfo.processInfo.systemUptime
                let gap = start - lastEnd
                notes.append("gesture=\(index) gapFromPreviousEnd=\(gap) start=\(start)")
                try require(gap <= 0.25, "Original inter-gesture bound exceeded: \(gap); no delayed substitute input")
                try require(previous.clip.maxY - previous.glyph.maxY >= 240, "Retained pre-input visible glyph lacks room below")
                reader.scroll(byDeltaX: 0, deltaY: 240)
                lastEnd = ProcessInfo.processInfo.systemUptime
                let completion = try await completedMovement(support, texts: [anchor, heading, paragraph],
                    references: [previous, correlationHeading, correlationParagraph],
                    returned: lastEnd, priorTravel: travel, notes: &notes)
                let current = completion[0]
                correlationHeading = completion[1]
                correlationParagraph = completion[2]
                let delta = current.point - previous.point
                travel += delta
                notes.append("gesture=\(index) end=\(lastEnd) duration=\(lastEnd - start) AX=\(anchor.element) glyph=\(current.glyph) delta=\(delta) linkedOriginalTravel=\(travel)")
                try require(delta > 20 && travel > 20, "Each input and linked original-relative semantic travel must exceed20")
                previous = current
            }
            let post = previous
            // All expensive diagnostics/captures are outside the <=0.25s gaps.
            // Sample throughout the ORIGINAL two-second settle, not only endpoints.
            for checkpoint in 0...4 {
                let due = lastEnd + Double(checkpoint) * 0.5
                try await Task.sleep(for: .seconds(max(0, due - ProcessInfo.processInfo.systemUptime)))
                let current = try sample(support, anchor, reference: post)
                let drift = current.point - post.point
                notes.append("settle=\(checkpoint) elapsed=\(ProcessInfo.processInfo.systemUptime - lastEnd) AX=\(anchor.element) glyph=\(current.glyph) drift=\(drift) originalTravel=\(travel + drift)")
                try require(abs(drift) <= 20 && travel + drift > 20, "Settle drift/no-return-to-original semantic oracle failed")
                if checkpoint == 0 {
                    notes.append("postSequenceFraction=\(try fraction(support, window)); diagnostic only")
                    _ = try support.capture(window, name: "generic-after-\(trial)")
                }
            }
            _ = try support.capture(window, name: "generic-settled-\(trial)")
            notes.append("beforeFraction=\(beforeFraction) settledFraction=\(try fraction(support, window)); diagnostic only; owned before/after/settled visual correspondence requires inspection, no numeric pixel oracle")
        }
        } catch {
            failureGlyphs(support, texts: failureTexts, phase: "before-image")
            support.captureFailure(window, error: error)
            failureGlyphs(support, texts: failureTexts, phase: "after-image")
            throw error
        }
    }

    /// Failure-only, outside input gaps. Never replaces a failed completion packet.
    @MainActor
    private func failureGlyphs(_ support: PriorityInteractionSupport, texts: [StableText], phase: String) {
        guard !texts.isEmpty else { return }
        var notes: [String] = []
        for text in texts {
            let began = ProcessInfo.processInfo.systemUptime
            do {
                let value = try sample(support, text, visible: false)
                notes.append("AX=\(text.element) text=\(text.text.debugDescription) glyph=\(value.glyph) start=\(began) end=\(ProcessInfo.processInfo.systemUptime)")
            } catch {
                notes.append("AX=\(text.element) start=\(began) end=\(ProcessInfo.processInfo.systemUptime) unavailable=\(error); original failure retained")
            }
        }
        support.record(notes.joined(separator: "\n"), name: "failure-retained-glyphs-" + phase)
    }

    @MainActor
    func testGenericScrollCancelsPendingRestoration() async throws {
        let (support, window) = try await prepare(delay: 1500)
        let sentinel = try middleSentinel(support, window)
        let reader = window.element.scrollViews["DocumentReaderScrollView"]
        let retained = try retain(support, window, sentinel, length: 6)
        let oldSample = try sample(support, retained)
        let oldPoint = oldSample.point
        _ = try support.capture(window, name: "restoration-before")
        // Only height changes by 20; no width/fullscreen/history/refresh permutations.
        let size = window.element.frame.size
        let corner = window.element.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -2, dy: -2))
        corner.press(forDuration: 0.1, thenDragTo: corner.withOffset(CGVector(dx: 0, dy: 20)))
        let started = Date()
        let heightError = window.element.frame.height - (size.height + 20)
        support.record("heightError=\(heightError)", name: "resize-oracle")
        try require(abs(heightError) <= 3, "Resize height error actual=\(heightError) expected abs<=3")
        reader.scroll(byDeltaX: 0, deltaY: 240)
        let newSample = try sample(support, retained, reference: oldSample, resized: true)
        let newPoint = newSample.point
        let elapsed = Date().timeIntervalSince(started)
        support.record("elapsed=\(elapsed) movement=\(newPoint - oldPoint)", name: "restoration-input")
        try require(elapsed < 1.5, "Input elapsed actual=\(elapsed) expected<1.5")
        try require(newPoint - oldPoint >= 80, "Input movement actual=\(newPoint - oldPoint) expected>=80")
        let settling = ProcessInfo.processInfo.systemUptime
        _ = try support.capture(window, name: "restoration-after-input")
        try await Task.sleep(for: .seconds(max(0, 2.5 - (ProcessInfo.processInfo.systemUptime - settling))))
        let finalSample = try sample(support, retained, reference: newSample)
        let finalPoint = finalSample.point
        support.record("final=\(finalPoint) new=\(newPoint) old=\(oldPoint)", name: "restoration-oracles")
        try require(abs(finalPoint - newPoint) <= 20, "Final displacement actual=\(finalPoint - newPoint) expected abs<=20")
        try require(finalPoint - oldPoint >= 60, "Final movement actual=\(finalPoint - oldPoint) expected>=60")
        support.record("oldSemanticPoint=\(oldPoint) new=\(newPoint) final=\(finalPoint) AX=\(retained.element) exactText=\(retained.text) range=[0,6) oldGlyph=\(oldSample.glyph) newGlyph=\(newSample.glyph) finalGlyph=\(finalSample.glyph) elapsedSettle=\(ProcessInfo.processInfo.systemUptime - settling) pending/cancel-generation=unavailable; configured1500ms delay and observed timing only, not direct pending-state proof; owned captures are visual inspection, not pixel proof", name: "restoration-cancellation")
        _ = try support.capture(window, name: "restoration-after")
    }
}
