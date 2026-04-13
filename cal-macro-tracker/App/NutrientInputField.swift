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
        if let focusedField, let field {
            AppNumericTextField(title, text: $text, focusedField: focusedField, field: field)
                .frame(minWidth: 72)
        } else {
            AppNumericTextField<Field>(title, text: $text)
                .frame(minWidth: 72)
        }
    }

    private var suffixWidth: CGFloat {
        suffix.count > 1 ? 36 : 24
    }

    private func focusFieldIfNeeded() {
        guard let focusedField, let field else { return }
        focusedField.wrappedValue = field
    }
}
