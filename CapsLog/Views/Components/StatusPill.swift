import SwiftUI

struct StatusPill: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.15), in: Capsule())
        .foregroundStyle(tint)
        .accessibilityElement(children: .combine)
    }
}
