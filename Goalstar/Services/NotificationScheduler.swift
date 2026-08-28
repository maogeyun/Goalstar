import Foundation
import UserNotifications
import WidgetKit

enum NotificationScheduler {
    static let taskReminderID = "goalstar.reminder.tasks"
    static var focusEndID: String { FocusEndNotifier.notificationID }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Ensure notification permission before scheduling focus-end alerts (non-blocking for callers).
    static func ensureAuthorizationForFocusEnd() {
        Task {
            let status = await authorizationStatus()
            if status == .notDetermined {
                _ = await requestAuthorization()
            }
        }
    }

    static func scheduleFocusEnd(after seconds: Int, goalName: String?) {
        FocusEndNotifier.schedule(after: seconds, goalName: goalName)
    }

    static func cancelFocusEnd() {
        FocusEndNotifier.cancel()
    }

    static func rescheduleFromDefaults(pendingTaskCount: Int = 0) {
        let defaults = AppConstants.sharedDefaults
        let tasksOn = defaults.object(forKey: AppConstants.notifyTasksEnabledKey) as? Bool ?? true
        let taskHour = defaults.object(forKey: AppConstants.notifyTasksHourKey) as? Int ?? 8
        let taskMinute = defaults.object(forKey: AppConstants.notifyTasksMinuteKey) as? Int ?? 0

        cancelAll()

        if tasksOn {
            scheduleDaily(
                id: taskReminderID,
                hour: taskHour,
                minute: taskMinute,
                title: "今日星图提醒",
                body: pendingTaskCount > 0
                    ? "今日还有 \(pendingTaskCount) 件事待完成，继续点亮星图吧"
                    : "查看今日三件事，开始绘制你的星图"
            )
        }
    }

    static func notifyFocusCompleted(minutes: Int, goalName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "专注完成"
        content.body = goalName.map { "已为「\($0)」投入 \(minutes) 分钟" } ?? "本轮专注 \(minutes) 分钟，很棒！"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "goalstar.focus.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [taskReminderID]
        )
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.todayWidgetKind)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func scheduleDaily(
        id: String,
        hour: Int,
        minute: Int,
        title: String,
        body: String
    ) {
        var date = DateComponents()
        date.hour = hour
        date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
