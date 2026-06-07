import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class FileListViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: LoadState = .idle
    private(set) var files: [SpaceFile] = []
    private(set) var isShowingCachedData = false
    private(set) var pendingWriteCount = 0
    var filterText = ""

    private let client: SilverBulletClient
    private let modelContext: ModelContext

    init(client: SilverBulletClient, modelContext: ModelContext) {
        self.client = client
        self.modelContext = modelContext
    }

    var visibleFiles: [SpaceFile] {
        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        let markdown = files.filter { $0.isMarkdown }

        // Hide locked pages (the bundled `Library/Std`/API docs are served as
        // read-only). If every page is read-only — e.g. the whole space is in
        // read-only mode — fall back to showing them so the list isn't empty.
        let writable = markdown.filter { $0.permission.isWritable }
        let base = writable.isEmpty ? markdown : writable

        return base
            .filter { trimmed.isEmpty || $0.path.localizedStandardContains(trimmed) }
            .sorted { $0.lastModified > $1.lastModified }
    }

    var suggestedNewFilePath: String {
        let existingPaths = Set(files.map(\.path))
        var suffix = 1

        while true {
            let candidate = suffix == 1
                ? "Untitled.md"
                : "Untitled \(suffix).md"

            if !existingPaths.contains(candidate) {
                return candidate
            }

            suffix += 1
        }
    }

    func loadInitial() async {
        loadFromCache()
        updatePendingWriteCount()
        await refresh()
    }

    func refresh() async {
        state = .loading

        do {
            files = try await client.list()
            isShowingCachedData = false
            state = .loaded
            await flushPendingWrites()
            persistListing(files)
        } catch let error as SilverBulletError {
            if !files.isEmpty {
                isShowingCachedData = true
                state = .loaded
            } else {
                state = .failed(error.userMessage)
            }
        } catch is CancellationError {
            state = files.isEmpty ? .idle : .loaded
        } catch {
            if !files.isEmpty {
                isShowingCachedData = true
                state = .loaded
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func createFile(path: String) async -> String? {
        guard !files.contains(where: { $0.path == path }) else {
            return "A file at this path already exists."
        }

        do {
            _ = try await client.readMeta(path: path)
            return "A file at this path already exists."
        } catch let error as SilverBulletError {
            switch error {
            case .notFound:
                break
            default:
                return error.userMessage
            }
        } catch is CancellationError {
            return "File creation was cancelled."
        } catch {
            return error.localizedDescription
        }

        do {
            let metadata = try await client.write(path: path, content: "")
            cacheCreatedFile(path: path, metadata: metadata)
            return nil
        } catch let error as SilverBulletError {
            return error.userMessage
        } catch is CancellationError {
            return "File creation was cancelled."
        } catch {
            return error.localizedDescription
        }
    }

    private func loadFromCache() {
        let descriptor = FetchDescriptor<CachedFile>()
        if let cached = try? modelContext.fetch(descriptor), !cached.isEmpty {
            files = cached.map { $0.toSpaceFile() }
            isShowingCachedData = true
            if state == .idle {
                state = .loaded
            }
        }
    }

    private func persistListing(_ remote: [SpaceFile]) {
        let existing = (try? modelContext.fetch(FetchDescriptor<CachedFile>())) ?? []
        for file in existing {
            modelContext.delete(file)
        }
        for file in remote {
            modelContext.insert(CachedFile(from: file))
        }
        try? modelContext.save()
    }

    private func flushPendingWrites() async {
        let descriptor = FetchDescriptor<PendingWrite>(
            sortBy: [SortDescriptor(\.queuedAt)]
        )
        guard let pendingWrites = try? modelContext.fetch(descriptor) else {
            return
        }

        for pending in pendingWrites {
            do {
                let current = try await client.readMeta(path: pending.path)
                if let base = pending.baseRemoteLastModified,
                   let remote = current.lastModified,
                   base != remote {
                    continue
                }

                let written = try await client.write(path: pending.path, content: pending.body)
                cacheFlushedWrite(pending, metadata: written)
                modelContext.delete(pending)
            } catch let error as SilverBulletError {
                if error == .unauthorized || error.isRetryableOfflineFailure {
                    break
                }
            } catch {
                break
            }
        }

        try? modelContext.save()
        updatePendingWriteCount()
    }

    private func cacheFlushedWrite(_ pending: PendingWrite, metadata: FileMetadata) {
        let target = pending.path
        let descriptor = FetchDescriptor<CachedPage>(
            predicate: #Predicate { $0.path == target }
        )
        let cached = try? modelContext.fetch(descriptor).first

        if let cached {
            cached.body = pending.body
            cached.remoteLastModified = metadata.lastModified
            cached.permissionRaw = metadata.permission.rawValue
            cached.syncedAt = .now
        } else {
            modelContext.insert(
                CachedPage(
                    path: pending.path,
                    body: pending.body,
                    remoteLastModified: metadata.lastModified,
                    permissionRaw: metadata.permission.rawValue
                )
            )
        }

        guard let index = files.firstIndex(where: { $0.path == pending.path }) else {
            return
        }

        let old = files[index]
        files[index] = SpaceFile(
            path: old.path,
            lastModified: metadata.lastModified ?? old.lastModified,
            permission: metadata.permission,
            size: metadata.contentLength ?? old.size
        )
    }

    private func cacheCreatedFile(path: String, metadata: FileMetadata) {
        let createdFile = SpaceFile(
            path: path,
            lastModified: metadata.lastModified ?? Self.currentTimestampMilliseconds(),
            permission: metadata.permission,
            size: metadata.contentLength ?? 0
        )

        if let index = files.firstIndex(where: { $0.path == path }) {
            files[index] = createdFile
        } else {
            files.append(createdFile)
        }

        persistListing(files)
    }

    private func updatePendingWriteCount() {
        pendingWriteCount = (try? modelContext.fetchCount(
            FetchDescriptor<PendingWrite>()
        )) ?? 0
    }

    nonisolated private static func currentTimestampMilliseconds() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
