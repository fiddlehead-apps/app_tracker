import AppIntents
import Foundation
import SwiftData
import WidgetKit

struct TrackerEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Tracker"
    static let defaultQuery = TrackerQuery()

    var id: UUID
    var name: String
    var symbol: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }

    init(id: UUID, name: String, symbol: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
    }

    init(_ tracker: Tracker) {
        self.init(id: tracker.id, name: tracker.name, symbol: tracker.symbol)
    }
}

struct TrackerQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [TrackerEntity] {
        try allTrackers().filter { identifiers.contains($0.id) }.map(TrackerEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [TrackerEntity] {
        try allTrackers().map(TrackerEntity.init)
    }

    @MainActor
    func defaultResult() async -> TrackerEntity? {
        try? allTrackers().first.map(TrackerEntity.init)
    }

    @MainActor
    private func allTrackers() throws -> [Tracker] {
        let context = Persistence.shared.mainContext
        return try context.fetch(FetchDescriptor<Tracker>(sortBy: [SortDescriptor(\.order)]))
    }
}

/// +1 from a widget or Shortcuts. Always logs instantly with the tracker's defaults.
struct LogTrackerIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Entry"
    static let description = IntentDescription("Adds one entry to a tracker, right now.")

    @Parameter(title: "Tracker")
    var tracker: TrackerEntity

    init() {}

    init(tracker: TrackerEntity) {
        self.tracker = tracker
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = Persistence.shared.mainContext
        let id = tracker.id
        let descriptor = FetchDescriptor<Tracker>(predicate: #Predicate { $0.id == id })
        if let found = try context.fetch(descriptor).first {
            EntryFactory.quickLog(found, in: context)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
