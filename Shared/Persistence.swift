import CloudKit
import Foundation
import SwiftData

/// One store, shared by the app and the widget through the App Group. Mirrored to the user's
/// private iCloud database only after they turned on iCloud sync in Settings; until then
/// everything stays on the device.
enum Persistence {
    static let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? ""
    /// Empty unless the app was built with SOLA_ICLOUD = YES (see Config/Config.xcconfig).
    static let cloudKitContainerID = Bundle.main.object(forInfoDictionaryKey: "SolaCloudKitContainer") as? String ?? ""

    /// Whether this build can sync. CloudKit terminates the process when the iCloud entitlement
    /// is missing (e.g. an unsigned build) instead of throwing. Both entitlements come from the
    /// same signing setup, so a missing App Group container means: don't try CloudKit.
    /// Extensions never sync themselves; the app picks up their changes and mirrors them.
    static let canSync = !cloudKitContainerID.isEmpty
        && FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
        && !Bundle.main.bundlePath.hasSuffix(".appex")

    /// The user's choice, off unless they turn it on.
    static var wantsSync: Bool {
        get { defaults.bool(forKey: syncKey) }
        set { defaults.set(newValue, forKey: syncKey) }
    }

    /// The user asked to delete the data in iCloud when turning sync off. Kept until it worked,
    /// so a deletion that failed offline is retried on the next launch.
    static var deleteRequested: Bool {
        get { defaults.bool(forKey: deleteKey) }
        set { defaults.set(newValue, forKey: deleteKey) }
    }

    private static let syncKey = "iCloudSync"
    private static let deleteKey = "iCloudDeleteRequested"
    private static let defaults = UserDefaults(suiteName: appGroupID) ?? .standard

    /// True while the open store mirrors to iCloud.
    nonisolated(unsafe) private(set) static var isCloudEnabled = false

    /// Replaced only by `apply()` on the main actor; intents, widget and watch read it per call.
    nonisolated(unsafe) private(set) static var shared: ModelContainer = makeContainer()

    /// Posted after `apply()` reopened the store; the app then swaps in the new container.
    static let didReopen = Notification.Name("PersistenceDidReopen")

    static var storeURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: "SolaTracker.store")
    }

    /// Reopens the store if the sync choice changed since it was opened. Both configurations
    /// use the same file: turning sync on mirrors the existing local data to iCloud, turning it
    /// off only stops mirroring and keeps everything on the device.
    @MainActor static func apply() {
        guard canSync else { return }
        if wantsSync != isCloudEnabled {
            shared = makeContainer()
            NotificationCenter.default.post(name: didReopen, object: nil)
        }
        if deleteRequested, !isCloudEnabled {
            Task {
                do {
                    try await deleteFromICloud()
                    deleteRequested = false
                } catch {
                    print("Sola Tracker: could not delete iCloud data, will retry. \(error)")
                }
            }
        }
    }

    /// Whether the user is signed in to iCloud, checked before sync is turned on.
    static func accountProblem() async -> String? {
        guard canSync else { return nil }
        do {
            switch try await CKContainer(identifier: cloudKitContainerID).accountStatus() {
            case .available: return nil
            case .noAccount: return String(localized: "Sign in to iCloud in the Settings app first.")
            case .restricted: return String(localized: "iCloud is restricted on this device.")
            default: return String(localized: "iCloud isn’t available right now. Try again later.")
            }
        } catch {
            return error.localizedDescription
        }
    }

    /// Deletes the mirrored data from iCloud. Only runs after the CloudKit store was closed,
    /// so this device doesn't react to the deletion.
    private static func deleteFromICloud() async throws {
        let zone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        let db = CKContainer(identifier: cloudKitContainerID).privateCloudDatabase
        let result = try await db.modifyRecordZones(saving: [], deleting: [zone])
        if case .failure(let error) = result.deleteResults[zone], (error as? CKError)?.code != .zoneNotFound {
            throw error
        }
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema(SolaTrackerSchema.models)
        isCloudEnabled = false
        if canSync, wantsSync {
            do {
                let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .private(cloudKitContainerID))
                let container = try ModelContainer(for: schema, configurations: config)
                isCloudEnabled = true
                return container
            } catch {
                print("Sola Tracker: CloudKit store unavailable, using local store. \(error)")
            }
        }
        do {
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            print("Sola Tracker: could not open store, using memory. \(error)")
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: config)
        }
    }
}
