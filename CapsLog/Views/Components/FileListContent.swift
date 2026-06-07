import Foundation
import SwiftUI

struct FileListContent: View {
    let files: [SpaceFile]
    let filterText: String
    let shareableNote: @MainActor (SpaceFile) -> ShareableNote
    let previewForFile: @MainActor (SpaceFile) -> NoteContextPreview
    let requestDeleteFile: @MainActor (SpaceFile) -> Void
    @Binding var selectedFileIDs: Set<SpaceFile.ID>

    @AppStorage("fileListPinnedPaths") private var pinnedPathsData = "[]"
    @State private var isPinnedSectionExpanded = true

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
            List(selection: $selectedFileIDs) {
                if !pinnedFiles.isEmpty {
                    Section {
                        if isPinnedSectionExpanded {
                            ForEach(pinnedFiles) { file in
                                fileLink(for: file)
                            }
                        }
                    } header: {
                        pinnedSectionHeader
                    }
                }

                ForEach(FileListGrouping.sections(from: unpinnedFiles)) { section in
                    Section(section.title) {
                        ForEach(section.files) { file in
                            fileLink(for: file)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var pinnedPaths: [String] {
        guard let data = pinnedPathsData.data(using: .utf8),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return paths
    }

    private var pinnedPathSet: Set<String> {
        Set(pinnedPaths)
    }

    private var pinnedFiles: [SpaceFile] {
        files.filter { pinnedPathSet.contains($0.path) }
    }

    private var unpinnedFiles: [SpaceFile] {
        files.filter { !pinnedPathSet.contains($0.path) }
    }

    private var pinnedSectionHeader: some View {
        Button {
            withAnimation {
                isPinnedSectionExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(isPinnedSectionExpanded ? 90 : 0))
                Text("Pinned")
                Text(pinnedFiles.count.formatted())
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(isPinnedSectionExpanded ? "Collapse pinned files" : "Expand pinned files")
    }

    @ViewBuilder
    private func fileLink(for file: SpaceFile) -> some View {
        NavigationLink(value: PageRoute(path: file.path)) {
            FileRow(file: file)
        }
        .tag(file.id)
        .contextMenu {
            ShareLink(
                item: shareableNote(file),
                subject: Text(file.title),
                preview: SharePreview(file.title)
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                togglePinned(file)
            } label: {
                Label(pinActionTitle(for: file), systemImage: pinActionImage(for: file))
            }

            if file.permission.isWritable {
                Divider()

                Button(role: .destructive) {
                    requestDeleteFile(file)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } preview: {
            previewForFile(file)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                togglePinned(file)
            } label: {
                Label(pinActionTitle(for: file), systemImage: pinActionImage(for: file))
            }
            .tint(isPinned(file) ? .gray : .yellow)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if file.permission.isWritable {
                Button(role: .destructive) {
                    requestDeleteFile(file)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            ShareLink(
                item: shareableNote(file),
                subject: Text(file.title),
                preview: SharePreview(file.title)
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        }
    }

    private func isPinned(_ file: SpaceFile) -> Bool {
        pinnedPathSet.contains(file.path)
    }

    private func togglePinned(_ file: SpaceFile) {
        let wasPinned = isPinned(file)
        var paths = pinnedPaths.filter { $0 != file.path }

        if !wasPinned {
            paths.insert(file.path, at: 0)
        }

        withAnimation {
            if !wasPinned {
                isPinnedSectionExpanded = true
            }
            savePinnedPaths(paths)
        }
    }

    private func pinActionTitle(for file: SpaceFile) -> String {
        isPinned(file) ? "Unpin" : "Pin"
    }

    private func pinActionImage(for file: SpaceFile) -> String {
        isPinned(file) ? "pin.slash" : "pin"
    }

    private func savePinnedPaths(_ paths: [String]) {
        var uniquePaths: [String] = []
        for path in paths where !uniquePaths.contains(path) {
            uniquePaths.append(path)
        }

        guard let data = try? JSONEncoder().encode(uniquePaths),
              let encoded = String(data: data, encoding: .utf8) else {
            return
        }

        pinnedPathsData = encoded
    }
}
