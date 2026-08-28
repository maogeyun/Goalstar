import Foundation
import SwiftData
import SwiftUI

enum CreateFormMode: String, CaseIterable, Identifiable {
    case task, goal
    var id: String { rawValue }
    var title: String { self == .task ? "新建任务" : "新建目标" }
}

enum TaskStatus: String, Codable, CaseIterable {
    case todo
    case inProgress
    case done
    case skipped

    var isDoneLike: Bool { self == .done || self == .skipped }
}

enum GoalMeasure: String, Codable, CaseIterable {
    case tasks
    case checkIns
    case focus
    case manual

    var title: String {
        switch self {
        case .tasks: return "任务数"
        case .checkIns: return "打卡"
        case .focus: return "专注"
        case .manual: return "手动"
        }
    }
}

@Model
final class UserProfile {
    var id: UUID
    var displayName: String
    var updatedAt: Date

    init(displayName: String = "Yunduan") {
        self.id = UUID()
        self.displayName = displayName
        self.updatedAt = Date()
    }
}

@Model
final class Goal {
    var id: UUID
    var name: String
    var emoji: String
    var category: String
    var accentHex: UInt32
    var totalDays: Int
    var currentDay: Int
    var weeklyRate: Double
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date
    var isPrimary: Bool
    var goalDescription: String = ""
    var startDate: Date = Date()
    var measureRaw: String = GoalMeasure.tasks.rawValue
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.goal)
    var tasks: [TaskItem]?
    @Relationship(deleteRule: .nullify, inverse: \FocusSession.goal)
    var sessions: [FocusSession]?
    @Relationship(deleteRule: .cascade, inverse: \GoalMilestone.goal)
    var milestones: [GoalMilestone]?

    init(
        name: String,
        emoji: String = "🎯",
        category: String,
        accentHex: UInt32 = 0x4F46E5,
        totalDays: Int = 30,
        currentDay: Int = 1,
        weeklyRate: Double = 0,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        isPrimary: Bool = false,
        goalDescription: String = "",
        startDate: Date = Date(),
        measure: GoalMeasure = .tasks
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.category = category
        self.accentHex = accentHex
        self.totalDays = totalDays
        self.currentDay = currentDay
        self.weeklyRate = weeklyRate
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = Date()
        self.isPrimary = isPrimary
        self.goalDescription = goalDescription
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.measureRaw = measure.rawValue
        self.tasks = []
        self.sessions = []
        self.milestones = []
    }

    var measure: GoalMeasure {
        get { GoalMeasure(rawValue: measureRaw) ?? .tasks }
        set { measureRaw = newValue.rawValue }
    }

    var progress: Double {
        let list = milestones ?? []
        if !list.isEmpty {
            let done = list.filter(\.isCompleted).count
            return min(1, Double(done) / Double(list.count))
        }
        guard totalDays > 0 else { return 0 }
        return min(1, Double(currentDay) / Double(totalDays))
    }

    var remainingDays: Int {
        max(0, totalDays - currentDay)
    }

    var accent: ColorHex { ColorHex(value: accentHex) }

    var sortedMilestones: [GoalMilestone] {
        (milestones ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class GoalMilestone {
    var id: UUID
    var title: String
    var order: Int
    var isCompleted: Bool
    var completedAt: Date?
    var startDate: Date?
    var endDate: Date?
    var goal: Goal?

    init(
        title: String,
        order: Int = 0,
        isCompleted: Bool = false,
        startDate: Date? = nil,
        endDate: Date? = nil,
        goal: Goal? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.order = order
        self.isCompleted = isCompleted
        self.completedAt = isCompleted ? Date() : nil
        self.goal = goal
        Self.applyDateRange(start: startDate, end: endDate) { s, e in
            self.startDate = s
            self.endDate = e
        }
    }

    /// Normalized day range when both ends exist; otherwise nil.
    var dateRange: ClosedRange<Date>? {
        guard let start = startDate.map({ Calendar.current.startOfDay(for: $0) }),
              let end = endDate.map({ Calendar.current.startOfDay(for: $0) }) else {
            return nil
        }
        return start <= end ? start...end : end...start
    }

    var hasDateRange: Bool { dateRange != nil }

    func setDateRange(start: Date?, end: Date?) {
        Self.applyDateRange(start: start, end: end) { s, e in
            startDate = s
            endDate = e
        }
    }

    private static func applyDateRange(
        start: Date?,
        end: Date?,
        assign: (Date?, Date?) -> Void
    ) {
        let cal = Calendar.current
        switch (start, end) {
        case let (s?, e?):
            let a = cal.startOfDay(for: s)
            let b = cal.startOfDay(for: e)
            assign(min(a, b), max(a, b))
        case let (s?, nil):
            assign(cal.startOfDay(for: s), nil)
        case let (nil, e?):
            assign(nil, cal.startOfDay(for: e))
        case (nil, nil):
            assign(nil, nil)
        }
    }
}

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var durationMinutes: Int
    var isCompleted: Bool
    var isPriority: Bool
    var sortOrder: Int
    var scheduledDate: Date
    /// End day of the task span; defaults to `scheduledDate`.
    var endDate: Date = Date()
    var completedAt: Date?
    var goal: Goal?
    /// Stored as ID to avoid Goal ↔ Milestone ↔ Task SwiftData circular reference.
    var milestoneID: UUID?
    var isPinned: Bool = false
    var statusRaw: String = TaskStatus.todo.rawValue
    var deferredTo: Date?
    var notes: String = ""
    var reminderMinutes: Int?
    var createdAt: Date = Date()
    var isLockCandidate: Bool = false

    init(
        title: String,
        durationMinutes: Int = 25,
        isCompleted: Bool = false,
        isPriority: Bool = false,
        sortOrder: Int = 0,
        scheduledDate: Date = Date(),
        endDate: Date? = nil,
        goal: Goal? = nil,
        milestone: GoalMilestone? = nil,
        isPinned: Bool = false,
        status: TaskStatus = .todo,
        deferredTo: Date? = nil,
        notes: String = "",
        reminderMinutes: Int? = nil,
        isLockCandidate: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.durationMinutes = durationMinutes
        self.isCompleted = isCompleted
        self.isPriority = isPriority
        self.sortOrder = sortOrder
        let cal = Calendar.current
        let start = cal.startOfDay(for: scheduledDate)
        let end = cal.startOfDay(for: endDate ?? scheduledDate)
        self.scheduledDate = min(start, end)
        self.endDate = max(start, end)
        self.completedAt = isCompleted ? Date() : nil
        self.goal = goal
        self.milestoneID = milestone?.id
        self.isPinned = isPinned
        self.statusRaw = isCompleted ? TaskStatus.done.rawValue : status.rawValue
        self.deferredTo = deferredTo
        self.notes = notes
        self.reminderMinutes = reminderMinutes
        self.createdAt = Date()
        self.isLockCandidate = isLockCandidate
        if isCompleted {
            self.statusRaw = TaskStatus.done.rawValue
        }
    }

    var status: TaskStatus {
        get {
            if let s = TaskStatus(rawValue: statusRaw) { return s }
            return isCompleted ? .done : .todo
        }
        set {
            statusRaw = newValue.rawValue
            switch newValue {
            case .done:
                isCompleted = true
                if completedAt == nil { completedAt = Date() }
            case .skipped:
                isCompleted = false
                completedAt = nil
            case .todo, .inProgress:
                isCompleted = false
                completedAt = nil
            }
        }
    }

    /// Sync legacy `isCompleted` flag into status for older rows.
    func migrateStatusIfNeeded() {
        if statusRaw.isEmpty {
            statusRaw = isCompleted ? TaskStatus.done.rawValue : TaskStatus.todo.rawValue
        }
        if isCompleted && status != .done {
            statusRaw = TaskStatus.done.rawValue
        }
        // Align endDate for rows created before the field existed.
        let cal = Calendar.current
        let start = cal.startOfDay(for: scheduledDate)
        let end = cal.startOfDay(for: endDate)
        if end < start {
            endDate = start
        }
    }

    /// Whether `day` falls within [scheduledDate, endDate] (day granularity).
    func spans(_ day: Date) -> Bool {
        let cal = Calendar.current
        let d = cal.startOfDay(for: day)
        let start = cal.startOfDay(for: scheduledDate)
        let end = cal.startOfDay(for: endDate)
        return d >= min(start, end) && d <= max(start, end)
    }

    func setDateRange(start: Date, end: Date) {
        let cal = Calendar.current
        let a = cal.startOfDay(for: start)
        let b = cal.startOfDay(for: end)
        scheduledDate = min(a, b)
        endDate = max(a, b)
    }
}

extension TaskItem {
    /// 已显式关联的阶段（按 ID 在目标阶段列表中解析）。
    var resolvedMilestone: GoalMilestone? {
        guard let milestoneID else { return nil }
        return goal?.sortedMilestones.first(where: { $0.id == milestoneID })
    }

    /// 展示用阶段：优先任务关联，否则取目标当前未完成阶段。
    var displayMilestone: GoalMilestone? {
        resolvedMilestone ?? goal?.sortedMilestones.first(where: { !$0.isCompleted })
    }
}

@Model
final class FocusSession {
    var id: UUID
    var minutes: Int
    var modeRaw: String
    var startedAt: Date
    var endedAt: Date?
    var isCompleted: Bool
    var goal: Goal?

    init(
        minutes: Int,
        mode: FocusMode = .pomodoro,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        isCompleted: Bool = false,
        goal: Goal? = nil
    ) {
        self.id = UUID()
        self.minutes = minutes
        self.modeRaw = mode.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.isCompleted = isCompleted
        self.goal = goal
    }

    var mode: FocusMode {
        get { FocusMode(rawValue: modeRaw) ?? .pomodoro }
        set { modeRaw = newValue.rawValue }
    }
}

enum FocusMode: String, CaseIterable, Identifiable {
    case pomodoro
    case countUp
    case deep
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pomodoro: return "番茄 25"
        case .countUp: return "正计时"
        case .deep: return "深度 45"
        case .custom: return "倒计时"
        }
    }

    var defaultMinutes: Int {
        switch self {
        case .pomodoro: return 25
        case .countUp: return 0
        case .deep: return 45
        case .custom: return 30
        }
    }

    var isCountUp: Bool { self == .countUp }

    var icon: GSIconName {
        switch self {
        case .pomodoro: return .clock
        case .countUp: return .play
        case .deep: return .timer
        case .custom: return .plus
        }
    }
}

