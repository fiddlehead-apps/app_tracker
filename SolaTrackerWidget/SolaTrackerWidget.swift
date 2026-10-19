import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

@main
struct SolaTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrackerWidget()
        OverviewWidget()
    }
}

// MARK: - Data

struct TrackerSnapshot: Identifiable {
    let id: UUID
    let name: String
    let symbol: String
    let colorIndex: Int
    let today: Int
    let goal: Int

    var entity: TrackerEntity { TrackerEntity(id: id, name: name, symbol: symbol) }
    var color: Color { Palette.color(colorIndex) }

    static let placeholder = TrackerSnapshot(id: UUID(), name: String(localized: "Water"), symbol: "drop.fill", colorIndex: 7, today: 3, goal: 8)
}

@MainActor
enum WidgetData {
    static func snapshots(ids: [UUID]? = nil, limit: Int = 4) -> [TrackerSnapshot] {
        let context = Persistence.shared.mainContext
        let trackers = (try? context.fetch(Tracker.visible)) ?? []
        let chosen = ids.map { ids in trackers.filter { ids.contains($0.id) } } ?? Array(trackers.prefix(limit))
        let start = Day.start(Date())
        let entries = (try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.date >= start }))) ?? []
        var counts: [UUID: Int] = [:]
        for e in entries where e.date < Day.tomorrow {
            if let id = e.tracker?.id { counts[id, default: 0] += 1 }
        }
        return chosen.map {
            TrackerSnapshot(id: $0.id, name: $0.name, symbol: $0.symbol, colorIndex: $0.colorIndex, today: counts[$0.id] ?? 0, goal: $0.dailyGoal)
        }
    }
}

// MARK: - Single tracker (small)

struct SelectTrackerIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Tracker"
    static let description = IntentDescription("Pick the tracker this widget logs to.")

    @Parameter(title: "Tracker")
    var tracker: TrackerEntity?
}

struct SingleEntry: TimelineEntry {
    let date: Date
    let tracker: TrackerSnapshot?
    let hasAnyTracker: Bool
}

struct SingleProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SingleEntry {
        SingleEntry(date: Date(), tracker: .placeholder, hasAnyTracker: true)
    }

    func snapshot(for configuration: SelectTrackerIntent, in context: Context) async -> SingleEntry {
        if context.isPreview { return placeholder(in: context) }
        return await entry(for: configuration)
    }

    func timeline(for configuration: SelectTrackerIntent, in context: Context) async -> Timeline<SingleEntry> {
        Timeline(entries: [await entry(for: configuration)], policy: .after(Day.tomorrow))
    }

    @MainActor
    private func entry(for configuration: SelectTrackerIntent) -> SingleEntry {
        let all = WidgetData.snapshots(limit: 1)
        let chosen = configuration.tracker.flatMap { WidgetData.snapshots(ids: [$0.id]).first } ?? all.first
        return SingleEntry(date: Date(), tracker: chosen, hasAnyTracker: !all.isEmpty)
    }
}

struct TrackerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "SolaTracker", intent: SelectTrackerIntent.self, provider: SingleProvider()) { entry in
            SingleTrackerView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tracker")
        .description("Today's count with a +1 button.")
        .supportedFamilies([.systemSmall])
    }
}

struct SingleTrackerView: View {
    let entry: SingleEntry

    var body: some View {
        if let t = entry.tracker {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: t.symbol)
                        .font(.title3)
                        .foregroundStyle(t.color)
                    Spacer()
                    if t.goal > 0 {
                        Text(verbatim: "\(t.today)/\(t.goal)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(t.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: "\(t.today)")
                            .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                        Text("today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    PlusButton(tracker: t, size: 48)
                }
            }
        } else {
            EmptyWidgetView(hasAnyTracker: entry.hasAnyTracker)
        }
    }
}

// MARK: - Overview (medium)

struct OverviewEntry: TimelineEntry {
    let date: Date
    let trackers: [TrackerSnapshot]
}

struct OverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> OverviewEntry {
        OverviewEntry(date: Date(), trackers: [
            .placeholder,
            TrackerSnapshot(id: UUID(), name: String(localized: "Coffee"), symbol: "cup.and.saucer.fill", colorIndex: 3, today: 2, goal: 0),
            TrackerSnapshot(id: UUID(), name: String(localized: "Meditation"), symbol: "figure.mind.and.body", colorIndex: 0, today: 1, goal: 1),
            TrackerSnapshot(id: UUID(), name: String(localized: "Reading"), symbol: "book.fill", colorIndex: 1, today: 0, goal: 0),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (OverviewEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { @MainActor in completion(OverviewEntry(date: Date(), trackers: WidgetData.snapshots())) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OverviewEntry>) -> Void) {
        Task { @MainActor in
            let entry = OverviewEntry(date: Date(), trackers: WidgetData.snapshots())
            completion(Timeline(entries: [entry], policy: .after(Day.tomorrow)))
        }
    }
}

struct OverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SolaTrackerOverview", provider: OverviewProvider()) { entry in
            OverviewView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Overview")
        .description("Your first four trackers, each with a +1 button.")
        .supportedFamilies([.systemMedium])
    }
}

struct OverviewView: View {
    let entry: OverviewEntry

    var body: some View {
        if entry.trackers.isEmpty {
            EmptyWidgetView(hasAnyTracker: false)
        } else {
            Grid(horizontalSpacing: 12, verticalSpacing: 10) {
                ForEach(rows.indices, id: \.self) { r in
                    GridRow {
                        ForEach(rows[r]) { t in tile(t) }
                        if rows[r].count == 1 { Color.clear }
                    }
                }
            }
        }
    }

    private var rows: [[TrackerSnapshot]] {
        stride(from: 0, to: entry.trackers.count, by: 2).map { Array(entry.trackers[$0..<min($0 + 2, entry.trackers.count)]) }
    }

    private func tile(_ t: TrackerSnapshot) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Label {
                    Text(t.name).lineLimit(1)
                } icon: {
                    Image(systemName: t.symbol).foregroundStyle(t.color)
                }
                .font(.caption.weight(.semibold))
                Text(verbatim: t.goal > 0 ? "\(t.today)/\(t.goal)" : "\(t.today)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            PlusButton(tracker: t, size: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Shared pieces

struct PlusButton: View {
    let tracker: TrackerSnapshot
    let size: CGFloat

    var body: some View {
        Button(intent: LogTrackerIntent(tracker: tracker.entity)) {
            Image(systemName: "plus")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(tracker.color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Log \(tracker.name)"))
    }
}

struct EmptyWidgetView: View {
    let hasAnyTracker: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(hasAnyTracker ? "Edit the widget to pick a tracker." : "Open Sola Tracker to create a tracker.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
