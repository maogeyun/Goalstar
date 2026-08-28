import Foundation
import SwiftData
import SwiftUI
import Combine
import WidgetKit
import ActivityKit
import UIKit

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var showCreateSheet = false
    @Published var createSheetMode: CreateFormMode = .task
    @Published var createSheetScheduledDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var createSheetPreferredGoalID: UUID?
    @Published var pendingCreateAfterDismiss = false
    @Published var showTomorrowPreview = false
    @Published var focusTargetMinutes: Int = 25
    @Published var focusMode: FocusMode = .pomodoro
    @Published var focusRemaining: Int = 25 * 60
    @Published var focusElapsed: Int = 0
    @Published var isFocusRunning = false
    @Published var selectedFocusGoalID: UUID?
    @Published var dataPeriod: DataPeriod = .week
    @Published var widgetGuideDismissed: Bool = AppConstants.sharedDefaults.bool(forKey: AppConstants.widgetGuideDismissedKey)
    @Published var userName: String = "Yunduan"
    @Published var activeFocusTaskTitle: String?
    @Published var selectedGoalID: UUID?
    @Published var showGoalDetail = false
    @Published var showFinishFocusConfirm = false
    @Published var showInterruptFocusConfirm = false
    @Published var showAbandonFocusConfirm = false
    @Published var pendingAutoStartFocus = false
    @Published var isPro: Bool = AppConstants.isProMember
    @Published var lastSaveError: String?

    private var resumeFocusAfterConfirmDismiss = false
    private var pendingInterruptFocusTaskID: UUID?

    /// Legacy alias used by older UI; maps to widget guide visibility inverted.
    var lockScreenEnabled: Bool {
        get { !widgetGuideDismissed }
        set { setWidgetGuideDismissed(!newValue) }
    }

    private var timer: AnyCancellable?
    private var focusStartedAt: Date?
    private(set) var activeFocusTaskID: UUID?
    private var focusTimerGoals: [Goal] = []
    private var liveActivityWatchTask: Task<Void, Never>?
    private var isApplyingLiveActivityState = false
    private var pendingCreateMode: CreateFormMode = .task
    private var pendingCreateScheduledDate: Date = Calendar.current.startOfDay(for: Date())
    private var pendingCreatePreferredGoalID: UUID?

    func loadProfile(context: ModelContext) {
        if let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first {
            userName = profile.displayName
        }
        migrateLegacyTaskFields(context: context)
        loadProStatus()
        if AppConstants.sharedDefaults.bool(forKey: AppConstants.storeBackupNoticeKey) {
            lastSaveError = "本地数据已备份并重建。若发现数据异常，请检查 App Group 目录中的备份文件。"
            AppConstants.sharedDefaults.set(false, forKey: AppConstants.storeBackupNoticeKey)
        }
    }

    func loadProStatus() {
        isPro = AppConstants.isProMember
    }

    /// Mock membership for E+B skeleton. Replace with StoreKit entitlement sync later.
    func setProMock(_ enabled: Bool) {
        AppConstants.isProMember = enabled
        isPro = enabled
    }

    /// Placeholder for StoreKit restore; currently reloads local mock flag.
    @discardableResult
    func restorePurchasesMock() -> Bool {
        loadProStatus()
        return isPro
    }

    func migrateLegacyTaskFields(context: ModelContext) {
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        var changed = false
        let cal = Calendar.current
        let needsEndDateBackfill = !AppConstants.sharedDefaults.bool(forKey: AppConstants.taskEndDateMigratedKey)

        for task in tasks {
            if task.statusRaw.isEmpty {
                task.statusRaw = task.isCompleted ? TaskStatus.done.rawValue : TaskStatus.todo.rawValue
                changed = true
            }
            task.migrateStatusIfNeeded()
            let start = cal.startOfDay(for: task.scheduledDate)
            let end = cal.startOfDay(for: task.endDate)
            if end < start {
                task.endDate = start
                changed = true
            }
        }

        if needsEndDateBackfill {
            AppConstants.sharedDefaults.set(true, forKey: AppConstants.taskEndDateMigratedKey)
        }
        if changed {
            saveContext(context)
        }
    }

    @discardableResult
    private func saveContext(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            lastSaveError = nil
            return true
        } catch {
            lastSaveError = error.localizedDescription
            #if DEBUG
            print("[AppStore] save failed: \(error)")
            #endif
            return false
        }
    }

    func updateUserName(_ name: String, context: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        if let profile = profiles.first {
            profile.displayName = trimmed
            profile.updatedAt = Date()
        } else {
            context.insert(UserProfile(displayName: trimmed))
        }
        userName = trimmed
        saveContext(context)
    }

    func resetHabitsForNewDay(context: ModelContext, habits: [Habit]) {
        let cal = Calendar.current
        var changed = false
        for habit in habits {
            if habit.state == .done,
               let last = habit.lastCheckIn,
               !cal.isDateInToday(last) {
                habit.state = .pending
                changed = true
            }
        }
        if changed {
            saveContext(context)
            NotificationScheduler.reloadWidgets()
        }
    }

    func openCreateSheet(mode: CreateFormMode = .task, scheduledDate: Date? = nil, preferredGoalID: UUID? = nil) {
        createSheetMode = mode
        createSheetScheduledDate = Calendar.current.startOfDay(for: scheduledDate ?? Date())
        createSheetPreferredGoalID = preferredGoalID
        showCreateSheet = true
    }

    /// Queue CreateSheet for the next runloop after another sheet dismisses.
    func openCreateSheetAfterDismiss(
        mode: CreateFormMode = .task,
        scheduledDate: Date? = nil,
        preferredGoalID: UUID? = nil
    ) {
        pendingCreateMode = mode
        pendingCreateScheduledDate = Calendar.current.startOfDay(for: scheduledDate ?? Date())
        pendingCreatePreferredGoalID = preferredGoalID
        pendingCreateAfterDismiss = true
    }

    func presentPendingCreateSheetIfNeeded() {
        guard pendingCreateAfterDismiss else { return }
        pendingCreateAfterDismiss = false
        openCreateSheet(
            mode: pendingCreateMode,
            scheduledDate: pendingCreateScheduledDate,
            preferredGoalID: pendingCreatePreferredGoalID
        )
    }

    func clearCreateSheetPreferences() {
        createSheetPreferredGoalID = nil
    }

    func openGoalDetail(_ goal: Goal) {
        selectedGoalID = goal.id
        showGoalDetail = true
    }

    enum AppTab: Int, CaseIterable, Identifiable {
        case today, goals, focus, data, profile
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .today: return "今日"
            case .goals: return "目标"
            case .focus: return "专注"
            case .data: return "数据"
            case .profile: return "我的"
            }
        }
        var icon: GSIconName {
            switch self {
            case .today: return .house
            case .goals: return .target
            case .focus: return .timer
            case .data: return .barChart
            case .profile: return .user
            }
        }
    }

    func setWidgetGuideDismissed(_ dismissed: Bool) {
        widgetGuideDismissed = dismissed
        AppConstants.sharedDefaults.set(dismissed, forKey: AppConstants.widgetGuideDismissedKey)
        UserDefaults.standard.set(!dismissed, forKey: "goalstar.lockScreenEnabled")
    }

    /// Hide the Today-page widget tip once the Goalstar widget is already on Home/Lock Screen.
    func refreshWidgetGuideVisibility() {
        WidgetCenter.shared.getCurrentConfigurations { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard case .success(let configs) = result else { return }
                let installed = configs.contains { $0.kind == AppConstants.todayWidgetKind }
                if installed {
                    self.setWidgetGuideDismissed(true)
                }
            }
        }
    }

    func setLockScreen(_ enabled: Bool) {
        AppConstants.lockWidgetEnabled = enabled
        NotificationScheduler.reloadWidgets()
    }

    // MARK: - Task actions

    func toggleTask(_ task: TaskItem, context: ModelContext, goals: [Goal], allTasks: [TaskItem]) {
        if task.status == .done {
            uncompleteTask(task, context: context, goals: goals, allTasks: allTasks)
        } else {
            completeTask(task, context: context, goals: goals, allTasks: allTasks)
        }
    }

    func completeTask(_ task: TaskItem, context: ModelContext, goals: [Goal], allTasks: [TaskItem]) {
        task.status = .done
        task.deferredTo = nil
        Metrics.refreshAllGoals(goals, tasks: allTasks)
        saveContext(context)
        NotificationScheduler.reloadWidgets()
        refreshReminderBodies(context: context)
    }

    func uncompleteTask(_ task: TaskItem, context: ModelContext, goals: [Goal], allTasks: [TaskItem]) {
        task.status = .todo
        Metrics.refreshAllGoals(goals, tasks: allTasks)
        saveContext(context)
        NotificationScheduler.reloadWidgets()
        refreshReminderBodies(context: context)
    }

    func deferTask(_ task: TaskItem, context: ModelContext) {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let target = cal.date(byAdding: .day, value: 1, to: base) ?? base
        let milestone = task.displayMilestone
        let (start, end) = clampTaskDates(start: target, end: target, to: milestone)
        task.deferredTo = start
        task.setDateRange(start: start, end: end)
        task.status = .todo
        saveContext(context)
        NotificationScheduler.reloadWidgets()
        refreshReminderBodies(context: context)
    }

    func skipTask(_ task: TaskItem, context: ModelContext, goals: [Goal], allTasks: [TaskItem]) {
        guard !task.status.isDoneLike else { return }
        task.status = .skipped
        Metrics.refreshAllGoals(goals, tasks: allTasks)
        saveContext(context)
        NotificationScheduler.reloadWidgets()
        refreshReminderBodies(context: context)
    }

    func unskipTask(_ task: TaskItem, context: ModelContext, goals: [Goal], allTasks: [TaskItem]) {
        guard task.status == .skipped else { return }
        task.status = .todo
        Metrics.refreshAllGoals(goals, tasks: allTasks)
        saveContext(context)
        NotificationScheduler.reloadWidgets()
        refreshReminderBodies(context: context)
    }

    func deleteTask(_ task: TaskItem, context: ModelContext) {
        clearActiveFocusBinding(for: task)
        context.delete(task)
        saveContext(context)
        NotificationScheduler.reloadWidgets()
        refreshReminderBodies(context: context)
    }

    func pinTask(_ task: TaskItem, context: ModelContext) {
        task.isPinned.toggle()
        saveContext(context)
        NotificationScheduler.reloadWidgets()
    }

    func markInProgress(_ task: TaskItem, context: ModelContext) {
        if task.status != .done {
            task.status = .inProgress
            saveContext(context)
            NotificationScheduler.reloadWidgets()
        }
    }

    func setLockCandidate(_ task: TaskItem, context: ModelContext) {
        task.isLockCandidate.toggle()
        saveContext(context)
        NotificationScheduler.reloadWidgets()
    }

    func updateTaskNotes(_ task: TaskItem, notes: String, context: ModelContext) {
        task.notes = notes
        saveContext(context)
    }

    func updateTaskReminder(_ task: TaskItem, minutes: Int?, context: ModelContext) {
        task.reminderMinutes = minutes
        saveContext(context)
    }

    func updateTaskAssociation(
        _ task: TaskItem,
        goal: Goal?,
        milestone: GoalMilestone?,
        context: ModelContext
    ) {
        task.goal = goal
        if let goal, let milestone, milestone.goal?.id == goal.id {
            task.milestoneID = milestone.id
        } else {
            task.milestoneID = nil
        }
        saveContext(context)
        NotificationScheduler.reloadWidgets()
    }

    // MARK: - Habits

    func checkInHabit(_ habit: Habit, context: ModelContext) {
        guard habit.state != .done else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let alreadyToday = habit.lastCheckIn.map { cal.isDateInToday($0) } ?? false
        habit.state = .done
        habit.lastCheckIn = Date()
        if !alreadyToday {
            habit.streak += 1
            let exists = (habit.checkIns ?? []).contains { cal.isDate($0.date, inSameDayAs: today) }
            if !exists {
                context.insert(HabitCheckIn(date: today, habit: habit))
            }
        }
        saveContext(context)
        NotificationScheduler.reloadWidgets()
        refreshReminderBodies(context: context)
    }

    // MARK: - Goals

    func setPrimaryGoal(_ goal: Goal, context: ModelContext, goals: [Goal]) {
        for g in goals { g.isPrimary = false }
        goal.isPrimary = true
        saveContext(context)
    }

    func archiveGoal(_ goal: Goal, context: ModelContext) {
        clearActiveFocusBinding(forGoal: goal, context: context)
        if selectedFocusGoalID == goal.id {
            selectedFocusGoalID = nil
        }
        goal.isCompleted = true
        goal.completedAt = Date()
        goal.isPrimary = false
        saveContext(context)
        NotificationScheduler.reloadWidgets()
    }

    func unarchiveGoal(_ goal: Goal, context: ModelContext) {
        goal.isCompleted = false
        goal.completedAt = nil
        saveContext(context)
        NotificationScheduler.reloadWidgets()
    }

    func deleteGoal(_ goal: Goal, context: ModelContext) {
        clearActiveFocusBinding(forGoal: goal, context: context)
        if selectedFocusGoalID == goal.id {
            selectedFocusGoalID = nil
        }
        if selectedGoalID == goal.id {
            selectedGoalID = nil
            showGoalDetail = false
        }
        context.delete(goal)
        saveContext(context)
        NotificationScheduler.reloadWidgets()
        refreshReminderBodies(context: context)
    }

    private func clearActiveFocusBinding(for task: TaskItem) {
        guard activeFocusTaskID == task.id else { return }
        activeFocusTaskID = nil
        activeFocusTaskTitle = nil
    }

    private func clearActiveFocusBinding(forGoal goal: Goal, context: ModelContext) {
        if selectedFocusGoalID == goal.id {
            selectedFocusGoalID = nil
        }
        guard let taskID = activeFocusTaskID else { return }
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        if let task = tasks.first(where: { $0.id == taskID }), task.goal?.id == goal.id {
            activeFocusTaskID = nil
            activeFocusTaskTitle = nil
        }
    }

    private func hasFocusProgress() -> Bool {
        isFocusRunning || focusElapsed > 0 || (
            !focusMode.isCountUp && focusRemaining < focusTargetMinutes * 60
        )
    }

    private func applyFocusTaskContext(_ task: TaskItem, autoStart: Bool) {
        activeFocusTaskID = task.id
        activeFocusTaskTitle = task.title
        focusMode = task.durationMinutes >= 40 ? .deep : .pomodoro
        focusTargetMinutes = max(task.durationMinutes, 5)
        focusElapsed = 0
        focusRemaining = focusTargetMinutes * 60
        focusStartedAt = nil
        selectedFocusGoalID = task.goal?.id
        pendingAutoStartFocus = autoStart
        selectedTab = .focus
    }

    /// Resolved goal for focus UI and session logging — nil means free focus (no fallback to primary).
    func focusLinkedGoal(in goals: [Goal]) -> Goal? {
        guard let id = selectedFocusGoalID else { return nil }
        return goals.first(where: { $0.id == id })
    }

    /// Celebration card → Focus tab with free focus and auto-start (aligned with Play).
    func continueFreeFocus() {
        if hasFocusProgress() {
            pendingInterruptFocusTaskID = nil
            showInterruptFocusConfirm = true
            return
        }
        activeFocusTaskID = nil
        activeFocusTaskTitle = nil
        selectedFocusGoalID = nil
        prepareFocusTimerForStart()
        pendingAutoStartFocus = true
        selectedTab = .focus
    }

    private func prepareFocusTimerForStart() {
        guard !isFocusRunning else { return }
        if focusMode.isCountUp {
            if focusElapsed == 0 {
                focusRemaining = 0
            }
        } else if focusRemaining <= 0 {
            focusRemaining = max(focusTargetMinutes, 1) * 60
            focusElapsed = 0
        }
        focusStartedAt = nil
    }

    func addMilestone(
        title: String,
        startDate: Date?,
        endDate: Date?,
        goal: Goal,
        context: ModelContext
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let order = (goal.milestones ?? []).count
        let m = GoalMilestone(
            title: trimmed,
            order: order,
            startDate: startDate,
            endDate: endDate,
            goal: goal
        )
        context.insert(m)
        saveContext(context)
    }

    func updateMilestone(
        _ milestone: GoalMilestone,
        title: String? = nil,
        startDate: Date?,
        endDate: Date?,
        context: ModelContext
    ) {
        if let title {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                milestone.title = trimmed
            }
        }
        milestone.setDateRange(start: startDate, end: endDate)
        saveContext(context)
    }

    func toggleMilestone(_ milestone: GoalMilestone, context: ModelContext) {
        milestone.isCompleted.toggle()
        milestone.completedAt = milestone.isCompleted ? Date() : nil
        if let goal = milestone.goal {
            let list = goal.sortedMilestones
            if !list.isEmpty {
                goal.currentDay = max(1, list.filter(\.isCompleted).count)
            }
        }
        saveContext(context)
    }

    func deleteMilestone(_ milestone: GoalMilestone, context: ModelContext) {
        let mid = milestone.id
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        for task in tasks where task.milestoneID == mid {
            task.milestoneID = nil
        }
        context.delete(milestone)
        saveContext(context)
    }

    /// Returns nil when the range is valid (or unconstrained); otherwise an error message.
    func validateTaskDates(
        start: Date,
        end: Date,
        milestone: GoalMilestone?
    ) -> String? {
        let cal = Calendar.current
        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end)
        if e < s {
            return "结束日期不能早于开始日期"
        }
        guard let range = milestone?.dateRange else { return nil }
        if s < range.lowerBound || e > range.upperBound {
            return "任务日期需在关联阶段的时间范围内"
        }
        return nil
    }

    func clampTaskDates(
        start: Date,
        end: Date,
        to milestone: GoalMilestone?
    ) -> (Date, Date) {
        let cal = Calendar.current
        var s = cal.startOfDay(for: start)
        var e = cal.startOfDay(for: end)
        if e < s { swap(&s, &e) }
        guard let range = milestone?.dateRange else { return (s, e) }
        s = min(max(s, range.lowerBound), range.upperBound)
        e = min(max(e, range.lowerBound), range.upperBound)
        if e < s { e = s }
        return (s, e)
    }

    // MARK: - Focus

    func selectFocusMode(_ mode: FocusMode) {
        let wasRunningCountdown = isFocusRunning && !focusMode.isCountUp
        focusMode = mode
        focusTargetMinutes = mode.isCountUp ? max(focusTargetMinutes, 25) : mode.defaultMinutes
        if mode == .custom && focusTargetMinutes == 0 {
            focusTargetMinutes = 30
        }
        if !isFocusRunning {
            if mode.isCountUp {
                focusElapsed = 0
                focusRemaining = 0
            } else {
                focusElapsed = 0
                focusRemaining = focusTargetMinutes * 60
            }
        }
        if mode.isCountUp {
            NotificationScheduler.cancelFocusEnd()
        } else if wasRunningCountdown || (isFocusRunning && !mode.isCountUp) {
            rescheduleFocusEndNotification(goals: focusTimerGoals)
        }
    }

    func startFocus(context: ModelContext, goals: [Goal]) {
        if isFocusRunning {
            pauseFocus(goals: goals)
            return
        }
        if !focusMode.isCountUp, focusRemaining <= 0 {
            focusRemaining = max(focusTargetMinutes, 1) * 60
            focusElapsed = 0
            focusStartedAt = nil
        }
        isFocusRunning = true
        if focusStartedAt == nil {
            focusStartedAt = Date()
        }
        focusTimerGoals = goals

        let goal = focusLinkedGoal(in: goals)
        let displaySeconds = focusMode.isCountUp ? focusElapsed : focusRemaining
        let goalName = goal.map { "\($0.emoji) \($0.name)" }
        if Activity<FocusActivityAttributes>.activities.isEmpty {
            LiveActivityManager.start(
                modeTitle: focusMode.title,
                targetMinutes: max(1, focusTargetMinutes),
                isCountUp: focusMode.isCountUp,
                displaySeconds: displaySeconds,
                taskTitle: activeFocusTaskTitle,
                goalName: goalName
            )
        } else {
            LiveActivityManager.resume(
                isCountUp: focusMode.isCountUp,
                displaySeconds: displaySeconds,
                taskTitle: activeFocusTaskTitle,
                goalName: goalName
            )
        }
        startWatchingLiveActivity()
        startLocalFocusTimer()
        scheduleFocusEndIfNeeded(goalName: goal?.name)
    }

    private func scheduleFocusEndIfNeeded(goalName: String?) {
        guard !focusMode.isCountUp else {
            NotificationScheduler.cancelFocusEnd()
            return
        }
        NotificationScheduler.ensureAuthorizationForFocusEnd()
        NotificationScheduler.scheduleFocusEnd(after: focusRemaining, goalName: goalName)
    }

    private func rescheduleFocusEndNotification(goals: [Goal]) {
        guard isFocusRunning, !focusMode.isCountUp else {
            NotificationScheduler.cancelFocusEnd()
            return
        }
        let goal = focusLinkedGoal(in: goals.isEmpty ? focusTimerGoals : goals)
        scheduleFocusEndIfNeeded(goalName: goal?.name)
    }

    private func startLocalFocusTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.isFocusRunning else { return }
                if self.focusMode.isCountUp {
                    self.focusElapsed += 1
                } else if self.focusRemaining > 0 {
                    self.focusRemaining -= 1
                } else {
                    self.requestFinishFocus(goals: self.focusTimerGoals)
                }
            }
    }

    func pauseFocus(goals: [Goal] = [], syncLiveActivity: Bool = true) {
        isFocusRunning = false
        timer?.cancel()
        timer = nil
        NotificationScheduler.cancelFocusEnd()
        guard syncLiveActivity else { return }
        let g = focusLinkedGoal(in: goals.isEmpty ? focusTimerGoals : goals)
        let seconds = focusMode.isCountUp ? focusElapsed : focusRemaining
        LiveActivityManager.pause(
            frozenSeconds: seconds,
            taskTitle: activeFocusTaskTitle,
            goalName: g.map { "\($0.emoji) \($0.name)" }
        )
    }

    func resetFocus() {
        pauseFocus(syncLiveActivity: false)
        focusElapsed = 0
        focusRemaining = focusMode.isCountUp ? 0 : focusTargetMinutes * 60
        focusStartedAt = nil
        activeFocusTaskID = nil
        activeFocusTaskTitle = nil
        stopWatchingLiveActivity()
        LiveActivityManager.endAll()
        NotificationScheduler.cancelFocusEnd()
    }

    func requestFinishFocus(goals: [Goal] = []) {
        let goalList = goals.isEmpty ? focusTimerGoals : goals
        let hasProgress = isFocusRunning || focusElapsed > 0 || (
            !focusMode.isCountUp && focusRemaining < focusTargetMinutes * 60
        )
        guard hasProgress else { return }
        let hitZero = !focusMode.isCountUp && focusRemaining <= 0
        if hitZero {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        resumeFocusAfterConfirmDismiss = isFocusRunning
        if isFocusRunning {
            pauseFocus(goals: goalList)
        } else {
            NotificationScheduler.cancelFocusEnd()
        }
        showFinishFocusConfirm = true
    }

    func handleFinishFocusConfirmDismissed(context: ModelContext, goals: [Goal]) {
        guard resumeFocusAfterConfirmDismiss else { return }
        resumeFocusAfterConfirmDismiss = false
        startFocus(context: context, goals: goals)
    }

    func finishFocus(completeTask: Bool, context: ModelContext, goals: [Goal], tasks: [TaskItem]) {
        resumeFocusAfterConfirmDismiss = false
        showFinishFocusConfirm = false
        pauseFocus(goals: goals, syncLiveActivity: false)

        let rawMinutes: Int
        if focusMode.isCountUp {
            rawMinutes = focusElapsed / 60
        } else if focusRemaining <= 0 {
            rawMinutes = focusTargetMinutes
        } else {
            rawMinutes = focusTargetMinutes - focusRemaining / 60
        }
        guard rawMinutes > 0 || focusElapsed > 0 else {
            abandonFocus()
            return
        }
        let minutes = max(1, rawMinutes)

        let goal = focusLinkedGoal(in: goals)
        let session = FocusSession(
            minutes: minutes,
            mode: focusMode,
            startedAt: focusStartedAt ?? Date(),
            endedAt: Date(),
            isCompleted: true,
            goal: goal
        )
        context.insert(session)

        if completeTask,
           let taskID = activeFocusTaskID,
           let task = tasks.first(where: { $0.id == taskID }),
           task.status != .done {
            task.status = .done
        }
        activeFocusTaskID = nil
        activeFocusTaskTitle = nil
        pendingAutoStartFocus = false

        Metrics.refreshAllGoals(goals, tasks: tasks)
        saveContext(context)
        focusElapsed = 0
        focusRemaining = focusMode.isCountUp ? 0 : focusTargetMinutes * 60
        focusStartedAt = nil

        stopWatchingLiveActivity()
        LiveActivityManager.endAll()
        NotificationScheduler.cancelFocusEnd()
        NotificationScheduler.notifyFocusCompleted(minutes: minutes, goalName: goal?.name)
        NotificationScheduler.reloadWidgets()
        refreshReminderBodies(context: context)
    }

    func abandonFocus() {
        resumeFocusAfterConfirmDismiss = false
        showFinishFocusConfirm = false
        pauseFocus(syncLiveActivity: false)
        focusElapsed = 0
        focusRemaining = focusMode.isCountUp ? 0 : focusTargetMinutes * 60
        focusStartedAt = nil
        activeFocusTaskID = nil
        activeFocusTaskTitle = nil
        pendingAutoStartFocus = false
        stopWatchingLiveActivity()
        LiveActivityManager.endAll()
        NotificationScheduler.cancelFocusEnd()
    }

    /// Align AppStore with Live Activity after returning from background / lock-screen intents.
    func reconcileFocusFromLiveActivityIfNeeded() {
        if let activity = Activity<FocusActivityAttributes>.activities.first {
            applyLiveActivityContent(activity.content.state, attributes: activity.attributes)
            startWatchingLiveActivity()
            return
        }
        reconcileFocusWallClockIfNeeded()
    }

    /// When Live Activity is unavailable, realign timer from wall clock while running.
    func reconcileFocusWallClockIfNeeded() {
        guard isFocusRunning, let started = focusStartedAt else { return }
        let elapsedSeconds = max(0, Int(Date().timeIntervalSince(started)))
        if focusMode.isCountUp {
            focusElapsed = elapsedSeconds
            return
        }
        let total = max(focusTargetMinutes, 1) * 60
        focusRemaining = max(0, total - elapsedSeconds)
        if focusRemaining <= 0 {
            requestFinishFocus(goals: focusTimerGoals)
        } else {
            rescheduleFocusEndNotification(goals: focusTimerGoals)
        }
    }

    /// Lock-screen End button: open confirm sheet on Focus tab.
    func consumePendingEndFocusFromLiveActivity(goals: [Goal]) {
        guard FocusLiveActivityBridge.pendingEndFocus else { return }
        FocusLiveActivityBridge.pendingEndFocus = false
        selectedTab = .focus
        reconcileFocusFromLiveActivityIfNeeded()
        requestFinishFocus(goals: goals)
    }

    private func startWatchingLiveActivity() {
        liveActivityWatchTask?.cancel()
        liveActivityWatchTask = Task { [weak self] in
            guard let activity = Activity<FocusActivityAttributes>.activities.first else { return }
            for await content in activity.contentUpdates {
                guard let self, !Task.isCancelled else { return }
                self.applyLiveActivityContent(content.state, attributes: activity.attributes)
            }
        }
    }

    private func stopWatchingLiveActivity() {
        liveActivityWatchTask?.cancel()
        liveActivityWatchTask = nil
    }

    private func applyLiveActivityContent(
        _ state: FocusActivityAttributes.ContentState,
        attributes: FocusActivityAttributes
    ) {
        guard !isApplyingLiveActivityState else { return }
        isApplyingLiveActivityState = true
        defer { isApplyingLiveActivityState = false }

        let seconds = state.displaySeconds(isCountUp: attributes.isCountUp)
        if attributes.isCountUp {
            focusElapsed = seconds
        } else {
            focusRemaining = seconds
        }

        if state.isRunning {
            if !isFocusRunning {
                isFocusRunning = true
                if focusStartedAt == nil {
                    focusStartedAt = Date()
                }
                startLocalFocusTimer()
                if !attributes.isCountUp {
                    let goal = focusLinkedGoal(in: focusTimerGoals)
                    scheduleFocusEndIfNeeded(goalName: goal?.name ?? state.goalName)
                }
            }
        } else if isFocusRunning {
            isFocusRunning = false
            timer?.cancel()
            timer = nil
            NotificationScheduler.cancelFocusEnd()
        }
    }

    /// Legacy path used when timer hits zero without sheet — auto finish and mark task done.
    func completeFocus(context: ModelContext, goals: [Goal], tasks: [TaskItem]) {
        finishFocus(completeTask: true, context: context, goals: goals, tasks: tasks)
    }

    func startFocusForTask(_ task: TaskItem, autoStart: Bool = true) {
        guard !task.status.isDoneLike else { return }
        if hasFocusProgress() {
            pendingInterruptFocusTaskID = task.id
            showInterruptFocusConfirm = true
            return
        }
        applyFocusTaskContext(task, autoStart: autoStart)
    }

    func confirmInterruptFocus(andStartPendingTask: Bool, allTasks: [TaskItem]) {
        showInterruptFocusConfirm = false
        let pendingID = pendingInterruptFocusTaskID
        pendingInterruptFocusTaskID = nil
        abandonFocus()
        if andStartPendingTask, let pendingID, let task = allTasks.first(where: { $0.id == pendingID }) {
            applyFocusTaskContext(task, autoStart: true)
        } else if pendingID == nil {
            activeFocusTaskID = nil
            activeFocusTaskTitle = nil
            selectedFocusGoalID = nil
            prepareFocusTimerForStart()
            pendingAutoStartFocus = true
            selectedTab = .focus
        }
    }

    func cancelInterruptFocus() {
        showInterruptFocusConfirm = false
        pendingInterruptFocusTaskID = nil
    }

    func requestAbandonFocus() {
        guard hasFocusProgress() else {
            abandonFocus()
            return
        }
        showAbandonFocusConfirm = true
    }

    func consumePendingAutoStartFocus(context: ModelContext, goals: [Goal]) {
        guard pendingAutoStartFocus else { return }
        pendingAutoStartFocus = false
        guard !isFocusRunning else { return }
        prepareFocusTimerForStart()
        startFocus(context: context, goals: goals)
    }

    func createGoal(
        name: String,
        emoji: String,
        category: String,
        days: Int,
        context: ModelContext
    ) -> String? {
        let activeCount = (try? context.fetch(FetchDescriptor<Goal>()))?.filter { !$0.isCompleted }.count ?? 0
        let freeLimit = ProEntitlement.freeActiveGoalLimit
        if !ProEntitlement.isUnlocked(.unlimitedGoals, isPro: isPro), activeCount >= freeLimit {
            return "免费版最多 \(freeLimit) 个进行中目标，升级 Pro 后可创建更多"
        }
        let hasPrimary = (try? context.fetch(FetchDescriptor<Goal>()))?.contains(where: { !$0.isCompleted && $0.isPrimary }) ?? false
        let goal = Goal(
            name: name,
            emoji: emoji,
            category: category,
            totalDays: days,
            currentDay: 1,
            weeklyRate: 0,
            isPrimary: !hasPrimary
        )
        context.insert(goal)
        saveContext(context)
        return nil
    }

    func createTask(
        title: String,
        minutes: Int,
        goal: Goal?,
        milestone: GoalMilestone? = nil,
        priority: Bool,
        scheduledDate: Date,
        endDate: Date? = nil,
        context: ModelContext
    ) -> String? {
        let resolvedMilestone = milestone ?? goal.flatMap { g in
            g.sortedMilestones.first(where: { !$0.isCompleted })
        }
        let (start, end) = clampTaskDates(
            start: scheduledDate,
            end: endDate ?? scheduledDate,
            to: resolvedMilestone
        )
        if let error = validateTaskDates(start: start, end: end, milestone: resolvedMilestone) {
            return error
        }
        let existing = (try? context.fetch(FetchDescriptor<TaskItem>()))?
            .filter { $0.spans(start) }
            .count ?? 0
        let task = TaskItem(
            title: title,
            durationMinutes: minutes,
            isPriority: priority,
            sortOrder: existing,
            scheduledDate: start,
            endDate: end,
            goal: goal,
            milestone: resolvedMilestone
        )
        context.insert(task)
        saveContext(context)
        NotificationScheduler.reloadWidgets()
        refreshReminderBodies(context: context)
        return nil
    }

    func updateTaskDates(
        _ task: TaskItem,
        start: Date,
        end: Date,
        milestone: GoalMilestone?,
        context: ModelContext
    ) -> String? {
        let (s, e) = clampTaskDates(start: start, end: end, to: milestone)
        if let error = validateTaskDates(start: s, end: e, milestone: milestone) {
            return error
        }
        task.setDateRange(start: s, end: e)
        saveContext(context)
        NotificationScheduler.reloadWidgets()
        refreshReminderBodies(context: context)
        return nil
    }

    func refreshReminderBodies(context: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let pendingTasks = tasks.filter {
            $0.spans(today) && $0.status != .done && $0.status != .skipped
        }.count
        let pendingHabits = habits.filter { $0.state != .done }.count
        NotificationScheduler.rescheduleFromDefaults(
            pendingTaskCount: pendingTasks,
            pendingHabitCount: pendingHabits
        )
    }

    private static let refreshMinimumNanoseconds: UInt64 = 550_000_000

    @MainActor
    func refreshTodayPage(context: ModelContext, goals: [Goal], tasks: [TaskItem]) async {
        Metrics.refreshAllGoals(goals, tasks: tasks)
        refreshReminderBodies(context: context)
        NotificationScheduler.reloadWidgets()
        refreshWidgetGuideVisibility()
        try? await Task.sleep(nanoseconds: Self.refreshMinimumNanoseconds)
    }

    @MainActor
    func refreshGoalsPage(context: ModelContext, goals: [Goal], tasks: [TaskItem]) async {
        Metrics.refreshAllGoals(goals, tasks: tasks)
        refreshReminderBodies(context: context)
        NotificationScheduler.reloadWidgets()
        try? await Task.sleep(nanoseconds: Self.refreshMinimumNanoseconds)
    }

    @MainActor
    func refreshDataPage(context: ModelContext, goals: [Goal], tasks: [TaskItem]) async {
        Metrics.refreshAllGoals(goals, tasks: tasks)
        refreshReminderBodies(context: context)
        NotificationScheduler.reloadWidgets()
        try? await Task.sleep(nanoseconds: Self.refreshMinimumNanoseconds)
    }
}
