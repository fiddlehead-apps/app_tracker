import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

/// CSV in the same shape as the web Tally export:
/// tracker, event_date, event_time, tracked_at, note, then one column per field name.
enum CSV {
    static let baseColumns = ["tracker", "event_date", "event_time", "tracked_at", "note"]

    // MARK: Export

    static func export(context: ModelContext) -> String {
        let trackers = (try? context.fetch(FetchDescriptor<Tracker>(sortBy: [SortDescriptor(\.order)]))) ?? []
        var fieldColumns: [String] = []
        var seen = Set<String>()
        for t in trackers {
            for f in t.sortedFields where seen.insert(f.name.lowercased()).inserted {
                fieldColumns.append(f.name)
            }
        }
        var rows = [baseColumns + fieldColumns]
        let entries = ((try? context.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.date)]))) ?? [])
        for e in entries {
            guard let t = e.tracker else { continue }
            var row = [
                t.name,
                dateFormatter.string(from: e.date),
                e.hasTime ? timeFormatter.string(from: e.date) : "",
                e.imported ? "" : isoFormatter.string(from: e.trackedAt),
                e.note,
            ]
            for column in fieldColumns {
                let field = t.sortedFields.first { $0.name.lowercased() == column.lowercased() }
                row.append(field.flatMap { e.value(for: $0) }.map { rawValue($0, kind: field!.kind) } ?? "")
            }
            rows.append(row)
        }
        return rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    private static func rawValue(_ v: EntryValue, kind: FieldKind) -> String {
        switch kind {
        case .text, .choice: return v.text
        default:
            guard let n = v.number else { return "" }
            return n == n.rounded() ? String(Int(n)) : String(n)
        }
    }

    private static func escape(_ s: String) -> String {
        s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" })
            ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            : s
    }

    // MARK: Import

    struct ImportResult {
        var imported = 0
        var duplicates = 0
        var skipped = 0
        var newTrackers = 0
    }

    enum ImportError: LocalizedError {
        case unreadable, noTrackerColumn
        var errorDescription: String? {
            switch self {
            case .unreadable: String(localized: "The file couldn't be read as text.")
            case .noTrackerColumn: String(localized: "The file needs a \"tracker\" or \"counter\" column and a \"date\" or \"event_date\" column.")
            }
        }
    }

    static func importCSV(_ text: String, context: ModelContext) throws -> ImportResult {
        var rows = parse(text)
        guard !rows.isEmpty else { return ImportResult() }
        let header = rows.removeFirst().map { $0.trimmingCharacters(in: .whitespaces) }
        let lower = header.map { $0.lowercased() }
        func col(_ names: String...) -> Int? { names.lazy.compactMap { lower.firstIndex(of: $0) }.first }
        guard let trackerCol = col("tracker", "counter"), let dateCol = col("event_date", "date") else {
            throw ImportError.noTrackerColumn
        }
        let timeCol = col("event_time", "time")
        let trackedCol = col("tracked_at")
        let noteCol = col("note")
        let used = Set([trackerCol, dateCol, timeCol, trackedCol, noteCol].compactMap { $0 })
        // The web Tally names its columns in English; map them to the same (localized)
        // field names the "Event" template uses. "person" is the old name of "target".
        let known = [
            "location": String(localized: "Location"),
            "source": String(localized: "Source"),
            "target": String(localized: "Target"),
            "person": String(localized: "Target"),
        ]
        let fieldCols: [(Int, String)] = header.indices.filter { !used.contains($0) }.map { i in
            (i, known[lower[i]] ?? header[i].prefix(1).uppercased() + header[i].dropFirst())
        }

        var trackers = (try? context.fetch(FetchDescriptor<Tracker>())) ?? []
        var result = ImportResult()
        var existingKeys = Set(((try? context.fetch(FetchDescriptor<Entry>())) ?? []).map(dedupeKey))

        for row in rows {
            func cell(_ i: Int?) -> String {
                guard let i, i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespaces)
            }
            let name = cell(trackerCol)
            guard !name.isEmpty, let day = dateFormatter.date(from: cell(dateCol)) else {
                result.skipped += 1
                continue
            }

            let tracker: Tracker
            if let found = trackers.first(where: { $0.name.lowercased() == name.lowercased() }) {
                tracker = found
            } else {
                tracker = Tracker(name: name, symbol: "number", colorIndex: trackers.count % Palette.count,
                                  order: (trackers.map(\.order).max() ?? 0) + 1)
                context.insert(tracker)
                trackers.append(tracker)
                result.newTrackers += 1
            }

            let time = cell(timeCol)
            var date = day
            var hasTime = false
            if let t = timeFormatter.date(from: time) {
                let c = Calendar.current.dateComponents([.hour, .minute], from: t)
                date = Calendar.current.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: day) ?? day
                hasTime = true
            }
            let trackedText = cell(trackedCol)
            let trackedAt = isoFormatter.date(from: trackedText) ?? isoFormatterNoFraction.date(from: trackedText)

            var values: [(TrackerField, String)] = []
            for (i, fieldName) in fieldCols {
                let raw = cell(i)
                guard !raw.isEmpty else { continue }
                let field = tracker.sortedFields.first { $0.name.lowercased() == fieldName.lowercased() } ?? {
                    let f = TrackerField(name: fieldName, kind: .text, order: (tracker.fields?.count ?? 0))
                    context.insert(f)
                    f.tracker = tracker
                    return f
                }()
                values.append((field, raw))
            }

            let key = dedupeKey(tracker: name, date: date, hasTime: hasTime, trackedAt: trackedAt,
                                values: values.map { "\($0.0.name.lowercased())=\($0.1)" })
            if existingKeys.contains(key) {
                result.duplicates += 1
                continue
            }
            existingKeys.insert(key)

            let entry = Entry(date: date, hasTime: hasTime)
            context.insert(entry)
            entry.tracker = tracker
            entry.note = cell(noteCol)
            entry.trackedAt = trackedAt ?? Date()
            entry.imported = trackedAt == nil
            for (field, raw) in values {
                let v: EntryValue
                switch field.kind {
                case .text, .choice:
                    v = EntryValue(text: raw)
                case .toggle:
                    v = EntryValue(number: ["1", "true", "yes", "ja", "y"].contains(raw.lowercased()) ? 1 : 0)
                default:
                    guard let n = Fmt.parseNumber(raw) else { continue }
                    v = EntryValue(number: n)
                }
                context.insert(v)
                v.entry = entry
                v.field = field
            }
            result.imported += 1
        }
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return result
    }

    private static func dedupeKey(_ e: Entry) -> String {
        let fields = e.tracker?.sortedFields ?? []
        let values = fields.compactMap { f -> String? in
            guard let v = e.value(for: f), !v.isEmpty else { return nil }
            return "\(f.name.lowercased())=\(rawValue(v, kind: f.kind))"
        }
        return dedupeKey(tracker: e.tracker?.name ?? "", date: e.date, hasTime: e.hasTime,
                         trackedAt: e.imported ? nil : e.trackedAt, values: values)
    }

    private static func dedupeKey(tracker: String, date: Date, hasTime: Bool, trackedAt: Date?, values: [String]) -> String {
        let when = hasTime ? dateFormatter.string(from: date) + "T" + timeFormatter.string(from: date) : dateFormatter.string(from: date)
        let tracked = trackedAt.map { String(Int($0.timeIntervalSince1970)) } ?? ""
        return [tracker.lowercased(), when, tracked, values.sorted().joined(separator: "|")].joined(separator: "#")
    }

    /// RFC 4180-ish parser: quoted fields, doubled quotes, CRLF.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = ""
        var inQuotes = false
        var chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))
        if chars.first == "\u{FEFF}" { chars.removeFirst() }
        // Spreadsheet apps in German locales often save with semicolons.
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r" }
        let delimiter: Character = firstLine.contains(",") || !firstLine.contains(";") ? "," : ";"
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { inQuotes = false }
                } else {
                    field.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == delimiter {
                    row.append(field); field = ""
                } else if c == "\n" {
                    row.append(field); field = ""
                    if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                    row = []
                } else {
                    field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }

    // MARK: Formatters

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let isoFormatterNoFraction = ISO8601DateFormatter()
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        text = configuration.file.regularFileContents.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
