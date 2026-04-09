import SwiftData
import SwiftUI

struct ReusableFoodEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let food: FoodItem
    @State private var draft: FoodDraft
    @State private var numericText: FoodDraftNumericText
    @State private var errorMessage: String?
    @FocusState private var focusedField: FoodDraftField?

    init(food: FoodItem) {
        self.food = food
        let initialDraft = FoodDraft(foodItem: food, saveAsCustomFood: true)
        _draft = State(initialValue: initialDraft)
        _numericText = State(initialValue: FoodDraftNumericText(draft: initialDraft))
    }

    private var foodRepository: FoodItemRepository {
        FoodItemRepository(modelContext: modelContext)
    }

    private var canSave: Bool {
        guard let finalizedDraft = numericText.finalizedDraft(from: draft) else { return false }
        return finalizedDraft.canSaveReusableFood
    }

    private var sourceURL: URL? {
        guard let sourceURL = draft.sourceURLOrNil else { return nil }
        return URL(string: sourceURL)
    }

    private var navigationTitle: String {
        switch food.sourceKind {
        case .common:
            return "Food"
        case .custom:
            return "Custom Food"
        case .barcodeLookup, .labelScan, .searchLookup:
            return "Saved Food"
        }
    }

    private var saveOperationName: String {
        switch food.sourceKind {
        case .common:
            return "Save food"
        case .custom:
            return "Save custom food"
        case .barcodeLookup:
            return "Save barcode food"
        case .labelScan:
            return "Save label scan food"
        case .searchLookup:
            return "Save searched food"
        }
    }

    private var deleteOperationName: String {
        switch food.sourceKind {
        case .common:
            return "Delete food"
        case .custom:
            return "Delete custom food"
        case .barcodeLookup:
            return "Delete barcode food"
        case .labelScan:
            return "Delete label scan food"
        case .searchLookup:
            return "Delete searched food"
        }
    }

    var body: some View {
        FoodDraftEditorForm(
            draft: $draft,
            numericText: $numericText,
            errorMessage: $errorMessage,
            brandPrompt: "Brand (optional)",
            gramsPrompt: "Grams per serving (optional)",
            focusedField: $focusedField,
            keyboardFields: FoodDraftField.formOrder,
            previewTotals: nil
        ) {
            if draft.sourceNameOrNil != nil || sourceURL != nil {
                Section("Source") {
                    if let sourceName = draft.sourceNameOrNil {
                        LabeledContent("Provider") {
                            Text(sourceName)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let sourceURL {
                        Link(destination: sourceURL) {
                            Label("View Source", systemImage: "link")
                        }
                    }
                }
            }
        } footerSections: {
            Section {
                Button("Save") {
                    saveFood()
                }
                .disabled(!canSave)
            }

            Section {
                Button("Delete Food", role: .destructive) {
                    do {
                        try foodRepository.deleteReusableFood(food, operation: deleteOperationName)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                        assertionFailure(error.localizedDescription)
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
        .inlineNavigationTitle()
    }

    private func saveFood() {
        do {
            guard let finalizedDraft = numericText.finalizedDraft(from: draft) else {
                errorMessage = "Please fix invalid numeric values before saving this food."
                return
            }

            let persistedFood = try foodRepository.saveReusableFood(from: finalizedDraft, operation: saveOperationName)
            draft = FoodDraft(foodItem: persistedFood, saveAsCustomFood: true)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }
}
