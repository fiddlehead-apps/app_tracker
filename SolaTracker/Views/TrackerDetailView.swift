import SwiftData
import SwiftUI

struct TrackerDetailView: View {
    @Environment(\.modelContext) private var context
    let tracker: Tracker
    @Binding var sheet: ActiveSheet?
    @Query private var entries: [Entry]
    @State private var selectedDay: Date?

    init(tracker: Tracker, sheet: Binding<ActiveSheet?>) {
        self.tracker = tracker
        _sheet = sheet
        let id = tracker.id
        _entries = Query(filter: #Predicate<Entry> { $0.tracker?.id == id },
                         sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.trackedAt, order: .reverse)])
    }

    var body: some View {
        let counts = entries.countsByDay()
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StatsRow(counts: counts, color: tracker.color, goal: tracker.dailyGoal)
                CalendarHeatmap(counts: counts, color: tracker.color, selected: $selectedDay)
                TimelineSection(tracker: tracker, entries: entries)
                entriesSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(tracker.name)
        .navigationBarTitleDisplayMode(.large)
        .tint(tracker.color)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if tracker.isHidden {
                    Button { tracker.setHidden(false, in: context) } label: {
                        Label("Unhide", systemImage: "eye")
                    }
                }
                Button { sheet = .editTracker(tracker) } label: {
                    Label("Edit tracker", systemImage: "slider.horizontal.3")
                }
                Button { sheet = .newEntry(tracker, day: selectedDay) } label: {
                    Label("Log entry", systemImage: "plus")
                }
            }
        }
    }

    @ViewBuilder
    private var entriesSection: some View {
        let shown = selectedDay.map { day in entries.filter { $0.day == day } } ?? entries
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                if let selectedDay {
                    Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.title3.weight(.bold))
                    Spacer()
                    Button("Show all") { self.selectedDay = nil }
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("Entries")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text("Tap a day to filter")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if shown.isEmpty {
                Text(selectedDay == nil ? "Nothing logged yet." : "Nothing logged on this day.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                let groups = Dictionary(grouping: shown.prefix(selectedDay == nil ? 300 : shown.count), by: \.day)
                ForEach(groups.keys.sorted(by: >), id: \.self) { day in
                    VStack(alignment: .leading, spacing: 6) {
                        if selectedDay == nil {
                            Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(groups[day] ?? []) { entry in
                            EntryRow(entry: entry, fields: tracker.sortedFields)
                                .onTapGesture { sheet = .editEntry(entry) }
                                .contextMenu {
                                    Button("Edit") { sheet = .editEntry(entry) }
                                    Button("Delete", role: .destructive) { EntryFactory.delete(entry, in: context) }
                                }
                        }
                    }
                }
            }
            if let selectedDay {
                Button {
                    sheet = .newEntry(tracker, day: selectedDay)
                } label: {
                    Label("Log entry on this day", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct EntryRow: View {
    let entry: Entry
    let fields: [TrackerField]

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Group {
                if entry.hasTime {
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(.body.weight(.bold).monospacedDigit())
                } else {
                    Text("All day")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                let parts = fields.compactMap { field -> (String, String)? in
                    guard let v = entry.value(for: field), !v.isEmpty else { return nil }
                    return (field.name, v.display(as: field.kind, unit: field.unit))
                }
                if parts.isEmpty && entry.note.isEmpty {
                    Text("No details").foregroundStyle(.secondary)
                }
                ForEach(parts, id: \.0) { name, value in
                    (Text(name + "  ").foregroundStyle(.secondary).font(.footnote) + Text(value))
                }
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatsRow: View {
    let counts: [Date: Int]
    let color: Color
    let goal: Int

    var body: some View {
        let now = Date()
        let today = Day.start(now), week = Day.startOfWeek(now), month = Day.startOfMonth(now)
        let items: [(String, Int)] = [
            (String(localized: "Today"), counts[today] ?? 0),
            (String(localized: "This week"), counts.filter { $0.key >= week }.values.reduce(0, +)),
            (String(localized: "This month"), counts.filter { $0.key >= month }.values.reduce(0, +)),
            (String(localized: "All time"), counts.values.reduce(0, +)),
        ]
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(items, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(verbatim: "\(value)")
                            .font(.title2.weight(.heavy).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
                }
            }
            if goal > 0 {
                let days = (0..<30).map { Day.add(-$0, to: now) }
                let hit = days.filter { (counts[$0] ?? 0) >= goal }.count
                let streak = streakLength(today: today)
                HStack(spacing: 16) {
                    Label { Text("Goal: \(goal) per day") } icon: { Image(systemName: "target") }
                    Label { Text("\(hit) of 30 days") } icon: { Image(systemName: "checkmark.circle") }
                    Label { Text("Streak \(streak)") } icon: { Image(systemName: "flame") }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            }
        }
    }

    /// Consecutive days that reached the goal. Today counts only once it's reached.
    private func streakLength(today: Date) -> Int {
        var n = 0
        var d = (counts[today] ?? 0) >= goal ? today : Day.add(-1, to: today)
        while (counts[d] ?? 0) >= goal {
            n += 1
            d = Day.add(-1, to: d)
        }
        return n
    }
}

/// 15 weeks of days. Tap a day to filter the list.
struct CalendarHeatmap: View {
    let counts: [Date: Int]
    let color: Color
    @Binding var selected: Date?
    private let weeks = 15

    var body: some View {
        let today = Day.start(Date())
        let start = Day.add(-(weeks - 1) * 7, to: Day.startOfWeek(today))
        let maxValue = max(1, (0..<(weeks * 7)).map { counts[Day.add($0, to: start)] ?? 0 }.max() ?? 1)
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1

        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Color.clear.frame(width: 14, height: 1)
                ForEach(0..<weeks, id: \.self) { w in
                    let d = Day.add(w * 7, to: start)
                    let prev = Day.add((w - 1) * 7, to: start)
                    let next = Day.add((w + 1) * 7, to: start)
                    let month = { (date: Date) in Calendar.current.component(.month, from: date) }
                    // The first column gets a label only if the next one doesn't start a new month.
                    let showMonth = w == 0 ? month(d) == month(next) : month(d) != month(prev)
                    Text(showMonth ? d.formatted(.dateTime.month(.abbreviated)) : "")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack(alignment: .top, spacing: 3) {
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { r in
                        Text(r % 2 == 0 ? symbols[(first + r) % 7] : "")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                            .frame(maxHeight: .infinity)
                    }
                }
                ForEach(0..<weeks, id: \.self) { w in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { r in
                            let day = Day.add(w * 7 + r, to: start)
                            cell(day: day, today: today, maxValue: maxValue)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    @ViewBuilder
    private func cell(day: Date, today: Date, maxValue: Int) -> some View {
        if day > today {
            Color.clear.aspectRatio(1, contentMode: .fit)
        } else {
            let v = counts[day] ?? 0
            let strength = v == 0 ? 0 : 0.2 + 0.8 * Double(v) / Double(maxValue)
            Button {
                selected = selected == day ? nil : day
            } label: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(v == 0 ? Color(.tertiarySystemFill) : color.opacity(strength))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if v > 0 {
                            Text(verbatim: "\(v)")
                                .font(.system(size: 8, weight: .semibold).monospacedDigit())
                                .foregroundStyle(strength > 0.55 ? .white : .primary)
                                .minimumScaleFactor(0.5)
                        }
                    }
                    .overlay {
                        if day == selected {
                            RoundedRectangle(cornerRadius: 3).strokeBorder(Color.primary, lineWidth: 2)
                        } else if day == today {
                            RoundedRectangle(cornerRadius: 3).strokeBorder(color, lineWidth: 1.5)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: "\(day.formatted(date: .complete, time: .omitted)): \(v)"))
        }
    }
}
