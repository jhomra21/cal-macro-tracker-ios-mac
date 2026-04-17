import Foundation
import SwiftData

@MainActor
struct FoodItemRepository {
    let modelContext: ModelContext

    func fetchReusableFood(id: UUID) throws -> FoodItem? {
        try fetchReusableFood(id: id, in: modelContext)
    }

    func fetchReusableFood(source: FoodSource, externalProductID: String) throws -> FoodItem? {
        try fetchReusableFood(source: source, externalProductID: externalProductID, in: modelContext)
    }

    func fetchCachedBarcodeFood(barcode: String) throws -> FoodItem? {
        try fetchBarcodeFood(
            barcode: barcode,
            preferredSources: [.barcodeLookup, .searchLookup],
            in: modelContext
        )
    }

    func fetchBarcodeLookupFood(barcode: String) throws -> FoodItem? {
        try fetchBarcodeFood(
            barcode: barcode,
            preferredSources: [.barcodeLookup],
            in: modelContext
        )
    }

    @discardableResult
    func saveReusableFood(
        from draft: FoodDraft,
        operation: String,
        sourceOverride: FoodSource? = nil,
        secondaryNutrientBackfillStateOverride: SecondaryNutrientBackfillState? = nil
    ) throws -> FoodItem {
        let savedFoodID = try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            try upsertReusableFood(
                from: draft,
                in: isolatedContext,
                sourceOverride: sourceOverride,
                secondaryNutrientBackfillStateOverride: secondaryNutrientBackfillStateOverride
            ).id
        }

