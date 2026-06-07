nonisolated struct ServerConfiguration: Decodable, Sendable {
    let readOnly: Bool
    let indexPage: String
}
