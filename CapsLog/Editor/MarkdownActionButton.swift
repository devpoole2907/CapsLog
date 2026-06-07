import SwiftUI

struct MarkdownActionButton: View {
    let action: MarkdownEditorAction
    let perform: (MarkdownEditorAction) -> Void

    var body: some View {
        Button(action.title, systemImage: action.systemImage) {
            perform(action)
        }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
    }
}
