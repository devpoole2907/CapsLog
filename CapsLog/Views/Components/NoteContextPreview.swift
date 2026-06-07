import SwiftUI

struct NoteContextPreview: View {
    @State private var viewModel: EditorViewModel

    let fallbackTitle: String

    init(viewModel: EditorViewModel, fallbackTitle: String) {
        _viewModel = State(initialValue: viewModel)
        self.fallbackTitle = fallbackTitle
    }

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .loading where viewModel.text.isEmpty:
                ProgressView("Loading page")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView(
                    "Preview Unavailable",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(message)
                )
            default:
                NoteReaderView(
                    presentation: NotePresentation(
                        source: viewModel.text,
                        fallbackTitle: fallbackTitle
                    ),
                    isShowingCachedData: viewModel.isShowingCachedData,
                    imageAttachmentLoader: viewModel.imageAttachmentLoader,
                    openPage: { _ in }
                )
            }
        }
        .frame(width: 320, height: 420)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
            await viewModel.load()
        }
    }
}
