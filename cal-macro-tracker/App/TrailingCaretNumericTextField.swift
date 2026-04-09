import SwiftUI

#if os(iOS)
import UIKit

struct TrailingCaretNumericTextField: UIViewRepresentable {
    let title: String
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = title
        textField.text = text
        textField.textAlignment = .right
        textField.keyboardType = .decimalPad
        textField.adjustsFontForContentSizeCategory = true
        textField.font = .preferredFont(forTextStyle: .body)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        if uiView.placeholder != title {
            uiView.placeholder = title
        }

        if isFocused {
            if uiView.isFirstResponder == false {
                uiView.becomeFirstResponder()
            }
            context.coordinator.moveCursorToEnd(in: uiView)
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private let text: Binding<String>
        private let isFocused: Binding<Bool>

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            self.text = text
            self.isFocused = isFocused
        }

        @objc func textDidChange(_ textField: UITextField) {
            let updatedText = textField.text ?? ""
            if text.wrappedValue != updatedText {
                text.wrappedValue = updatedText
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if isFocused.wrappedValue == false {
                isFocused.wrappedValue = true
            }
            moveCursorToEnd(in: textField)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if isFocused.wrappedValue {
                isFocused.wrappedValue = false
            }
        }

        func moveCursorToEnd(in textField: UITextField) {
            let endOfDocument = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: endOfDocument, to: endOfDocument)
        }
    }
}
#endif
