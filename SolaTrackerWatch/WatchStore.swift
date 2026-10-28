import Foundation
import WatchConnectivity
import WatchKit

/// Watch side: keeps the trackers the iPhone sent, and the entries logged on this watch.
///
/// Logging stores the event (with the current time) on the watch first, then sends it to
/// the iPhone: right away when it's reachable, otherwise queued by WatchConnectivity and
/// delivered later. Picking field values afterwards re-sends the same event; the iPhone
/// updates the entry with that id.
@MainActor
final class WatchStore: NSObject, ObservableObject {
    static let shared = WatchStore()

    @Published private(set) var context: WatchContext?
    /// Logged on this watch in the last two days.
    @Published private(set) var events: [WatchEvent] = []

    private let defaults = UserDefaults.standard
    /// Changed before the session was ready; sent once it activates.
    private var unsent = Set<UUID>()

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    override init() {
        super.init()
        load()
    }

    func start() {
        guard let session, session.delegate == nil else { return }
        session.delegate = self
        session.activate()
    }

    var trackers: [WatchTracker] { context?.trackers ?? [] }

    func tracker(_ id: UUID) -> WatchTracker? { trackers.first { $0.id == id } }

    func event(_ id: UUID) -> WatchEvent? { events.first { $0.id == id } }

    /// Entries today: the iPhone's plus the ones logged here that it hasn't reported back yet.
    func todayCount(_ tracker: WatchTracker) -> Int {
        var ids = Set(tracker.todayEntryIDs)
        for e in events where e.trackerID == tracker.id {
            if e.deleted { ids.remove(e.id) } else if Calendar.current.isDateInToday(e.date) { ids.insert(e.id) }
        }
        return ids.count
    }

    func todaysEvents(_ tracker: WatchTracker) -> [WatchEvent] {
        events.filter { $0.trackerID == tracker.id && !$0.deleted && Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    // MARK: Actions

    /// Logs one entry now, with the tracker's default values filled in.
    @discardableResult
    func log(_ tracker: WatchTracker) -> WatchEvent {
        var event = WatchEvent(trackerID: tracker.id, date: Date())
        for field in tracker.fields {
            if let option = field.defaultOption { event.values[field.id.uuidString] = option }
        }
        events.append(event)
        save()
        send(event)
        WKInterfaceDevice.current().play(.success)
        return event
    }

    func set(_ option: WatchOption?, for field: WatchField, on eventID: UUID) {
        guard let i = events.firstIndex(where: { $0.id == eventID }) else { return }
        events[i].values[field.id.uuidString] = option ?? WatchOption.cleared
        save()
        send(events[i])
    }

    func undo(_ eventID: UUID) {
        guard let i = events.firstIndex(where: { $0.id == eventID }) else { return }
        events[i].deleted = true
        save()
        send(events[i])
        WKInterfaceDevice.current().play(.click)
    }

    func refresh() {
        guard let session, session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([WatchKeys.requestContext: true], replyHandler: { reply in
            let context = WatchCoding.decode(WatchContext.self, from: reply[WatchKeys.context])
            Task { @MainActor in
                if let context { WatchStore.shared.apply(context) }
            }
        }, errorHandler: nil)
    }

    // MARK: Sending

    private func send(_ event: WatchEvent) {
        guard let session, session.activationState == .activated, let data = WatchCoding.encode(event) else {
            unsent.insert(event.id)
            return
        }
        let payload: [String: Any] = [WatchKeys.event: data]
        if session.isReachable {
            // Wakes the iPhone app; if that fails, fall back to the guaranteed queue.
            session.sendMessage(payload, replyHandler: { reply in
                let context = WatchCoding.decode(WatchContext.self, from: reply[WatchKeys.context])
                Task { @MainActor in
                    if let context { WatchStore.shared.apply(context) }
                }
            }, errorHandler: { _ in
                session.transferUserInfo(payload)
            })
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func flushUnsent() {
        let ids = unsent
        unsent.removeAll()
        for id in ids {
            if let e = event(id) { send(e) }
        }
    }

    fileprivate func apply(_ context: WatchContext) {
        self.context = context
        if let data = WatchCoding.encode(context) { defaults.set(data, forKey: "context") }
    }

    // MARK: Storage

    private func load() {
        context = WatchCoding.decode(WatchContext.self, from: defaults.data(forKey: "context"))
        let stored = WatchCoding.decode([WatchEvent].self, from: defaults.data(forKey: "events")) ?? []
        let cutoff = Calendar.current.date(byAdding: .day, value: -2, to: Calendar.current.startOfDay(for: Date())) ?? .distantPast
        events = stored.filter { $0.date >= cutoff }
        unsent = Set((defaults.stringArray(forKey: "unsent") ?? []).compactMap(UUID.init))
        #if DEBUG
        if context == nil, defaults.bool(forKey: "demoData") { context = Self.demoContext() }
        #endif
    }

    #if DEBUG
    /// Sample trackers for App Store screenshots, without a paired iPhone (`-demoData YES`).
    private static func demoContext() -> WatchContext {
        let de = Locale.current.language.languageCode?.identifier == "de"
        func option(_ label: String, number: Double? = nil) -> WatchOption {
            WatchOption(label: label, text: number == nil ? label : "", number: number)
        }
        func field(_ name: String, _ options: [WatchOption]) -> WatchField {
            WatchField(id: UUID(), name: name, options: options, defaultOption: options.first)
        }
        func tracker(_ name: String, _ symbol: String, _ color: Int, goal: Int = 0, today: Int, _ fields: [WatchField] = []) -> WatchTracker {
            WatchTracker(id: UUID(), name: name, symbol: symbol, colorIndex: color, goal: goal,
                         todayEntryIDs: (0..<today).map { _ in UUID() }, fields: fields)
        }
        return WatchContext(trackers: [
            tracker(de ? "Wasser" : "Water", "drop.fill", 7, goal: 8, today: 5, [
                field(de ? "Menge" : "Amount", [option("250 ml", number: 250), option("500 ml", number: 500), option("330 ml", number: 330)]),
                field(de ? "Getränk" : "Drink", [option(de ? "Wasser" : "Water"), option(de ? "Sprudel" : "Sparkling water"), option(de ? "Tee" : "Tea")]),
            ]),
            tracker(de ? "Kaffee" : "Coffee", "cup.and.saucer.fill", 3, today: 2),
            tracker("Meditation", "figure.mind.and.body", 0, goal: 1, today: 1),
            tracker(de ? "Schlaf" : "Sleep", "bed.double.fill", 5, today: 1),
            tracker(de ? "Laufen" : "Run", "figure.run", 4, today: 0),
            tracker(de ? "Lesen" : "Reading", "book.fill", 1, today: 1),
        ])
    }
    #endif

    private func save() {
        if let data = WatchCoding.encode(events) { defaults.set(data, forKey: "events") }
        defaults.set(unsent.map(\.uuidString), forKey: "unsent")
    }
}

extension WatchStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = WatchCoding.decode(WatchContext.self, from: session.receivedApplicationContext[WatchKeys.context])
        Task { @MainActor in
            let store = WatchStore.shared
            if let context { store.apply(context) }
            store.flushUnsent()
            store.save()
            store.refresh()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let context = WatchCoding.decode(WatchContext.self, from: applicationContext[WatchKeys.context])
        Task { @MainActor in
            if let context { WatchStore.shared.apply(context) }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in WatchStore.shared.refresh() }
    }
}
