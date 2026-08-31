import Foundation

/// Feature gates. Membership is `AppStore.isPro` (StoreKit lifetime + DEBUG override).
enum ProFeature: String, CaseIterable, Identifiable {
    case unlimitedGoals
    case advancedInsights
    case themePack
    case prioritySupport

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedGoals: return "无限目标与任务"
        case .advancedInsights: return "高级数据洞察"
        case .themePack: return "主题外观包"
        case .prioritySupport: return "优先支持"
        }
    }

    var subtitle: String {
        switch self {
        case .unlimitedGoals: return "免费版最多 3 个进行中目标"
        case .advancedInsights: return "更长周期复盘与导出（开发中）"
        case .themePack: return "更多配色与外观（开发中）"
        case .prioritySupport: return "问题反馈优先处理"
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
