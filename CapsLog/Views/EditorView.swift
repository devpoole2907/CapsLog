import SwiftUI

struct EditorView: View {
    @State private var viewModel: EditorViewModel
    @State private var isEditing: Bool
    @State private var isEditorFocused = false

    let openPage: (String) -> Void

    init(
        viewModel: EditorViewModel,
        startsEditing: Bool = false,
        openPage: @escaping (String) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        _isEditing = State(initialValue: startsEditing)
        self.openPage = openPage
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            switch viewModel.loadState {
            case .loading where viewModel.text.isEmpty:
                ProgressView("Loading page")
            case .failed(let message):
                ErrorView(message: message, retry: reload)
            default:
                if isEditing {
                    NoteSourceEditorView(
                        text: $viewModel.text,
                        isFocused: $isEditorFocused,
                        isReadOnly: viewModel.isReadOnly
                    )
                } else {
                    NoteReaderView(
                        presentation: NotePresentation(
                            source: viewModel.text,
                            fallbackTitle: pageTitle
                        ),
                        isShowingCachedData: viewModel.isShowingCachedData,
                        imageAttachmentLoader: viewModel.imageAttachmentLoader,
                        openPage: openReference
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .principal) {
                    EditorSaveStatusView(
                        state: viewModel.saveState,
                        isReadOnly: viewModel.isReadOnly
                    )
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(
                    item: shareableNote,
                    subject: Text(pageTitle),
                    preview: SharePreview(pageTitle)
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .disabled(isShareDisabled)

                if isEditing {
                    Button("Done", systemImage: "checkmark", action: finishEditing)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Edit", systemImage: "pencil", action: beginEditing)
                        .disabled(viewModel.isReadOnly)
                }
            }
        }
        .task {
            await viewModel.load()
            focusEditorIfNeeded()
        }
        .onChange(of: viewModel.text) {
            viewModel.textDidChange()
        }
        .alert("Edit Conflict", isPresented: $viewModel.isConflictPresented) {
            Button("Keep Mine") {
                Task {
                    await viewModel.resolveConflictKeepingLocal()
                }
            }
            Button("Keep Server", role: .destructive) {
                Task {
                    await viewModel.resolveConflictKeepingRemote()
                }
            }
            Button("Cancel", role: .cancel, action: viewModel.dismissConflict)
        } message: {
            Text("This page changed on the server after you opened it.")
        }
    }

    private var pageTitle: String {
        let last = (viewModel.path as NSString).lastPathComponent
        return last.lowercased().hasSuffix(".md")
            ? String(last.dropLast(3))
            : last
    }

    private var shareableNote: ShareableNote {
        ShareableNote(
            title: pageTitle,
            path: viewModel.path,
            body: viewModel.text
        )
    }

    private var isShareDisabled: Bool {
        if case .loading = viewModel.loadState, viewModel.text.isEmpty {
            return true
        }

        return false
    }

    private func beginEditing() {
        withAnimation(.snappy) {
            isEditing = true
        }

        Task {
            await Task.yield()
            isEditorFocused = true
        }
    }

    private func focusEditorIfNeeded() {
        guard isEditing else {
            return
        }

        Task {
            await Task.yield()
            isEditorFocused = true
        }
    }

    private func finishEditing() {
        isEditorFocused = false
        withAnimation(.snappy) {
            isEditing = false
        }

        Task {
            await viewModel.save()
        }
    }

    private func openReference(_ reference: String) {
        guard let path = SilverBulletMarkdownRenderer.resolvePagePath(
            reference: reference,
            from: viewModel.path
        ), path != viewModel.path else {
            return
        }

        openPage(path)
    }

    private func reload() {
        Task {
            await viewModel.load()
        }
    }
}
