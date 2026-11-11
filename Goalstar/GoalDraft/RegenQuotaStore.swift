import Foundation

/// On-device counter for confirm-card 「再生成」. The first 「生成草稿」 does not consume this quota.
/// Free: 3 regenerations per local calendar day. Pro: unlimited. Never gates save or manual create.
enum RegenQuotaStore {
    static let freeDailyLimit = 3

    private static let dayKey = "goalstar.ai.regen.day"
    private static let countKey = "goalstar.ai.regen.count"

    static func canRegenerate(
        isPro: Bool,
        now: Date = Date(),
        defaults: UserDefaults = AppConstants.sharedDefaults
    ) -> Bool {
        if isPro { return true }
        return usedCount(now: now, defaults: defaults) < freeDailyLimit
    }

    /// `nil` means unlimited (Pro).
    static func remaining(
        isPro: Bool,
        now: Date = Date(),
        defaults: UserDefaults = AppConstants.sharedDefaults
    ) -> Int? {
        if isPro { return nil }
        return max(0, freeDailyLimit - usedCount(now: now, defaults: defaults))
    }

    static func record(
        isPro: Bool,
        now: Date = Date(),
        defaults: UserDefaults = AppConstants.sharedDefaults
    ) {
        guard !isPro else { return }
        let count = usedCount(now: now, defaults: defaults) + 1
        defaults.set(dayStamp(now), forKey: dayKey)
        defaults.set(count, forKey: countKey)
    }

    private static func usedCount(now: Date, defaults: UserDefaults) -> Int {
        guard defaults.string(forKey: dayKey) == dayStamp(now) else { return 0 }
        return max(0, defaults.integer(forKey: countKey))
    }

    private static func dayStamp(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
