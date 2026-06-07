import SwiftUI

struct MarkdownSourceEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var isFocused: Bool
    let command: MarkdownEditorCommand?
    let isReadOnly: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            selection: $selection,
            isFocused: $isFocused
        )
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        let baseFont = UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)

        textView.delegate = context.coordinator
        textView.text = text
        textView.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont)
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.tintColor = .systemBlue
        textView.isEditable = !isReadOnly
        textView.isSelectable = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(
            top: 18,
            left: 16,
            bottom: 80,
            right: 16
        )
        textView.textContainer.lineFragmentPadding = 0

        // Markdown is source text, so typographic substitutions must stay off.
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.writingToolsBehavior = .none

        textView.accessibilityLabel = "Markdown source editor"
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.isEditable = !isReadOnly

        if textView.text != text {
            context.coordinator.isApplyingModelUpdate = true
            textView.text = text
            textView.selectedRange = clamped(selection, for: textView.text)
            context.coordinator.isApplyingModelUpdate = false
        }

        if let command, context.coordinator.lastCommandID != command.id {
            context.coordinator.apply(command, to: textView)
        }

        if isFocused, !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !isFocused, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    private func clamped(_ range: NSRange, for text: String) -> NSRange {
        let length = (text as NSString).length
        let location = min(range.location, length)
        return NSRange(
            location: location,
            length: min(range.length, length - location)
        )
    }
}

extension MarkdownSourceEditor {
    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var isApplyingModelUpdate = false
        var lastCommandID: UUID?
        private let text: Binding<String>
        private let selection: Binding<NSRange>
        private let isFocused: Binding<Bool>

        init(
            text: Binding<String>,
            selection: Binding<NSRange>,
            isFocused: Binding<Bool>
        ) {
            self.text = text
            self.selection = selection
            self.isFocused = isFocused
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingModelUpdate, text.wrappedValue != textView.text else {
                return
            }
            text.wrappedValue = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingModelUpdate,
                  selection.wrappedValue != textView.selectedRange else {
                return
            }
            selection.wrappedValue = textView.selectedRange
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused.wrappedValue = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isFocused.wrappedValue = false
        }

        func apply(_ command: MarkdownEditorCommand, to textView: UITextView) {
            lastCommandID = command.id
            let mutation = MarkdownTextMutation.applying(
                command.action,
                to: textView.text,
                selection: textView.selectedRange
            )

            isApplyingModelUpdate = true
            textView.text = mutation.text
            textView.selectedRange = mutation.selection
            text.wrappedValue = mutation.text
            selection.wrappedValue = mutation.selection
            isApplyingModelUpdate = false
        }
    }
}
