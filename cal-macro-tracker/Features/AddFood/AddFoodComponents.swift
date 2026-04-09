import SwiftUI

struct AddFoodQuickActions: View {
    let logDate: Date
    let onFoodLogged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan")
                .font(.headline)

            if #available(iOS 26, macOS 26, *) {
                GlassEffectContainer(spacing: 10) {
                    quickActionLinks
                }
            } else {
                quickActionLinks
            }
        }
    }

    private var quickActionLinks: some View {
        HStack(alignment: .top, spacing: 10) {
            NavigationLink {
                BarcodeScanScreen(logDate: logDate, onFoodLogged: onFoodLogged, entryMode: .immediateCamera)
            } label: {
                quickActionCard(title: "Scan Barcode", systemImage: "barcode.viewfinder")
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)

            NavigationLink {
                LabelScanScreen(logDate: logDate, onFoodLogged: onFoodLogged)
            } label: {
                quickActionCard(title: "Scan Label", systemImage: "camera.viewfinder")
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
        }
    }

    private func quickActionCard(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.primary)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
        .appGlassRoundedRect(cornerRadius: 18)
    }
}

enum AddFoodMode: String, CaseIterable, Identifiable {
    case search
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: "Search"
        case .manual: "Manual"
        }
    }
}

struct ManualFoodEntryScreen: View {
    let logDate: Date
    let onFoodLogged: () -> Void

    @State private var draft = FoodDraft()
    @State private var numericText = FoodDraftNumericText(draft: FoodDraft())
    @FocusState private var focusedField: FoodDraftField?

    var body: some View {
        Form {
            FoodDraftFormSections(
                draft: $draft,
                numericText: $numericText,
                brandPrompt: "Brand (optional)",
                gramsPrompt: "Grams per serving (optional)",
                focusedField: $focusedField
            )

            Section {
                NavigationLink {
                    LogFoodScreen(
                        logDate: logDate,
                        initialDraft: numericText.finalizedDraft(from: draft) ?? draft,
                        onFoodLogged: onFoodLogged
                    )
                } label: {
                    Text("Continue")
                }
                .disabled(!canContinue)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardNavigationToolbar(focusedField: $focusedField, fields: FoodDraftField.formOrder)
    }

    private var canContinue: Bool {
        guard let finalizedDraft = numericText.finalizedDraft(from: draft) else { return false }
        return finalizedDraft.canSaveReusableFood
    }
}
