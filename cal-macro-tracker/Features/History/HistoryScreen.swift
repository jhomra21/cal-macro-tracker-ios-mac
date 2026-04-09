import SwiftData
import SwiftUI

struct HistoryScreen: View {
    @Query private var goals: [DailyGoals]

    @State private var selectedDate = Date().startOfDayValue
    @State private var showsCalendar = false

    private var currentGoals: DailyGoals {
        goals.first ?? DailyGoals()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HistoryWeekCard(selectedDate: $selectedDate, showsCalendar: $showsCalendar, goals: currentGoals)

                LogEntryDaySnapshotReader(date: selectedDate) { snapshot in
                    CompactMacroSummaryView(totals: snapshot.totals, goals: currentGoals, horizontalPadding: 0)

                    LogEntryListSection(
                        title: selectedDate.dayTitle,
                        emptyTitle: "Nothing logged",
                        emptySystemImage: "calendar.badge.exclamationmark",
                        emptyDescription: "No entries were saved for this date.",
                        entries: snapshot.entries,
                        emptyVerticalPadding: 20,
                        showsHeader: false
                    )
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PlatformColors.groupedBackground)
        .navigationTitle(selectedDate.historyNavigationTitle)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .appTopBarTrailing) {
                calendarToolbarButton
            }
        }
    }

    private func toggleCalendar() {
        withAnimation(.easeInOut(duration: 0.24)) {
            showsCalendar.toggle()
        }
    }

    private var calendarToolbarButton: some View {
        Button(action: toggleCalendar) {
            Image(systemName: "calendar")
                .font(.title3.weight(.semibold))
        }
    }
}

private struct HistoryWeekCard: View {
    @Binding var selectedDate: Date
    @Binding var showsCalendar: Bool
    let goals: DailyGoals

    var body: some View {
        cardContent
            .appGlassRoundedRect(cornerRadius: showsCalendar ? 28 : 24, interactive: false)
            .clipShape(RoundedRectangle(cornerRadius: showsCalendar ? 28 : 24, style: .continuous))
            .animation(.easeInOut(duration: 0.24), value: showsCalendar)
    }

    @ViewBuilder
    private var cardContent: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: 12) {
                content
            }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            HistoryWeekStrip(selectedDate: $selectedDate, goals: goals)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 0.5)
                .padding(.horizontal, 16)

            if showsCalendar {
                calendarSection
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    private var calendarSection: some View {
        HistoryCalendarView(selection: $selectedDate)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
    }
}

private struct HistoryWeekStrip: View {
    @Binding var selectedDate: Date
    let goals: DailyGoals

    @Query private var entries: [LogEntry]

    init(selectedDate: Binding<Date>, goals: DailyGoals) {
        _selectedDate = selectedDate
        self.goals = goals

        let normalizedSelection = selectedDate.wrappedValue.startOfDayValue
        let weekDates = normalizedSelection.weekDates
        let weekStart = weekDates.first ?? normalizedSelection
        let weekEnd = Calendar.current.date(byAdding: .day, value: 1, to: weekDates.last ?? normalizedSelection) ?? normalizedSelection
        _entries = Query(LogEntryDaySummary.descriptor(start: weekStart, end: weekEnd))
    }

    private var weekDates: [Date] {
        selectedDate.weekDates
    }

    private var snapshotsByDay: [Date: LogEntryDaySnapshot] {
        LogEntryDaySummary.snapshotsByDay(for: entries, matching: weekDates)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedDate = date
                    }
                } label: {
                    HistoryWeekdayCell(
                        date: date,
                        isSelected: date == selectedDate,
                        snapshot: snapshotsByDay[date] ?? .empty,
                        goals: goals
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct HistoryWeekdayCell: View {
    let date: Date
    let isSelected: Bool
    let snapshot: LogEntryDaySnapshot
    let goals: DailyGoals

    var body: some View {
        VStack(spacing: 8) {
            Text(date.weekdayNarrowTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                    }
                }

            WeekdayMacroRingView(totals: snapshot.totals, goals: goals)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(date.weekdayAccessibilityTitle))
        .accessibilityValue(Text("\(snapshot.entries.count) logged items"))
    }
}
