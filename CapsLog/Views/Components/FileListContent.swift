import SwiftUI

struct FileListContent: View {
    let files: [SpaceFile]
    let filterText: String

    var body: some View {
        if files.isEmpty {
            if filterText.isEmpty {
                ContentUnavailableView(
                    "No Pages",
                    systemImage: "doc.text",
                    description: Text("This space has no Markdown pages.")
                )
            } else {
                ContentUnavailableView.search
            }
        } else {
            List(files) { file in
                NavigationLink(value: PageRoute(path: file.path)) {
                    FileRow(file: file)
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}
