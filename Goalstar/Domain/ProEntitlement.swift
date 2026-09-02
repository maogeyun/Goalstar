import Foundation

/// Shipped Pro gates only. Membership is `AppStore.isPro` (StoreKit lifetime + DEBUG override).
/// Do not list unreleased capabilities here — they must not appear on the paywall.
enum ProFeature: String, CaseIterable, Identifiable {
    case unlimitedGoals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedGoals: return "无限进行中目标"
        }
    }

    var subtitle: String {
        switch self {
        case .unlimitedGoals: return "免费版最多 3 个。升级后不再限制数量。"
        }
    }
}

enum ProEntitlement {
    static let freeActiveGoalLimit = 3

    static var freeGoalLimitMessage: String {
        "免费版最多 \(freeActiveGoalLimit) 个进行中目标，升级 Pro 后可创建更多"
    }

    static func isUnlocked(_ feature: ProFeature, isPro: Bool) -> Bool {
        isPro
    }

    static func requirePro(_ feature: ProFeature, isPro: Bool) -> Bool {
        isUnlocked(feature, isPro: isPro)
    }
}
