import SwiftData
import SwiftUI
import WidgetKit

/// Create or edit a tracker. Works on a draft; nothing is written until Save.
struct TrackerEditorView: View {
    @Environment(\.modelContext) private var context
    let tracker: Tracker?
    @State var draft: TrackerDraft
    /// Called after save, cancel or delete. `true` means the user confirmed deletion.
    let onDone: (Bool) -> Void

    @State private var confirmDelete = false
    @State private var fieldPath: UUID?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: draft.symbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.color(draft.colorIndex)))
                    TextField("Name", text: $draft.name)
                        .font(.title3.weight(.semibold))
                }
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(SymbolChoices.all, id: \.self) { symbol in
                        let isOn = symbol == draft.symbol
                        Button { draft.symbol = symbol } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 17))
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .foregroundStyle(isOn ? .white : .primary)
                                .background(RoundedRectangle(cornerRadius: 8).fill(isOn ? Palette.color(draft.colorIndex) : Color(.tertiarySystemFill)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 10) {
                    ForEach(0..<Palette.count, id: \.self) { i in
                        Button { draft.colorIndex = i } label: {
                            Circle()
                                .fill(Palette.color(i))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if i == draft.colorIndex {
                                        Circle().strokeBorder(Color.primary, lineWidth: 2.5).padding(-5)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                Picker("+1 button", selection: $draft.logMode) {
                    ForEach(LogMode.allCases) { Text($0.label).tag($0) }
                }
                Stepper(value: $draft.goal, in: 0...100) {
                    HStack {
                        Text("Daily goal")
                        Spacer()
                        Text(draft.goal == 0 ? String(localized: "Off") : "\(draft.goal)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Logging")
            } footer: {
                Text(draft.logMode == .quick
                     ? "One tap logs right away with the default values. You can add details afterwards."
                     : "Tapping +1 opens a form for time and fields. The widget always logs instantly.")
            }

            Section {
                ForEach($draft.fields) { $field in
                    NavigationLink {
                        FieldEditorView(field: $field, color: Palette.color(draft.colorIndex))
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: field.kind.symbol)
                                .foregroundStyle(Palette.color(draft.colorIndex))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(field.name.isEmpty ? String(localized: "Untitled field") : field.name)
                                Text(field.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .onMove { draft.fields.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { draft.fields.remove(atOffsets: $0) }

                Menu {
                    ForEach(FieldKind.allCases) { kind in
                        Button {
                            let field = FieldDraft(name: "", kind: kind)
                            draft.fields.append(field)
                            fieldPath = field.id
                        } label: {
                            Label(kind.label, systemImage: kind.symbol)
                        }
                    }
                } label: {
                    Label("Add field", systemImage: "plus.circle.fill")
                }
            } header: {
                HStack {
                    Text("Fields")
                    Spacer()
                    if draft.fields.count > 1 { EditButton().font(.caption.weight(.semibold)) }
                }
            } footer: {
                Text("Fields are what you note down with each entry, e.g. location, amount in ml or duration. A tracker without fields just counts.")
            }

            if tracker != nil {
                Section {
                    Button("Delete tracker", role: .destructive) { confirmDelete = true }
                } footer: {
                    Text("Removing a field also removes its values from all entries.")
                }
            }
        }
        .navigationTitle(tracker == nil ? String(localized: "New tracker") : String(localized: "Edit"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $fieldPath) { id in
            if let index = draft.fields.firstIndex(where: { $0.id == id }) {
                FieldEditorView(field: $draft.fields[index], color: Palette.color(draft.colorIndex))
            }
        }
        .tint(Palette.color(draft.colorIndex))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if tracker != nil {
                    Button("Cancel") { onDone(false) }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    draft.apply(to: tracker, in: context)
                    onDone(false)
                }
                .fontWeight(.semibold)
                .disabled(!draft.isValid)
            }
        }
        .confirmationDialog("Delete \(draft.name) and all its entries?", isPresented: $confirmDelete, titleVisibility: .visible) {
            // The presenter deletes the tracker once its screens are gone.
            Button("Delete", role: .destructive) { onDone(true) }
        }
    }
}

struct FieldEditorView: View {
    @Binding var field: FieldDraft
    let color: Color
    @State private var newOption = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("Name") {
                    TextField("Field name", text: $field.name)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Type", selection: $field.kind) {
                    ForEach(FieldKind.allCases) { kind in
                        Label(kind.label, systemImage: kind.symbol).tag(kind)
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(field.kind.hint)
                    if field.existingID != nil {
                        Text("Changing the type keeps existing values but they may not fit the new type.")
                    }
                }
            }

            switch field.kind {
            case .text:
                Section {
                    LabeledContent("Default value") {
                        TextField("Optional", text: $field.defaultText)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("Pre-filled for new entries and used when logging instantly. Leave empty for none.")
                }

            case .choice:
                Section("Options") {
                    ForEach(field.options.indices, id: \.self) { i in
                        TextField("Option", text: Binding(
                            get: { field.options.indices.contains(i) ? field.options[i] : "" },
                            set: { if field.options.indices.contains(i) { field.options[i] = $0 } }
                        ))
                    }
                    .onDelete { field.options.remove(atOffsets: $0) }
                    .onMove { field.options.move(fromOffsets: $0, toOffset: $1) }
                    HStack {
                        TextField("New option", text: $newOption)
                            .onSubmit(addOption)
                        Button("Add", action: addOption)
                            .disabled(newOption.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section {
                    Picker("Default", selection: $field.defaultText) {
                        Text("None").tag("")
                        ForEach(field.options.filter { !$0.isEmpty }, id: \.self) { Text($0).tag($0) }
                    }
                } footer: {
                    Text("Pre-filled for new entries and used when logging instantly.")
                }

            case .number:
                Section {
                    LabeledContent("Unit") {
                        TextField("ml, km, €", text: $field.unit)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Default value") {
                        TextField("Optional", text: $field.defaultNumberText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Timeline shows", selection: $field.aggregate) {
                        ForEach(Aggregate.allCases) { Text($0.label).tag($0) }
                    }
                } footer: {
                    Text("The default is pre-filled and used when logging instantly, e.g. 250 ml for a glass of water. Use Sum for amounts and Average for things like weight.")
                }

            case .duration:
                Section {
                    DurationPicker(minutes: Binding(
                        get: { field.defaultNumber ?? 0 },
                        set: { field.defaultNumberText = $0 == 0 ? "" : Fmt.editable($0) }
                    ))
                } header: {
                    Text("Default duration")
                } footer: {
                    Text("Set to 0 for no default.")
                }

            case .rating:
                Section {
                    RatingPicker(value: Binding(
                        get: { field.defaultNumber },
                        set: { field.defaultNumberText = Fmt.editable($0) }
                    ), color: color)
                } header: {
                    Text("Default rating")
                } footer: {
                    Text("Tap the selected star again for no default.")
                }

            case .toggle:
                Section {
                    Picker("Default", selection: $field.defaultNumberText) {
                        Text("None").tag("")
                        Text("Yes").tag(Fmt.editable(1))
                        Text("No").tag(Fmt.editable(0))
                    }
                }
            }
        }
        .navigationTitle(field.name.isEmpty ? field.kind.label : field.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(color)
    }

    private func addOption() {
        let t = newOption.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        field.options.append(t)
        newOption = ""
    }
}
