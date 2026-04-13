import SwiftUI

struct AppRootView: View {
    private enum Route: Hashable {
        case history
        case settings
    }

    @State private var destination: Route?

    var body: some View {
        NavigationStack {
            DashboardScreen(
                onOpenHistory: { open(.history) },
                onOpenSettings: { open(.settings) }
            )
            .navigationDestination(item: $destination) { route in
                switch route {
                case .history:
                    HistoryScreen()
                case .settings:
                    SettingsScreen()
                }
            }
        }
    }

    private func open(_ route: Route) {
        guard destination == nil else { return }
        destination = route
    }
}