struct ColorHex {
    let value: UInt32
    var color: Color { Color(hex: value) }
}

enum TodayTaskRanking {
    /// PRD five-level sort for today's three tasks.
    static func ranked(_ tasks: [TaskItem]) -> [TaskItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return tasks
            .filter { $0.spans(today) }
            .filter { task in
                if let deferred = task.deferredTo, cal.startOfDay(for: deferred) > today {
                    return false
                }
                return true
            }
            .sorted { a, b in
                let ra = rankTuple(a)
                let rb = rankTuple(b)
                if ra.0 != rb.0 { return ra.0 < rb.0 }
                if ra.1 != rb.1 { return ra.1 < rb.1 }
                return a.sortOrder < b.sortOrder
            }
    }

    /// Lower is higher priority.
    private static func rankTuple(_ task: TaskItem) -> (Int, Int) {
        if task.isPinned { return (0, 0) }
        if task.isLockCandidate { return (1, 0) }
        if task.status == .inProgress { return (2, 0) }
        if task.isPriority { return (3, 0) }
        if task.goal?.isPrimary == true { return (4, 0) }
        return (5, task.sortOrder)
    }

    static func topThree(_ tasks: [TaskItem]) -> [TaskItem] {
        Array(ranked(tasks).prefix(3))
    }

    static func actionable(_ tasks: [TaskItem]) -> [TaskItem] {
        ranked(tasks).filter { $0.status != .skipped }
    }
}
