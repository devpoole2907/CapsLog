import SwiftUI

struct NoteSourceEditorView: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    let isReadOnly: Bool

    @State private var selection = NSRange(location: 0, length: 0)
    @State private var command: MarkdownEditorCommand?

    var body: some View {
        MarkdownSourceEditor(
            text: $text,
            selection: $selection,
            isFocused: $isFocused,
            command: command,
            isReadOnly: isReadOnly
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MarkdownKeyboardToolbar(
                isKeyboardActive: isFocused,
                perform: perform
            )
        }
    }

    private func perform(_ action: MarkdownEditorAction) {
        command = MarkdownEditorCommand(action: action)
        isFocused = true
    }
}
