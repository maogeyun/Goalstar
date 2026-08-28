import Foundation

enum AppConstants {
    static let appGroupID = "group.com.goalstar.native"
    static let storeFileName = "goalstar.store"
    static let todayWidgetKind = "GoalstarTodayTasks"
    static let notifyTasksEnabledKey = "goalstar.notify.tasksEnabled"
    static let notifyTasksHourKey = "goalstar.notify.tasksHour"
    static let notifyTasksMinuteKey = "goalstar.notify.tasksMinute"
    static let widgetGuideDismissedKey = "goalstar.widgetGuideDismissed"
    static let taskEndDateMigratedKey = "goalstar.taskEndDateMigrated.v1"
    static let storeMigratedKey = "goalstar.store.migrated.v5"
    static let lockWidgetEnabledKey = "goalstar.lock.enabled"
    static let lockWidgetCountKey = "goalstar.lock.count"
    static let lockPrivacyModeKey = "goalstar.lock.privacy"
    static let proMembershipKey = "goalstar.pro.isMember"
    static let storeBackupNoticeKey = "goalstar.store.backupNotice"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var isProMember: Bool {
        get { sharedDefaults.bool(forKey: proMembershipKey) }
        set { sharedDefaults.set(newValue, forKey: proMembershipKey) }
    }

    static var lockWidgetEnabled: Bool {
        get {
            if sharedDefaults.object(forKey: lockWidgetEnabledKey) == nil { return true }
            return sharedDefaults.bool(forKey: lockWidgetEnabledKey)
        }
        set { sharedDefaults.set(newValue, forKey: lockWidgetEnabledKey) }
    }

    static var lockWidgetCount: Int {
        get {
            let n = sharedDefaults.object(forKey: lockWidgetCountKey) as? Int ?? 3
            return min(3, max(1, n))
        }
        set { sharedDefaults.set(min(3, max(1, newValue)), forKey: lockWidgetCountKey) }
    }

    static var lockPrivacyMode: Bool {
        get { sharedDefaults.bool(forKey: lockPrivacyModeKey) }
        set { sharedDefaults.set(newValue, forKey: lockPrivacyModeKey) }
    }

    static var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static var sharedStoreURL: URL? {
        appGroupContainerURL?.appendingPathComponent(storeFileName)
    }
}
