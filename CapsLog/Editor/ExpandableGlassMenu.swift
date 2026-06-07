import SwiftUI

// Adapted from the CustomTFT project supplied with CapsLog.
struct ExpandableGlassMenu<Content: View, Label: View>: View, Animatable {
    let alignment: Alignment
    var progress: CGFloat
    let labelSize: CGSize
    let cornerRadius: CGFloat
    @ViewBuilder let content: Content
    @ViewBuilder let label: Label

    @State private var contentSize: CGSize = .zero

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GlassEffectContainer {
            let widthDifference = contentSize.width - labelSize.width
            let heightDifference = contentSize.height - labelSize.height

            ZStack(alignment: alignment) {
                content
                    .compositingGroup()
                    .scaleEffect(contentScale)
                    .blur(radius: 14 * blurProgress)
                    .opacity(contentOpacity)
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { newValue in
                        contentSize = newValue
                    }
                    .fixedSize()
                    .frame(
                        width: labelSize.width + widthDifference * contentOpacity,
                        height: labelSize.height + heightDifference * contentOpacity
                    )

                label
                    .compositingGroup()
                    .blur(radius: 14 * blurProgress)
                    .opacity(1 - labelOpacity)
                    .frame(width: labelSize.width, height: labelSize.height)
            }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: cornerRadius))
            .glassEffect(
                .regular.interactive(),
                in: .rect(cornerRadius: cornerRadius)
            )
        }
        .scaleEffect(
            x: 1 - blurProgress * 0.25,
            y: 1 + blurProgress * 0.25,
            anchor: scaleAnchor
        )
        .offset(y: offset * blurProgress)
    }

    private var labelOpacity: CGFloat {
        min(progress / 0.35, 1)
    }

    private var contentOpacity: CGFloat {
        max(progress - 0.35, 0) / 0.65
    }

    private var contentScale: CGFloat {
        guard contentSize.width > 0, contentSize.height > 0 else {
            return 1
        }

        let minimumScale = min(
            labelSize.width / contentSize.width,
            labelSize.height / contentSize.height
        )
        return minimumScale + (1 - minimumScale) * progress
    }

    private var blurProgress: CGFloat {
        progress > 0.5 ? (1 - progress) / 0.5 : progress / 0.5
    }

    private var offset: CGFloat {
        switch alignment {
        case .bottom, .bottomLeading, .bottomTrailing:
            -40
        case .top, .topLeading, .topTrailing:
            40
        default:
            0
        }
    }

    private var scaleAnchor: UnitPoint {
        switch alignment {
        case .bottomLeading:
            .bottomLeading
        case .bottom:
            .bottom
        case .bottomTrailing:
            .bottomTrailing
        case .topLeading:
            .topLeading
        case .top:
            .top
        case .topTrailing:
            .topTrailing
        case .leading:
            .leading
        case .trailing:
            .trailing
        default:
            .center
        }
    }
}
