import SwiftUI

struct MacroRingView: View {
    let totals: NutritionSnapshot
    let goals: DailyGoals

    private let ringDiameter: CGFloat = 224

    var body: some View {
        FitnessStyleMacroRings(
            totals: totals,
            goals: goals,
            ringDiameter: ringDiameter,
            centerValueFontSize: 42,
            minimumLineWidth: 5,
            showsGoalSubtitle: true
        )
    }
}

struct CompactMacroRingView: View {
    let totals: NutritionSnapshot
    let goals: DailyGoals

    private let ringDiameter: CGFloat = 64

    var body: some View {
        FitnessStyleMacroRings(
            totals: totals,
            goals: goals,
            ringDiameter: ringDiameter,
            centerValueFontSize: 14,
            minimumLineWidth: 5,
            showsGoalSubtitle: false
        )
    }
}

struct WeekdayMacroRingView: View {
    let totals: NutritionSnapshot
    let goals: DailyGoals

    private let ringDiameter: CGFloat = 28

    var body: some View {
        FitnessStyleMacroRings(
            totals: totals,
            goals: goals,
            ringDiameter: ringDiameter,
            centerValueFontSize: nil,
            minimumLineWidth: 2.4,
            showsGoalSubtitle: false
        )
    }
}

private struct RingPaletteColor {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double = 1

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

private struct FitnessStyleMacroRings: View {
    let totals: NutritionSnapshot
    let goals: DailyGoals
    let ringDiameter: CGFloat
    let centerValueFontSize: CGFloat?
    let minimumLineWidth: CGFloat
    let showsGoalSubtitle: Bool

    private struct RingMetric {
        let progress: Double
        let trackColor: Color
        let gradientStartColor: RingPaletteColor
        let gradientEndColor: RingPaletteColor
    }

    private var ringLineWidth: CGFloat {
        max(minimumLineWidth, ringDiameter * 0.08)
    }

    private var ringBandOverlap: CGFloat {
        max(0.3, ringDiameter * 0.004)
    }

    private var minimumRingDiameter: CGFloat {
        max(ringLineWidth * 2, 1)
    }

    private var ringMetrics: [RingMetric] {
        [
            RingMetric(
                progress: progress(consumed: totals.protein, goal: goals.proteinGoalGrams),
                trackColor: Color(red: 0.62, green: 0.75, blue: 0.93),
                gradientStartColor: RingPaletteColor(red: 0.14, green: 0.40, blue: 0.90),
                gradientEndColor: RingPaletteColor(red: 0.40, green: 0.68, blue: 1.0)
            ),
            RingMetric(
                progress: progress(consumed: totals.carbs, goal: goals.carbGoalGrams),
                trackColor: Color(red: 0.84, green: 0.62, blue: 0.24),
                gradientStartColor: RingPaletteColor(red: 0.92, green: 0.50, blue: 0.02),
                gradientEndColor: RingPaletteColor(red: 1.0, green: 0.76, blue: 0.34)
            ),
            RingMetric(
                progress: progress(consumed: totals.fat, goal: goals.fatGoalGrams),
                trackColor: Color(red: 0.84, green: 0.48, blue: 0.62),
                gradientStartColor: RingPaletteColor(red: 0.90, green: 0.18, blue: 0.44),
                gradientEndColor: RingPaletteColor(red: 1.0, green: 0.44, blue: 0.62)
            )
        ]
    }

