import SwiftUI

struct ConnectionStatusView: View {
    let status: ConnectionViewModel.Status

    var body: some View {
        switch status {
        case .unknown:
            EmptyView()
        case .checking:
            HStack {
                ProgressView()
                Text("Checking connection")
            }
        case .reachable:
            StatusPill(
                text: "Connected",
                systemImage: "checkmark.circle.fill",
                tint: .green
            )
        case .reachableWithWarning(let message):
            VStack(alignment: .leading) {
                StatusPill(
                    text: "Connected",
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                )
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .unreachable(let message):
            VStack(alignment: .leading) {
                StatusPill(
                    text: "Not connected",
                    systemImage: "xmark.circle.fill",
                    tint: .red
                )
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
