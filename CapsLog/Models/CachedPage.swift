import Foundation
import SwiftData

@Model
final class CachedPage {
    @Attribute(.unique) var path: String
    var body: String
    var remoteLastModified: Int64?
    var permissionRaw: String
    var syncedAt: Date

    init(
        path: String,
        body: String,
        remoteLastModified: Int64?,
        permissionRaw: String,
        syncedAt: Date = .now
    ) {
        self.path = path
        self.body = body
        self.remoteLastModified = remoteLastModified
        self.permissionRaw = permissionRaw
        self.syncedAt = syncedAt
    }

    var permission: FilePermission {
        FilePermission(rawHeader: permissionRaw)
    }
}
