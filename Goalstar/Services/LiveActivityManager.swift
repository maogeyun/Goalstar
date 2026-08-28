import Foundation
import ActivityKit

@MainActor
enum LiveActivityManager {
    static func start(
        modeTitle: String,
        targetMinutes: Int,
        isCountUp: Bool,
        displaySeconds: Int,
        taskTitle: String?,
        goalName: String?
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endAll()

        let now = Date()
        let state: FocusActivityAttributes.ContentState
        if isCountUp {
            let start = now.addingTimeInterval(TimeInterval(-max(0, displaySeconds)))
            state = FocusActivityAttributes.ContentState(
                isRunning: true,
                countUpStartDate: start,
                frozenSeconds: max(0, displaySeconds),
                taskTitle: taskTitle,
                goalName: goalName
            )
        } else {
            let end = now.addingTimeInterval(TimeInterval(max(0, displaySeconds)))
            state = FocusActivityAttributes.ContentState(
                isRunning: true,
                timerEndDate: end,
                frozenSeconds: max(0, displaySeconds),
                taskTitle: taskTitle,
                goalName: goalName
            )
        }

        let attributes = FocusActivityAttributes(
            modeTitle: modeTitle,
            targetMinutes: max(1, targetMinutes),
            isCountUp: isCountUp
        )
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: staleDate(for: state, isCountUp: isCountUp)),
                pushType: nil
            )
        } catch {
            // Live Activity unavailable (simulator / denied)
        }
    }

    static func pause(
        frozenSeconds: Int,
        taskTitle: String? = nil,
        goalName: String? = nil
    ) {
        let state = FocusActivityAttributes.ContentState(
            isRunning: false,
            frozenSeconds: max(0, frozenSeconds),
            taskTitle: taskTitle,
            goalName: goalName
        )
        push(state: state, isCountUpHint: nil)
    }

    static func resume(
        isCountUp: Bool,
        displaySeconds: Int,
        taskTitle: String? = nil,
        goalName: String? = nil
    ) {
        let now = Date()
        let state: FocusActivityAttributes.ContentState
        if isCountUp {
            let start = now.addingTimeInterval(TimeInterval(-max(0, displaySeconds)))
            state = FocusActivityAttributes.ContentState(
                isRunning: true,
                countUpStartDate: start,
                frozenSeconds: max(0, displaySeconds),
                taskTitle: taskTitle,
                goalName: goalName
            )
        } else {
            let end = now.addingTimeInterval(TimeInterval(max(0, displaySeconds)))
            state = FocusActivityAttributes.ContentState(
                isRunning: true,
                timerEndDate: end,
                frozenSeconds: max(0, displaySeconds),
                taskTitle: taskTitle,
                goalName: goalName
            )
        }
        push(state: state, isCountUpHint: isCountUp)
    }

    /// Update metadata only (task/goal title) while keeping timer dates.
    static func updateMetadata(taskTitle: String?, goalName: String?) {
        for activity in Activity<FocusActivityAttributes>.activities {
            var state = activity.content.state
            state.taskTitle = taskTitle
            state.goalName = goalName
            let content = ActivityContent(
                state: state,
                staleDate: staleDate(for: state, isCountUp: activity.attributes.isCountUp)
            )
            Task { await activity.update(content) }
        }
    }

    static func endAll() {
        for activity in Activity<FocusActivityAttributes>.activities {
            Task {
                let state = activity.content.state
                let final = FocusActivityAttributes.ContentState(
                    isRunning: false,
                    frozenSeconds: 0,
                    taskTitle: state.taskTitle,
                    goalName: state.goalName
                )
                await activity.end(
                    ActivityContent(state: final, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
    }

    private static func push(state: FocusActivityAttributes.ContentState, isCountUpHint: Bool?) {
        for activity in Activity<FocusActivityAttributes>.activities {
            let isCountUp = isCountUpHint ?? activity.attributes.isCountUp
            let content = ActivityContent(
                state: state,
                staleDate: staleDate(for: state, isCountUp: isCountUp)
            )
            Task { await activity.update(content) }
        }
    }

    private static func staleDate(for state: FocusActivityAttributes.ContentState, isCountUp: Bool) -> Date? {
        if state.isRunning {
            if isCountUp {
                return Date().addingTimeInterval(8 * 60 * 60)
            }
            if let end = state.timerEndDate {
                return end.addingTimeInterval(60)
            }
        }
        return Date().addingTimeInterval(60 * 60)
    }
}
