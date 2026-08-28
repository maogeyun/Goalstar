import Foundation
import SwiftData
import CoreGraphics

enum DataPeriod: String, CaseIterable, Identifiable {
    case week, month, year
    var id: String { rawValue }
    var title: String {
        switch self {
        case .week: return "本周"
        case .month: return "本月"
        case .year: return "本年"
        }
    }
}

enum GSFormat {
    static let calendar = Calendar.current

    static func greeting(for date: Date = Date()) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }

    static func dateLine(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: date)
            .replacingOccurrences(of: "星期", with: "周")
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M.d"
        return f.string(from: date)
    }

    static func dateRangeLabel(start: Date, end: Date) -> String {
        let a = calendar.startOfDay(for: start)
        let b = calendar.startOfDay(for: end)
        if calendar.isDate(a, inSameDayAs: b) {
            return shortDate(a)
        }
        return "\(shortDate(a)) – \(shortDate(b))"
    }

    static func milestoneRangeLabel(_ milestone: GoalMilestone) -> String? {
        guard let range = milestone.dateRange else { return nil }
        return dateRangeLabel(start: range.lowerBound, end: range.upperBound)
    }

    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func minutesLabel(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }
        return "\(minutes)m"
    }

    static func focusChip(_ minutes: Int) -> String {
        "专注 \(minutes) 分钟"
    }

    static func checkInChip(_ count: Int) -> String {
        "打卡 \(count) 次"
    }

    static func hoursLabel(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) 分钟"
        }
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 {
            return "\(h) 小时"
        }
        return "\(h) 小时 \(m) 分钟"
    }

    static func timer(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        let s = max(0, seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

enum Metrics {
    static func completedTasks(in tasks: [TaskItem], period: DataPeriod, reference: Date = Date()) -> Int {
        let cal = Calendar.current
        return tasks.filter { task in
            guard task.status == .done || task.isCompleted, let completedAt = task.completedAt else { return false }
            switch period {
            case .week:
                return cal.isDate(completedAt, equalTo: reference, toGranularity: .weekOfYear)
            case .month:
                return cal.isDate(completedAt, equalTo: reference, toGranularity: .month)
            case .year:
                return cal.isDate(completedAt, equalTo: reference, toGranularity: .year)
            }
        }.count
    }

    static func completionRate(in tasks: [TaskItem], period: DataPeriod, reference: Date = Date()) -> Int {
        let cal = Calendar.current
        let scoped = tasks.filter { task in
            switch period {
            case .week:
                return cal.isDate(task.scheduledDate, equalTo: reference, toGranularity: .weekOfYear)
            case .month:
                return cal.isDate(task.scheduledDate, equalTo: reference, toGranularity: .month)
            case .year:
                return cal.isDate(task.scheduledDate, equalTo: reference, toGranularity: .year)
            }
        }
        guard !scoped.isEmpty else { return 0 }
        let done = scoped.filter { $0.status == .done || $0.isCompleted }.count
        return Int((Double(done) / Double(scoped.count) * 100).rounded())
    }

    static func habitStreakMax(in habits: [Habit]) -> Int {
        habits.map(\.streak).max() ?? 0
    }

    static func weeklyFocusHoursByWeekday(in sessions: [FocusSession], reference: Date = Date()) -> [CGFloat] {
        let cal = Calendar.current
        var values = Array(repeating: CGFloat(0), count: 7)
        for session in sessions where session.isCompleted && cal.isDate(session.startedAt, equalTo: reference, toGranularity: .weekOfYear) {
            let weekday = cal.component(.weekday, from: session.startedAt)
            let idx = (weekday + 5) % 7
            values[idx] += CGFloat(session.minutes) / 60
        }
        let maxV = values.max() ?? 0
        guard maxV > 0 else { return values }
        return values.map { $0 / maxV }
    }

    static func refreshGoalStats(_ goal: Goal, tasks: [TaskItem]) {
        let cal = Calendar.current
        let goalTasks = tasks.filter { $0.goal?.id == goal.id }
        let completedThisWeek = goalTasks.filter { task in
            guard task.status == .done || task.isCompleted, let completedAt = task.completedAt else { return false }
            return cal.isDate(completedAt, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
        let scheduledThisWeek = max(goalTasks.filter {
            cal.isDate($0.scheduledDate, equalTo: Date(), toGranularity: .weekOfYear)
        }.count, 1)
        goal.weeklyRate = Double(completedThisWeek) / Double(scheduledThisWeek)
    }

    static func refreshAllGoals(_ goals: [Goal], tasks: [TaskItem]) {
        for goal in goals where !goal.isCompleted {
            refreshGoalStats(goal, tasks: tasks)
        }
    }

    /// Peak 2-hour focus window for the current week. Returns start hour 0–23, or nil.
    static func peakFocusHour(in sessions: [FocusSession], reference: Date = Date()) -> Int? {
        let cal = Calendar.current
        var buckets = Array(repeating: 0, count: 24)
        for session in sessions where session.isCompleted
            && cal.isDate(session.startedAt, equalTo: reference, toGranularity: .weekOfYear) {
            let h = cal.component(.hour, from: session.startedAt)
            buckets[h] += session.minutes
        }
        guard let maxMinutes = buckets.max(), maxMinutes > 0,
              let hour = buckets.firstIndex(of: maxMinutes) else { return nil }
        return hour
    }

    static func weeklyReviewAdvice(completionRate: Int, focusMinutes: Int, streak: Int) -> String {
        if completionRate < 50 {
            return "本周完成率偏低，建议下周减少今日任务数量，先保证主目标推进。"
        }
        if completionRate >= 80 {
            return "完成节奏很好。下周可以继续巩固主目标，并适当拉开阶段计划。"
        }
        if focusMinutes < 60 {
            return "专注投入偏少，试试每天固定一段 25 分钟番茄，建立稳定节奏。"
        }
        if streak >= 7 {
            return "打卡连续表现优秀，保持习惯即可，任务上可聚焦高优事项。"
        }
        return "保持当前节奏，优先完成置顶与锁屏上的三件事即可。"
    }
}
