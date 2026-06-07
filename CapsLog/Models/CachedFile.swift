import Foundation
import SwiftData

@Model
final class CachedFile {
    @Attribute(.unique) var path: String
    var lastModified: Int64
    var permissionRaw: String
    var size: Int64?
    var cachedAt: Date

    init(
        path: String,
        lastModified: Int64,
        permissionRaw: String,
        size: Int64?,
        cachedAt: Date = .now
    ) {
        self.path = path
        self.lastModified = lastModified
        self.permissionRaw = permissionRaw
        self.size = size
        self.cachedAt = cachedAt
    }

    convenience init(from file: SpaceFile, cachedAt: Date = .now) {
        self.init(
            path: file.path,
            lastModified: file.lastModified,
            permissionRaw: file.permission.rawValue,
            size: file.size,
            cachedAt: cachedAt
        )
    }

    func toSpaceFile() -> SpaceFile {
        SpaceFile(
            path: path,
            lastModified: lastModified,
            permission: FilePermission(rawHeader: permissionRaw),
            size: size
        )
    }
}
