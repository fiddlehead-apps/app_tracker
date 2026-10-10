import Foundation
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Colors

extension Tracker {
    var color: Color { Palette.color(colorIndex) }
}

// MARK: - Formatting

enum Fmt {
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func duration(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        if total == 0 { return "0 min" }
        return Duration.seconds(total * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// Accepts both "1.5" and "1,5".
    static func parseNumber(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !t.isEmpty else { return nil }
        return Double(t)
    }

    /// Plain text for editing a number, using the user's decimal separator.
    static func editable(_ value: Double?) -> String {
        guard let value else { return "" }
        let s = value.formatted(.number.precision(.fractionLength(0...4)).grouping(.never))
        return s
    }
}

// MARK: - Days

enum Day {
    static var calendar: Calendar { Calendar.current }

    static func start(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    static func add(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: start(date)) ?? date
    }

    static func startOfWeek(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? start(date)
    }

    static func startOfMonth(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? start(date)
    }

    static var tomorrow: Date { add(1, to: Date()) }
}

extension Collection where Element == Entry {
    func countsByDay() -> [Date: Int] {
        var out: [Date: Int] = [:]
        for e in self { out[e.day, default: 0] += 1 }
        return out
    }
}

// MARK: - Logging

enum EntryFactory {
    /// Logs one entry right now, filling every field that has a default.
    @discardableResult
    static func quickLog(_ tracker: Tracker, in context: ModelContext, at date: Date = Date()) -> Entry {
        let entry = Entry(date: date, hasTime: true)
        context.insert(entry)
        entry.tracker = tracker
        for field in tracker.sortedFields where field.hasDefault {
            let value: EntryValue
            switch field.kind {
            case .text, .choice: value = EntryValue(text: field.defaultText)
            default: value = EntryValue(number: field.defaultNumber)
            }
            context.insert(value)
            value.entry = entry
            value.field = field
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return entry
    }

    static func delete(_ entry: Entry, in context: ModelContext) {
        context.delete(entry)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
