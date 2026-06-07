nonisolated enum FilePermission: String, Sendable, Codable, Hashable {
    case readWrite = "rw"
    case readOnly = "ro"

    init(rawHeader: String?) {
        guard let rawHeader,
              let value = FilePermission(rawValue: rawHeader.lowercased()) else {
            self = .readOnly
            return
        }
        self = value
    }

    var isWritable: Bool {
        self == .readWrite
    }
}
