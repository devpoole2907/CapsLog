import Foundation

struct MarkdownTextMutation {
    let text: String
    let selection: NSRange

    static func applying(
        _ action: MarkdownEditorAction,
        to text: String,
        selection: NSRange
    ) -> MarkdownTextMutation {
        let source = text as NSString
        let clampedSelection = NSRange(
            location: min(selection.location, source.length),
            length: min(selection.length, max(source.length - selection.location, 0))
        )

        switch action {
        case .heading(let level):
            return replacingLinePrefixes(
                in: source,
                selection: clampedSelection,
                style: .heading(level)
            )
        case .bulletList:
            return replacingLinePrefixes(
                in: source,
                selection: clampedSelection,
                style: .fixed("- ")
            )
        case .numberedList:
            return replacingLinePrefixes(
                in: source,
                selection: clampedSelection,
                style: .numbered
            )
        case .checklist:
            return replacingLinePrefixes(
                in: source,
                selection: clampedSelection,
                style: .fixed("- [ ] ")
            )
        case .quote:
            return replacingLinePrefixes(
                in: source,
                selection: clampedSelection,
                style: .fixed("> ")
            )
        case .bold:
            return wrapping(source, selection: clampedSelection, prefix: "**", suffix: "**")
        case .italic:
            return wrapping(source, selection: clampedSelection, prefix: "_", suffix: "_")
        case .strikethrough:
            return wrapping(source, selection: clampedSelection, prefix: "~~", suffix: "~~")
        case .inlineCode:
            return wrapping(source, selection: clampedSelection, prefix: "`", suffix: "`")
        case .codeBlock:
            return wrapping(
                source,
                selection: clampedSelection,
                prefix: "```\n",
                suffix: "\n```"
            )
        case .link:
            return insertingLink(in: source, selection: clampedSelection)
        case .indent:
            return indenting(source, selection: clampedSelection)
        case .outdent:
            return outdenting(source, selection: clampedSelection)
        case .horizontalRule:
            return replacing(
                source,
                range: clampedSelection,
                with: "\n\n---\n\n",
                selectionOffset: 7
            )
        }
    }

    private enum LineStyle {
        case heading(Int)
        case fixed(String)
        case numbered
    }

    private static func wrapping(
        _ source: NSString,
        selection: NSRange,
        prefix: String,
        suffix: String
    ) -> MarkdownTextMutation {
        let selected = source.substring(with: selection)
        let replacement = prefix + selected + suffix
        let prefixLength = (prefix as NSString).length

        return replacing(
            source,
            range: selection,
            with: replacement,
            selectionOffset: prefixLength,
            selectionLength: selection.length
        )
    }

    private static func insertingLink(
        in source: NSString,
        selection: NSRange
    ) -> MarkdownTextMutation {
        let selected = source.substring(with: selection)
        let label = selected.isEmpty ? "link" : selected
        let replacement = "[\(label)](url)"
        let selectedLength = (label as NSString).length

        return replacing(
            source,
            range: selection,
            with: replacement,
            selectionOffset: 1,
            selectionLength: selectedLength
        )
    }

