import SwiftData
import SwiftUI

struct FileListContainerView: View {
    let client: SilverBulletClient

    @Environment(\.modelContext) private var modelContext
    @Environment(ConnectionViewModel.self) private var connection
    @State private var isShowingSettings = false
    @State private var navigationPath: [PageRoute] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            FileListView(
                viewModel: FileListViewModel(
                    client: client,
                    modelContext: modelContext
                ),
                openPage: openPage
            )
            .navigationDestination(for: PageRoute.self, destination: noteDestination)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Connection", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                NavigationStack {
                    ConnectionSettingsView(viewModel: connection)
                }
            }
        }
    }

    private func noteDestination(for route: PageRoute) -> some View {
        EditorView(
            viewModel: EditorViewModel(
                path: route.path,
                client: client,
                modelContext: modelContext
            ),
            startsEditing: route.startsEditing,
            openPage: { path in
                openPage(PageRoute(path: path))
            }
        )
    }

    private func openPage(_ route: PageRoute) {
        navigationPath.append(route)
    }
}
