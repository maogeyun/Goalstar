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

    static func makeSharedContainer() -> ModelContainer? {
        let url = sharedStoreURLOrFallback()
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
            // Incompatible schema after model changes — reset shared store once.
            let fm = FileManager.default
            for suffix in ["", "-shm", "-wal"] {
                let path = url.path + suffix
                if fm.fileExists(atPath: path) {
                    try? fm.removeItem(atPath: path)
                }
            }
            return try? ModelContainer(for: schema, configurations: [config])
        }
    }

    static func sharedStoreURLOrFallback() -> URL {
        if let url = AppConstants.sharedStoreURL {
            return url
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent(AppConstants.storeFileName)
    }
}
