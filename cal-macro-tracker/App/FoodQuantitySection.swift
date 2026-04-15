import SwiftUI

struct FoodQuantitySection<AmountEditor: View>: View {
    @Binding var quantityMode: QuantityMode
    let canLogByGrams: Bool
    let gramLoggingMessage: String
    let showsGramLoggingMessageOnlyInGramsMode: Bool
    @ViewBuilder let amountEditor: (QuantityMode) -> AmountEditor

    init(
        quantityMode: Binding<QuantityMode>,
        canLogByGrams: Bool,
        gramLoggingMessage: String = FoodDraftValidationError.gramsPerServingRequiredForGramLogging.errorDescription
            ?? "Add grams per serving to log by grams.",
        showsGramLoggingMessageOnlyInGramsMode: Bool = false,
        @ViewBuilder amountEditor: @escaping (QuantityMode) -> AmountEditor
    ) {
        _quantityMode = quantityMode
        self.canLogByGrams = canLogByGrams
        self.gramLoggingMessage = gramLoggingMessage
        self.showsGramLoggingMessageOnlyInGramsMode = showsGramLoggingMessageOnlyInGramsMode
        self.amountEditor = amountEditor
    }

    var body: some View {
        Section("Quantity") {
            Picker("Mode", selection: $quantityMode) {
                Text("Servings").tag(QuantityMode.servings)
                Text("Grams").tag(QuantityMode.grams)
            }
            .pickerStyle(.segmented)

            amountEditor(quantityMode)

            if shouldShowGramLoggingMessage {
                Text(gramLoggingMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            normalizeQuantityModeIfNeeded()
        }
        .onChange(of: canLogByGrams) { _, canLogByGrams in
            guard !canLogByGrams else { return }
            normalizeQuantityModeIfNeeded()
        }
    }

    private func normalizeQuantityModeIfNeeded() {
        if !canLogByGrams && quantityMode == .grams {
            quantityMode = .servings
        }
    }

    private var shouldShowGramLoggingMessage: Bool {
        guard !canLogByGrams else { return false }
        return !showsGramLoggingMessageOnlyInGramsMode || quantityMode == .grams
    }
}
