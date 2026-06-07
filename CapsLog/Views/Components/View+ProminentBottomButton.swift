import SwiftUI

extension View {
    func prominentBottomButton(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        safeAreaInset(edge: .bottom) {
            ProminentBottomButton(
                title: title,
                systemImage: systemImage,
                isLoading: isLoading,
                isDisabled: isDisabled,
                action: action
            )
        }
    }
}
