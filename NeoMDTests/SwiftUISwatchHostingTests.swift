import AppKit
import SwiftUI
import Testing
@testable import NeoMD

@MainActor
struct SwiftUISwatchHostingTests {
    private final class Probe {
        var draws = 0
        var cues = 0
    }

    private struct Renderer: TextRenderer {
        let probe: Probe
        func draw(layout: Text.Layout, in context: inout GraphicsContext) {
            probe.draws += 1
            probe.cues += layout.reduce(0) { total, line in total + line.filter { $0[FailedSwiftUISwatchPrototype.Cue.self] != nil }.count }
            FailedSwiftUISwatchPrototype.Renderer().draw(layout: layout, in: &context)
        }
    }

    @Test(.disabled("Historical failed feasibility probe; production uses the native bridge. See docs/m1-13-validation.md."))
    func selectableAndNonselectableSwiftUITextInvokePassiveCueRenderer() throws {
        let block = try #require(MarkdownBlockRenderer.render(from: "Visible `#00FF00` next").roots.first)
        for selectable in [false, true] {
            let probe = Probe()
            let text = FailedSwiftUISwatchPrototype.text(ReaderTheme().presentationText(for: block.text), scale: 1)
                .textRenderer(Renderer(probe: probe)).font(ReaderTheme().font())
            let root = selectable ? AnyView(text.textSelection(.enabled)) : AnyView(text.textSelection(.disabled))
            let host = NSHostingView(rootView: root)
            let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 400, height: 100),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.makeKeyAndOrderFront(nil)
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            print("SWATCH_RENDERER selectable=\(selectable) draws=\(probe.draws) cues=\(probe.cues)")
            #expect(probe.draws > 0 && probe.cues > 0)
            window.close()
        }
    }
}

// Retained only to reproduce the rejected selectable SwiftUI implementation.
private enum FailedSwiftUISwatchPrototype {
    static let attribute = NSAttributedString.Key("NeoMD.PassiveColorSwatch")
    static func side(scale: CGFloat) -> CGFloat { 9 * scale }
    static func gap(scale: CGFloat) -> CGFloat { 3 * scale }

    static func color(_ value: MarkdownColorReference) -> NSColor {
        NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: 1)
    }

    struct Cue: TextAttribute {
        let value: MarkdownColorReference
        let scale: CGFloat
    }

    static func text(_ source: AttributedString, scale: CGFloat) -> Text {
        source.runs[\.markdownColorReference].reduce(Text("")) { result, item in
            let (value, range) = item
            guard let value, !source[range].characters.isEmpty else {
                return Text("\(result)\(Text(AttributedString(source[range])))")
            }
            let last = source.characters.index(before: range.upperBound)
            let prefix = Text(AttributedString(source[range.lowerBound..<last]))
            let end = Text(AttributedString(source[last..<range.upperBound]))
                .kerning(side(scale: scale) + 2 * gap(scale: scale))
                .customAttribute(Cue(value: value, scale: scale))
            return Text("\(result)\(prefix)\(end)")
        }
    }

    struct Renderer: TextRenderer {
        func draw(layout: Text.Layout, in context: inout GraphicsContext) {
            for line in layout {
                for run in line {
                    context.draw(run)
                    if let cue = run[Cue.self] {
                        let side = side(scale: cue.scale)
                        let gap = gap(scale: cue.scale)
                        let bounds = run.typographicBounds.rect
                        let rect = CGRect(x: bounds.maxX - side - gap,
                                          y: bounds.maxY - run.typographicBounds.descent - side,
                                          width: side, height: side)
                        context.fill(Path(rect), with: .color(Color(nsColor: color(cue.value))))
                        context.stroke(Path(rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(.secondary), lineWidth: 1)
                    }
                }
            }
        }
    }
}
