import Foundation

nonisolated struct SpaceFile: Sendable, Identifiable, Hashable {
    let path: String
    let lastModified: Int64
    let permission: FilePermission
    let size: Int64?

    var id: String { path }

    var title: String {
        let last = (path as NSString).lastPathComponent
        if last.lowercased().hasSuffix(".md") {
            return String(last.dropLast(3))
        }
        return last
    }

    var folder: String {
        (path as NSString).deletingLastPathComponent
    }

    var isMarkdown: Bool {
        path.lowercased().hasSuffix(".md")
    }

    var lastModifiedDate: Date {
        Date(timeIntervalSince1970: TimeInterval(lastModified) / 1000.0)
    }
}

extension SpaceFile: Decodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case path
        case lastModified
        case perm
        case permission
        case size
        case contentLength
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        if let name = try c.decodeIfPresent(String.self, forKey: .name) {
            path = name
        } else if let p = try c.decodeIfPresent(String.self, forKey: .path) {
            path = p
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .name, in: c,
                debugDescription: "Listing entry missing both 'name' and 'path'."
            )
        }

        lastModified = (try c.decodeIfPresent(Int64.self, forKey: .lastModified)) ?? 0

        let permRaw = try c.decodeIfPresent(String.self, forKey: .perm)
            ?? c.decodeIfPresent(String.self, forKey: .permission)
        permission = FilePermission(rawHeader: permRaw)

        size = try c.decodeIfPresent(Int64.self, forKey: .size)
            ?? c.decodeIfPresent(Int64.self, forKey: .contentLength)
    }
}
