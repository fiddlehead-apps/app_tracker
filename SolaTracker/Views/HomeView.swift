import SwiftData
import SwiftUI
import WidgetKit

enum ActiveSheet: Identifiable {
    case newTracker
    case editTracker(Tracker)
    case newEntry(Tracker, day: Date?)
    case editEntry(Entry)
    case settings

    var id: String {
        switch self {
        case .newTracker: "new"
        case .editTracker(let t): "edit-\(t.id)"
        case .newEntry(let t, let d): "entry-\(t.id)-\(d?.timeIntervalSince1970 ?? 0)"
        case .editEntry(let e): "entry-\(e.id)"
        case .settings: "settings"
        }
    }
}

enum Route: Hashable {
    case tracker(Tracker)
    case hidden

    var showsHidden: Bool {
        switch self {
        case .tracker(let t): t.isHidden
        case .hidden: true
        }
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    let refreshID: UUID
    @State private var path: [Route] = []
    @State private var sheet: ActiveSheet?
    @State private var toast: Toast?

    var body: some View {
        // Keeps hidden trackers out of the app switcher.
        let cover = scenePhase != .active && showsHidden
        NavigationStack(path: $path) {
            TrackerListView(hidden: false, sheet: $sheet, toast: $toast, path: $path, onUnlock: unlockHidden)
                .id(refreshID)
                .navigationTitle("Sola Tracker")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { sheet = .settings } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { sheet = .newTracker } label: {
                            Label("New tracker", systemImage: "plus")
                        }
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .tracker(let tracker):
                        TrackerDetailView(tracker: tracker, sheet: $sheet)
                            .id(refreshID)
                    case .hidden:
                        TrackerListView(hidden: true, sheet: $sheet, toast: $toast, path: $path)
                            .id(refreshID)
                            .navigationTitle("Hidden trackers")
                    }
                }
        }
        .sheet(item: $sheet) { sheet in
            Group {
            switch sheet {
            case .newTracker:
                NewTrackerView()
            case .editTracker(let tracker):
                NavigationStack {
                    TrackerEditorView(tracker: tracker, draft: TrackerDraft(tracker: tracker)) { deleted in
                        self.sheet = nil
                        if deleted { delete(tracker) }
                    }
                }
            case .newEntry(let tracker, let day):
                EntryFormView(tracker: tracker, entry: nil, day: day)
            case .editEntry(let entry):
                if let tracker = entry.tracker {
                    EntryFormView(tracker: tracker, entry: entry, day: nil)
                }
            case .settings:
                SettingsView(onUnlock: unlockHidden)
            }
            }
            .privacyCover(cover)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                ToastView(toast: toast) {
                    // A replaced toast's timer must not close its successor.
                    if self.toast?.id == toast.id { self.toast = nil }
                } onDetails: { entry in
                    self.toast = nil
                    sheet = .editEntry(entry)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(toast.id)
            }
        }
        .animation(.snappy, value: toast?.id)
        .privacyCover(cover)
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app locks the hidden trackers again.
            if phase == .background { lockHidden() }
        }
    }

    private var showsHidden: Bool { path.contains { $0.showsHidden } }

    /// Asks for Face ID / Touch ID, then opens the hidden trackers.
    private func unlockHidden() {
        Task {
            guard await Unlock.run() else { return }
            sheet = nil
            toast = nil
            path = [.hidden]
        }
    }

    private func lockHidden() {
        guard let i = path.firstIndex(where: \.showsHidden) else { return }
        path.removeSubrange(i...)
        sheet = nil
        toast = nil
    }

    /// Pops back to the list first, so no screen still shows the tracker when it goes away.
    private func delete(_ tracker: Tracker) {
        path = []
        toast = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            context.delete(tracker)
            try? context.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

/// The list of tracker cards, either the home screen or the hidden trackers.
/// Separate so it can be re-created to re-run its queries.
struct TrackerListView: View {
    @Environment(\.modelContext) private var context
    /// Hidden trackers open on the first tap and offer "Unhide". On the home screen
    /// five quick taps on a tracker offer to hide it.
    let hidden: Bool
    @Query private var trackers: [Tracker]
    @Query private var recent: [Entry]
    @Binding var sheet: ActiveSheet?
    @Binding var toast: Toast?
    @Binding var path: [Route]
    var onUnlock: (() -> Void)?
    @State private var hideCandidate: Tracker?

    init(hidden: Bool, sheet: Binding<ActiveSheet?>, toast: Binding<Toast?>, path: Binding<[Route]>,
         onUnlock: (() -> Void)? = nil) {
        self.hidden = hidden
        _sheet = sheet
        _toast = toast
        _path = path
        self.onUnlock = onUnlock
        _trackers = Query(filter: #Predicate<Tracker> { $0.isHidden == hidden }, sort: \Tracker.order)
        let since = Day.add(-6, to: Date())
        _recent = Query(filter: #Predicate<Entry> { $0.date >= since })
    }

    var body: some View {
        let counts = countsByTracker
        Group {
            if trackers.isEmpty && hidden {
                ContentUnavailableView {
                    Label("No hidden trackers", systemImage: "eye.slash")
                } description: {
                    Text("Tap a tracker on the home screen five times to hide it.")
                }
            } else if trackers.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("Nothing to track yet")
                    } icon: {
                        TallyIllustration()
                    }
                } description: {
                    Text("Start from a template like Water or Meditation, or build your own tracker with the fields you need.")
                } actions: {
                    Button("Create a tracker") { sheet = .newTracker }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        dateLine
                        ForEach(trackers) { tracker in
                            card(tracker, counts: counts[tracker.id] ?? [:])
                                .contextMenu {
                                    if hidden {
                                        Button { withAnimation { tracker.setHidden(false, in: context) } } label: {
                                            Label("Unhide", systemImage: "eye")
                                        }
                                    }
                                    Button { sheet = .newEntry(tracker, day: nil) } label: {
                                        Label("Log with details", systemImage: "square.and.pencil")
                                    }
                                    Button { EntryFactory.quickLog(tracker, in: context) } label: {
                                        Label("Log instantly", systemImage: "bolt")
                                    }
                                    Button { sheet = .editTracker(tracker) } label: {
                                        Label("Edit tracker", systemImage: "slider.horizontal.3")
                                    }
                                }
                        }
                        if hidden {
                            Text("Hidden trackers don't show up on the home screen, in widgets, in Shortcuts or on Apple Watch. Touch and hold one to unhide it.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .padding(.top, 6)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .confirmationDialog("Hide this tracker?", isPresented: Binding(get: { hideCandidate != nil },
                                                                         set: { if !$0 { hideCandidate = nil } }),
                            titleVisibility: .visible, presenting: hideCandidate) { t in
            Button("Hide “\(t.name)”") {
                withAnimation { t.setHidden(true, in: context) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It disappears from this list, the widgets and Apple Watch, and only shows up in the hidden trackers.")
        }
    }

    @ViewBuilder private var dateLine: some View {
        let text = Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        if let onUnlock {
            // Tapping the date five times asks for Face ID / Touch ID and opens the hidden trackers.
            text
                .contentShape(.rect)
                .onMultiTap(5, window: .milliseconds(1200), reached: onUnlock)
        } else {
            text
        }
    }

    @ViewBuilder private func card(_ tracker: Tracker, counts: [Date: Int]) -> some View {
        let card = TrackerCard(tracker: tracker, counts: counts) { plusTapped(tracker) }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        if hidden {
            card.onTapGesture { path.append(.tracker(tracker)) }
        } else {
            card.onMultiTap(5, window: .milliseconds(300), single: { path.append(.tracker(tracker)) }) {
                hideCandidate = tracker
            }
        }
    }

    private var countsByTracker: [UUID: [Date: Int]] {
        var out: [UUID: [Date: Int]] = [:]
        for e in recent {
            guard let id = e.tracker?.id else { continue }
            out[id, default: [:]][e.day, default: 0] += 1
        }
        return out
    }

    private func plusTapped(_ tracker: Tracker) {
        switch tracker.logMode {
        case .form:
            sheet = .newEntry(tracker, day: nil)
        case .quick:
            let entry = EntryFactory.quickLog(tracker, in: context)
            toast = Toast(message: String(localized: "Logged \(tracker.name)"), entry: entry)
        }
    }
}
