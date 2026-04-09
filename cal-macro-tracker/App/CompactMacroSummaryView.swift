import SwiftUI

struct CompactMacroSummaryView: View {
    let totals: NutritionSnapshot
    let goals: DailyGoals
    let horizontalPadding: CGFloat

    init(totals: NutritionSnapshot, goals: DailyGoals, horizontalPadding: CGFloat = 8) {
        self.totals = totals
        self.goals = goals
        self.horizontalPadding = horizontalPadding
    }

    var body: some View {
        HStack(spacing: 0) {
            CompactMacroRingView(totals: totals, goals: goals)
                .frame(width: 72, height: 72)
                .frame(maxWidth: .infinity)

            macroColumn(
                title: "Protein",
                value: totals.protein,
                goal: goals.proteinGoalGrams,
                color: .blue
            )
            macroColumn(
                title: "Carbs",
                value: totals.carbs,
                goal: goals.carbGoalGrams,
                color: .orange
            )
            macroColumn(
                title: "Fat",
                value: totals.fat,
                goal: goals.fatGoalGrams,
                color: .pink
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .appGlassRoundedRect(cornerRadius: 28, interactive: false)
        .padding(.horizontal, horizontalPadding)
    }

    private func macroColumn(title: String, value: Double, goal: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.weight(.medium))
            }

            Text("\(value.roundedForDisplay)g")
                .font(.headline.weight(.semibold))
                .monospacedDigit()

            Text("Goal \(goal.roundedForDisplay)g")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
    }
}
