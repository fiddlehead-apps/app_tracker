import Charts
import SwiftUI

/// Line charts over a day range: one for the number of entries, one per field.
/// Text and choice fields get a line per value (top five + "Other"),
/// numeric fields a line of their daily sum or average.
struct TimelineSection: View {
    let tracker: Tracker
    let entries: [Entry]
    @State private var range = 30
    @State private var selected: Date?

    var body: some View {
        let days = (0..<range).map { Day.add($0 - (range - 1), to: Date()) }
        let inRange = entries.filter { $0.day >= days[0] }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Timeline")
                    .font(.title3.weight(.bold))
                Spacer()
                Picker("Range", selection: $range) {
                    Text("14 d").tag(14)
                    Text("30 d").tag(30)
                    Text("90 d").tag(90)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            ChartCard(model: countModel(days: days, entries: inRange), selected: $selected)
            ForEach(tracker.sortedFields) { field in
                ChartCard(model: model(for: field, days: days, entries: inRange), selected: $selected)
            }
        }
        .onChange(of: range) { selected = nil }
    }

    // MARK: Models

    private func countModel(days: [Date], entries: [Entry]) -> ChartModel {
        let counts = entries.countsByDay()
        let name = String(localized: "Entries")
        let points = days.map { ChartPoint(day: $0, series: name, value: Double(counts[$0] ?? 0)) }
        return ChartModel(title: name, points: points, series: [name], colors: [tracker.color],
                          kind: .count, unit: "", showPoints: days.count <= 30)
    }

    private func model(for field: TrackerField, days: [Date], entries: [Entry]) -> ChartModel {
        let values: [(Date, EntryValue)] = entries.compactMap { e in
            guard let v = e.value(for: field), !v.isEmpty else { return nil }
            return (e.day, v)
        }
        switch field.kind {
        case .text, .choice:
            return categoricalModel(field: field, days: days, values: values)
        case .number, .duration, .rating, .toggle:
            return numericModel(field: field, days: days, values: values)
        }
    }

    private func categoricalModel(field: TrackerField, days: [Date], values: [(Date, EntryValue)]) -> ChartModel {
        struct Bucket { var label: String; var perDay: [Date: Int] = [:]; var total = 0 }
        var buckets: [String: Bucket] = [:]
        for (day, v) in values {
            let label = v.text.trimmingCharacters(in: .whitespaces)
            let key = label.lowercased()
            buckets[key, default: Bucket(label: label)].perDay[day, default: 0] += 1
            buckets[key]?.total += 1
        }
        // Ties broken by name so colors stay put between renders.
        let sorted = buckets.values.sorted { ($0.total, $1.label.lowercased()) > ($1.total, $0.label.lowercased()) }
        var series = Array(sorted.prefix(5))
        if sorted.count > 5 {
            var other = Bucket(label: String(localized: "Other"))
            for b in sorted.dropFirst(5) {
                for (d, n) in b.perDay { other.perDay[d, default: 0] += n }
                other.total += b.total
            }
            series.append(other)
        }
        let names = series.map(\.label)
        let colors = series.indices.map { i in
            i == 5 ? Color.gray : Palette.color(Self.seriesColorOrder[i % Self.seriesColorOrder.count])
        }
        let points = series.flatMap { b in
            days.map { ChartPoint(day: $0, series: b.label, value: Double(b.perDay[$0] ?? 0)) }
        }
        return ChartModel(title: field.name, points: points, series: names, colors: colors,
                          kind: .count, unit: "", showPoints: days.count <= 30,
                          totals: Dictionary(uniqueKeysWithValues: series.map { ($0.label, Double($0.total)) }))
    }

    private func numericModel(field: TrackerField, days: [Date], values: [(Date, EntryValue)]) -> ChartModel {
        var perDay: [Date: [Double]] = [:]
        for (day, v) in values {
            guard let n = v.number else { continue }
            perDay[day, default: []].append(field.kind == .toggle ? (n >= 0.5 ? 1 : 0) : n)
        }
        let average = field.kind == .rating || (field.kind == .number && field.aggregate == .average)
        let name = field.name
        var points: [ChartPoint] = []
        for day in days {
            let list = perDay[day] ?? []
            if average {
                guard !list.isEmpty else { continue }
                points.append(ChartPoint(day: day, series: name, value: list.reduce(0, +) / Double(list.count)))
            } else {
                points.append(ChartPoint(day: day, series: name, value: list.reduce(0, +)))
            }
        }
        let kind: ChartModel.Kind = switch field.kind {
        case .duration: .duration
        case .rating: .rating
        case .toggle: .count
        default: .number
        }
        let all = perDay.values.flatMap { $0 }
        let summary: Double? = all.isEmpty ? nil : (average ? all.reduce(0, +) / Double(all.count) : all.reduce(0, +))
        var title = field.name
        if field.kind == .toggle { title += " · " + String(localized: "Yes") }
        return ChartModel(title: title, points: points, series: [name], colors: [tracker.color],
                          kind: kind, unit: field.unit, showPoints: average || days.count <= 30,
                          summary: summary.map { (average ? String(localized: "Average") : String(localized: "Total"), $0) })
    }

