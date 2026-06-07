enum MarkdownEditorAction: Hashable {
    case heading(Int)
    case bulletList
    case numberedList
    case checklist
    case quote
    case bold
    case italic
    case strikethrough
    case inlineCode
    case codeBlock
    case link
    case indent
    case outdent
    case horizontalRule

    var title: String {
        switch self {
        case .heading(let level):
            "Heading \(level)"
        case .bulletList:
            "Bulleted List"
        case .numberedList:
            "Numbered List"
        case .checklist:
            "Checklist"
        case .quote:
            "Quote"
        case .bold:
            "Bold"
        case .italic:
            "Italic"
        case .strikethrough:
            "Strikethrough"
        case .inlineCode:
            "Inline Code"
        case .codeBlock:
            "Code Block"
        case .link:
            "Link"
        case .indent:
            "Increase Indent"
        case .outdent:
            "Decrease Indent"
        case .horizontalRule:
            "Divider"
        }
    }

    var systemImage: String {
        switch self {
        case .heading:
            "textformat.size"
        case .bulletList:
            "list.bullet"
        case .numberedList:
            "list.number"
        case .checklist:
            "checklist"
        case .quote:
            "text.quote"
        case .bold:
            "bold"
        case .italic:
            "italic"
        case .strikethrough:
            "strikethrough"
        case .inlineCode:
            "chevron.left.forwardslash.chevron.right"
        case .codeBlock:
            "curlybraces.square"
        case .link:
            "link"
        case .indent:
            "increase.indent"
        case .outdent:
            "decrease.indent"
        case .horizontalRule:
            "minus"
        }
    }
}
