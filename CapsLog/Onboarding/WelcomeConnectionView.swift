import SwiftUI

struct WelcomeConnectionView: View {
    let isConfigured: Bool
    let serverDescription: String
    let maxContentWidth: Double
    let connect: () -> Void
    let finish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text("Connect SilverBullet")
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)

                    Text("Add your server, test its API, then continue into CapsLog.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                WelcomeSetupRow(
                    icon: "server.rack",
                    color: .blue,
                    title: "SilverBullet Server",
                    description: serverDescription,
                    isConfigured: isConfigured,
                    action: connect
                )
            }
            .padding(32)
            .frame(maxWidth: maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .prominentBottomButton("Go", isDisabled: !isConfigured, action: finish)
        .navigationTitle("Connect Server")
        .navigationBarTitleDisplayMode(.inline)
    }
}
