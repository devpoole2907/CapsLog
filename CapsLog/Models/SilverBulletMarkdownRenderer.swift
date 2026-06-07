import Foundation

nonisolated enum SilverBulletMarkdownRenderer {
    static func prepare(_ source: String) -> String {
        var isInsideFence = false
        var renderedLines: [String] = []
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)

        for (index, line) in lines.enumerated() {
            let string = String(line)
            let trimmed = string.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                isInsideFence.toggle()
                renderedLines.append(string)
            } else if isInsideFence {
                renderedLines.append(string)
            } else if let task = renderedTask(from: string) {
                let previousIsTask = index > 0 && renderedTask(from: String(lines[index - 1])) != nil
                if !previousIsTask, renderedLines.last?.isEmpty == false {
                    renderedLines.append("")
                }
                renderedLines.append(task + "  ")

                let nextIsTask = index + 1 < lines.count
                    && renderedTask(from: String(lines[index + 1])) != nil
                if !nextIsTask {
                    renderedLines.append("")
                }
            } else {
                renderedLines.append(prepareLinks(in: string))
            }
        }

        return renderedLines.joined(separator: "\n")
    }

    private static func renderedTask(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let prefixes = [
            "- [x] ": "☑︎",
            "- [X] ": "☑︎",
            "* [x] ": "☑︎",
            "* [X] ": "☑︎",
            "- [ ] ": "☐",
            "* [ ] ": "☐"
        ]

        guard let match = prefixes.first(where: { trimmed.hasPrefix($0.key) }) else {
            return nil
        }

        let label = trimmed.dropFirst(match.key.count)
        return "\(match.value) \(prepareLinks(in: String(label)))"
    }

    static func pageURL(reference: String) -> URL? {
        var components = URLComponents()
        components.scheme = "capslog"
        components.host = "page"
        components.queryItems = [
            URLQueryItem(name: "reference", value: reference)
        ]
        return components.url
    }

    static func pageReference(from url: URL) -> String? {
        guard url.scheme == "capslog", url.host == "page" else {
            return nil
        }

        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "reference" })?
            .value
    }

    static func resolvePagePath(reference: String, from currentPath: String) -> String? {
        var target = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, !target.hasPrefix("#") else {
            return nil
        }

        if let fragmentIndex = target.firstIndex(of: "#") {
            target = String(target[..<fragmentIndex])
        }
        if let positionIndex = target.firstIndex(of: "@") {
            target = String(target[..<positionIndex])
        }

        target = target.removingPercentEncoding ?? target
        target = target.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if target.hasPrefix("./") || target.hasPrefix("../") {
            let folder = (currentPath as NSString).deletingLastPathComponent
            let combined = (folder as NSString).appendingPathComponent(target)
            target = (combined as NSString).standardizingPath
        }

        guard !target.isEmpty else {
            return nil
        }

        return target.lowercased().hasSuffix(".md") ? target : "\(target).md"
    }

    static func resolveDocumentPath(
        reference: String,
        from currentPath: String,
        isAbsolute: Bool
    ) -> String? {
        var target = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else {
            return nil
        }

        target = target.removingPercentEncoding ?? target
        if let sizeSeparator = target.lastIndex(of: "|") {
            target = String(target[..<sizeSeparator])
        }

        target = target.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !target.isEmpty else {
            return nil
        }

        if !isAbsolute {
            let folder = (currentPath as NSString).deletingLastPathComponent
            let combined = (folder as NSString).appendingPathComponent(target)
            target = (combined as NSString).standardizingPath
        }

        return target
    }

    private static func prepareLinks(in line: String) -> String {
        let wikiPrepared = replacingMatches(
            pattern: #"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]"#,
            in: line
        ) { match, source in
            let reference = substring(for: match.range(at: 1), in: source)
            let alias = substring(for: match.range(at: 2), in: source)
            let label = alias.isEmpty ? reference : alias

            guard let url = pageURL(reference: reference) else {
                return label
            }
            return "[\(label)](\(url.absoluteString))"
        }

        return replacingMatches(
            pattern: #"(?<!!)\[([^\]]+)\]\(([^)]+)\)"#,
            in: wikiPrepared
        ) { match, source in
            let label = substring(for: match.range(at: 1), in: source)
            var destination = substring(for: match.range(at: 2), in: source)
            destination = destination.trimmingCharacters(
                in: CharacterSet(charactersIn: "<>")
            )

            guard isInternalReference(destination),
                  let url = pageURL(reference: destination) else {
                return substring(for: match.range, in: source)
            }
            return "[\(label)](\(url.absoluteString))"
        }
    }

    private static func isInternalReference(_ destination: String) -> Bool {
        guard !destination.hasPrefix("#") else {
            return false
        }

        if let scheme = URL(string: destination)?.scheme {
            return scheme.isEmpty
        }
        return true
    }

    private static func replacingMatches(
        pattern: String,
        in source: String,
        transform: (NSTextCheckingResult, NSString) -> String
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return source
        }

        let mutable = NSMutableString(string: source)
        let original = source as NSString
        let matches = expression.matches(
            in: source,
            range: NSRange(location: 0, length: original.length)
        )

        for match in matches.reversed() {
            mutable.replaceCharacters(
                in: match.range,
                with: transform(match, original)
            )
        }
        return mutable as String
    }

    private static func substring(for range: NSRange, in source: NSString) -> String {
        guard range.location != NSNotFound else {
            return ""
        }
        return source.substring(with: range)
    }
}
