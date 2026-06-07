import Foundation

nonisolated struct FileMetadata: Sendable, Equatable {
    let lastModified: Int64?
    let created: Int64?
    let permission: FilePermission
    let contentLength: Int64?

    static func parse(from response: HTTPURLResponse) -> FileMetadata {
        FileMetadata(
            lastModified: response.int64Header(forKey: "X-Last-Modified"),
            created: response.int64Header(forKey: "X-Created"),
            permission: FilePermission(
                rawHeader: response.stringHeader(forKey: "X-Permission")
            ),
            contentLength: response.int64Header(forKey: "X-Content-Length")
        )
    }

    func applyingServerReadOnly(_ isReadOnly: Bool) -> FileMetadata {
        guard isReadOnly else {
            return self
        }

        return FileMetadata(
            lastModified: lastModified,
            created: created,
            permission: .readOnly,
            contentLength: contentLength
        )
    }
}
