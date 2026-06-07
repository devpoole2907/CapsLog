import SwiftUI
import Textual
import UIKit

struct SilverBulletImageAttachment: Attachment {
    let data: Data
    let text: String
    let imageSize: CGSize

    var description: String {
        text
    }

    @MainActor
    var body: some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .accessibilityLabel(text.isEmpty ? "Image" : text)
            } else {
                Color.clear
            }
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        in environment: TextEnvironmentValues
    ) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return .zero
        }

        guard let proposedWidth = proposal.width else {
            return imageSize
        }

        let width = min(proposedWidth, imageSize.width)
        return CGSize(
            width: width,
            height: width * imageSize.height / imageSize.width
        )
    }
}
