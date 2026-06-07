import Foundation

struct NotePresentation: Equatable {
    let title: String
    let markdown: String

    init(source: String, fallbackTitle: String) {
        let content = Self.removingFrontmatter(from: source)
        let titleAndBody = Self.extractingTitle(from: content)

        title = titleAndBody.title ?? fallbackTitle
        markdown = SilverBulletMarkdownRenderer.prepare(
            titleAndBody.body.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func removingFrontmatter(from source: String) -> String {
        let normalized = source.hasPrefix("\u{feff}")
            ? String(source.dropFirst())
            : source
        let lines = normalized.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return normalized
        }

        guard let closingIndex = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) else {
            return normalized
        }

        return lines
            .dropFirst(closingIndex + 1)
            .joined(separator: "\n")
    }

    private static func extractingTitle(
        from source: String
    ) -> (title: String?, body: String) {
        var lines = source.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )

        guard let firstContentIndex = lines.firstIndex(where: {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            return (nil, "")
        }

        let firstLine = lines[firstContentIndex]
            .trimmingCharacters(in: .whitespaces)
        guard firstLine.hasPrefix("# "), firstLine.count > 2 else {
            return (nil, source)
        }

        let title = String(firstLine.dropFirst(2))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        lines.remove(at: firstContentIndex)

        return (title.isEmpty ? nil : title, lines.joined(separator: "\n"))
    }
}
