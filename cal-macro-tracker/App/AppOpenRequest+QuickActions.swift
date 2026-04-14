#if os(iOS)
import UIKit

extension AppOpenRequest {
    init?(shortcutItem: UIApplicationShortcutItem) {
        guard shortcutItem.type.hasPrefix(SharedAppConfiguration.quickActionTypePrefix) else {
            return nil
        }

        let rawEntryPoint = String(shortcutItem.type.dropFirst(SharedAppConfiguration.quickActionTypePrefix.count))
        guard let entryPoint = AddFoodEntryPoint(rawValue: rawEntryPoint) else { return nil }
        self = .addFood(entryPoint)
    }
}
#endif
