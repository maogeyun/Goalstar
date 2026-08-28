import Foundation
import ActivityKit

public struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var isRunning: Bool
        /// Countdown while running: wall-clock end.
        public var timerEndDate: Date?
        /// Count-up while running: wall-clock start (elapsed = now - start).
        public var countUpStartDate: Date?
        /// Display seconds when paused (and fallback).
        public var frozenSeconds: Int
        public var taskTitle: String?
        public var goalName: String?

        public init(
            isRunning: Bool,
            timerEndDate: Date? = nil,
            countUpStartDate: Date? = nil,
            frozenSeconds: Int = 0,
            taskTitle: String? = nil,
            goalName: String? = nil
        ) {
            self.isRunning = isRunning
            self.timerEndDate = timerEndDate
            self.countUpStartDate = countUpStartDate
            self.frozenSeconds = frozenSeconds
            self.taskTitle = taskTitle
            self.goalName = goalName
        }

        public func displaySeconds(isCountUp: Bool, now: Date = Date()) -> Int {
            if isRunning {
                if isCountUp, let start = countUpStartDate {
                    return max(0, Int(now.timeIntervalSince(start)))
                }
                if let end = timerEndDate {
                    return max(0, Int(end.timeIntervalSince(now)))
                }
            }
            return max(0, frozenSeconds)
        }
    }

    public var modeTitle: String
    public var targetMinutes: Int
    public var isCountUp: Bool

    public init(modeTitle: String, targetMinutes: Int, isCountUp: Bool) {
        self.modeTitle = modeTitle
        self.targetMinutes = targetMinutes
        self.isCountUp = isCountUp
    }
}

/// Shared keys for Live Activity ↔ App handoff (App Group when available).
public enum FocusLiveActivityBridge {
    public static let pendingEndFocusKey = "goalstar.focus.pendingEndFromLiveActivity"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    public static var pendingEndFocus: Bool {
        get { defaults.bool(forKey: pendingEndFocusKey) }
        set { defaults.set(newValue, forKey: pendingEndFocusKey) }
    }
}
