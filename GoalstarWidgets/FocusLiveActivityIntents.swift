import ActivityKit
import AppIntents
import Foundation

/// Live Activity buttons run these intents in the **app** process.
/// Must be compiled into both Goalstar and GoalstarWidgets targets.

struct PauseFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "暂停专注"
    static var description = IntentDescription("暂停锁屏上的专注计时")
    static var isDiscoverable: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        await FocusLiveActivityActions.pause()
        return .result()
    }
}

struct ResumeFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "继续专注"
    static var description = IntentDescription("继续锁屏上的专注计时")
    static var isDiscoverable: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        await FocusLiveActivityActions.resume()
        return .result()
    }
}

struct EndFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "结束专注"
    static var description = IntentDescription("结束专注并在 App 中确认")
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        await FocusLiveActivityActions.pause()
        FocusLiveActivityBridge.pendingEndFocus = true
        return .result()
    }
}

enum FocusLiveActivityActions {
    @MainActor
    static func pause() async {
        FocusEndNotifier.cancel()
        for activity in Activity<FocusActivityAttributes>.activities {
            let attrs = activity.attributes
            let current = activity.content.state
            let frozen = current.displaySeconds(isCountUp: attrs.isCountUp)
            let state = FocusActivityAttributes.ContentState(
                isRunning: false,
                frozenSeconds: frozen,
                taskTitle: current.taskTitle,
                goalName: current.goalName
            )
            await activity.update(
                ActivityContent(state: state, staleDate: Date().addingTimeInterval(60 * 60))
            )
        }
    }

    @MainActor
    static func resume() async {
        let now = Date()
        for activity in Activity<FocusActivityAttributes>.activities {
            let attrs = activity.attributes
            let current = activity.content.state
            let seconds = max(0, current.frozenSeconds)
            let state: FocusActivityAttributes.ContentState
            if attrs.isCountUp {
                state = FocusActivityAttributes.ContentState(
                    isRunning: true,
                    countUpStartDate: now.addingTimeInterval(TimeInterval(-seconds)),
                    frozenSeconds: seconds,
                    taskTitle: current.taskTitle,
                    goalName: current.goalName
                )
                FocusEndNotifier.cancel()
            } else {
                state = FocusActivityAttributes.ContentState(
                    isRunning: true,
                    timerEndDate: now.addingTimeInterval(TimeInterval(seconds)),
                    frozenSeconds: seconds,
                    taskTitle: current.taskTitle,
                    goalName: current.goalName
                )
                FocusEndNotifier.schedule(after: seconds, goalName: current.goalName)
            }
            let stale: Date? = attrs.isCountUp
                ? now.addingTimeInterval(8 * 60 * 60)
                : state.timerEndDate?.addingTimeInterval(60)
            await activity.update(ActivityContent(state: state, staleDate: stale))
        }
    }
}
