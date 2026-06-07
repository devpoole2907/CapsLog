import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class EditorViewModel {
    enum SaveState: Equatable {
        case clean
        case dirty
        case saving
        case saved
        case queuedOffline
        case failed(String)
        case conflict
    }

    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    let path: String
    var text = ""
    var isConflictPresented = false

    private(set) var saveState: SaveState = .clean
    private(set) var loadState: LoadState = .loading
    private(set) var isReadOnly = false
    private(set) var isShowingCachedData = false
    private(set) var baseRemoteLastModified: Int64?

    private var savedText = ""
    private var autosaveTask: Task<Void, Never>?
    private let client: SilverBulletClient
    private let modelContext: ModelContext

    init(path: String, client: SilverBulletClient, modelContext: ModelContext) {
        self.path = path
        self.client = client
        self.modelContext = modelContext
    }

    var imageAttachmentLoader: SilverBulletImageAttachmentLoader {
        SilverBulletImageAttachmentLoader(client: client, pagePath: path)
    }

    func textDidChange() {
        guard !isReadOnly else {
            return
        }

        if text == savedText, fetchPendingWrite() == nil {
            if saveState == .dirty {
                saveState = .clean
            }
            autosaveTask?.cancel()
            return
        }

        if saveState != .saving && saveState != .conflict {
            saveState = .dirty
        }
        scheduleAutosave()
    }

    func load() async {
        loadFromCache()
        await refreshFromServer()
    }

    func save() async {
        autosaveTask?.cancel()

        guard !isReadOnly else {
            saveState = .failed("This file is read-only.")
            return
        }

        let hasPendingWrite = fetchPendingWrite() != nil
        guard text != savedText || hasPendingWrite || saveState == .conflict else {
            saveState = .clean
            return
        }

        saveState = .saving

        do {
            let metadata = try await client.readMeta(path: path)
            if let base = baseRemoteLastModified,
               let current = metadata.lastModified,
               current != base {
                markConflict()
                return
            }
        } catch let error as SilverBulletError where !error.isRetryableOfflineFailure {
            saveState = .failed(error.userMessage)
            return
        } catch is CancellationError {
            saveState = .dirty
            return
        } catch {
            // A retryable metadata failure is followed by the write attempt.
        }

        do {
            let metadata = try await client.write(path: path, content: text)
            savedText = text
            baseRemoteLastModified = metadata.lastModified
            saveState = .saved
            isShowingCachedData = false
            cachePage(
                body: text,
                remoteLastModified: metadata.lastModified,
                permission: metadata.permission
            )
            removePendingWrite()
        } catch let error as SilverBulletError {
            if error.isRetryableOfflineFailure {
                queueOffline()
            } else {
                saveState = .failed(error.userMessage)
            }
        } catch is CancellationError {
            saveState = .dirty
        } catch {
            queueOffline()
        }
    }

    func resolveConflictKeepingLocal() async {
        isConflictPresented = false
        baseRemoteLastModified = try? await client.readMeta(path: path).lastModified
        saveState = .dirty
        await save()
    }

    func resolveConflictKeepingRemote() async {
        isConflictPresented = false

        do {
            let content = try await client.read(path: path)
            adoptRemote(content)
            removePendingWrite()
        } catch let error as SilverBulletError {
            saveState = .failed(error.userMessage)
        } catch is CancellationError {
            saveState = .conflict
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    func dismissConflict() {
        isConflictPresented = false
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1.2))
                await self?.save()
            } catch {
                // Cancellation is expected while the user continues typing.
            }
        }
    }

    private func loadFromCache() {
        let cached = fetchCachedPage()
        let pending = fetchPendingWrite()

        if let cached {
            savedText = cached.body
            baseRemoteLastModified = cached.remoteLastModified
            isReadOnly = !cached.permission.isWritable
            text = pending?.body ?? cached.body
            isShowingCachedData = true
            loadState = .loaded
        } else if let pending {
            text = pending.body
            savedText = ""
            baseRemoteLastModified = pending.baseRemoteLastModified
            isShowingCachedData = true
            loadState = .loaded
        }

        if pending != nil {
            saveState = .queuedOffline
        }
    }

    private func refreshFromServer() async {
        do {
            let content = try await client.read(path: path)
            let hasLocalChanges = text != savedText || fetchPendingWrite() != nil

            isReadOnly = !content.metadata.permission.isWritable
            isShowingCachedData = false

            if hasLocalChanges {
                if let base = baseRemoteLastModified,
                   let remote = content.metadata.lastModified,
                   remote != base {
                    markConflict()
                } else {
                    savedText = content.text
                    baseRemoteLastModified = content.metadata.lastModified
                    saveState = fetchPendingWrite() == nil ? .dirty : .queuedOffline
                    cachePage(
                        body: content.text,
                        remoteLastModified: content.metadata.lastModified,
                        permission: content.metadata.permission
                    )
                }
            } else {
                adoptRemote(content)
            }

            loadState = .loaded
        } catch let error as SilverBulletError {
            if loadState != .loaded {
                loadState = .failed(error.userMessage)
            } else {
                isShowingCachedData = true
            }
        } catch is CancellationError {
            return
        } catch {
            if loadState != .loaded {
                loadState = .failed(error.localizedDescription)
            }
        }
    }

    private func adoptRemote(_ content: FileContent) {
        text = content.text
        savedText = content.text
        baseRemoteLastModified = content.metadata.lastModified
        isReadOnly = !content.metadata.permission.isWritable
        isShowingCachedData = false
        saveState = .clean
        loadState = .loaded
        cachePage(
            body: content.text,
            remoteLastModified: content.metadata.lastModified,
            permission: content.metadata.permission
        )
    }

    private func markConflict() {
        autosaveTask?.cancel()
        saveState = .conflict
        isConflictPresented = true
    }

    private func queueOffline() {
        if let existing = fetchPendingWrite() {
            existing.body = text
            existing.baseRemoteLastModified = baseRemoteLastModified
            existing.queuedAt = .now
        } else {
            modelContext.insert(
                PendingWrite(
                    path: path,
                    body: text,
                    baseRemoteLastModified: baseRemoteLastModified
                )
            )
        }

        try? modelContext.save()
        saveState = .queuedOffline
        isShowingCachedData = true
    }

    private func fetchCachedPage() -> CachedPage? {
        let target = path
        let descriptor = FetchDescriptor<CachedPage>(
            predicate: #Predicate { $0.path == target }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func cachePage(
        body: String,
        remoteLastModified: Int64?,
        permission: FilePermission
    ) {
        if let existing = fetchCachedPage() {
            existing.body = body
            existing.remoteLastModified = remoteLastModified
            existing.permissionRaw = permission.rawValue
            existing.syncedAt = .now
        } else {
            modelContext.insert(
                CachedPage(
                    path: path,
                    body: body,
                    remoteLastModified: remoteLastModified,
                    permissionRaw: permission.rawValue
                )
            )
        }
        try? modelContext.save()
    }

    private func fetchPendingWrite() -> PendingWrite? {
        let target = path
        let descriptor = FetchDescriptor<PendingWrite>(
            predicate: #Predicate { $0.path == target }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func removePendingWrite() {
        if let pending = fetchPendingWrite() {
            modelContext.delete(pending)
            try? modelContext.save()
        }
    }
}
