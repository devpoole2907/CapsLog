import SwiftUI

struct WelcomeFlowView: View {
    @Binding var isInWelcomeFlow: Bool
    @Binding var isShowingConnectionSetup: Bool
    let isConfigured: Bool
    let serverDescription: String

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var welcomePath: [WelcomeStep] = []

    var body: some View {
        NavigationStack(path: $welcomePath) {
            WelcomeIntroView {
                welcomePath.append(.connection)
            }
            .navigationDestination(for: WelcomeStep.self) { step in
                switch step {
                case .connection:
                    WelcomeConnectionView(
                        isConfigured: isConfigured,
                        serverDescription: serverDescription,
                        maxContentWidth: maxContentWidth,
                        connect: showConnectionSetup,
                        finish: finish
                    )
                }
            }
        }
    }

    private var maxContentWidth: Double {
        horizontalSizeClass == .regular ? 600 : 440
    }

    private func showConnectionSetup() {
        isShowingConnectionSetup = true
    }

    private func finish() {
        withAnimation(.snappy) {
            isInWelcomeFlow = false
        }
    }
}
