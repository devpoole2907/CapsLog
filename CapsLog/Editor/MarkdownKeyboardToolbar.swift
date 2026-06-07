import SwiftUI

struct MarkdownKeyboardToolbar: View {
    let isKeyboardActive: Bool
    let perform: (MarkdownEditorAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ExpandableGlassMenu(
                alignment: .center,
                progress: isKeyboardActive ? 1 : 0,
                labelSize: CGSize(width: 220, height: proxy.size.height),
                cornerRadius: 22.5
            ) {
                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        MarkdownStyleMenu(perform: perform)
                        MarkdownActionButton(action: .checklist, perform: perform)
                        MarkdownActionButton(action: .bulletList, perform: perform)
                        MarkdownActionButton(action: .numberedList, perform: perform)
                        MarkdownActionButton(action: .bold, perform: perform)
                        MarkdownActionButton(action: .italic, perform: perform)
                        MarkdownActionButton(action: .strikethrough, perform: perform)
                        MarkdownActionButton(action: .link, perform: perform)
                        MarkdownActionButton(action: .indent, perform: perform)
                        MarkdownActionButton(action: .outdent, perform: perform)
                    }
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .padding(.horizontal)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .frame(width: proxy.size.width, height: proxy.size.height)
            } label: {
                HStack(spacing: 8) {
                    MarkdownStyleMenu(perform: perform)
                    MarkdownActionButton(action: .checklist, perform: perform)
                    MarkdownActionButton(action: .bold, perform: perform)
                    MarkdownActionButton(action: .link, perform: perform)
                }
                .font(.title3)
                .foregroundStyle(.primary)
            }
        }
        .frame(height: 45)
        .padding(.horizontal)
        .padding(.bottom, isKeyboardActive ? 10 : 0)
        .animation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .interactiveSpring(response: 0.5, dampingFraction: 0.65),
            value: isKeyboardActive
        )
    }
}
