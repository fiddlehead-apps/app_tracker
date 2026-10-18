import SwiftUI

@main
struct TallyWatchApp: App {
    @StateObject private var store = WatchStore.shared

    init() {
        WatchStore.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                TrackerListView()
            }
            .environmentObject(store)
        }
    }
}

// MARK: - Tracker list

struct TrackerListView: View {
    @EnvironmentObject private var store: WatchStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if store.trackers.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        Image(systemName: store.context == nil ? "iphone.radiowaves.left.and.right" : "plus.circle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(store.context == nil
                             ? "Open Sola Tracker on your iPhone once to load your trackers."
                             : "Create a tracker in Sola Tracker on your iPhone.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                }
            } else {
                List(store.trackers) { tracker in
                    NavigationLink(value: tracker.id) {
                        TrackerRow(tracker: tracker, count: store.todayCount(tracker))
                    }
                    .swipeActions(edge: .leading) {
                        Button { store.log(tracker) } label: {
                            Label("+1", systemImage: "plus")
                        }
                        .tint(Palette.color(tracker.colorIndex))
                    }
                }
            }
        }
        .navigationTitle("Sola Tracker")
        .navigationDestination(for: UUID.self) { id in
            TrackerLogView(trackerID: id)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refresh() }
        }
    }
}

struct TrackerRow: View {
    let tracker: WatchTracker
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tracker.symbol)
                .foregroundStyle(Palette.color(tracker.colorIndex))
                .frame(width: 22)
            Text(tracker.name)
                .lineLimit(2)
            Spacer(minLength: 4)
            Text(verbatim: tracker.goal > 0 ? "\(count)/\(tracker.goal)" : "\(count)")
                .font(.body.weight(.bold).monospacedDigit())
                .foregroundStyle(count == 0 ? .secondary : .primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Logging one tracker

struct TrackerLogView: View {
    @EnvironmentObject private var store: WatchStore
    let trackerID: UUID
    /// The entry logged on this screen; its details can be picked right below.
    @State private var currentID: UUID?

    var body: some View {
        if let tracker = store.tracker(trackerID) {
            let color = Palette.color(tracker.colorIndex)
            ScrollView {
                VStack(spacing: 10) {
                    Button {
                        currentID = store.log(tracker).id
                    } label: {
                        Text(verbatim: "+1")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 18))
                    .tint(color)

                    Text(tracker.goal > 0
                         ? String(localized: "Today: \(store.todayCount(tracker)) of \(tracker.goal)")
                         : String(localized: "Today: \(store.todayCount(tracker))"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let currentID, let event = store.event(currentID), !event.deleted {
                        EventEditor(tracker: tracker, eventID: currentID, color: color) {
                            self.currentID = nil
                        }
                    }

                    let earlier = store.todaysEvents(tracker).filter { $0.id != currentID }
                    if !earlier.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Logged on this watch today")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            ForEach(earlier) { event in
                                NavigationLink {
                                    ScrollView {
                                        EventEditor(tracker: tracker, eventID: event.id, color: color, onUndo: nil)
                                    }
                                    .navigationTitle(tracker.name)
                                } label: {
                                    HStack {
                                        Text(event.date, style: .time)
                                            .font(.body.weight(.semibold).monospacedDigit())
                                        Spacer()
                                        Text(summary(event, tracker: tracker))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .padding(.top, 6)
                    }
                }
            }
            .navigationTitle(tracker.name)
        } else {
            Text("This tracker no longer exists.")
                .foregroundStyle(.secondary)
        }
    }

    private func summary(_ event: WatchEvent, tracker: WatchTracker) -> String {
        tracker.fields.compactMap { event.values[$0.id.uuidString] }.filter { !$0.isNone }.map(\.label).joined(separator: " · ")
    }
}

/// Confirmation and optional details for one logged entry.
struct EventEditor: View {
    @EnvironmentObject private var store: WatchStore
    let tracker: WatchTracker
    let eventID: UUID
    let color: Color
    /// Shown as Undo right after logging; nil for older entries (they get Delete instead).
    let onUndo: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let event = store.event(eventID), !event.deleted {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Logged at \(event.date.formatted(date: .omitted, time: .shortened))")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                .font(.footnote.weight(.semibold))

                if !tracker.fields.isEmpty {
                    Text("Details (optional)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    ForEach(tracker.fields) { field in
                        FieldPicker(field: field, eventID: eventID)
                    }
                    Text("You can add the rest later on your iPhone.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    store.undo(eventID)
                    if let onUndo { onUndo() } else { dismiss() }
                } label: {
                    Label(onUndo == nil ? "Delete" : "Undo", systemImage: onUndo == nil ? "trash" : "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
        }
    }
}

struct FieldPicker: View {
    @EnvironmentObject private var store: WatchStore
    let field: WatchField
    let eventID: UUID

    var body: some View {
        if field.options.isEmpty {
            LabeledContent(field.name) {
                Text("Later on iPhone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Picker(field.name, selection: selection) {
                Text("None").tag("")
                ForEach(field.options) { option in
                    Text(option.label).tag(option.label)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    private var selection: Binding<String> {
        Binding(
            get: { store.event(eventID)?.values[field.id.uuidString]?.label ?? "" },
            set: { label in store.set(field.options.first { $0.label == label }, for: field, on: eventID) }
        )
    }
}