    private static func replacingLinePrefixes(
        in source: NSString,
        selection: NSRange,
        style: LineStyle
    ) -> MarkdownTextMutation {
        let lineRange = source.lineRange(for: selection)
        let block = source.substring(with: lineRange)
        let hasTrailingNewline = block.hasSuffix("\n")
        var lines = block.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        if hasTrailingNewline, lines.last?.isEmpty == true {
            lines.removeLast()
        }

        let transformed = lines.enumerated().map { index, line in
            applying(style, to: line, index: index)
        }
        var replacement = transformed.joined(separator: "\n")
        if hasTrailingNewline {
            replacement += "\n"
        }

        let newSelection: NSRange
        if selection.length == 0 {
            let currentLineRange = source.lineRange(
                for: NSRange(location: selection.location, length: 0)
            )
            let lineIndex = source
                .substring(with: NSRange(
                    location: lineRange.location,
                    length: currentLineRange.location - lineRange.location
                ))
                .filter { $0 == "\n" }
                .count
            let oldLine = source.substring(with: currentLineRange)
            let oldLineLength = (
                oldLine.hasSuffix("\n") ? String(oldLine.dropLast()) : oldLine
            ).utf16.count
            let newLineLength = transformed[
                min(lineIndex, max(transformed.count - 1, 0))
            ].utf16.count
            newSelection = NSRange(
                location: max(
                    lineRange.location,
                    selection.location + newLineLength - oldLineLength
                ),
                length: 0
            )
        } else {
            newSelection = NSRange(
                location: lineRange.location,
                length: (replacement as NSString).length
            )
        }

        let result = source.replacingCharacters(in: lineRange, with: replacement)
        return MarkdownTextMutation(text: result, selection: newSelection)
    }

    private static func applying(
        _ style: LineStyle,
        to line: String,
        index: Int
    ) -> String {
        let indentation = line.prefix { $0 == " " || $0 == "\t" }
        let content = String(line.dropFirst(indentation.count))

        switch style {
        case .heading(let level):
            let clean = content.replacingOccurrences(
                of: #"^#{1,6}\s+"#,
                with: "",
                options: .regularExpression
            )
            return indentation + String(repeating: "#", count: min(max(level, 1), 6))
                + " " + clean
        case .fixed(let prefix):
            if content.hasPrefix(prefix) {
                return String(indentation) + String(content.dropFirst(prefix.count))
            }
            return String(indentation) + prefix + content
        case .numbered:
            let clean = content.replacingOccurrences(
                of: #"^\d+\.\s+"#,
                with: "",
                options: .regularExpression
            )
            return String(indentation) + "\(index + 1). " + clean
        }
    }

    private static func indenting(
        _ source: NSString,
        selection: NSRange
    ) -> MarkdownTextMutation {
        let lineRange = source.lineRange(for: selection)
        let block = source.substring(with: lineRange)
        let replacement = block
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "  " + $0 }
            .joined(separator: "\n")

        let result = source.replacingCharacters(in: lineRange, with: replacement)
        let newSelection = selection.length == 0
            ? NSRange(location: selection.location + 2, length: 0)
            : NSRange(
                location: lineRange.location,
                length: (replacement as NSString).length
            )
        return MarkdownTextMutation(text: result, selection: newSelection)
    }

    private static func outdenting(
        _ source: NSString,
        selection: NSRange
    ) -> MarkdownTextMutation {
        let lineRange = source.lineRange(for: selection)
        let block = source.substring(with: lineRange)
        let replacement = block
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                if line.hasPrefix("  ") {
                    return String(line.dropFirst(2))
                }
                if line.hasPrefix("\t") || line.hasPrefix(" ") {
                    return String(line.dropFirst())
                }
                return String(line)
            }
            .joined(separator: "\n")

        let removedBeforeCursor = source
            .substring(with: source.lineRange(
                for: NSRange(location: selection.location, length: 0)
            ))
            .prefix { $0 == " " || $0 == "\t" }
            .prefix(2)
            .utf16
            .count
        let result = source.replacingCharacters(in: lineRange, with: replacement)
        let newSelection = selection.length == 0
            ? NSRange(
                location: max(selection.location - removedBeforeCursor, lineRange.location),
                length: 0
            )
            : NSRange(
                location: lineRange.location,
                length: (replacement as NSString).length
            )
        return MarkdownTextMutation(text: result, selection: newSelection)
    }

    private static func replacing(
        _ source: NSString,
        range: NSRange,
        with replacement: String,
        selectionOffset: Int,
        selectionLength: Int = 0
    ) -> MarkdownTextMutation {
        let result = source.replacingCharacters(in: range, with: replacement)
        return MarkdownTextMutation(
            text: result,
            selection: NSRange(
                location: range.location + selectionOffset,
                length: selectionLength
            )
        )
    }
}
