import Foundation

/// A titled run of files that share a date bucket (e.g. "Today", "April", "2025").
nonisolated struct FileListSection: Identifiable, Sendable {
    let id: String
    let title: String
    let files: [SpaceFile]
}

/// Buckets files into date sections and formats per-row date subtitles, mirroring
/// the grouping used by the system Files and Notes apps.
nonisolated enum FileListGrouping {
    /// Groups files into date sections ordered most-recent first.
    static func sections(
        from files: [SpaceFile],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [FileListSection] {
        let sorted = files.sorted { $0.lastModified > $1.lastModified }

        var order: [String] = []
        var buckets: [String: [SpaceFile]] = [:]

        for file in sorted {
            let title = sectionTitle(for: file.lastModifiedDate, now: now, calendar: calendar)
            if buckets[title] == nil {
                order.append(title)
            }
            buckets[title, default: []].append(file)
        }

        return order.map { FileListSection(id: $0, title: $0, files: buckets[$0] ?? []) }
    }

    static func sectionTitle(for date: Date, now: Date, calendar: Calendar) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)

        if startOfDate >= startOfToday {
            return "Today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
           startOfDate >= yesterday {
            return "Yesterday"
        }
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday),
           startOfDate >= weekAgo {
            return "Previous 7 Days"
        }
        if let monthAgo = calendar.date(byAdding: .day, value: -30, to: startOfToday),
           startOfDate >= monthAgo {
            return "Previous 30 Days"
        }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return date.formatted(.dateTime.month(.wide))
        }
        return date.formatted(.dateTime.year())
    }

    /// A compact, per-row subtitle: a time for today, a weekday name within the
    /// last week (including yesterday), otherwise a `dd/MM/yyyy` date.
    static func rowSubtitle(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)

        if startOfDate >= startOfToday {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday),
           startOfDate >= weekAgo {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(day: .twoDigits)/\(month: .twoDigits)/\(year: .defaultDigits)",
                timeZone: calendar.timeZone,
                calendar: calendar
            )
        )
    }
}
