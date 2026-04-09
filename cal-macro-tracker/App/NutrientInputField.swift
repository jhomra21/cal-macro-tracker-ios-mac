import SwiftUI

struct NutrientInputField<Field: Hashable>: View {
    let title: String
    let suffix: String
    @Binding var text: String

    private let focusedField: FocusState<Field?>.Binding?
    private let field: Field?

    init(title: String, suffix: String, text: Binding<String>) {
        self.title = title
        self.suffix = suffix
        _text = text
        focusedField = nil
        field = nil
    }

    init(title: String, suffix: String, text: Binding<String>, focusedField: FocusState<Field?>.Binding, field: Field) {
        self.title = title
        self.suffix = suffix
        _text = text
        self.focusedField = focusedField
        self.field = field
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                fieldView

                Text(suffix)
                    .foregroundStyle(.secondary)
                    .frame(width: suffixWidth, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusFieldIfNeeded()
        }
    }

    @ViewBuilder
    private var fieldView: some View {
        #if os(iOS)
        if let focusBinding {
            TrailingCaretNumericTextField(
                title: title,
                text: $text,
                isFocused: focusBinding
            )
            .frame(minWidth: 72)
        } else if let focusedField, let field {
            TextField(title, text: $text)
                .focused(focusedField, equals: field)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72)
                .numericKeyboard()
        } else {
            TextField(title, text: $text)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72)
                .numericKeyboard()
        }
        #else
        if let focusedField, let field {
            TextField(title, text: $text)
                .focused(focusedField, equals: field)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72)
                .numericKeyboard()
        } else {
            TextField(title, text: $text)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72)
                .numericKeyboard()
        }
        #endif
    }

    private var suffixWidth: CGFloat {
        suffix.count > 1 ? 36 : 24
    }

    private var focusBinding: Binding<Bool>? {
        guard let focusedField, let field else { return nil }

        return Binding(
            get: {
                focusedField.wrappedValue == field
            },
            set: { isFocused in
                if isFocused {
                    focusedField.wrappedValue = field
                } else if focusedField.wrappedValue == field {
                    focusedField.wrappedValue = nil
                }
            }
        )
    }

    private func focusFieldIfNeeded() {
        guard let focusedField, let field else { return }
        focusedField.wrappedValue = field
    }
}
