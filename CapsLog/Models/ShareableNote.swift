import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ShareableNote: Sendable, Transferable {
    let title: String
    let path: String
    let body: String?
    let client: SilverBulletClient?

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .utf8PlainText) { note in
            let text = await note.exportText()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(note.suggestedFileName)
            try text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }

    init(
        title: String,
        path: String,
        body: String? = nil,
        client: SilverBulletClient? = nil
    ) {
        self.title = title
        self.path = path
        self.body = body
        self.client = client
    }

    /// The file name to suggest when exporting, e.g. "index.md".
    private var suggestedFileName: String {
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? "note.md" : name
    }

    private var fallbackText: String {
        if let body, !body.isEmpty {
            return body
        }

        return path
    }

    private func exportText() async -> String {
        if let body, !body.isEmpty {
            return body
        }

        guard let client else {
            return fallbackText
        }

        do {
            return try await client.read(path: path).text
        } catch {
            return fallbackText
        }
    }
}
