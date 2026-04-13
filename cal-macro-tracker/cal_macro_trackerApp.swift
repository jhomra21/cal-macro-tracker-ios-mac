//
//  cal_macro_trackerApp.swift
//  cal-macro-tracker
//
//  Created by Juan Martinez on 4/1/26.
//

import Foundation
import SwiftData
import SwiftUI

@main
struct cal_macro_trackerApp: App {
    @State private var launchState = AppLaunchState()
    @State private var dayContext = AppDayContext()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                switch launchState.phase {
                case .launching:
                    ProgressView("Starting app…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case let .ready(modelContainer):
                    ContentView()
                        .modelContainer(modelContainer)
                case let .failed(message):
                    AppLaunchErrorView(message: message)
                }
            }
            .environment(dayContext)
            .task {
                await launchState.start()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                dayContext.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                dayContext.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
                dayContext.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                dayContext.refresh()
            }
        }
    }
}
