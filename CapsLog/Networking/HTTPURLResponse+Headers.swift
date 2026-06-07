import Foundation

extension HTTPURLResponse {
    nonisolated func stringHeader(forKey key: String) -> String? {
        guard let raw = value(forHTTPHeaderField: key) else {
            return nil
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated func int64Header(forKey key: String) -> Int64? {
        stringHeader(forKey: key).flatMap(Int64.init)
    }
}
