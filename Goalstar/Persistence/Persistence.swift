import Foundation
import SwiftData

enum Persistence {
    static var schema: Schema { SharedPersistence.schema }

    /// Never crashes on store load. Prefers App Group, then Application Support, then memory/temp.
    ///
    /// Note: if the provisioning profile omits App Group `group.com.goalstar.native` while
    /// entitlements declare it, iOS may SIGKILL before any Swift runs — that cannot be caught here.
    /// Enable the App Group for team `A47KHX4UCC` in Apple Developer and regenerate profiles.
    static func makeContainer() -> ModelContainer {
        migrateStoreIfNeeded()

        if AppConstants.sharedStoreURL == nil {
            SharedPersistence.log(
                "App Group container unavailable for \(AppConstants.appGroupID); using Application Support"
            )
        }

        // 1) App Group store (shared with widgets) when container exists
        if let groupURL = AppConstants.sharedStoreURL {
            ensureStoreDirectory(for: groupURL)
            if let container = openPersistent(at: groupURL, allowReset: true) {
                return container
            }
            SharedPersistence.log("App Group store failed; falling back to Application Support")
        }

        // 2) App sandbox Application Support — mis-provisioned devices still launch
        let sandboxURL = SharedPersistence.applicationSupportStoreURL()
        ensureStoreDirectory(for: sandboxURL)
        if let container = openPersistent(at: sandboxURL, allowReset: true) {
            return container
        }
        SharedPersistence.log("Application Support store failed; trying temp then memory")

        // 3) Unique temp file (avoids a corrupted sandbox path)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("goalstar-fallback-\(UUID().uuidString).store")
        if let container = openPersistent(at: tempURL, allowReset: false) {
            return container
        }

        // 4) In-memory — soft open, no force try
        if let memory = SharedPersistence.openMemoryStore(schema: schema) {
            SharedPersistence.log("Using in-memory ModelContainer")
            return memory
        }

        // 5) Soft last resorts — no force unwrap
        SharedPersistence.resetStoreFiles(at: sandboxURL)
        if let container = SharedPersistence.openStore(at: sandboxURL, schema: schema, allowReset: false) {
            return container
        }

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let cacheStore = caches.appendingPathComponent("goalstar.emergency.store")
        try? FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        SharedPersistence.resetStoreFiles(at: cacheStore)
        if let container = SharedPersistence.openStore(at: cacheStore, schema: schema, allowReset: false) {
            return container
        }

        for _ in 0..<8 {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("goalstar-\(UUID().uuidString).store")
            if let container = SharedPersistence.openStore(at: url, schema: schema, allowReset: false) {
                return container
            }
        }

        if let memory = SharedPersistence.openMemoryStore(schema: schema) {
            return memory
        }

        // Result-based construction — never force-try store creation.
        return makeContainerViaResult()
    }

    /// Last-line soft path using Result — never force-try store creation.
    private static func makeContainerViaResult() -> ModelContainer {
        if case .success(let container) = Result(catching: {
            try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }) {
            return container
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("goalstar-final-\(UUID().uuidString).store")
        if case .success(let container) = Result(catching: {
            try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
            )
        }) {
            return container
        }

        if case .success(let container) = Result(catching: {
            try ModelContainer(for: schema)
        }) {
            return container
        }

        // Valid schema succeeds for in-memory on iOS 17+; bounded soft retries.
        for _ in 0..<32 {
            if case .success(let container) = Result(catching: {
                try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
                )
            }) {
                return container
            }
        }

