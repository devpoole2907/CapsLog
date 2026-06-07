import Foundation

struct MarkdownEditorCommand: Equatable, Identifiable {
    let id = UUID()
    let action: MarkdownEditorAction
}
