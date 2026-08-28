import SwiftUI
import SwiftData

struct TaskDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore

    let task: TaskItem
    var goals: [Goal]
    var allTasks: [TaskItem]

    @State private var notes: String = ""
    @State private var reminderMinutes: Int = 0
    @State private var selectedGoalID: UUID?
    @State private var selectedMilestoneID: UUID?
    @State private var taskStartDate = Calendar.current.startOfDay(for: Date())
    @State private var taskEndDate = Calendar.current.startOfDay(for: Date())
    @State private var dateError: String?
    @State private var didSave = false
    @State private var showDeleteConfirm = false
    @State private var showSkipConfirm = false

    private var isDoneLike: Bool { task.status.isDoneLike }
    private var isSkipped: Bool { task.status == .skipped }
    private var isDone: Bool { task.status == .done }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    headerCard
                    scheduleCard
                    associationCard
                    notesCard
                    reminderCard
                    actionsCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, GSSpacing.page)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(PageBackground())
            .navigationTitle("任务详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        saveAndDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                notes = task.notes
                reminderMinutes = task.reminderMinutes ?? 0
                selectedGoalID = task.goal?.id
                selectedMilestoneID = task.milestoneID
                taskStartDate = Calendar.current.startOfDay(for: task.scheduledDate)
                taskEndDate = Calendar.current.startOfDay(for: task.endDate)
                didSave = false
            }
            .onDisappear {
                if !didSave {
                    _ = saveMeta()
                }
            }
            .confirmationDialog("确定跳过此任务？", isPresented: $showSkipConfirm, titleVisibility: .visible) {
                Button("跳过", role: .destructive) {
                    didSave = true
                    store.skipTask(task, context: context, goals: goals, allTasks: allTasks)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("跳过后任务会从今日列表隐藏，可在「已跳过」分区恢复。")
            }
            .confirmationDialog("确定删除此任务？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除任务", role: .destructive) {
                    didSave = true
                    store.deleteTask(task, context: context)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后不可恢复。")
            }
        }
    }

    private var selectedGoal: Goal? {
        goals.first(where: { $0.id == selectedGoalID })
    }

    private var previewMilestone: GoalMilestone? {
        if let selectedMilestoneID,
           let milestone = selectedGoal?.sortedMilestones.first(where: { $0.id == selectedMilestoneID }) {
            return milestone
        }
        return selectedGoal?.sortedMilestones.first(where: { !$0.isCompleted })
    }

    private var constrainingMilestone: GoalMilestone? {
        if let selectedMilestoneID,
           let milestone = selectedGoal?.sortedMilestones.first(where: { $0.id == selectedMilestoneID }) {
            return milestone
        }
        if selectedMilestoneID == nil {
            return selectedGoal?.sortedMilestones.first(where: { !$0.isCompleted })
        }
        return nil
    }

    private var taskDateBounds: ClosedRange<Date>? {
        constrainingMilestone?.dateRange
    }

    private var taskEndDateRange: ClosedRange<Date>? {
        if let bounds = taskDateBounds {
            let lower = max(taskStartDate, bounds.lowerBound)
            return lower...bounds.upperBound
        }
        return taskStartDate...Date.distantFuture
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(task.title)
                .font(GSFont.semibold(GSFont.hero))
                .foregroundStyle(GSColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    CategoryTag(
                        text: "\(task.durationMinutes) 分钟",
                        color: GSColor.textSecondary,
                        background: GSColor.bgTertiary,
                        compact: true
                    )
                    CategoryTag(
                        text: GSFormat.dateRangeLabel(start: taskStartDate, end: taskEndDate),
                        color: GSColor.textSecondary,
                        background: GSColor.bgTertiary,
                        compact: true
                    )
                }
                CategoryTag(
                    text: statusText,
                    color: statusTagColor,
                    background: statusTagBackground,
                    compact: true
                )
            }

            if selectedGoal != nil || previewMilestone != nil {
                HStack(spacing: 6) {
                    if let goal = selectedGoal {
                        CategoryTag(
                            text: "\(goal.emoji) \(goal.name)",
                            color: Color(hex: goal.accentHex),
                            background: Color(hex: goal.accentHex).opacity(0.12)
                        )
                    }
                    if let milestone = previewMilestone {
                        CategoryTag(
                            text: milestone.title,
                            color: GSColor.textSecondary,
                            background: GSColor.bgTertiary
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "时间安排")
            DatePickerFormRow(
                title: "开始日期",
                selection: $taskStartDate,
                range: taskDateBounds
            )
            .onChange(of: taskStartDate) { _, newValue in
                if taskEndDate < newValue { taskEndDate = newValue }
                clampDates()
                dateError = nil
            }
            DatePickerFormRow(
                title: "结束日期",
                selection: $taskEndDate,
                range: taskEndDateRange
            )
            .onChange(of: taskEndDate) { _, _ in
                clampDates()
                dateError = nil
            }
            if let range = taskDateBounds {
                Text("需在阶段范围内：\(GSFormat.dateRangeLabel(start: range.lowerBound, end: range.upperBound))")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
            }
            if let dateError {
                Text(dateError)
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var associationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "关联信息")

            MenuPickerFormRow(title: "关联目标", selection: $selectedGoalID) {
                Text("无").tag(UUID?.none)
                ForEach(goals, id: \.id) { goal in
                    Text("\(goal.emoji) \(goal.name)")
                        .lineLimit(1)
                        .tag(Optional(goal.id))
                }
            }
            .onChange(of: selectedGoalID) { _, newValue in
                syncMilestoneSelection(for: newValue)
            }

            if let goal = selectedGoal, !goal.sortedMilestones.isEmpty {
                MenuPickerFormRow(title: "关联阶段", selection: $selectedMilestoneID) {
                    Text("自动（当前阶段）")
                        .lineLimit(1)
                        .tag(UUID?.none)
                    ForEach(goal.sortedMilestones, id: \.id) { milestone in
                        Text(milestone.title)
                            .lineLimit(1)
                            .tag(Optional(milestone.id))
                    }
                }
                .onChange(of: selectedMilestoneID) { _, _ in
                    clampDates()
                }
            } else if selectedGoal != nil {
                DetailFormRow(label: "关联阶段") {
                    Text("暂无阶段")
                        .font(GSFont.semibold(GSFont.md))
                        .foregroundStyle(GSColor.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "备注")
            TextField("补充说明（可选）", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(GSTextFieldStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "提醒")
            DetailFormRow(label: "提醒") {
                HStack(spacing: 8) {
                    Text(reminderMinutes == 0 ? "不提醒" : "\(reminderMinutes) 分钟后")
                        .font(GSFont.semibold(GSFont.lg))
                        .foregroundStyle(GSColor.textPrimary)
                        .lineLimit(1)
                    Stepper("", value: $reminderMinutes, in: 0...180, step: 5)
                        .labelsHidden()
                        .fixedSize()
                }
            }
            Text("仅作备注，不会发送系统通知")
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var actionsCard: some View {
        VStack(spacing: 10) {
            if isSkipped {
                PrimaryButton(title: "取消跳过", icon: .check) {
                    didSave = true
                    store.unskipTask(task, context: context, goals: goals, allTasks: allTasks)
                    dismiss()
                }
            } else {
                PrimaryButton(title: isDone ? "标为未完成" : "完成任务", icon: .check) {
                    _ = saveMeta()
                    didSave = true
                    store.toggleTask(task, context: context, goals: goals, allTasks: allTasks)
                    dismiss()
                }
            }

            if !isDoneLike {
                PrimaryButton(title: "开始专注", icon: .play, filled: false) {
                    _ = saveMeta()
                    didSave = true
                    dismiss()
                    store.startFocusForTask(task)
                }
            }

            if !isDoneLike {
                HStack(spacing: 10) {
                    OutlineActionButton(title: "延后到明天") {
                        didSave = true
                        store.deferTask(task, context: context)
                        dismiss()
                    }
                    OutlineActionButton(title: task.isPinned ? "取消置顶" : "置顶") {
                        store.pinTask(task, context: context)
                    }
                }
                HStack(spacing: 10) {
                    OutlineActionButton(title: task.isLockCandidate ? "取消锁屏候选" : "设为锁屏候选") {
                        store.setLockCandidate(task, context: context)
                    }
                    if !isSkipped {
                        OutlineActionButton(title: "跳过") {
                            showSkipConfirm = true
                        }
                    }
                }
            }

            DestructiveActionButton(title: "删除任务") {
                showDeleteConfirm = true
            }
        }
        .frame(maxWidth: .infinity)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var statusText: String {
        switch task.status {
        case .todo: return "待办"
        case .inProgress: return "进行中"
        case .done: return "已完成"
        case .skipped: return "已跳过"
        }
    }

    private var statusTagColor: Color {
        switch task.status {
        case .todo, .inProgress: return GSColor.brand
        case .done: return GSColor.successDark
        case .skipped: return GSColor.textSecondary
        }
    }

    private var statusTagBackground: Color {
        switch task.status {
        case .todo, .inProgress: return GSColor.brandLight
        case .done: return GSColor.successLight
        case .skipped: return GSColor.bgTertiary
        }
    }

    private func syncMilestoneSelection(for goalID: UUID?) {
        guard let goal = goals.first(where: { $0.id == goalID }) else {
            selectedMilestoneID = nil
            return
        }
        selectedMilestoneID = goal.sortedMilestones.first(where: { !$0.isCompleted })?.id
        clampDates()
    }

    private func clampDates() {
        let (start, end) = store.clampTaskDates(
            start: taskStartDate,
            end: taskEndDate,
            to: constrainingMilestone
        )
        taskStartDate = start
        taskEndDate = end
    }

    private func saveAndDismiss() {
        guard saveMeta() else { return }
        didSave = true
        dismiss()
    }

    @discardableResult
    private func saveMeta() -> Bool {
        let goal = goals.first(where: { $0.id == selectedGoalID })
        let milestone = goal?.sortedMilestones.first(where: { $0.id == selectedMilestoneID })
        if let error = store.updateTaskDates(
            task,
            start: taskStartDate,
            end: taskEndDate,
            milestone: milestone ?? constrainingMilestone,
            context: context
        ) {
            dateError = error
            return false
        }
        store.updateTaskNotes(task, notes: notes, context: context)
        store.updateTaskReminder(task, minutes: reminderMinutes == 0 ? nil : reminderMinutes, context: context)
        store.updateTaskAssociation(task, goal: goal, milestone: milestone, context: context)
        dateError = nil
        return true
    }
}
