import SwiftUI

struct AppNumericTextField<Field: Hashable>: View {
    let title: String
    @Binding var text: String

    private let focusedField: FocusState<Field?>.Binding?
    private let field: Field?

    init(_ title: String, text: Binding<String>) {
        self.title = title
        _text = text
        focusedField = nil
        field = nil
    }

    init(_ title: String, text: Binding<String>, focusedField: FocusState<Field?>.Binding, field: Field) {
        self.title = title
        _text = text
        self.focusedField = focusedField
        self.field = field
    }

    var body: some View {
        fieldView
    }

    @ViewBuilder
    private var fieldView: some View {
        if let focusedField, let field {
            TextField(title, text: $text)
                .focused(focusedField, equals: field)
                .multilineTextAlignment(.trailing)
                .numericKeyboard()
        } else {
            TextField(title, text: $text)
                .multilineTextAlignment(.trailing)
                .numericKeyboard()
        }
    }
}
