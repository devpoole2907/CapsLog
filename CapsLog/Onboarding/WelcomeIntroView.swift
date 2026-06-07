import SwiftUI

struct WelcomeIntroView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let getStarted: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Image(systemName: "text.document")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                Text("Welcome to CapsLog")
                    .font(.largeTitle)
                    .bold()

                Text("Your SilverBullet space, native on iPhone and iPad.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                WelcomeFeatureRow(
                    icon: "server.rack",
                    color: .blue,
                    title: "Self-Hosted",
                    description: "Connect directly to your own SilverBullet server"
                )
                WelcomeFeatureRow(
                    icon: "doc.text",
                    color: .orange,
                    title: "Raw Markdown",
                    description: "Browse and edit every page without changing its source"
                )
                WelcomeFeatureRow(
                    icon: "wifi.slash",
                    color: .green,
                    title: "Works Offline",
                    description: "Read cached pages and queue edits until you reconnect"
                )
                WelcomeFeatureRow(
                    icon: "arrow.triangle.branch",
                    color: .purple,
                    title: "Conflict Aware",
                    description: "Protect remote changes before anything is overwritten"
                )
            }
            .padding(.horizontal, 8)
        }
        .padding(32)
        .frame(maxWidth: horizontalSizeClass == .regular ? 600 : 440)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .prominentBottomButton("Get Started", action: getStarted)
    }
}
