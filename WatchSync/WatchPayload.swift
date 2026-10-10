import Foundation

// What the iPhone and the Watch send each other over WatchConnectivity, as JSON.
// iPhone → Watch: `WatchContext` (trackers, their fields with recent values, today's entries).
// Watch → iPhone: `WatchEvent` (one logged entry; re-sent whenever it changes).

enum WatchKeys {
    static let context = "context"
    static let event = "event"
    static let requestContext = "requestContext"
}

struct WatchContext: Codable, Equatable {
    var trackers: [WatchTracker] = []
    var generatedAt = Date()
}

struct WatchTracker: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var symbol: String
    var colorIndex: Int
    var goal: Int
    /// Today's entries known to the iPhone, so the watch can count without counting its own twice.
    var todayEntryIDs: [UUID]
    var fields: [WatchField]
}

struct WatchField: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    /// Ready-to-pick values: the default, recent values, fixed choices.
    var options: [WatchOption]
    var defaultOption: WatchOption?
}

struct WatchOption: Codable, Hashable, Identifiable {
    /// Display text, already formatted by the iPhone (e.g. "250 ml", "1 h 30 min", "★★★★☆").
    var label: String
    var text: String = ""
    var number: Double? = nil

    var id: String { label }

    /// Sent to clear a field the user had picked before.
    static let cleared = WatchOption(label: "")
    var isNone: Bool { label.isEmpty }
}

/// One entry logged on the watch. The iPhone upserts it by `id`, so sending it again is safe.
struct WatchEvent: Codable, Identifiable, Hashable {
    var id = UUID()
    var trackerID: UUID
    /// When it happened: the moment +1 was tapped on the watch.
    var date: Date
    /// Field id (uuidString) → chosen value. Fields not in here are left untouched.
    var values: [String: WatchOption] = [:]
    var deleted = false
}

enum WatchCoding {
    static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from value: Any?) -> T? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