        guard let savedFood = try fetchReusableFood(id: savedFoodID) else {
            throw NSError(domain: "FoodItemRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load saved food."])
        }

        return savedFood
    }

    func deleteReusableFood(_ food: FoodItem, operation: String) throws {
        let foodID = food.persistentModelID

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            guard let isolatedFood = isolatedContext.model(for: foodID) as? FoodItem else {
                throw NSError(
                    domain: "FoodItemRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to load saved food for deletion."])
            }

            guard isolatedFood.sourceKind != .common else {
                throw NSError(
                    domain: "FoodItemRepository", code: 3, userInfo: [NSLocalizedDescriptionKey: "Common foods cannot be deleted."])
            }

            isolatedContext.delete(isolatedFood)
        }
    }

    @discardableResult
    func upsertReusableFood(
        from draft: FoodDraft,
        in context: ModelContext,
        sourceOverride: FoodSource? = nil,
        secondaryNutrientBackfillStateOverride: SecondaryNutrientBackfillState? = nil
    ) throws -> FoodItem {
        let normalizedDraft = draft.normalized()
        if let validationError = normalizedDraft.validationErrorForSaving() {
            throw validationError
        }

        let existingFood = try reusableFood(for: normalizedDraft, in: context)
        let resolvedSource = resolvedReusableSource(for: normalizedDraft, existingFood: existingFood, sourceOverride: sourceOverride)
        let persistedDraft = resolvedPersistenceDraft(
            from: normalizedDraft,
            existingFood: existingFood,
            resolvedSource: resolvedSource
        )
        let secondaryNutrientUpdate = resolvedSecondaryNutrientUpdate(
            for: persistedDraft,
            existingFood: existingFood,
            override: secondaryNutrientBackfillStateOverride
        )
        let food = existingFood ?? normalizedDraft.makeReusableFoodItem(sourceOverride: resolvedSource)

        if food.modelContext == nil {
            context.insert(food)
        }

        apply(
            secondaryNutrientUpdate.draft,
            source: resolvedSource,
            secondaryNutrientBackfillState: secondaryNutrientUpdate.state,
            to: food
        )
        return food
    }

    private func reusableFood(for draft: FoodDraft, in context: ModelContext) throws -> FoodItem? {
        if let existingID = draft.foodItemID,
            let existingFood = try fetchReusableFood(id: existingID, in: context)
        {
            return existingFood
        }

        if let externalProductID = draft.externalProductIDOrNil {
            let lookupSources: [FoodSource]
            switch draft.source {
            case .searchLookup:
                lookupSources = [.searchLookup, .barcodeLookup]
            default:
                lookupSources = [draft.source]
            }

            for source in lookupSources {
                if let externalFood = try fetchReusableFood(source: source, externalProductID: externalProductID, in: context) {
                    return externalFood
                }
            }
        }

        if draft.source == .barcodeLookup,
            let barcode = draft.barcodeOrNil,
            let barcodeFood = try fetchBarcodeFood(
                barcode: barcode,
                preferredSources: [.barcodeLookup],
                in: context
            )
        {
            return barcodeFood
        }

        return nil
    }

    private func fetchReusableFood(id: UUID, in context: ModelContext) throws -> FoodItem? {
        let commonSource = FoodSource.common.rawValue
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { food in
                food.id == id && food.source != commonSource
            },
            sortBy: [SortDescriptor(\FoodItem.updatedAt, order: .reverse)]
        )

        return try context.fetch(descriptor).first
    }

    private func fetchReusableFood(source: FoodSource, externalProductID: String, in context: ModelContext) throws -> FoodItem? {
        let commonSource = FoodSource.common.rawValue
        let sourceValue = source.rawValue
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { food in
                food.source == sourceValue && food.externalProductID == externalProductID && food.source != commonSource
            },
            sortBy: [SortDescriptor(\FoodItem.updatedAt, order: .reverse)]
        )

        return try context.fetch(descriptor).first
    }

    private func fetchBarcodeFood(
        barcode: String,
        preferredSources: [FoodSource],
        in context: ModelContext
    ) throws -> FoodItem? {
        for source in preferredSources {
            for barcodeAlias in OpenFoodFactsIdentity.barcodeAliases(for: barcode) {
                if let food = try fetchBarcodeFood(barcode: barcodeAlias, source: source, in: context) {
                    return food
                }
            }
        }

        return nil
    }

    private func fetchBarcodeFood(barcode: String, source: FoodSource, in context: ModelContext) throws -> FoodItem? {
        let sourceValue = source.rawValue
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { food in
                food.barcode == barcode && food.source == sourceValue
            },
            sortBy: [SortDescriptor(\FoodItem.updatedAt, order: .reverse)]
        )

        return try context.fetch(descriptor).first
    }

    private func resolvedReusableSource(for draft: FoodDraft, existingFood: FoodItem?, sourceOverride: FoodSource?) -> FoodSource {
        if let sourceOverride {
            return sourceOverride
        }

        if let existingFood {
            return existingFood.sourceKind
        }

        switch draft.source {
        case .common:
            return .custom
        case .custom, .barcodeLookup, .labelScan, .searchLookup:
            return draft.source
        }
    }

    private func resolvedPersistenceDraft(from draft: FoodDraft, existingFood: FoodItem?, resolvedSource: FoodSource) -> FoodDraft {
        guard let existingFood, preservesExternalIdentity(for: resolvedSource) else {
            return draft
        }

        var persistedDraft = draft

        if persistedDraft.barcodeOrNil == nil {
            persistedDraft.barcode = existingFood.barcode ?? ""
        }

        if persistedDraft.externalProductIDOrNil == nil {
            persistedDraft.externalProductID = existingFood.externalProductID ?? ""
        }

        if persistedDraft.sourceNameOrNil == nil {
            persistedDraft.sourceName = existingFood.sourceName ?? ""
        }

        if persistedDraft.sourceURLOrNil == nil {
            persistedDraft.sourceURL = existingFood.sourceURL ?? ""
        }

        return persistedDraft
    }

    private func preservesExternalIdentity(for source: FoodSource) -> Bool {
        switch source {
        case .barcodeLookup, .searchLookup:
            return true
        case .common, .custom, .labelScan:
            return false
        }
    }

    private func resolvedSecondaryNutrientUpdate(
        for draft: FoodDraft,
        existingFood: FoodItem?,
        override: SecondaryNutrientBackfillState?
    ) -> SecondaryNutrientBackfillPolicy.UpdateResolution {
        if let override {
            return .init(draft: draft, state: override)
        }

        guard let existingFood else {
            return .init(
                draft: draft,
                state: SecondaryNutrientBackfillPolicy.resolvedStateForNewRecord(from: draft)
            )
        }

        let initialDraft = FoodDraft(foodItem: existingFood)
        let baselineState =
            existingFood.secondaryNutrientBackfillState
            ?? SecondaryNutrientBackfillPolicy.inferredState(for: existingFood)

        return SecondaryNutrientBackfillPolicy.resolvedUpdate(
            initialDraft: initialDraft,
            updatedDraft: draft,
            initialState: baselineState
        )
    }

    private func apply(
        _ draft: FoodDraft,
        source: FoodSource,
        secondaryNutrientBackfillState: SecondaryNutrientBackfillState?,
        to food: FoodItem
    ) {
        food.name = draft.name
        food.brand = draft.brandOrNil
        food.source = source.rawValue
        food.barcode = draft.barcodeOrNil
        food.externalProductID = draft.externalProductIDOrNil
        food.sourceName = draft.sourceNameOrNil
        food.sourceURL = draft.sourceURLOrNil
        food.servingDescription = draft.servingDescription
        food.gramsPerServing = draft.gramsPerServing
        food.caloriesPerServing = draft.caloriesPerServing
        food.proteinPerServing = draft.proteinPerServing
        food.fatPerServing = draft.fatPerServing
        food.carbsPerServing = draft.carbsPerServing
        food.saturatedFatPerServing = draft.saturatedFatPerServing
        food.fiberPerServing = draft.fiberPerServing
        food.sugarsPerServing = draft.sugarsPerServing
        food.addedSugarsPerServing = draft.addedSugarsPerServing
        food.sodiumPerServing = draft.sodiumPerServing
        food.cholesterolPerServing = draft.cholesterolPerServing
        food.secondaryNutrientBackfillState = secondaryNutrientBackfillState
        food.normalizeForPersistence()
    }
}
