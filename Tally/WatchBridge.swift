import Foundation
import SwiftData
import WatchConnectivity
import WidgetKit

/// iPhone side of the Apple Watch connection.
/// Sends the trackers (with recent field values to pick from) to the watch, and stores
/// entries logged on the watch. Works without iCloud: WatchConnectivity talks to the
/// paired watch directly and queues messages while it's out of reach.
@MainActor
final class WatchBridge: NSObject {
    static let shared = WatchBridge()

    private var pushTask: Task<Void, Never>?
    private var saveObserver: NSObjectProtocol?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func start() {
        guard let session, session.delegate == nil else { return }
        session.delegate = self
        session.activate()
        // Any change in the app (new entry, renamed tracker, …) refreshes the watch.
        saveObserver = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { _ in
            Task { @MainActor in WatchBridge.shared.schedulePush() }
        }
    }

    /// Coalesces bursts of saves into one update.
    func schedulePush() {
        pushTask?.cancel()
        pushTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            pushContext()
        }
    }

    func pushContext() {
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled,
              let data = WatchCoding.encode(makeContext()) else { return }
        try? session.updateApplicationContext([WatchKeys.context: data])
    }

    // MARK: Context

    func makeContext() -> WatchContext {
        let context = Persistence.shared.mainContext
        let trackers = (try? context.fetch(FetchDescriptor<Tracker>(sortBy: [SortDescriptor(\.order)]))) ?? []
        let start = Day.start(Date()), end = Day.tomorrow
        let today = (try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.date >= start }))) ?? []
        var todayIDs: [UUID: [UUID]] = [:]
        for e in today where e.date < end {
            if let id = e.tracker?.id { todayIDs[id, default: []].append(e.id) }
        }
        return WatchContext(trackers: trackers.map { t in
            WatchTracker(id: t.id, name: t.name, symbol: t.symbol, colorIndex: t.colorIndex, goal: t.dailyGoal,
                         todayEntryIDs: todayIDs[t.id] ?? [], fields: t.sortedFields.map(watchField))
        })
    }

    private func watchField(_ f: TrackerField) -> WatchField {
        var options: [WatchOption] = []
        func add(_ o: WatchOption) {
            if !o.isNone, !options.contains(where: { $0.label == o.label }) { options.append(o) }
        }
        func numeric(_ n: Double) -> WatchOption {
            WatchOption(label: EntryValue.format(n, kind: f.kind, unit: f.unit), number: n)
        }

        var defaultOption: WatchOption?
        if f.hasDefault {
            switch f.kind {
            case .text, .choice: defaultOption = WatchOption(label: f.defaultText, text: f.defaultText)
            default: defaultOption = f.defaultNumber.map(numeric)
            }
        }
        if let defaultOption { add(defaultOption) }

        switch f.kind {
        case .text:
            f.suggestions(limit: 8).forEach { add(WatchOption(label: $0, text: $0)) }
        case .choice:
            f.options.forEach { add(WatchOption(label: $0, text: $0)) }
        case .number, .duration:
            recentNumbers(f, limit: 8).forEach { add(numeric($0)) }
            if f.kind == .duration, options.count < 4 {
                [5.0, 10, 15, 30, 45, 60, 90].forEach { add(numeric($0)) }
            }
        case .rating:
            (1...5).forEach { add(numeric(Double($0))) }
        case .toggle:
            [1.0, 0].forEach { add(numeric($0)) }
        }
        return WatchField(id: f.id, name: f.name, options: options, defaultOption: defaultOption)
    }

    private func recentNumbers(_ f: TrackerField, limit: Int) -> [Double] {
        let sorted = (f.values ?? []).sorted { ($0.entry?.date ?? .distantPast) > ($1.entry?.date ?? .distantPast) }
        var out: [Double] = []
        for v in sorted {
            guard let n = v.number, !out.contains(n) else { continue }
            out.append(n)
            if out.count == limit { break }
        }
        return out
    }

    // MARK: Events from the watch

    func apply(_ event: WatchEvent) {
        let context = Persistence.shared.mainContext
        let entryID = event.id, trackerID = event.trackerID
        let existing = try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.id == entryID })).first

        if event.deleted {
            if let existing { EntryFactory.delete(existing, in: context) }
            return
        }
        guard let tracker = try? context.fetch(FetchDescriptor<Tracker>(predicate: #Predicate { $0.id == trackerID })).first else {
            return
        }

        let entry: Entry
        if let existing {
            entry = existing
        } else {
            entry = Entry(date: event.date, hasTime: true)
            entry.id = event.id
            entry.trackedAt = event.date
            context.insert(entry)
            entry.tracker = tracker
        }
        entry.date = event.date
        entry.hasTime = true

        for field in tracker.sortedFields {
            guard let option = event.values[field.id.uuidString] else { continue }
            let current = entry.value(for: field)
            if option.isNone {
                if let current { context.delete(current) }
                continue
            }
            let value = current ?? {
                let v = EntryValue()
                context.insert(v)
                v.entry = entry
                v.field = field
                return v
            }()
            switch field.kind {
            case .text, .choice:
                value.text = option.text
                value.number = nil
            default:
                value.text = ""
                value.number = option.number
            }
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in WatchBridge.shared.pushContext() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switched to another watch: reconnect to the new one.
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in WatchBridge.shared.pushContext() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(message)
    }

    /// The watch asks for fresh trackers (and may carry an event); reply with the current context.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        let event = WatchCoding.decode(WatchEvent.self, from: message[WatchKeys.event])
        Task { @MainActor in
            if let event { WatchBridge.shared.apply(event) }
            replyHandler([WatchKeys.context: WatchCoding.encode(WatchBridge.shared.makeContext()) ?? Data()])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(userInfo)
    }

    nonisolated private func receive(_ payload: [String: Any]) {
        guard let event = WatchCoding.decode(WatchEvent.self, from: payload[WatchKeys.event]) else { return }
        Task { @MainActor in WatchBridge.shared.apply(event) }
    }
}
