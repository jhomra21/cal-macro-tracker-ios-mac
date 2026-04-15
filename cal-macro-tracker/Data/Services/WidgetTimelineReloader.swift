import WidgetKit

enum WidgetTimelineReloader {
    static func reloadDailyMacroWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConfiguration.dailyMacroWidgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConfiguration.dailyMacroAccessoryWidgetKind)
    }
}
