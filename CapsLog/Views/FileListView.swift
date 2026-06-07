import SwiftUI

struct FileListView: View {
    @State private var viewModel: FileListViewModel
    @State private var isShowingNewFile = false
    @State private var selectedFileIDs = Set<SpaceFile.ID>()
    @State private var editMode: EditMode = .inactive
    @State private var filePendingDeletion: SpaceFile?
    @State private var filesPendingDeletion: [SpaceFile] = []
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingSelectedDeleteConfirmation = false
    @State private var deleteErrorMessage: String?

    let openPage: (PageRoute) -> Void

    init(
        viewModel: FileListViewModel,
        openPage: @escaping (PageRoute) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.openPage = openPage
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            switch viewModel.state {
            case .idle:
                ProgressView("Loading pages")
            case .loading where viewModel.files.isEmpty:
                ProgressView("Loading pages")
            case .failed(let message):
                ErrorView(message: message, retry: refresh)
            default:
                FileListContent(
                    files: viewModel.visibleFiles,
                    filterText: viewModel.filterText,
                    shareableNote: viewModel.shareableNote,
                    previewForFile: notePreview,
                    requestDeleteFile: requestDelete,
                    selectedFileIDs: $selectedFileIDs
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("CapsLog")
        .navigationSubtitle(notesCountSubtitle(for: viewModel.visibleFiles.count))
        .searchable(text: $viewModel.filterText, prompt: "Filter by path")
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editMode.isEditing ? "Done" : "Select", action: toggleSelectionMode)
            }

            if editMode.isEditing {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        if allVisibleFilesSelected {
                            deselectAllVisibleFiles()
                        } else {
                            selectAllVisibleFiles()
                        }
                    } label: {
                        Label(allVisibleFilesSelected ? "Deselect All" : "Select All", systemImage: "checkmark.circle")
                    }
                    .labelStyle(.titleOnly)
                    .disabled(viewModel.visibleFiles.isEmpty)
                }
                ToolbarSpacer(placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        requestDeleteSelectedFiles()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selectedVisibleFiles.isEmpty)
                }
            } else {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        isShowingNewFile = true
                    } label: {
                        Label("New", systemImage: "square.and.pencil")
                    }
                }
            }
        }
        .toolbar(removing: editMode.isEditing ? .search : nil)
        .sheet(isPresented: $isShowingNewFile) {
            NavigationStack {
                NewFileView(
                    existingPaths: viewModel.files.map(\.path),
                    suggestedPath: viewModel.suggestedNewFilePath,
                    createFile: viewModel.createFile,
                    openFile: openCreatedFile
                )
            }
        }
        .alert("Delete Note?", isPresented: $isShowingDeleteConfirmation, presenting: filePendingDeletion) { file in
            Button("Delete", role: .destructive) {
                delete(file)
            }
            Button("Cancel", role: .cancel) {
                filePendingDeletion = nil
                isShowingDeleteConfirmation = false
            }
        } message: { file in
            Text("\(file.title) will be permanently deleted.")
        }
        .alert("Delete Selected Notes?", isPresented: $isShowingSelectedDeleteConfirmation) {
            Button("Delete", role: .destructive, action: deleteSelectedFiles)
            Button("Cancel", role: .cancel) {
                filesPendingDeletion = []
                isShowingSelectedDeleteConfirmation = false
            }
        } message: {
            Text(selectedDeleteConfirmationMessage)
        }
        .alert("Couldn't Delete Note", isPresented: isShowingDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let deleteErrorMessage {
                Text(deleteErrorMessage)
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadInitial()
        }
        .overlay(alignment: .top) {
            if viewModel.isShowingCachedData {
                StatusPill(
                    text: "Showing cached data",
                    systemImage: "wifi.slash",
                    tint: .orange
                )
                .padding(.top)
            } else if viewModel.pendingWriteCount > 0 {
                StatusPill(
                    text: "\(viewModel.pendingWriteCount) queued",
                    systemImage: "tray.and.arrow.up",
                    tint: .orange
                )
                .padding(.top)
            }
        }
    }

    private var isShowingDeleteError: Binding<Bool> {
        Binding {
            deleteErrorMessage != nil
        } set: { isPresented in
            if !isPresented {
                deleteErrorMessage = nil
            }
        }
    }

    private var selectedVisibleFiles: [SpaceFile] {
        viewModel.visibleFiles.filter { selectedFileIDs.contains($0.id) }
    }

    private var selectedDeleteConfirmationMessage: String {
        let count = filesPendingDeletion.count
        let noteLabel = count == 1 ? "note" : "notes"
        return "\(count) selected \(noteLabel) will be permanently deleted."
    }

    private func refresh() {
        Task {
            await viewModel.refresh()
        }
    }

    private func toggleSelectionMode() {
        withAnimation {
            if editMode.isEditing {
                editMode = .inactive
                selectedFileIDs.removeAll()
            } else {
                editMode = .active
            }
        }
    }

    private var allVisibleFilesSelected: Bool {
        let visibleIDs = Set(viewModel.visibleFiles.map(\.id))
        return !visibleIDs.isEmpty && visibleIDs.isSubset(of: selectedFileIDs)
    }

    private func selectAllVisibleFiles() {
        selectedFileIDs = Set(viewModel.visibleFiles.map(\.id))
    }

    private func deselectAllVisibleFiles() {
        selectedFileIDs.subtract(viewModel.visibleFiles.map(\.id))
    }

    private func requestDeleteSelectedFiles() {
        let selectedFiles = selectedVisibleFiles
        guard !selectedFiles.isEmpty else {
            return
        }

        filesPendingDeletion = selectedFiles
        isShowingSelectedDeleteConfirmation = true
    }

    private func requestDelete(_ file: SpaceFile) {
        filePendingDeletion = file
        isShowingDeleteConfirmation = true
    }

    private func notePreview(for file: SpaceFile) -> NoteContextPreview {
        NoteContextPreview(
            viewModel: viewModel.makePreviewViewModel(for: file),
            fallbackTitle: file.title
        )
    }

    private func delete(_ file: SpaceFile) {
        filePendingDeletion = nil
        isShowingDeleteConfirmation = false

        Task {
            if let errorMessage = await viewModel.deleteFile(file) {
                deleteErrorMessage = errorMessage
            } else {
                selectedFileIDs.remove(file.id)
            }
        }
    }

    private func deleteSelectedFiles() {
        let files = filesPendingDeletion
        filesPendingDeletion = []
        isShowingSelectedDeleteConfirmation = false

        Task {
            var failedMessages: [String] = []

            for file in files {
                if let errorMessage = await viewModel.deleteFile(file) {
                    failedMessages.append(errorMessage)
                } else {
                    selectedFileIDs.remove(file.id)
                }
            }

            if let firstMessage = failedMessages.first {
                deleteErrorMessage = firstMessage
            }
        }
    }

    private func notesCountSubtitle(for count: Int) -> String {
        count == 1 ? "1 note" : "\(count) notes"
    }

    private func openCreatedFile(_ path: String) {
        openPage(PageRoute(path: path, startsEditing: true))
    }
}