    var body: some View {
        ZStack {
            ForEach(Array(ringMetrics.enumerated()), id: \.offset) { index, metric in
                GoalProgressRing(
                    diameter: ringDiameter(at: index),
                    lineWidth: ringLineWidth,
                    progress: metric.progress,
                    trackColor: metric.trackColor,
                    gradientStartColor: metric.gradientStartColor,
                    gradientEndColor: metric.gradientEndColor
                )
            }

            if let centerValueFontSize {
                VStack(spacing: showsGoalSubtitle ? 4 : 0) {
                    Text(totals.calories.roundedForDisplay)
                        .font(.system(size: centerValueFontSize, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if showsGoalSubtitle {
                        Text("of \(goals.calorieGoal.roundedForDisplay) kcal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, ringDiameter * 0.18)
                .padding(.vertical, ringDiameter * (showsGoalSubtitle ? 0.10 : 0.06))
            }
        }
        .frame(width: ringDiameter, height: ringDiameter)
    }

    private func ringDiameter(at index: Int) -> CGFloat {
        guard index > 0 else { return max(ringDiameter, minimumRingDiameter) }

        var diameter = max(ringDiameter, minimumRingDiameter)
        for _ in 1...index {
            diameter = max(minimumRingDiameter, diameter - ((ringLineWidth * 2) - ringBandOverlap))
        }

        return diameter
    }

    private func progress(consumed: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return max(consumed / goal, 0)
    }
}

private struct GoalProgressRing: View {
    @Environment(\.colorScheme) private var colorScheme

    let diameter: CGFloat
    let lineWidth: CGFloat
    let progress: Double
    let trackColor: Color
    let gradientStartColor: RingPaletteColor
    let gradientEndColor: RingPaletteColor

    private var resolvedTrackColor: Color {
        colorScheme == .dark ? trackColor.opacity(0.2) : trackColor.opacity(0.45)
    }

    private var overflowHeadShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.8 : 0.5)
    }

    private var completedOverflowLapCount: Int {
        max(Int(progress.rounded(.down)) - 1, 0)
    }

    private var overflowRemainder: Double {
        let remainder = progress.truncatingRemainder(dividingBy: 1.0)
        return remainder == 0 ? 0 : remainder
    }

    private var lapInset: CGFloat {
        max(lineWidth * 0.18, 0.8)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(resolvedTrackColor, lineWidth: lineWidth)

            if progress > 0 {
                if progress <= 1.0 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(dynamicSingleLapGradient(fraction: progress), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                } else {
                    Circle()
                        .stroke(rotatedMultiLapGradient(activeProgress: 1.0), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    ForEach(0..<completedOverflowLapCount, id: \.self) { lapIndex in
                        Circle()
                            .stroke(
                                rotatedMultiLapGradient(activeProgress: 1.0),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(
                                width: lapDiameter(forOverflowLapIndex: lapIndex + 1),
                                height: lapDiameter(forOverflowLapIndex: lapIndex + 1)
                            )
                    }

                    if overflowRemainder > 0 {
                        let activeLapDiameter = lapDiameter(forOverflowLapIndex: completedOverflowLapCount + 1)
                        let activeGradient = rotatedMultiLapGradient(activeProgress: overflowRemainder)

                        overflowHead(
                            diameter: activeLapDiameter,
                            progress: overflowRemainder
                        )

                        Circle()
                            .trim(from: 0, to: overflowRemainder)
                            .stroke(activeGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: activeLapDiameter, height: activeLapDiameter)
                    } else {
                        overflowHead(
                            diameter: lapDiameter(forOverflowLapIndex: completedOverflowLapCount),
                            progress: 1.0
                        )
                    }
                }
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func lapDiameter(forOverflowLapIndex index: Int) -> CGFloat {
        max(lineWidth, diameter - (CGFloat(index) * lapInset))
    }

    private func overflowHead(diameter: CGFloat, progress: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: lineWidth, height: lineWidth)
                .offset(y: -diameter / 2)
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(progress * 360))
        .shadow(color: overflowHeadShadowColor, radius: lineWidth * 0.5, x: 0, y: lineWidth * 0.05)
    }

    private func dynamicSingleLapGradient(fraction: Double) -> AngularGradient {
        let head = min(max(fraction, 0.01), 0.98)
        let headBuffer = min(head + 0.01, 0.99)
        return AngularGradient(
            gradient: Gradient(stops: [
                .init(color: gradientStartColor.color, location: 0.0),
                .init(color: gradientEndColor.color, location: head),
                .init(color: gradientEndColor.color, location: headBuffer),
                // Instantly drops to strictly startColor to totally eliminate Start Cap vertical slices
                .init(color: gradientStartColor.color, location: min(headBuffer + 0.01, 1.0)),
                .init(color: gradientStartColor.color, location: 1.0)
            ]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }

    private func rotatedMultiLapGradient(activeProgress: Double) -> AngularGradient {
        // Compute to place the absolute brightest color map exactly under the physical sweeping tip!
        let targetAngle = activeProgress * 360.0
        let currentAngleOfBrightest = 0.90 * 360.0
        let shift = targetAngle - currentAngleOfBrightest

        return AngularGradient(
            gradient: Gradient(stops: [
                .init(color: gradientStartColor.color, location: 0.0),
                .init(color: gradientEndColor.color, location: 0.90),
                .init(color: gradientStartColor.color, location: 1.0)
            ]),
            center: .center,
            startAngle: .degrees(shift),
            endAngle: .degrees(shift + 360)
        )
    }
}
