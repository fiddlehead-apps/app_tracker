import Foundation
import SwiftData

// All models follow the CloudKit rules for SwiftData: every attribute has a
// default, every relationship is optional with an inverse, nothing is unique.

enum FieldKind: String, CaseIterable, Identifiable, Codable {
    case text, choice, number, duration, rating, toggle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: String(localized: "Text")
        case .choice: String(localized: "Choice")
        case .number: String(localized: "Number")
        case .duration: String(localized: "Duration")
        case .rating: String(localized: "Rating")
        case .toggle: String(localized: "Yes / No")
        }
    }

    var symbol: String {
        switch self {
        case .text: "textformat"
        case .choice: "list.bullet"
        case .number: "number"
        case .duration: "timer"
        case .rating: "star"
        case .toggle: "checkmark.circle"
        }
    }

    var hint: String {
        switch self {
        case .text: String(localized: "Free text. Earlier values are suggested as you type.")
        case .choice: String(localized: "Pick one of a fixed list of options.")
        case .number: String(localized: "A number with an optional unit, like ml, km or €.")
        case .duration: String(localized: "Hours and minutes.")
        case .rating: String(localized: "One to five stars.")
        case .toggle: String(localized: "A simple yes or no.")
        }
    }

    var isNumeric: Bool { self == .number || self == .duration || self == .rating || self == .toggle }
}

enum LogMode: String, CaseIterable, Identifiable {
    case quick, form
    var id: String { rawValue }
    var label: String {
        switch self {
        case .quick: String(localized: "Log instantly")
        case .form: String(localized: "Ask for details")
        }
    }
}

enum Aggregate: String, CaseIterable, Identifiable {
    case sum, average
    var id: String { rawValue }
    var label: String {
        switch self {
        case .sum: String(localized: "Sum per day")
        case .average: String(localized: "Average per day")
        }
    }
}

@Model
final class Tracker {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "circle.fill"
    var colorIndex: Int = 0
    var order: Int = 0
    var logModeRaw: String = LogMode.form.rawValue
    var dailyGoal: Int = 0
    var templateKey: String = ""
    var createdAt: Date = Date()
    /// Hidden trackers only show up behind Face ID, not on the home screen, in widgets or on the watch.
    var isHidden: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \TrackerField.tracker)
    var fields: [TrackerField]? = []

    @Relationship(deleteRule: .cascade, inverse: \Entry.tracker)
    var entries: [Entry]? = []

    init(name: String, symbol: String = "circle.fill", colorIndex: Int = 0, order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.symbol = symbol
        self.colorIndex = colorIndex
        self.order = order
        self.createdAt = Date()
    }

    var logMode: LogMode {
        get { LogMode(rawValue: logModeRaw) ?? .form }
        set { logModeRaw = newValue.rawValue }
    }

    var sortedFields: [TrackerField] {
        (fields ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class TrackerField {
    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = FieldKind.text.rawValue
    var unit: String = ""
    /// Choice options, one per line.
    var optionsText: String = ""
    /// Default for number (value), duration (minutes), rating (stars) and toggle (0/1).
    var defaultNumber: Double? = nil
    /// Default for text and choice fields.
    var defaultText: String = ""
    var aggregateRaw: String = Aggregate.sum.rawValue
    var order: Int = 0
    var tracker: Tracker?

    @Relationship(deleteRule: .cascade, inverse: \EntryValue.field)
    var values: [EntryValue]? = []

    init(name: String, kind: FieldKind, order: Int) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.order = order
    }

    var kind: FieldKind {
        get { FieldKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    var aggregate: Aggregate {
        get { Aggregate(rawValue: aggregateRaw) ?? .sum }
        set { aggregateRaw = newValue.rawValue }
    }

    var options: [String] {
        get { optionsText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        set { optionsText = newValue.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n") }
    }

    /// Whether quick logging fills in a value for this field.
    var hasDefault: Bool {
        switch kind {
        case .text, .choice: !defaultText.trimmingCharacters(in: .whitespaces).isEmpty
        case .number, .duration, .rating, .toggle: defaultNumber != nil
        }
    }

    /// Distinct earlier text values, most recent first.
    func suggestions(limit: Int = 12) -> [String] {
        let sorted = (values ?? []).sorted { ($0.entry?.date ?? .distantPast) > ($1.entry?.date ?? .distantPast) }
        var seen = Set<String>(), out: [String] = []
        for v in sorted {
            let t = v.text.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty, seen.insert(t.lowercased()).inserted else { continue }
            out.append(t)
            if out.count == limit { break }
        }
        return out
    }
}

@Model
final class Entry {
    var id: UUID = UUID()
    /// When it happened. For entries without a time this is the start of the day.
    var date: Date = Date()
    var hasTime: Bool = true
    /// When it was logged.
    var trackedAt: Date = Date()
    var note: String = ""
    var imported: Bool = false
    var tracker: Tracker?

    @Relationship(deleteRule: .cascade, inverse: \EntryValue.entry)
    var values: [EntryValue]? = []

    init(date: Date = Date(), hasTime: Bool = true) {
        self.id = UUID()
        self.date = hasTime ? date : Calendar.current.startOfDay(for: date)
        self.hasTime = hasTime
        self.trackedAt = Date()
    }

    var day: Date { Calendar.current.startOfDay(for: date) }

    func value(for field: TrackerField) -> EntryValue? {
        values?.first { $0.field?.id == field.id }
    }
}

@Model
final class EntryValue {
    var text: String = ""
    var number: Double? = nil
    var entry: Entry?
    var field: TrackerField?

    init(text: String = "", number: Double? = nil) {
        self.text = text
        self.number = number
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty && number == nil
    }

    func display(as kind: FieldKind, unit: String = "") -> String {
        switch kind {
        case .text, .choice: return text
        default: return number.map { Self.format($0, kind: kind, unit: unit) } ?? ""
        }
    }

    /// Display text for a numeric value of a number, duration, rating or yes/no field.
    static func format(_ number: Double, kind: FieldKind, unit: String = "") -> String {
        switch kind {
        case .text, .choice, .number:
            return unit.isEmpty ? Fmt.number(number) : "\(Fmt.number(number)) \(unit)"
        case .duration:
            return Fmt.duration(minutes: number)
        case .rating:
            let n = max(0, min(5, Int(number.rounded())))
            return String(repeating: "★", count: n) + String(repeating: "☆", count: 5 - n)
        case .toggle:
            return number >= 0.5 ? String(localized: "Yes") : String(localized: "No")
        }
    }
}

extension Tracker {
    /// The trackers that aren't hidden, in list order.
    static var visible: FetchDescriptor<Tracker> {
        FetchDescriptor(predicate: #Predicate { !$0.isHidden }, sortBy: [SortDescriptor(\.order)])
    }
}

enum SolaTrackerSchema {
    static let models: [any PersistentModel.Type] = [Tracker.self, TrackerField.self, Entry.self, EntryValue.self]
}
