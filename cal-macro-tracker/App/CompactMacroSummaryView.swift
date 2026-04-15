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

    private var goalSnapshot: MacroGoalsSnapshot {
        MacroGoalsSnapshot(goals: goals)
    }

    var body: some View {
        HStack(spacing: 0) {
            CompactMacroRingView(totals: totals, goals: goals)
                .frame(width: 72, height: 72)
                .frame(maxWidth: .infinity)

            ForEach(MacroMetric.allCases) { metric in
                macroColumn(metric: metric)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .appGlassRoundedRect(cornerRadius: 28, interactive: false)
        .padding(.horizontal, horizontalPadding)
    }

    private func macroColumn(metric: MacroMetric) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(metric.accentColor)
                    .frame(width: 8, height: 8)
                Text(metric.title)
                    .font(.caption.weight(.medium))
            }

            Text("\(metric.value(from: totals).roundedForDisplay)g")
                .font(.headline.weight(.semibold))
                .monospacedDigit()

            Text("Goal \(metric.goal(from: goalSnapshot).roundedForDisplay)g")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
    }
}
