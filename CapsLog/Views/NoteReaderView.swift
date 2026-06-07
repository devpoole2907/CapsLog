import SwiftUI
import Textual

struct NoteReaderView: View {
    let presentation: NotePresentation
    let isShowingCachedData: Bool
    let imageAttachmentLoader: SilverBulletImageAttachmentLoader
    let openPage: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(presentation.title)
                    .font(.largeTitle)
                    .bold()
                    .textSelection(.enabled)

                if presentation.markdown.isEmpty {
                    Text("No additional text")
                        .foregroundStyle(.secondary)
                } else {
                    StructuredText(markdown: presentation.markdown)
                        .font(.body)
                        .textual.structuredTextStyle(.default)
                        .textual.textSelection(.enabled)
                        .textual.overflowMode(.wrap)
                        .textual.imageAttachmentLoader(imageAttachmentLoader)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 60)
        }
        .scrollContentBackground(.visible)
        .environment(\.openURL, OpenURLAction(handler: handleURL))
        .overlay(alignment: .top) {
            if isShowingCachedData {
                StatusPill(
                    text: "Offline copy",
                    systemImage: "wifi.slash",
                    tint: .orange
                )
                .padding(.top)
            }
        }
    }

    private func handleURL(_ url: URL) -> OpenURLAction.Result {
        guard let reference = SilverBulletMarkdownRenderer.pageReference(from: url) else {
            return .systemAction(url)
        }

        openPage(reference)
        return .handled
    }
}
