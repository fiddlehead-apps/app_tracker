import LocalAuthentication
import SwiftData
import SwiftUI
import WidgetKit

enum Unlock {
    /// Face ID or Touch ID (or the device passcode as fallback). Fails when the device has no passcode.
    static func run() async -> Bool {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "Show hidden trackers"))) ?? false
    }
}

extension Tracker {
    /// Moves the tracker out of (or back into) the home screen, widgets, Shortcuts suggestions and the watch.
    @MainActor func setHidden(_ hidden: Bool, in context: ModelContext) {
        isHidden = hidden
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        WatchBridge.shared.pushContext()
    }
}

/// Counts quick successive taps. A single (or double) tap runs `single`
/// once the taps stop; reaching `count` taps runs `reached` instead.
struct MultiTap: ViewModifier {
    var count: Int
    var window: Duration
    var single: (() -> Void)?
    var reached: () -> Void

    @State private var taps = 0
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content.onTapGesture {
            taps += 1
            pending?.cancel()
            if taps >= count {
                taps = 0
                reached()
                return
            }
            pending = Task {
                try? await Task.sleep(for: window)
                guard !Task.isCancelled else { return }
                let n = taps
                taps = 0
                if n <= 2 { single?() }
            }
        }
    }
}

extension View {
    func onMultiTap(_ count: Int, window: Duration, single: (() -> Void)? = nil, reached: @escaping () -> Void) -> some View {
        modifier(MultiTap(count: count, window: window, single: single, reached: reached))
    }

    /// Covers the screen, so hidden trackers don't show up in the app switcher.
    func privacyCover(_ on: Bool) -> some View {
        overlay {
            if on { Color(.systemGroupedBackground).ignoresSafeArea() }
        }
    }
}
