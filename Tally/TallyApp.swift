import SwiftData
import SwiftUI
import WidgetKit

@main
struct TallyApp: App {
    init() {
        WatchBridge.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Persistence.shared)
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
    }
}
