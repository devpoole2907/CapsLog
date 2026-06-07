import SwiftUI

struct MarkdownStyleMenu: View {
    let perform: (MarkdownEditorAction) -> Void

    var body: some View {
        Menu("Text Style", systemImage: "textformat.size") {
            Button("Title") {
                perform(.heading(1))
            }
            Button("Heading") {
                perform(.heading(2))
            }
            Button("Subheading") {
                perform(.heading(3))
            }
            Divider()
            Button("Quote", systemImage: "text.quote") {
                perform(.quote)
            }
            Button("Inline Code", systemImage: "chevron.left.forwardslash.chevron.right") {
                perform(.inlineCode)
            }
            Button("Code Block", systemImage: "curlybraces.square") {
                perform(.codeBlock)
            }
            Button("Divider", systemImage: "minus") {
                perform(.horizontalRule)
            }
        }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
    }
}
