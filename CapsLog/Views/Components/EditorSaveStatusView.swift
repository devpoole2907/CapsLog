import SwiftUI

struct EditorSaveStatusView: View {
    let state: EditorViewModel.SaveState
    let isReadOnly: Bool

    var body: some View {
        if isReadOnly {
            StatusPill(text: "Read-only", systemImage: "lock.fill", tint: .gray)
        } else {
            switch state {
            case .clean:
                EmptyView()
            case .dirty:
                StatusPill(text: "Unsaved", systemImage: "pencil", tint: .orange)
            case .saving:
                StatusPill(
                    text: "Saving",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .blue
                )
            case .saved:
                StatusPill(
                    text: "Saved",
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                )
            case .queuedOffline:
                StatusPill(
                    text: "Queued",
                    systemImage: "tray.and.arrow.up",
                    tint: .orange
                )
            case .failed:
                StatusPill(
                    text: "Save failed",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .red
                )
            case .conflict:
                StatusPill(
                    text: "Conflict",
                    systemImage: "arrow.triangle.branch",
                    tint: .red
                )
            }
        }
    }
}
