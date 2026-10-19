import SwiftData
import SwiftUI
import WidgetKit

@main
struct SolaTrackerApp: App {
    /// Replaced when the user turns iCloud sync on or off (see Persistence.apply).
    @State private var container = Persistence.shared

    init() {
        WatchBridge.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // A fresh view tree, so no screen keeps objects from the old store.
                .id(ObjectIdentifier(container))
                .onReceive(NotificationCenter.default.publisher(for: Persistence.didReopen)) { _ in
                    container = Persistence.shared
                    WidgetCenter.shared.reloadAllTimelines()
                    WatchBridge.shared.pushContext()
                }
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    /// Bumped when the app returns from the background, so lists re-query
    /// (picks up entries logged from the widget, and a new day).
    @State private var refreshID = UUID()
    @State private var wasInBackground = false

    var body: some View {
        HomeView(refreshID: refreshID)
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    wasInBackground = true
                    WidgetCenter.shared.reloadAllTimelines()
                case .active where wasInBackground:
                    wasInBackground = false
                    refreshID = UUID()
                    WatchBridge.shared.pushContext()
                default:
                    break
                }
            }
            // Retries an iCloud deletion that didn't go through last time.
            .task { Persistence.apply() }
    }
}
