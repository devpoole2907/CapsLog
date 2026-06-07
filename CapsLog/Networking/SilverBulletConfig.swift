import Foundation

nonisolated struct SilverBulletConfig: Sendable, Hashable {
    let baseURL: URL
    let token: String

    init(baseURL: URL, token: String) {
        var string = baseURL.absoluteString
        while string.hasSuffix("/") {
            string.removeLast()
        }
        self.baseURL = URL(string: string) ?? baseURL
        self.token = token
    }

    init?(rawURL: String, token: String) {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            return nil
        }

        components.scheme = scheme
        guard let url = components.url else {
            return nil
        }

        self.init(baseURL: url, token: token)
    }
}