    private static let seriesColorOrder = [0, 2, 1, 3, 4]
}

struct ChartPoint: Identifiable {
    let id = UUID()
    let day: Date
    let series: String
    let value: Double
}

struct ChartModel {
    enum Kind { case count, number, duration, rating }

    var title: String
    var points: [ChartPoint]
    var series: [String]
    var colors: [Color]
    var kind: Kind
    var unit: String
    var showPoints: Bool
    var totals: [String: Double] = [:]
    var summary: (String, Double)? = nil

    var isEmpty: Bool { points.allSatisfy { $0.value == 0 } }

    func format(_ v: Double) -> String {
        switch kind {
        case .count: return Fmt.number(v)
        case .number: return unit.isEmpty ? Fmt.number(v) : "\(Fmt.number(v)) \(unit)"
        case .duration: return Fmt.duration(minutes: v)
        case .rating: return v.formatted(.number.precision(.fractionLength(0...1))) + " ★"
        }
    }

    func axisLabel(_ v: Double) -> String {
        switch kind {
        case .duration: return v >= 120 ? Fmt.number(v / 60) + " h" : Fmt.number(v) + " min"
        default: return Fmt.number(v)
        }
    }
}

struct ChartCard: View {
    let model: ChartModel
    @Binding var selected: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let (label, value) = model.summary {
                    Text(verbatim: "\(label): \(model.format(value))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            if model.isEmpty {
                Text("Nothing logged in this range.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                chart
                readout
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var chart: some View {
        Chart {
            ForEach(model.points) { p in
                LineMark(x: .value("Day", p.day, unit: .day), y: .value("Value", p.value))
                    .foregroundStyle(by: .value("Series", p.series))
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                if model.showPoints && (p.value > 0 || model.kind == .rating) {
                    PointMark(x: .value("Day", p.day, unit: .day), y: .value("Value", p.value))
                        .foregroundStyle(by: .value("Series", p.series))
                        .symbolSize(18)
                }
            }
            if let selected {
                RuleMark(x: .value("Selected", selected, unit: .day))
                    .foregroundStyle(Color.primary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartForegroundStyleScale(domain: model.series, range: model.colors)
        .chartLegend(model.series.count > 1 ? .visible : .hidden)
        .chartLegend(position: .bottom, alignment: .leading)
        .chartYScale(domain: model.kind == .rating ? 0...5 : 0...max(1, (model.points.map(\.value).max() ?? 1)))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text(model.axisLabel(v)) }
                }
            }
        }
        // chartXSelection loses its gesture to the surrounding ScrollView, so selection is
        // done by hand: tap picks a day (tap again clears), horizontal drags scrub.
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let day = day(at: location, proxy: proxy, geo: geo)
                        selected = day == selected ? nil : day
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                if let day = day(at: value.location, proxy: proxy, geo: geo) { selected = day }
                            }
                    )
            }
        }
        .frame(height: 170)
    }

    private func day(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> Date? {
        guard let plot = proxy.plotFrame else { return nil }
        let x = location.x - geo[plot].origin.x
        guard let date: Date = proxy.value(atX: x) else { return nil }
        let days = Set(model.points.map(\.day))
        let day = Day.start(date)
        return days.contains(day) ? day : nil
    }

    @ViewBuilder
    private var readout: some View {
        if let selected {
            // Single-line charts show their value even when it is 0; multi-line charts only list what happened.
            let items = model.points.filter { $0.day == selected && (model.series.count == 1 || $0.value > 0) }
            let parts = items.map { model.series.count > 1 ? "\($0.series) \(model.format($0.value))" : model.format($0.value) }
            Text(verbatim: "\(selected.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))): " + (parts.isEmpty ? "–" : parts.joined(separator: " · ")))
                .font(.footnote.weight(.medium))
        } else if model.series.count > 1 {
            Text(model.series.map { "\($0) \(Fmt.number(model.totals[$0] ?? 0))" }.joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        } else {
            Text("Tap or drag on the chart to see a day.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
