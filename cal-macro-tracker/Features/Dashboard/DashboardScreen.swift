import SwiftData
import SwiftUI

struct DashboardScreen: View {
    private enum Destination: Hashable {
        case history
        case settings
    }

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @Query private var goals: [DailyGoals]

    @State private var showingAddFood = false
    @State private var editingEntry: LogEntry?
    @State private var destination: Destination?
    @State private var errorMessage: String?
    @State private var showsCompactSummary = false

    private var currentGoals: DailyGoals {
        goals.first ?? DailyGoals()
    }

    private var showsBottomActionBar: Bool {
        destination == nil
    }

    var body: some View {
        LogEntryDaySnapshotReader(date: .now) { snapshot in
            ZStack(alignment: .top) {
                List {
                    HStack {
                        Spacer(minLength: 0)
                        MacroRingView(totals: snapshot.totals, goals: currentGoals)
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 20)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    MacroLegendView(totals: snapshot.totals, goals: currentGoals)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    LogEntryListSection(
                        title: "Today",
                        emptyTitle: "No food logged yet",
                        emptySystemImage: "fork.knife.circle",
                        emptyDescription: "Tap the add button to log your first food today.",
                        entries: snapshot.entries,
                        emptyVerticalPadding: 24,
                        layout: .list,
                        onDeleteEntry: deleteEntry,
                        onEditEntry: beginEditingEntry,
                        onLogAgain: logEntryAgain
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(PlatformColors.groupedBackground)
                .onScrollGeometryChange(for: CGFloat.self) { scrollGeometry in
                    max(0, scrollGeometry.contentOffset.y)
                } action: { _, newOffset in
                    updateCompactSummaryVisibility(for: newOffset)
                }

                if showsCompactSummary {
                    CompactMacroSummaryView(totals: snapshot.totals, goals: currentGoals)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                }
            }
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .largeNavigationTitle()
            .dashboardNavigationBackground(showsCompactSummary: showsCompactSummary)
            .animation(.easeInOut(duration: 0.2), value: showsCompactSummary)
            .toolbar {
                ToolbarItemGroup(placement: .appTopBarTrailing) {
                    Button {
                        destination = .history
                    } label: {
                        Image(systemName: "calendar")
                    }

                    Button {
                        destination = .settings
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if showsBottomActionBar {
                    BottomPinnedActionBar(title: "Add Food", systemImage: "plus", isDisabled: false) {
                        showingAddFood = true
                    }
                }
            }
            .navigationDestination(item: $destination) { destination in
                switch destination {
                case .history:
                    HistoryScreen()
                case .settings:
                    SettingsScreen()
                }
            }
            .sheet(isPresented: $showingAddFood) {
                NavigationStack {
                    AddFoodScreen(logDate: .now, foods: foods)
                }
            }
            .sheet(item: $editingEntry) { entry in
                NavigationStack {
                    EditLogEntryScreen(entry: entry)
                }
            }
            .errorBanner(message: $errorMessage)
        }
    }

    private var logEntryRepository: LogEntryRepository {
        LogEntryRepository(modelContext: modelContext)
    }

    private func beginEditingEntry(_ entry: LogEntry) {
        editingEntry = entry
    }

    private func deleteEntry(_ entry: LogEntry) {
        do {
            try logEntryRepository.delete(entry: entry, operation: "Delete today entry")
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func logEntryAgain(_ entry: LogEntry) {
        do {
            try logEntryRepository.logAgain(
                entry: entry, logDate: .now, operation: "Log food again")
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func updateCompactSummaryVisibility(for offset: CGFloat) {
        let visibilityThreshold: CGFloat = showsCompactSummary ? 180 : 220
        showsCompactSummary = offset > visibilityThreshold
    }
}

private struct MacroLegendView: View {
    let totals: NutritionSnapshot
    let goals: DailyGoals

    var body: some View {
        HStack(spacing: 24) {
            legendCard(
                title: "Protein", value: totals.protein, goal: goals.proteinGoalGrams, color: .blue)
            legendCard(
                title: "Carbs", value: totals.carbs, goal: goals.carbGoalGrams, color: .orange)
            legendCard(title: "Fat", value: totals.fat, goal: goals.fatGoalGrams, color: .pink)
        }
        .frame(maxWidth: .infinity)
    }

    private func legendCard(title: String, value: Double, goal: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }

            Text("\(value.roundedForDisplay)g")
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Text("Goal \(goal.roundedForDisplay)g")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

extension View {
    @ViewBuilder
    fileprivate func dashboardNavigationBackground(showsCompactSummary: Bool) -> some View {
        #if os(iOS)
        toolbarBackground(showsCompactSummary ? .hidden : .visible, for: .navigationBar)
        #else
        self
        #endif
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.foodName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(entry.quantitySummary) • \(entry.dateLogged.timeTitle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(entry.caloriesConsumed.roundedForDisplay) kcal")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(
                    "P \(entry.proteinConsumed.roundedForDisplay) • C \(entry.carbsConsumed.roundedForDisplay) • F \(entry.fatConsumed.roundedForDisplay)"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 16)
    }
}
