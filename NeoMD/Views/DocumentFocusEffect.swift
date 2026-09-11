import SwiftUI

/// Quiets only a document focus target. The target must restore the supplied
/// incoming policy on its children, inside any ScrollView/focusable wrapper.
/// A child focusEffectDisabled(false) cannot override an ancestor suppression.
struct DocumentFocusEffect<Content: View>: View {
    @Environment(\.isFocusEffectEnabled) private var inheritedEffectEnabled
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        content(inheritedEffectEnabled)
            .focusEffectDisabled()
    }
}