        // Schema/runtime catastrophe only — normal App Group / sandbox failures never reach here.
        preconditionFailure("[Persistence] Unable to create any ModelContainer")
    }

    private static func openPersistent(at url: URL, allowReset: Bool) -> ModelContainer? {
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
            SharedPersistence.log("Local store incompatible at \(url.lastPathComponent): \(error)")
            guard allowReset else { return nil }
            backupStoreFiles(at: url)
            AppConstants.sharedDefaults.set(true, forKey: AppConstants.storeBackupNoticeKey)
            resetStoreFiles(at: url)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                SharedPersistence.log("Reset store failed at \(url.lastPathComponent): \(error)")
                return nil
            }
        }
    }

    /// Widget / App Intent: shared store.
    static func makeSharedContainer() -> ModelContainer? {
        SharedPersistence.makeSharedContainer()
    }

    private static func ensureStoreDirectory(for url: URL) {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private static func backupStoreFiles(at url: URL) {
        let fm = FileManager.default
        let backupName = "goalstar.store.backup-\(Int(Date().timeIntervalSince1970))"
        let backupURL = url.deletingLastPathComponent().appendingPathComponent(backupName)
        guard fm.fileExists(atPath: url.path) else { return }
        try? fm.copyItem(at: url, to: backupURL)
        for suffix in ["-shm", "-wal"] {
            let src = URL(fileURLWithPath: url.path + suffix)
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: URL(fileURLWithPath: backupURL.path + suffix))
            }
        }
    }

    private static func resetStoreFiles(at url: URL) {
        SharedPersistence.resetStoreFiles(at: url)
    }

    static func migrateStoreIfNeeded() {
        let defaults = AppConstants.sharedDefaults
        // v5: TaskItem.milestone → milestoneID (break SwiftData circular reference)
        let key = AppConstants.storeMigratedKey
        guard !defaults.bool(forKey: key) else { return }
        guard let groupURL = AppConstants.sharedStoreURL else {
            defaults.set(true, forKey: key)
            return
        }

        let fm = FileManager.default
        if fm.fileExists(atPath: groupURL.path) {
            defaults.set(true, forKey: key)
            return
        }

        // Default Application Support store used by v1 SwiftData
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let candidates: [URL] = [
            appSupport?.appendingPathComponent("default.store"),
            appSupport?.appendingPathComponent(AppConstants.storeFileName),
            appSupport?.appendingPathComponent("Goalstar.sqlite")
        ].compactMap { $0 }

        for old in candidates where fm.fileExists(atPath: old.path) {
            do {
                try fm.createDirectory(at: groupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: old, to: groupURL)
                let shm = URL(fileURLWithPath: old.path + "-shm")
                let wal = URL(fileURLWithPath: old.path + "-wal")
                if fm.fileExists(atPath: shm.path) {
                    try? fm.copyItem(at: shm, to: URL(fileURLWithPath: groupURL.path + "-shm"))
                }
                if fm.fileExists(atPath: wal.path) {
                    try? fm.copyItem(at: wal, to: URL(fileURLWithPath: groupURL.path + "-wal"))
                }
                break
            } catch {
                continue
            }
        }
        defaults.set(true, forKey: key)
    }

    static func seedIfNeeded(context: ModelContext) {
        // Gate demo seed on a one-shot flag so deleting all goals stays empty
        // (clean install / first launch still seeds when the flag is unset).
        let defaults = UserDefaults.standard
        let alreadySeeded = defaults.bool(forKey: AppConstants.demoSeededKey)
        if !alreadySeeded {
            let goalCount = (try? context.fetchCount(FetchDescriptor<Goal>())) ?? 0
            if goalCount == 0 {
                seedDemoData(context: context)
            }
            defaults.set(true, forKey: AppConstants.demoSeededKey)
        }

        let profileCount = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        if profileCount == 0 {
            context.insert(UserProfile(displayName: "Yunduan"))
            try? context.save()
        }
    }

    private static func seedDemoData(context: ModelContext) {
        let english = Goal(
            name: "系统学习英语",
            emoji: "📖",
            category: "语言学习",
            accentHex: 0x4F46E5,
            totalDays: 30,
            currentDay: 12,
            weeklyRate: 0.8,
            isPrimary: true
        )
        let marathon = Goal(
            name: "准备半程马拉松",
            emoji: "💪",
            category: "身体健康",
            accentHex: 0x10B981,
            totalDays: 60,
            currentDay: 45,
            weeklyRate: 0.75
        )
        let design = Goal(
            name: "个人星图设计集",
            emoji: "🎯",
            category: "职业作品",
            accentHex: 0xA855F7,
            totalDays: 45,
            currentDay: 9,
            weeklyRate: 0.4
        )
        let completed = Goal(
            name: "完成 30 天早起挑战",
            emoji: "✅",
            category: "生活习惯",
            accentHex: 0x10B981,
            totalDays: 30,
            currentDay: 30,
            weeklyRate: 1,
            isCompleted: true,
            completedAt: Calendar.current.date(byAdding: .day, value: -30, to: Date())
        )

        context.insert(english)
        context.insert(marathon)
        context.insert(design)
        context.insert(completed)

        let today = Calendar.current.startOfDay(for: Date())
        let weekLater = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        let twoWeeks = Calendar.current.date(byAdding: .day, value: 14, to: today) ?? today
        let threeWeeks = Calendar.current.date(byAdding: .day, value: 21, to: today) ?? today
        let monthLater = Calendar.current.date(byAdding: .day, value: 30, to: today) ?? today

        let milestones = [
            GoalMilestone(
                title: "打好词汇基础",
                order: 0,
                isCompleted: true,
                startDate: Calendar.current.date(byAdding: .day, value: -14, to: today),
                endDate: Calendar.current.date(byAdding: .day, value: -1, to: today),
                goal: english
            ),
            GoalMilestone(
                title: "完成精读训练",
                order: 1,
                startDate: today,
                endDate: twoWeeks,
                goal: english
            ),
            GoalMilestone(
                title: "模拟口语考试",
                order: 2,
                startDate: twoWeeks,
                endDate: monthLater,
                goal: english
            )
        ]
        for m in milestones { context.insert(m) }

        let readingMilestone = milestones[1]
        let tasks: [(String, Int, Bool, Goal, GoalMilestone?, Int, Date, Date)] = [
            ("完成英语阅读精读篇章", 25, true, english, readingMilestone, 0, today, weekLater),
            ("完成核心力量训练", 40, false, marathon, nil, 1, today, today),
            ("整理本周星图草图", 30, false, design, nil, 2, today, threeWeeks)
        ]
        for (title, mins, priority, goal, milestone, order, start, end) in tasks {
            let t = TaskItem(
                title: title,
                durationMinutes: mins,
                isPriority: priority,
                sortOrder: order,
                scheduledDate: start,
                endDate: end,
                goal: goal,
                milestone: milestone
            )
            context.insert(t)
        }

        let s1 = FocusSession(
            minutes: 25,
            mode: .pomodoro,
            startedAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date(),
            endedAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()),
            isCompleted: true,
            goal: english
        )
        let s2 = FocusSession(
            minutes: 45,
            mode: .deep,
            startedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            endedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            isCompleted: true,
            goal: marathon
        )
        context.insert(s1)
        context.insert(s2)
        context.insert(UserProfile(displayName: "Yunduan"))

        try? context.save()
        // Don't force-show the widget tip again on every reseed of an existing install.
        if AppConstants.sharedDefaults.object(forKey: AppConstants.widgetGuideDismissedKey) == nil {
            AppConstants.sharedDefaults.set(false, forKey: AppConstants.widgetGuideDismissedKey)
        }
    }
}
