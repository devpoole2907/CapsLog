import Foundation
import SwiftData

@Model
final class PendingWrite {
    @Attribute(.unique) var path: String
    var body: String
    var baseRemoteLastModified: Int64?
    var queuedAt: Date

    init(
        path: String,
        body: String,
        baseRemoteLastModified: Int64?,
        queuedAt: Date = .now
    ) {
        self.path = path
        self.body = body
        self.baseRemoteLastModified = baseRemoteLastModified
        self.queuedAt = queuedAt
    }
}
