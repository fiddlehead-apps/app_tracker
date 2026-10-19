import SwiftUI

/// Template gallery. Picking a template (or Blank) opens the editor pre-filled,
/// so names and fields can be adjusted before saving.
struct NewTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var chosen: ChosenDraft?

    struct ChosenDraft: Identifiable, Hashable {
        let id = UUID()
        let templateID: String?
        static func == (a: Self, b: Self) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    Section {
                        Button {
                            chosen = ChosenDraft(templateID: nil)
                        } label: {
                            row(symbol: "plus", color: .gray, title: String(localized: "Blank tracker"),
                                subtitle: String(localized: "Name it and add your own fields."))
                        }
                    }
                }
                ForEach(TrackerTemplate.Category.allCases) { category in
                    let items = filtered.filter { $0.category == category }
                    if !items.isEmpty {
                        Section(category.label) {
                            ForEach(items) { t in
                                Button {
                                    chosen = ChosenDraft(templateID: t.id)
                                } label: {
                                    row(symbol: t.symbol, color: Palette.color(t.colorIndex), title: t.name,
                                        subtitle: t.summary.isEmpty ? String(localized: "Just counts") : t.summary)
                                }
                            }
                        }
                    }
                }
            }
            .tint(.primary)
            .searchable(text: $search, prompt: Text("Search templates"))
            .navigationTitle("New tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $chosen) { choice in
                let draft = choice.templateID.flatMap { id in Templates.all.first { $0.id == id } }
                    .map(TrackerDraft.init(template:)) ?? TrackerDraft()
                TrackerEditorView(tracker: nil, draft: draft) { _ in dismiss() }
            }
        }
    }

    private var filtered: [TrackerTemplate] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Templates.all }
        return Templates.all.filter { $0.name.lowercased().contains(q) || $0.summary.lowercased().contains(q) }
    }

    private func row(symbol: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10).fill(color))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
