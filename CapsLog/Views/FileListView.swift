import SwiftUI

struct FileListView: View {
    @State private var viewModel: FileListViewModel
    @State private var isShowingNewFile = false

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
                FileListContent(files: viewModel.visibleFiles, filterText: viewModel.filterText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("CapsLog")
        .searchable(text: $viewModel.filterText, prompt: "Filter by path")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New File", systemImage: "plus") {
                    isShowingNewFile = true
                }
            }
        }
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

    private func refresh() {
        Task {
            await viewModel.refresh()
        }
    }

    private func openCreatedFile(_ path: String) {
        openPage(PageRoute(path: path, startsEditing: true))
    }
}
