import Foundation
import SwiftData

/// One store, shared by the app and the widget through the App Group,
/// mirrored to the user's private iCloud database when CloudKit is available.
enum Persistence {
    static let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? ""
    static let cloudKitContainerID = Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerID") as? String ?? ""

    /// False when the store had to fall back to local-only (e.g. no signing team / entitlements).
    private(set) static var isCloudEnabled = false

    static let shared: ModelContainer = makeContainer()

    static var storeURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: "Tally.store")
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema(TallySchema.models)
        // CloudKit terminates the process when the iCloud entitlement is missing (e.g. an
        // unsigned build) instead of throwing. Both entitlements come from the same signing
        // setup, so a missing App Group container means: don't try CloudKit.
        let isEntitled = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
        if !cloudKitContainerID.isEmpty, isEntitled {
            do {
                let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .private(cloudKitContainerID))
                let container = try ModelContainer(for: schema, configurations: config)
                isCloudEnabled = true
                return container
            } catch {
                print("Tally: CloudKit store unavailable, using local store. \(error)")
            }
        }
        do {
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            print("Tally: could not open store, using memory. \(error)")
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: config)
        }
    }
}
