import Foundation
import SwiftData
import WidgetKit

/// Editable copy of a tracker, so Cancel throws changes away cleanly.
struct TrackerDraft {
    var name = ""
    var symbol = "circle.fill"
    var colorIndex = 0
    var logMode: LogMode = .form
    var goal = 0
    var templateKey = ""
    var fields: [FieldDraft] = []

    init() {}

    init(template t: TrackerTemplate) {
        name = t.name
        symbol = t.symbol
        colorIndex = t.colorIndex
        logMode = t.logMode
        goal = t.goal
        templateKey = t.id
        fields = t.fields.map(FieldDraft.init(template:))
    }

    init(tracker t: Tracker) {
        name = t.name
        symbol = t.symbol
        colorIndex = t.colorIndex
        logMode = t.logMode
        goal = t.dailyGoal
        templateKey = t.templateKey
        fields = t.sortedFields.map(FieldDraft.init(field:))
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && fields.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Writes the draft into `tracker` (or a new tracker) and saves.
    @discardableResult
    func apply(to tracker: Tracker?, in context: ModelContext) -> Tracker {
        let target: Tracker
        if let tracker {
            target = tracker
        } else {
            let existing = (try? context.fetch(FetchDescriptor<Tracker>())) ?? []
            target = Tracker(name: name, order: (existing.map(\.order).max() ?? 0) + 1)
            context.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.symbol = symbol
        target.colorIndex = colorIndex
        target.logMode = logMode
        target.dailyGoal = goal
        target.templateKey = templateKey

        let current = target.fields ?? []
        let keep = Set(fields.compactMap(\.existingID))
        for field in current where !keep.contains(field.id) {
            context.delete(field)
        }
        for (index, draft) in fields.enumerated() {
            let field: TrackerField
            if let id = draft.existingID, let found = current.first(where: { $0.id == id }) {
                field = found
            } else {
                field = TrackerField(name: draft.name, kind: draft.kind, order: index)
                context.insert(field)
                field.tracker = target
            }
            draft.write(to: field, order: index)
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return target
    }
}

struct FieldDraft: Identifiable, Hashable {
    var id = UUID()
    var existingID: UUID?
    var name = ""
    var kind: FieldKind = .text
    var unit = ""
    var options: [String] = []
    var defaultNumberText = ""
    var defaultText = ""
    var aggregate: Aggregate = .sum

    init(name: String, kind: FieldKind) {
        self.name = name
        self.kind = kind
        if kind == .rating { aggregate = .average }
    }

    init(template f: FieldTemplate) {
        name = f.name
        kind = f.kind
        unit = f.unit
        options = f.options
        defaultNumberText = Fmt.editable(f.defaultNumber)
        defaultText = f.defaultText
        aggregate = f.aggregate
    }

    init(field f: TrackerField) {
        existingID = f.id
        name = f.name
        kind = f.kind
        unit = f.unit
        options = f.options
        defaultNumberText = Fmt.editable(f.defaultNumber)
        defaultText = f.defaultText
        aggregate = f.aggregate
    }

    var defaultNumber: Double? { Fmt.parseNumber(defaultNumberText) }

    var summary: String {
        var parts = [kind.label]
        if kind == .number, !unit.isEmpty { parts.append(unit) }
        if kind == .choice, !options.isEmpty { parts.append(options.prefix(3).joined(separator: ", ") + (options.count > 3 ? "…" : "")) }
        return parts.joined(separator: " · ")
    }

    func write(to field: TrackerField, order: Int) {
        field.name = name.trimmingCharacters(in: .whitespaces)
        field.kind = kind
        field.unit = kind == .number ? unit.trimmingCharacters(in: .whitespaces) : ""
        field.options = kind == .choice ? options : []
        field.aggregate = aggregate
        field.order = order
        switch kind {
        case .text, .choice:
            field.defaultText = defaultText.trimmingCharacters(in: .whitespaces)
            field.defaultNumber = nil
        case .number, .duration, .rating, .toggle:
            field.defaultText = ""
            field.defaultNumber = defaultNumber
        }
    }
}
