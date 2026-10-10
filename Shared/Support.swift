import Foundation
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Colors

enum Palette {
    /// (light, dark) pairs. Index 0 matches the web Tally's default blue.
    static let pairs: [(UInt32, UInt32)] = [
        (0x3547D4, 0x8A9BFF), // indigo
        (0x1E8A5A, 0x5FD39B), // green
        (0xB8367A, 0xF27DB8), // magenta
        (0xB7791F, 0xF2B860), // amber
        (0x0E7C8C, 0x4FC9D9), // teal
        (0x6A4BB5, 0xB59CF5), // violet
        (0xC2412D, 0xFF8A75), // red
        (0x2F7FC1, 0x7CBEF5), // sky
        (0x6B7A1F, 0xB8C95A), // olive
        (0x4A5868, 0xA3B0BE), // slate
    ]

    static var count: Int { pairs.count }

    static func color(_ index: Int) -> Color {
        let (light, dark) = pairs[((index % count) + count) % count]
        return Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

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
