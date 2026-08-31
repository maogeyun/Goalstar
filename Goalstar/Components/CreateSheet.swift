import SwiftUI
import SwiftData

struct CreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore
    @Query(filter: #Predicate<Goal> { !$0.isCompleted }, sort: \Goal.createdAt)
    private var goals: [Goal]

    @State private var mode: CreateFormMode = .task
    @State private var title = ""
    @State private var minutes = 25
    @State private var days = 30
    @State private var category = "语言学习"
    @State private var emoji = "📖"
    @State private var selectedGoalID: UUID?
    @State private var selectedMilestoneID: UUID?
    @State private var priority = false
    @State private var taskStartDate = Calendar.current.startOfDay(for: Date())
    @State private var taskEndDate = Calendar.current.startOfDay(for: Date())
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var titleError: String?

    private let goalPresets: [(String, String, String)] = [
        ("语言学习", "📖", "系统学习英语"),
        ("工作项目", "💼", "推进本周关键交付"),
        ("健康运动", "💪", "每周三次力量训练"),
        ("生活习惯", "🌱", "早睡早起 30 天")
    ]

    private var lockToGoalMode: Bool { goals.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    if !lockToGoalMode {
                        Picker("", selection: $mode) {
                            ForEach(CreateFormMode.allCases) { m in
                                Text(m.title).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(GSColor.brand)
                    }

                    if mode == .task && !lockToGoalMode {
                        taskForm
                    } else {
                        goalForm
                    }

                    if let titleError {
                        Text(titleError)
                            .font(GSFont.semibold(GSFont.lg))
                            .foregroundStyle(GSColor.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if titleError == ProEntitlement.freeGoalLimitMessage {
                            OutlineActionButton(title: "升级 Pro") {
                                store.requestProPaywall()
                            }
                        }
                    }

                    PrimaryButton(title: "保存") {
                        save()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, GSSpacing.page)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(PageBackground())
            .navigationTitle(lockToGoalMode ? CreateFormMode.goal.title : mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        store.clearCreateSheetPreferences()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if lockToGoalMode || store.createSheetMode == .goal {
                    mode = .goal
                } else {
                    mode = store.createSheetMode
                }
                if let preferred = store.createSheetPreferredGoalID {
                    selectedGoalID = preferred
                } else {
                    selectedGoalID = goals.first(where: \.isPrimary)?.id ?? goals.first?.id
                }
                let day = store.createSheetScheduledDate
                taskStartDate = day
                taskEndDate = day
                syncMilestoneSelection(for: selectedGoalID)
                clampTaskDatesToSelectedMilestone()
            }
        }
    }

    private var selectedGoal: Goal? {
        goals.first(where: { $0.id == selectedGoalID })
    }

    private var selectedMilestone: GoalMilestone? {
        guard let selectedMilestoneID else { return nil }
        return selectedGoal?.sortedMilestones.first(where: { $0.id == selectedMilestoneID })
    }

    /// Milestone used for date constraints (explicit pick, or auto current when nil).
    private var constrainingMilestone: GoalMilestone? {
        if let selectedMilestone { return selectedMilestone }
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

    private func syncMilestoneSelection(for goalID: UUID?) {
        guard let goal = goals.first(where: { $0.id == goalID }) else {
            selectedMilestoneID = nil
            return
        }
        let current = goal.sortedMilestones.first(where: { !$0.isCompleted })
        selectedMilestoneID = current?.id
        clampTaskDatesToSelectedMilestone()
    }

    private func clampTaskDatesToSelectedMilestone() {
        let (start, end) = store.clampTaskDates(
            start: taskStartDate,
            end: taskEndDate,
            to: constrainingMilestone
        )
        taskStartDate = start
        taskEndDate = end
    }

    private var taskForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                DetailFieldLabel(text: "任务名称")
                TextField("例如：完成英语阅读", text: $title)
                    .textFieldStyle(GSTextFieldStyle())
                    .onChange(of: title) { _, _ in titleError = nil }
            }

            DetailFormRow(label: "时长（分钟）") {
                HStack(spacing: 8) {
                    Text("\(minutes) min")
                        .font(GSFont.semibold(GSFont.lg))
                        .foregroundStyle(GSColor.textPrimary)
                        .lineLimit(1)
                    Stepper("", value: $minutes, in: 5...120, step: 5)
                        .labelsHidden()
                        .fixedSize()
                }
            }

            DatePickerFormRow(
                title: "开始日期",
                selection: $taskStartDate,
                range: taskDateBounds
            )
            .onChange(of: taskStartDate) { _, newValue in
                if taskEndDate < newValue { taskEndDate = newValue }
                clampTaskDatesToSelectedMilestone()
                titleError = nil
            }

            DatePickerFormRow(
                title: "结束日期",
                selection: $taskEndDate,
                range: taskEndDateRange
            )
            .onChange(of: taskEndDate) { _, _ in
                clampTaskDatesToSelectedMilestone()
                titleError = nil
            }

            if let range = taskDateBounds {
                Text("需在阶段范围内：\(GSFormat.dateRangeLabel(start: range.lowerBound, end: range.upperBound))")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
            }

            MenuPickerFormRow(title: "关联目标", selection: $selectedGoalID) {
                Text("无").tag(UUID?.none)
                ForEach(goals, id: \.id) { g in
                    Text("\(g.emoji) \(g.name)")
                        .lineLimit(1)
                        .tag(Optional(g.id))
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
                    clampTaskDatesToSelectedMilestone()
                }
            }

            DetailFormRow(label: "设为优先") {
                Toggle("", isOn: $priority)
                    .labelsHidden()
                    .tint(GSColor.brand)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var goalForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                DetailFieldLabel(text: "类型预设")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(goalPresets, id: \.0) { preset in
                            Button {
                                category = preset.0
                                emoji = preset.1
                                if title.isEmpty { title = preset.2 }
                            } label: {
                                CategoryTag(
                                    text: "\(preset.1) \(preset.0)",
                                    color: category == preset.0 ? GSColor.brand : GSColor.textPrimary,
                                    background: category == preset.0 ? GSColor.brandLight : GSColor.bgTertiary
                                )
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                DetailFieldLabel(text: "目标名称")
                TextField("例如：系统学习英语", text: $title)
                    .textFieldStyle(GSTextFieldStyle())
                    .onChange(of: title) { _, _ in titleError = nil }
            }

            VStack(alignment: .leading, spacing: 8) {
                DetailFieldLabel(text: "分类")
                TextField("语言学习", text: $category)
                    .textFieldStyle(GSTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                DetailFieldLabel(text: "Emoji")
                TextField("📖", text: $emoji)
                    .textFieldStyle(GSTextFieldStyle())
            }

            DetailFormRow(label: "计划天数") {
                HStack(spacing: 8) {
                    Text("\(days) 天")
                        .font(GSFont.semibold(GSFont.lg))
                        .foregroundStyle(GSColor.textPrimary)
                        .lineLimit(1)
                    Stepper("", value: Binding(
                        get: { days },
                        set: { newValue in
                            days = newValue
                            endDate = Calendar.current.date(byAdding: .day, value: newValue, to: Date()) ?? endDate
                        }
                    ), in: 7...365, step: 1)
                    .labelsHidden()
                    .fixedSize()
                }
            }

            DatePickerFormRow(
                title: "截止日期（可选）",
                selection: Binding(
                    get: { endDate },
                    set: { newValue in
                        endDate = newValue
                        let start = Calendar.current.startOfDay(for: Date())
                        let end = Calendar.current.startOfDay(for: newValue)
                        days = max(7, Calendar.current.dateComponents([.day], from: start, to: end).day ?? days)
                    }
                )
            )

            Text("衡量方式：默认按任务完成推进")
                .font(GSFont.semibold(GSFont.base, relativeTo: .caption))
                .foregroundStyle(GSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            titleError = mode == .goal || lockToGoalMode ? "请输入目标名称" : "请输入任务名称"
            return
        }
        titleError = nil
        if mode == .task && !lockToGoalMode {
            let goal = goals.first(where: { $0.id == selectedGoalID })
            let milestone = goal?.sortedMilestones.first(where: { $0.id == selectedMilestoneID })
            if let error = store.createTask(
                title: trimmed,
                minutes: minutes,
                goal: goal,
                milestone: milestone,
                priority: priority,
                scheduledDate: taskStartDate,
                endDate: taskEndDate,
                context: context
            ) {
                titleError = error
                return
            }
        } else {
            if let error = store.createGoal(
                name: trimmed,
                emoji: emoji.isEmpty ? "🎯" : emoji,
                category: category.isEmpty ? "综合" : category,
                days: days,
                context: context
            ) {
                titleError = error
                return
            }
        }
        store.clearCreateSheetPreferences()
        dismiss()
    }
}

struct GSTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(12)
            .background(GSColor.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous))
            .font(GSFont.semibold(GSFont.xl))
            .foregroundStyle(GSColor.textPrimary)
    }
}

struct TomorrowPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]

    private var tomorrowTasks: [TaskItem] {
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) else {
            return []
        }
        return allTasks.filter { $0.spans(tomorrow) }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: GSSpacing.lg) {
                if tomorrowTasks.isEmpty {
                    EmptyStateCard(
                        icon: .star,
                        title: "明天还没有安排",
                        message: "今晚可以先规划明天的三件事",
                        actionTitle: "添加任务"
                    ) {
                        let cal = Calendar.current
                        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
                        dismiss()
                        store.openCreateSheetAfterDismiss(scheduledDate: tomorrow)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "明日任务")
                            ForEach(tomorrowTasks, id: \.id) { task in
                                HStack(spacing: 12) {
                                    Circle()
                                        .stroke(GSColor.border, lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(GSFont.semibold(GSFont.lg))
                                            .foregroundStyle(GSColor.textPrimary)
                                        Text("\(task.durationMinutes) 分钟")
                                            .font(GSFont.semibold(GSFont.sm))
                                            .foregroundStyle(GSColor.textSecondary)
                                    }
                                    Spacer()
                                }
                                .gsCard(radius: GSRadius.card, padding: 14)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, GSSpacing.page)
            .padding(.vertical, 16)
            .background(PageBackground())
            .navigationTitle("明日预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
