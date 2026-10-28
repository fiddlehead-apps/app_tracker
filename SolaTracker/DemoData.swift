#if DEBUG
import Foundation
import SwiftData

/// Sample trackers with a few months of entries, for App Store screenshots.
/// Only in debug builds, and only with the launch argument `-demoData YES` on an empty store.
enum DemoData {
    @MainActor static func seedIfRequested(in context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "demoData"),
              (try? context.fetchCount(FetchDescriptor<Tracker>())) == 0 else { return }
        var rng = SeededRandom(seed: 42)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let books = ["Der Hobbit", "Momo", "Stoner"]

        for id in ["water", "coffee", "meditation", "sleep", "run", "reading"] {
            guard let template = Templates.all.first(where: { $0.id == id }) else { continue }
            let tracker = TrackerDraft(template: template).apply(to: nil, in: context)
            let fields = tracker.sortedFields
            for back in 0..<120 {
                let day = cal.date(byAdding: .day, value: -back, to: today)!
                let count: Int
                switch id {
                case "water": count = back == 0 ? 5 : Int.random(in: back < 22 ? 8...10 : 5...10, using: &rng)
                case "coffee": count = back == 0 ? 2 : Int.random(in: 1...3, using: &rng)
                case "meditation": count = back < 23 || Int.random(in: 0...3, using: &rng) > 0 ? 1 : 0
                case "sleep": count = back == 0 ? 1 : (Int.random(in: 0...9, using: &rng) > 0 ? 1 : 0)
                case "run": count = back % 3 == 1 && Int.random(in: 0...4, using: &rng) > 0 ? 1 : 0
                default: count = Int.random(in: 0...2, using: &rng) > 0 ? 1 : 0
                }
                for n in 0..<count {
                    let minutes = back == 0 ? 7 * 60 + n * 70 : Int.random(in: 7 * 60...21 * 60, using: &rng)
                    let entry = Entry(date: day.addingTimeInterval(TimeInterval(minutes * 60)), hasTime: true)
                    context.insert(entry)
                    entry.tracker = tracker
                    for field in fields {
                        let value: EntryValue
                        switch (id, field.kind) {
                        case ("sleep", .duration): value = EntryValue(number: Double(Int.random(in: 380...510, using: &rng)))
                        case (_, .rating): value = EntryValue(number: Double(Int.random(in: 3...5, using: &rng)))
                        case ("run", .number): value = EntryValue(number: Double(Int.random(in: 45...110, using: &rng)) / 10)
                        case ("run", .duration): value = EntryValue(number: Double(Int.random(in: 25...60, using: &rng)))
                        case ("reading", .number): value = EntryValue(number: Double(Int.random(in: 8...45, using: &rng)))
                        case ("reading", .duration): value = EntryValue(number: Double(Int.random(in: 15...60, using: &rng)))
                        case ("reading", .text): value = EntryValue(text: books[min(back / 40, books.count - 1)])
                        case (_, .choice) where !field.options.isEmpty && field.defaultText.isEmpty:
                            value = EntryValue(text: field.options[Int.random(in: 0..<field.options.count, using: &rng)])
                        default:
                            guard field.hasDefault else { continue }
                            value = field.kind == .text || field.kind == .choice
                                ? EntryValue(text: field.defaultText) : EntryValue(number: field.defaultNumber)
                        }
                        context.insert(value)
                        value.entry = entry
                        value.field = field
                    }
                }
            }
        }
        try? context.save()
    }
}

/// Same numbers on every run, so screenshots can be redone.
private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
#endif
