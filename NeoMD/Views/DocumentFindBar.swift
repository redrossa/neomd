import SwiftUI

struct DocumentFindBar: View {
    @Binding var query: String
    let count: Int
    let cursor: Int?
    let focused: FocusState<Bool>.Binding
    let step: (Bool) -> Void
    let dismiss: () -> Void

    private var status: String {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "" }
        guard let cursor, count > 0 else { return "Not found" }
        return "\(cursor + 1) of \(count)"
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Find", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused(focused)
                .accessibilityIdentifier("DocumentFindField")
                .onKeyPress(.return, phases: .down) { press in
                    step(press.modifiers.contains(.shift))
                    return .handled
                }
            Text(status).font(.callout).foregroundStyle(.secondary)
                .accessibilityIdentifier("DocumentFindStatus")
            Button { step(true) } label: { Image(systemName: "chevron.up") }
                .accessibilityLabel("Previous match")
                .accessibilityIdentifier("DocumentFindPrevious")
                .disabled(count == 0)
            Button { step(false) } label: { Image(systemName: "chevron.down") }
                .accessibilityLabel("Next match")
                .accessibilityIdentifier("DocumentFindNext")
                .disabled(count == 0)
            Button("Done", action: dismiss).accessibilityIdentifier("DocumentFindDone")
        }
        .padding(8)
        .background(.bar)
        .accessibilityIdentifier("DocumentFindBar")
        .onExitCommand(perform: dismiss)
    }
}

struct DocumentFindHighlight: Equatable {
    let leafID: Int
    let range: NSRange
    let serial: Int

    /// Presentation-only conversion. UTF-16 endpoints must be valid in this text.
    static func applying(_ range: NSRange?, to text: AttributedString) -> AttributedString {
        guard let range, range.location >= 0, range.length > 0,
              NSMaxRange(range) <= String(text.characters).utf16.count,
              let stringRange = Range(range, in: String(text.characters)),
              let lower = AttributedString.Index(stringRange.lowerBound, within: text),
              let upper = AttributedString.Index(stringRange.upperBound, within: text) else { return text }
        var result = text
        result[lower..<upper].backgroundColor = Color(nsColor: .findHighlightColor)
        return result
    }

    func applying(to text: AttributedString, leafID: Int) -> AttributedString {
        Self.applying(self.leafID == leafID ? range : nil, to: text)
    }
}
