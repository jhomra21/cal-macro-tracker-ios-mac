import Foundation
import SwiftUI

@MainActor
@Observable
final class AppDayContext {
    private(set) var today = CalendarDay(date: .now)

    func refresh(using date: Date = .now) {
        today = CalendarDay(date: date)
    }
}
