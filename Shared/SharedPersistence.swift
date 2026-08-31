import Foundation
import SwiftData

enum SharedPersistence {
    static let schema = Schema([
        Goal.self,
        TaskItem.self,
        FocusSession.self,
        UserProfile.self,
        GoalMilestone.self
    ])

    /// Preferred shared store when App Group container is available; else Application Support.
    static func sharedStoreURLOrFallback() -> URL {
        if let url = AppConstants.sharedStoreURL {
            return url
        }
        return applicationSupportStoreURL()
    }

    /// App-sandbox store used when App Group is unavailable or fails to open.
    static func applicationSupportStoreURL() -> URL {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        try? fm.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent(AppConstants.storeFileName)
    }

    static func makeSharedContainer() -> ModelContainer? {
        // Prefer App Group so widgets share data; fall back to sandbox if missing/unusable.
        var urls: [URL] = []
        if let groupURL = AppConstants.sharedStoreURL {
            urls.append(groupURL)
        }
        let sandbox = applicationSupportStoreURL()
        if urls.last != sandbox {
            urls.append(sandbox)
        }

        for url in urls {
            if let container = openStore(at: url, schema: schema, allowReset: true) {
                return container
            }
        }
        return openMemoryStore(schema: schema)
    }

    static func openStore(
        at url: URL,
        schema: Schema,
        allowReset: Bool
    ) -> ModelContainer? {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let config = ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            log("Open store failed at \(url.path): \(error)")
            guard allowReset else { return nil }
            resetStoreFiles(at: url)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                log("Reset+reopen failed at \(url.path): \(error)")
                return nil
            }
        }
    }

    static func openMemoryStore(schema: Schema) -> ModelContainer? {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            log("In-memory store failed: \(error)")
            return nil
        }
    }

    static func resetStoreFiles(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let path = url.path + suffix
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
            }
        }
    }

    static func log(_ message: String) {
        #if DEBUG
        print("[Persistence] \(message)")
        #else
        NSLog("[Goalstar Persistence] %@", message)
        #endif
    }
}
