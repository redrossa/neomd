import AppKit
import SwiftUI
import Testing
@testable import NeoMD

@MainActor
struct NativeColorLeafTests {
    @Test func routingPreservesUnlinkedImageOnlyLeaves() throws {
        for source in ["![badge](image.png)", "![](image.png)", "![one](a.png)  ![two](b.png)",
                       "<picture>\n<img src=\"image.png\" alt=\"badge\">\n</picture>",
                       "<picture>\n<img src=\"image.png\" alt=\"\">\n</picture>"] {
            let block = try #require(MarkdownBlockRenderer.render(from: source).roots.first)
            #expect(!MarkdownLinkedImageText.requiresNativeText(block.text))
        }
        #expect(!MarkdownLinkedImageText.requiresNativeText(AttributedString(" \n\t")))
        for source in ["ordinary `#FFF`", "`rgb(256,0,0)`", "plain #FFFFFF", "# Heading",
                       "> Quoted prose", "`#FFFFFF`", "before ![badge](image.png) `#000000`",
                       "before ![badge](image.png)", "![](image.png) after", "[![badge](image.png)](#target)"] {
            let block = try #require(MarkdownBlockRenderer.render(from: source).leaves.first)
            #expect(MarkdownLinkedImageText.requiresNativeText(block.text))
        }
    }

    @Test func noImageLeavesPreserveSelectionAcrossThemeScaleAndWidthUpdates() throws {
        let block = try #require(MarkdownBlockRenderer.render(from: "Before `#FFFFFF` next [`rgb(0,0,0)`](#target) after").roots.first)
        let view = MarkdownLinkedImageTextView(frame: .zero)
        defer { view.detach() }
        let original = String(block.text.characters)
        let selection = (original as NSString).range(of: "#FFFFFF")
        var opened: URL?
        view.open = { opened = $0 }
        for scale in [CGFloat(1), 1.5, 2] {
            for dark in [false, true, false] {
                for width in [CGFloat(836), 416] {
                    let input = MarkdownLinkedImageText.Input(text: ReaderTheme(scale: scale).presentationText(for: block.text),
                        states: [:], dark: dark, width: width, scale: scale)
                    view.update(input)
                    #expect(view.string == original)
                    if view.replacementCount > 1 { #expect(view.selectedRange() == selection) }
                    view.setSelectedRange(selection)
                    let count = view.replacementCount
                    view.update(input)
                    #expect(view.replacementCount == count)
                    let size = view.measure(width: width)
                    view.frame.size = size
                    #expect(size.height.isFinite && size.height > 0)
                    let cues = view.swatchBounds()
                    #expect(cues.count == 2)
                    for (rect, _) in cues {
                        #expect(rect.width == 9 * scale && rect.minX >= 0 && rect.maxX <= width)
                        #expect(rect.minY >= 0 && rect.maxY <= size.height)
                    }
                    let storage = try #require(view.textStorage)
                    let font = try #require(storage.attribute(.font, at: selection.location, effectiveRange: nil) as? NSFont)
                    #expect(font.pointSize == NSFont.preferredFont(forTextStyle: .body).pointSize * scale)
                    let children = try #require(view.accessibilityChildren() as? [MarkdownImageAccessibilityElement])
                    #expect(children.count == 1 && children[0].alternative == "rgb(0,0,0)")
                    #expect(children[0].accessibilityPerformPress())
                    #expect(opened?.absoluteString == "#target")
                    #expect(view.isSelectable && !view.isEditable)
                    print("COLOR_LEAF scale=\(scale) dark=\(dark) width=\(width) font=\(font.pointSize) size=\(size) swatches=\(cues.map { $0.0 }) selection=\(view.selectedRange())")
                }
            }
        }
        let children = try #require(view.accessibilityChildren() as? [MarkdownImageAccessibilityElement])
        view.detach()
        #expect(view.string.isEmpty && view.input == nil && view.delegate == nil)
        #expect(children.allSatisfy { $0.owner == nil && !$0.accessibilityPerformPress() })
    }

    @Test func selectableNoImageProductionBridgeDrawsInNativeHostingWindow() throws {
        let block = try #require(MarkdownBlockRenderer.render(from: "Visible `#00FF00` next").roots.first)
        let input = MarkdownLinkedImageText.Input(text: ReaderTheme().presentationText(for: block.text),
            states: [:], dark: false, width: 400)
        let host = NSHostingView(rootView: MarkdownLinkedImageText(input: input).textSelection(.enabled))
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 400, height: 100),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        func native(_ root: NSView) -> MarkdownLinkedImageTextView? {
            if let view = root as? MarkdownLinkedImageTextView { return view }
            return root.subviews.lazy.compactMap { native($0) }.first
        }
        let view = try #require(native(host))
        #expect(view.string == String(block.text.characters))
        #expect(view.isSelectable && view.swatchBounds().count == 1)
        #expect(view.accessibilityChildren()?.isEmpty == true)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        print("HOSTED_COLOR frame=\(view.frame) bounds=\(view.bounds) cues=\(view.swatchBounds()) bitmap=\(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
        let capture = FileManager.default.temporaryDirectory.appendingPathComponent("neomd-13-hosted-native-color.png")
        try bitmap.representation(using: .png, properties: [:])?.write(to: capture)
        print("HOSTED_COLOR capture=\(capture.path)")
        var green = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                   color.greenComponent > 0.8 && color.greenComponent - color.redComponent > 0.35 &&
                   color.greenComponent - color.blueComponent > 0.35 { green += 1 }
            }
        }
        #expect(green > 20)
    }
}
