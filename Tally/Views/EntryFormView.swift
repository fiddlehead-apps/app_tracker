import SwiftData
import SwiftUI
import WidgetKit

/// What the user typed for one field; converted to an EntryValue on save.
struct FieldInput {
    var text = ""
    var number: Double?
    var numberText = ""

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty && number == nil }
}

struct EntryFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let tracker: Tracker
    let entry: Entry?

    @State private var date: Date
    @State private var hasTime: Bool
    @State private var note: String
    @State private var inputs: [UUID: FieldInput]
    @State private var confirmDelete = false

    init(tracker: Tracker, entry: Entry?, day: Date?) {
        self.tracker = tracker
        self.entry = entry
        var inputs: [UUID: FieldInput] = [:]
        if let entry {
            _date = State(initialValue: entry.date)
            _hasTime = State(initialValue: entry.hasTime)
            _note = State(initialValue: entry.note)
            for field in tracker.sortedFields {
                if let v = entry.value(for: field) {
                    inputs[field.id] = FieldInput(text: v.text, number: v.number, numberText: Fmt.editable(v.number))
                }
            }
        } else {
            let isOtherDay = day.map { !Calendar.current.isDateInToday($0) } ?? false
            if let day, isOtherDay {
                _date = State(initialValue: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day)
                _hasTime = State(initialValue: false)
            } else {
                _date = State(initialValue: Date())
                _hasTime = State(initialValue: true)
            }
            _note = State(initialValue: "")
            for field in tracker.sortedFields where field.hasDefault {
                switch field.kind {
                case .text, .choice: inputs[field.id] = FieldInput(text: field.defaultText)
                default: inputs[field.id] = FieldInput(number: field.defaultNumber, numberText: Fmt.editable(field.defaultNumber))
                }
            }
        }
        _inputs = State(initialValue: inputs)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Toggle("Include time", isOn: $hasTime.animation())
                    if hasTime {
                        HStack {
                            DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
                            Button("Now") { date = Date() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                } header: {
                    Text("When it happened")
                }

                ForEach(tracker.sortedFields) { field in
                    Section {
                        FieldInputView(field: field, input: binding(for: field), color: tracker.color)
                    } header: {
                        Text(field.name)
                    }
                }

                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(1...5)
                }

                if let entry {
                    Section {
                        LabeledContent("Logged") {
                            Text(entry.imported ? String(localized: "Imported") : entry.trackedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        Button("Delete entry", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(entry == nil ? tracker.name : String(localized: "Edit"))
            .navigationBarTitleDisplayMode(.inline)
            .tint(tracker.color)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let entry { EntryFactory.delete(entry, in: context) }
                    dismiss()
                }
            }
        }
    }

    private func binding(for field: TrackerField) -> Binding<FieldInput> {
        Binding(
            get: { inputs[field.id] ?? FieldInput() },
            set: { inputs[field.id] = $0 }
        )
    }

    private func save() {
        let target: Entry
        if let entry {
            target = entry
        } else {
            target = Entry()
            context.insert(target)
            target.tracker = tracker
        }
        target.hasTime = hasTime
        target.date = hasTime ? date : Calendar.current.startOfDay(for: date)
        target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)

        for field in tracker.sortedFields {
            var input = inputs[field.id] ?? FieldInput()
            if field.kind == .number { input.number = Fmt.parseNumber(input.numberText) }
            if field.kind == .duration, input.number == 0 { input.number = nil }
            let existing = target.value(for: field)
            if input.isEmpty {
                if let existing { context.delete(existing) }
                continue
            }
            let value = existing ?? {
                let v = EntryValue()
                context.insert(v)
                v.entry = target
                v.field = field
                return v
            }()
            switch field.kind {
            case .text, .choice:
                value.text = input.text.trimmingCharacters(in: .whitespaces)
                value.number = nil
            default:
                value.text = ""
                value.number = input.number
            }
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}

struct FieldInputView: View {
    let field: TrackerField
    @Binding var input: FieldInput
    let color: Color
    @State private var suggestions: [String] = []

    var body: some View {
        switch field.kind {
        case .text:
            TextField(field.name, text: $input.text)
                .onAppear { suggestions = field.suggestions() }
            let q = input.text.trimmingCharacters(in: .whitespaces).lowercased()
            let filtered = suggestions.filter { q.isEmpty || ($0.lowercased().contains(q) && $0.lowercased() != q) }
            if !filtered.isEmpty {
                FlowChips(items: filtered, color: color) { input.text = $0 }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
            }

        case .choice:
            if field.options.isEmpty {
                TextField(field.name, text: $input.text)
            } else {
                FlowChips(items: field.options, selected: input.text, color: color) { option in
                    input.text = input.text == option ? "" : option
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
            }

        case .number:
            HStack {
                TextField("0", text: $input.numberText)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold).monospacedDigit())
                if !field.unit.isEmpty {
                    Text(field.unit).foregroundStyle(.secondary)
                }
                if let step = stepSize {
                    Stepper("", onIncrement: { bump(step) }, onDecrement: { bump(-step) })
                        .labelsHidden()
                }
            }

        case .duration:
            DurationPicker(minutes: Binding(
                get: { input.number ?? 0 },
                set: { input.number = $0 }
            ))

        case .rating:
            RatingPicker(value: $input.number, color: color)

        case .toggle:
            Toggle(field.name, isOn: Binding(
                get: { (input.number ?? 0) >= 0.5 },
                set: { input.number = $0 ? 1 : 0 }
            ))
        }
    }

    /// A sensible +/- step: the default amount (e.g. 250 ml), otherwise 1.
    private var stepSize: Double? {
        if let d = field.defaultNumber, d > 0 { return d }
        return 1
    }

    private func bump(_ by: Double) {
        let current = Fmt.parseNumber(input.numberText) ?? 0
        let next = max(0, current + by)
        input.numberText = Fmt.editable(next)
        input.number = next
    }
}

struct DurationPicker: View {
    @Binding var minutes: Double

    var body: some View {
        let total = Int(minutes.rounded())
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Picker("Hours", selection: Binding(
                    get: { total / 60 },
                    set: { minutes = Double($0 * 60 + total % 60) }
                )) {
                    ForEach(0..<24, id: \.self) { Text(verbatim: "\($0) h").tag($0) }
                }
                Picker("Minutes", selection: Binding(
                    get: { total % 60 },
                    set: { minutes = Double((total / 60) * 60 + $0) }
                )) {
                    ForEach(0..<60, id: \.self) { Text(verbatim: "\($0) min").tag($0) }
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .labelsHidden()
            HStack {
                ForEach([5, 10, 15, 30, 60], id: \.self) { m in
                    Button { minutes = Double(m) } label: {
                        Text(Fmt.duration(minutes: Double(m)))
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

struct RatingPicker: View {
    @Binding var value: Double?
    let color: Color

    var body: some View {
        let current = Int((value ?? 0).rounded())
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    value = current == star ? nil : Double(star)
                } label: {
                    Image(systemName: star <= current ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(star <= current ? color : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(star) stars"))
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
