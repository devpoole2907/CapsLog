import SwiftUI

struct ConnectionSettingsView: View {
    @Bindable var viewModel: ConnectionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                Text("Connect CapsLog to your SilverBullet server.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("https://notes.example.com", text: $viewModel.urlString)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            } header: {
                Text("Server URL")
            } footer: {
                Text("Include the scheme and any port or URL prefix.")
            }

            Section {
                SecureField("Optional bearer token", text: $viewModel.token)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            } header: {
                Text("Auth Token")
            } footer: {
                Text("Use the server's SB_AUTH_TOKEN. CapsLog stores it in Keychain.")
            }

            if viewModel.status != .unknown {
                Section {
                    ConnectionStatusView(status: viewModel.status)
                }
            }

            if viewModel.isConfigured {
                Section {
                    Button("Disconnect", systemImage: "rectangle.portrait.and.arrow.right") {
                        viewModel.disconnect()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .modalFormStyle(
            title: viewModel.isConfigured ? "Edit Server" : "Add Server",
            primaryTitle: "Connect",
            isPrimaryDisabled: isConnectDisabled,
            isSaving: viewModel.status == .checking,
            primaryAction: testAndSave
        )
        .onDisappear {
            if viewModel.status == .checking {
                viewModel.cancelValidation()
            }
        }
        .onChange(of: viewModel.status) { _, status in
            if status == .reachable {
                dismiss()
            }
        }
    }

    private var isConnectDisabled: Bool {
        viewModel.status == .checking
            || viewModel.urlString.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
    }

    private func testAndSave() {
        viewModel.startValidation()
    }
}
