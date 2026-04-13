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

    // Visual contract for this ring:
    // - `progress <= 1`: one trimmed arc with a real `.round` cap and an angular gradient.
    // - `progress > 1`: keep the first lap and the overlapping lap as separate layers.
    //   The base lap stays a nearly full gradient ring, the overlapping tail is a flat
    //   `endColor` stroke, and the visible head is a separate circular tip.
    // This split is intentional. Converting the overlap case back into one closed circle
    // or one extra highlighted arc removes the true rounded head and reintroduces seams,
    // blobs, or a second visible mini-ring at the overlap point.
    private func dynamicSingleLapGradient(fraction: Double) -> AngularGradient {
        let span = max(fraction, 0.001) * 360.0

        let safeStartAngle: CGFloat = -15.0
        let totalSpan = span + 30.0  // from -15 to span + 15

        let zeroLocation = abs(safeStartAngle) / totalSpan
        let tipLocation = (span + abs(safeStartAngle)) / totalSpan

        return AngularGradient(
            gradient: Gradient(stops: [
                .init(color: gradientStartColor.color, location: 0.0),
                .init(color: gradientStartColor.color, location: zeroLocation),
                .init(color: gradientEndColor.color, location: tipLocation),
                .init(color: gradientEndColor.color, location: 1.0)  // forward cap buffer
            ]),
            center: .center,
            startAngle: .degrees(safeStartAngle),
            endAngle: .degrees(span + 15)  // +15 ensures forward caps are fully covered
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(resolvedTrackColor, lineWidth: lineWidth)

            if progress > 0 {
                let remainder = progress.truncatingRemainder(dividingBy: 1.0)
                let overlap = (remainder == 0 && progress >= 1.0) ? 1.0 : remainder
                let hasFullLap = progress > 1.0

                let startTrim: CGFloat = 0.0001
                let safeOverlap = max(startTrim, overlap == 1.0 ? 0.999 : overlap)

                if hasFullLap {
                    // Keep the overlap renderer layer-split. The first lap remains the
                    // continuous ring under everything else so the overlap still reads
                    // as one ring instead of a second concentric or detached segment.
                    Circle()
                        .trim(from: startTrim, to: 0.999)
                        .stroke(
                            dynamicSingleLapGradient(fraction: 1.0),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    // Shadow is isolated to the overlap tip so depth appears only where
                    // lap two passes over lap one, without muddying the active sweep.
                    Circle()
                        .fill(Color.black)
                        .frame(width: lineWidth * 0.9, height: lineWidth * 0.9)
                        .shadow(
                            color: .black.opacity(colorScheme == .dark ? 0.8 : 0.45),
                            radius: lineWidth * 0.25,
                            x: -lineWidth * 0.15,
                            y: 0
                        )
                        .offset(y: -diameter / 2)
                        .rotationEffect(.degrees(overlap * 360))

                    // The active overlap tail must stay `.butt` capped. A rounded start
                    // cap at 12 o'clock bleeds backwards and exposes a false restart.
                    Circle()
                        .trim(from: startTrim, to: safeOverlap)
                        .stroke(
                            gradientEndColor.color,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))

                    // The visible rounded head is restored explicitly as a tip circle.
                    // This is what keeps the overlap looking like one ring with one head.
                    Circle()
                        .fill(gradientEndColor.color)
                        .frame(width: lineWidth, height: lineWidth)
                        .offset(y: -diameter / 2)
                        .rotationEffect(.degrees(overlap * 360))

                } else {
                    // Single lap
                    let safeProgress = max(startTrim, progress == 1.0 ? 0.999 : progress)
                    Circle()
                        .trim(from: startTrim, to: safeProgress)
                        .stroke(
                            dynamicSingleLapGradient(fraction: progress),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
