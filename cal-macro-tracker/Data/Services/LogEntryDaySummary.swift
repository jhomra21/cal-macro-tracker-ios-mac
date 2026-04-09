import Foundation
import SwiftData

struct LogEntryDaySnapshot {
    let entries: [LogEntry]
    let totals: NutritionSnapshot

    static let empty = LogEntryDaySnapshot(entries: [], totals: .zero)
}

enum LogEntryDaySummary {
    static func descriptor(for date: Date) -> FetchDescriptor<LogEntry> {
        let interval = date.dayInterval
        return descriptor(start: interval.start, end: interval.end)
    }

    static func descriptor(start: Date, end: Date) -> FetchDescriptor<LogEntry> {
        let predicate = #Predicate<LogEntry> { entry in
            entry.dateLogged >= start && entry.dateLogged < end
        }

        return FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\LogEntry.dateLogged, order: .reverse)]
        )
    }

    static func snapshot(for entries: [LogEntry]) -> LogEntryDaySnapshot {
        LogEntryDaySnapshot(entries: entries, totals: NutritionMath.totals(for: entries))
    }

    static func snapshotsByDay(for entries: [LogEntry], matching dates: [Date]) -> [Date: LogEntryDaySnapshot] {
        let entriesByDay = Dictionary(grouping: entries) { entry in
            entry.dateLogged.startOfDayValue
        }

        return dates.reduce(into: [Date: LogEntryDaySnapshot]()) { snapshots, date in
            snapshots[date] = snapshot(for: entriesByDay[date] ?? [])
        }
    }
}
