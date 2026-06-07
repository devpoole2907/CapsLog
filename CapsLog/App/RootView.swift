import SwiftUI

struct RootView: View {
    @State private var connection = ConnectionViewModel()
    @State private var isInWelcomeFlow = true
    @State private var isShowingConnectionSetup = false
    @State private var didEvaluateWelcomeState = false

    var body: some View {
        Group {
            if !didEvaluateWelcomeState {
                ProgressView()
            } else if isInWelcomeFlow || !connection.isConfigured {
                WelcomeFlowView(
                    isInWelcomeFlow: $isInWelcomeFlow,
                    isShowingConnectionSetup: $isShowingConnectionSetup,
                    isConfigured: connection.isConfigured,
                    serverDescription: connection.serverDescription
                )
            } else {
                FileListContainerView(client: connection.makeClient())
                    .environment(connection)
                    .id(connection.configurationID)
            }
        }
        .task {
            evaluateInitialWelcomeStateIfNeeded()
        }
        .sheet(isPresented: $isShowingConnectionSetup) {
            NavigationStack {
                ConnectionSettingsView(viewModel: connection)
            }
        }
        .onChange(of: connection.isConfigured) { _, isConfigured in
            if !isConfigured {
                withAnimation(.snappy) {
                    isInWelcomeFlow = true
                }
            }
        }
    }

    private func evaluateInitialWelcomeStateIfNeeded() {
        guard !didEvaluateWelcomeState else {
            return
        }

        connection.loadSavedConfiguration()
        isInWelcomeFlow = !connection.isConfigured
        didEvaluateWelcomeState = true
    }
}
