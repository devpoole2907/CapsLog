import SwiftUI

struct ModalFormStyle: ViewModifier {
    let title: String
    let primaryTitle: String
    var isPrimaryDisabled = false
    var isSaving = false
    let primaryAction: () -> Void

    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                        .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(primaryTitle, action: primaryAction)
                            .disabled(isPrimaryDisabled)
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(isSaving)
    }
}

extension View {
    func modalFormStyle(
        title: String,
        primaryTitle: String,
        isPrimaryDisabled: Bool = false,
        isSaving: Bool = false,
        primaryAction: @escaping () -> Void
    ) -> some View {
        modifier(
            ModalFormStyle(
                title: title,
                primaryTitle: primaryTitle,
                isPrimaryDisabled: isPrimaryDisabled,
                isSaving: isSaving,
                primaryAction: primaryAction
            )
        )
    }
}
