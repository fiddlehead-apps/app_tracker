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

struct HomeView: View {
    @Environment(\.modelContext) private var context
    let refreshID: UUID
    @State private var path = NavigationPath()
    @State private var sheet: ActiveSheet?
    @State private var toast: Toast?

    var body: some View {
        NavigationStack(path: $path) {
            TrackerListView(sheet: $sheet, toast: $toast, path: $path)
                .id(refreshID)
                .navigationTitle("Tally")
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
                .navigationDestination(for: Tracker.self) { tracker in
                    TrackerDetailView(tracker: tracker, sheet: $sheet)
                        .id(refreshID)
                }
        }
        .sheet(item: $sheet) { sheet in
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
                SettingsView()
            }
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
    }

    /// Pops back to the list first, so no screen still shows the tracker when it goes away.
    private func delete(_ tracker: Tracker) {
        path = NavigationPath()
        toast = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            context.delete(tracker)
            try? context.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

/// The list of tracker cards. Separate so it can be re-created to re-run its queries.
struct TrackerListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Tracker.order) private var trackers: [Tracker]
    @Query private var recent: [Entry]
    @Binding var sheet: ActiveSheet?
    @Binding var toast: Toast?
    @Binding var path: NavigationPath

    init(sheet: Binding<ActiveSheet?>, toast: Binding<Toast?>, path: Binding<NavigationPath>) {
        _sheet = sheet
        _toast = toast
        _path = path
        let since = Day.add(-6, to: Date())
        _recent = Query(filter: #Predicate<Entry> { $0.date >= since })
    }

    var body: some View {
        let counts = countsByTracker
        Group {
            if trackers.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to track yet", systemImage: "number")
                } description: {
                    Text("Start from a template like Water or Meditation, or build your own tracker with the fields you need.")
                } actions: {
                    Button("Create a tracker") { sheet = .newTracker }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                        ForEach(trackers) { tracker in
                            TrackerCard(tracker: tracker, counts: counts[tracker.id] ?? [:]) {
                                plusTapped(tracker)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 16))
                            .onTapGesture { path.append(tracker) }
                            .contextMenu {
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80)
                }
                .background(Color(.systemGroupedBackground))
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
