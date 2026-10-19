import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Tracker> { !$0.isHidden }, sort: \Tracker.order) private var trackers: [Tracker]
    var onUnlock: () -> Void = {}

    @State private var exportDoc: CSVDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var message: String?
    @State private var syncOn = Persistence.wantsSync
    @State private var syncProblem: String?
    @State private var checkingAccount = false
    @State private var askTurnOff = false

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
                    Text("Import reads files in the same format as the export: trackers are matched by name, missing trackers and fields are created, and rows you already have are skipped.")
                }

                Section {
                    if Persistence.canSync {
                        Toggle("iCloud sync", isOn: Binding(get: { syncOn }, set: { on in
                            if on { turnSyncOn() } else { askTurnOff = true }
                        }))
                        .disabled(checkingAccount)
                    } else {
                        LabeledContent("iCloud sync", value: String(localized: "Off"))
                    }
                } footer: {
                    syncFooter
                }
                .confirmationDialog("Turn off iCloud sync?", isPresented: $askTurnOff, titleVisibility: .visible) {
                    Button("Keep data in iCloud") { setSync(false, deleteFromICloud: false) }
                    Button("Delete data from iCloud", role: .destructive) { setSync(false, deleteFromICloud: true) }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Your trackers and entries stay on this device either way. Before deleting, turn off iCloud sync on your other devices.")
                }

                Section {
                    // Tapping this row five times asks for Face ID / Touch ID and opens the hidden trackers.
                    LabeledContent("Version") {
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    }
                    .contentShape(.rect)
                    .onMultiTap(5, window: .milliseconds(1200), reached: onUnlock)
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
                          defaultFilename: "sola-tracker-\(CSV.dateFormatter.string(from: Date())).csv") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
                handleImport(result)
            }
            // The store is reopened with or without iCloud once Settings closes.
            .onDisappear { Persistence.apply() }
            .alert("Import", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    @ViewBuilder private var syncFooter: some View {
        if !Persistence.canSync {
            Text("This build keeps everything on this device and can't sync.")
        } else if let syncProblem {
            Text(syncProblem).foregroundStyle(.red)
        } else if syncOn != Persistence.isCloudEnabled {
            Text(syncOn ? "Sync starts when you close Settings." : "Sync stops when you close Settings. Your data stays on this device.")
        } else if syncOn {
            Text("Your trackers and entries sync through your private iCloud database to your devices signed in to the same Apple Account.")
        } else {
            Text("Off: everything stays on this device. Turn it on to sync your trackers and entries through your private iCloud database to your other devices.")
        }
    }

    private func turnSyncOn() {
        checkingAccount = true
        Task {
            let problem = await Persistence.accountProblem()
            checkingAccount = false
            syncProblem = problem
            if problem == nil { setSync(true, deleteFromICloud: false) }
        }
    }

    private func setSync(_ on: Bool, deleteFromICloud: Bool) {
        syncOn = on
        syncProblem = nil
        Persistence.wantsSync = on
        Persistence.deleteRequested = deleteFromICloud
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
    @Query(filter: #Predicate<Tracker> { !$0.isHidden }, sort: \Tracker.order) private var trackers: [Tracker]

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
