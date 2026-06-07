nonisolated struct ServerConfiguration: Decodable, Sendable {
    let readOnly: Bool
    let indexPage: String

    private enum CodingKeys: String, CodingKey {
        case readOnly
        case indexPage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Be tolerant of server-version differences: every field is optional so a
        // missing or renamed key never breaks listing, reading, or writing.
        readOnly = try container.decodeIfPresent(Bool.self, forKey: .readOnly) ?? false
        indexPage = try container.decodeIfPresent(String.self, forKey: .indexPage) ?? "index"
    }
}
