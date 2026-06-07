import Foundation

nonisolated enum SilverBulletMarkdownRenderer {
    static func prepare(_ source: String) -> String {
        // Space Lua directives (`${ … }`) can't be evaluated by a native read
        // client, so resolve them to their fallback text (or nothing) before any
        // line-based processing. Doing this first also prevents the wiki-link
        // regex from mangling Lua long brackets such as `query[[ … ]]`.
        let withoutDirectives = renderingLuaDirectives(in: source)

        var isInsideFence = false
        var renderedLines: [String] = []
        let lines = withoutDirectives.split(separator: "\n", omittingEmptySubsequences: false)

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

    /// Replaces Space Lua directives (`${ … }`) with their fallback text.
    ///
    /// A native read-only client can't run the Lua engine, so a directive such
    /// as `${some(query[[ … ]]) or "No notes yet"}` is reduced to its trailing
    /// `or "…"` fallback string, and directives without a fallback (for example
    /// `${widgets.commandButton "Quick Note"}`) are removed entirely. The scan
    /// is fence-aware and balances braces while skipping Lua string literals and
    /// long brackets, so directives may span multiple lines.
    private static func renderingLuaDirectives(in source: String) -> String {
        let chars = Array(source)
        let count = chars.count
        var result = ""
        result.reserveCapacity(count)

        var index = 0
        var isInsideFence = false
        var isAtLineStart = true

        while index < count {
            if isAtLineStart, isFenceLine(chars, at: index) {
                isInsideFence.toggle()
            }

            if !isInsideFence,
               chars[index] == "$",
               index + 1 < count,
               chars[index + 1] == "{",
               let directive = parseLuaDirective(chars, openingAt: index) {
                result.append(contentsOf: directive.replacement)
                index = directive.endIndex
                isAtLineStart = false
                continue
            }

            let character = chars[index]
            result.append(character)
            isAtLineStart = character == "\n"
            index += 1
        }

        return result
    }

    /// Reports whether the line beginning at `index` opens or closes a code
    /// fence (``` ``` ``` or `~~~`, ignoring leading whitespace).
    private static func isFenceLine(_ chars: [Character], at index: Int) -> Bool {
        var cursor = index
        while cursor < chars.count, chars[cursor] == " " || chars[cursor] == "\t" {
            cursor += 1
        }
        guard cursor + 2 < chars.count else {
            return false
        }
        let fence: Character = chars[cursor] == "`" ? "`" : (chars[cursor] == "~" ? "~" : " ")
        guard fence != " " else {
            return false
        }
        return chars[cursor + 1] == fence && chars[cursor + 2] == fence
    }

    /// Parses a `${ … }` directive starting at `openingAt` (where `chars[openingAt]`
    /// is `$` and the next character is `{`). Returns the index just past the
    /// closing brace and the text it should be replaced with, or `nil` if the
    /// braces are unbalanced (in which case the source is left untouched).
    private static func parseLuaDirective(
        _ chars: [Character],
        openingAt openingIndex: Int
    ) -> (endIndex: Int, replacement: String)? {
        let count = chars.count
        var cursor = openingIndex + 2
        var depth = 1

        while cursor < count {
            let character = chars[cursor]

            if character == "\"" || character == "'" {
                cursor = endOfStringLiteral(chars, openingQuoteAt: cursor)
                continue
            }

            if character == "[", let longBracketEnd = endOfLongBracket(chars, openingAt: cursor) {
                cursor = longBracketEnd
                continue
            }

            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    let inner = String(chars[(openingIndex + 2)..<cursor])
                    return (cursor + 1, fallbackText(in: inner))
                }
            }

            cursor += 1
        }

        return nil
    }

    /// Returns the index just past the closing quote of a Lua string literal
    /// whose opening quote is at `openingQuoteAt`, honoring backslash escapes.
    private static func endOfStringLiteral(
        _ chars: [Character],
        openingQuoteAt openingIndex: Int
    ) -> Int {
        let count = chars.count
        let quote = chars[openingIndex]
        var cursor = openingIndex + 1

        while cursor < count {
            if chars[cursor] == "\\" {
                cursor += 2
                continue
            }
            if chars[cursor] == quote {
                return cursor + 1
            }
            cursor += 1
        }

        return count
    }

    /// If a Lua long bracket (`[[`, `[=[`, … ) opens at `openingAt`, returns the
    /// index just past its matching close bracket. Returns `nil` when `openingAt`
    /// is an ordinary `[` rather than a long bracket.
    private static func endOfLongBracket(_ chars: [Character], openingAt openingIndex: Int) -> Int? {
        let count = chars.count
        var cursor = openingIndex + 1
        var level = 0
        while cursor < count, chars[cursor] == "=" {
            level += 1
            cursor += 1
        }
        guard cursor < count, chars[cursor] == "[" else {
            return nil
        }

        cursor += 1
        while cursor < count {
            if chars[cursor] == "]" {
                var lookahead = cursor + 1
                var closingLevel = 0
                while lookahead < count, chars[lookahead] == "=" {
                    closingLevel += 1
                    lookahead += 1
                }
                if closingLevel == level, lookahead < count, chars[lookahead] == "]" {
                    return lookahead + 1
                }
            }
            cursor += 1
        }

        return count
    }

    /// Extracts the trailing `or "…"` / `or '…'` fallback string from a directive
    /// body, returning an empty string when there is none.
    private static func fallbackText(in directive: String) -> String {
        let pattern = #"\bor\s+(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)')\s*$"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return ""
        }

        let source = directive as NSString
        guard let match = expression.firstMatch(
            in: directive,
            range: NSRange(location: 0, length: source.length)
        ) else {
            return ""
        }

        let doubleQuoted = substring(for: match.range(at: 1), in: source)
        let value = doubleQuoted.isEmpty
            ? substring(for: match.range(at: 2), in: source)
            : doubleQuoted
        return value
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
