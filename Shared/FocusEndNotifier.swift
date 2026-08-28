import Foundation
import UserNotifications

/// Schedules a one-shot local notification when a countdown focus session should end.
/// Lives in Shared so App + Widget (Live Activity intents) can both cancel/reschedule.
enum FocusEndNotifier {
    static let notificationID = "goalstar.focus.end"

    static func schedule(after seconds: Int, goalName: String?) {
        cancel()
        let interval = max(1, seconds)
        let content = UNMutableNotificationContent()
        content.title = "专注时间到"
        if let goalName, !goalName.isEmpty {
            content.body = "「\(goalName)」的倒计时已结束，回来结束本轮专注吧"
        } else {
            content.body = "本轮倒计时已结束，回来结束本轮专注吧"
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(interval), repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        center.removeDeliveredNotifications(withIdentifiers: [notificationID])
    }
}
