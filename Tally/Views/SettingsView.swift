import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tracker.order) private var trackers: [Tracker]

    @State private var exportDoc: CSVDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ReorderView()
                    } label: {
                        Label("Reorder trackers", systemImage: "arrow.up.arrow.down")
                    }
                    .disabled(trackers.count < 2)
                }

                Section {
                    Button {
                        exportDoc = CSVDocument(text: CSV.export(context: context))
                        showExporter = true
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Import works with the export from the Tally web page: trackers are matched by name, missing trackers and fields are created, and rows you already have are skipped.")
                }

                Section {
                    LabeledContent("iCloud sync") {
                        Text(Persistence.isCloudEnabled ? String(localized: "On") : String(localized: "Off"))
                    }
                } footer: {
                    Text(Persistence.isCloudEnabled
                         ? "Entries sync through your private iCloud database to every device signed in to the same Apple Account."
                         : "This build stores data on this device only. Set a development team and enable iCloud to sync.")
                }

                Section {
                    LabeledContent("Version") {
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .commaSeparatedText,
                          defaultFilename: "tally-\(CSV.dateFormatter.string(from: Date())).csv") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
                handleImport(result)
            }
            .alert("Import", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                throw CSV.ImportError.unreadable
            }
            let r = try CSV.importCSV(text, context: context)
            var lines = [String(localized: "Entries imported: \(r.imported)")]
            if r.newTrackers > 0 { lines.append(String(localized: "New trackers: \(r.newTrackers)")) }
            if r.duplicates > 0 { lines.append(String(localized: "Already there, skipped: \(r.duplicates)")) }
            if r.skipped > 0 { lines.append(String(localized: "Rows without tracker or date: \(r.skipped)")) }
            message = lines.joined(separator: "\n")
        } catch {
            message = error.localizedDescription
        }
    }
}

struct ReorderView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Tracker.order) private var trackers: [Tracker]

    var body: some View {
        List {
            ForEach(trackers) { t in
                Label {
                    Text(t.name)
                } icon: {
                    Image(systemName: t.symbol).foregroundStyle(t.color)
                }
            }
            .onMove { from, to in
                var list = trackers
                list.move(fromOffsets: from, toOffset: to)
                for (i, t) in list.enumerated() { t.order = i }
                try? context.save()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Reorder trackers")
        .navigationBarTitleDisplayMode(.inline)
    }
}
