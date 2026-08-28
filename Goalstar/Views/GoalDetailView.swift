import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore

    let goal: Goal
    var allGoals: [Goal]
    var allTasks: [TaskItem]
    var sessions: [FocusSession]

    @State private var showArchiveConfirm = false
    @State private var showDeleteConfirm = false
    @State private var detailTaskID: UUID?
    @State private var showAllTasks = false
    @State private var showCreateMilestone = false
    @State private var editingMilestone: GoalMilestone?
    @State private var milestoneToDelete: GoalMilestone?

    private var goalTasks: [TaskItem] {
        allTasks
            .filter { $0.goal?.id == goal.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var openTasks: [TaskItem] {
        goalTasks.filter { $0.status != .done && $0.status != .skipped }
    }

    private var visibleTasks: [TaskItem] {
        showAllTasks ? openTasks : Array(openTasks.prefix(5))
    }

    private var detailTask: TaskItem? {
        guard let detailTaskID else { return nil }
        return allTasks.first { $0.id == detailTaskID }
    }

    private var recentSessions: [FocusSession] {
        sessions
            .filter { $0.goal?.id == goal.id && $0.isCompleted }
            .prefix(3)
            .map { $0 }
    }

    private var isArchived: Bool { goal.isCompleted }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    headerCard
                    milestonesCard
                    tasksCard
                    if !recentSessions.isEmpty {
                        sessionsCard
                    }
                    actionsCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, GSSpacing.page)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(PageBackground())
            .navigationTitle("目标详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .confirmationDialog("归档后目标将移至已归档列表", isPresented: $showArchiveConfirm, titleVisibility: .visible) {
                Button("归档目标", role: .destructive) {
                    store.archiveGoal(goal, context: context)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("删除后不可恢复，关联任务与阶段将一并删除", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除目标", role: .destructive) {
                    store.deleteGoal(goal, context: context)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("确定删除此阶段？", isPresented: Binding(
                get: { milestoneToDelete != nil },
                set: { if !$0 { milestoneToDelete = nil } }
            ), titleVisibility: .visible) {
                if let milestone = milestoneToDelete {
                    Button("删除阶段", role: .destructive) {
                        store.deleteMilestone(milestone, context: context)
                        milestoneToDelete = nil
                    }
                }
                Button("取消", role: .cancel) {
                    milestoneToDelete = nil
                }
            } message: {
                Text("关联任务的阶段引用将被清空。")
            }
            .sheet(isPresented: Binding(
                get: { detailTaskID != nil && detailTask != nil },
                set: { if !$0 { detailTaskID = nil } }
            )) {
                if let task = detailTask {
                    TaskDetailSheet(
                        task: task,
                        goals: allGoals.filter { !$0.isCompleted },
                        allTasks: allTasks
                    )
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showCreateMilestone) {
                CreateMilestoneSheet(goal: goal)
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $editingMilestone) { milestone in
                CreateMilestoneSheet(goal: goal, milestone: milestone)
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: detailTaskID) { _, id in
                if let id, allTasks.first(where: { $0.id == id }) == nil {
                    detailTaskID = nil
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(goal.emoji)
                    .font(.system(size: 28))
                Text(goal.name)
                    .font(GSFont.semibold(GSFont.hero))
                    .foregroundStyle(GSColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if goal.isPrimary {
                    CategoryTag(
                        text: "主目标",
                        color: GSColor.brand,
                        background: GSColor.brandLight
                    )
                }
                if isArchived {
                    CategoryTag(
                        text: "已归档",
                        color: GSColor.textSecondary,
                        background: GSColor.bgTertiary
                    )
                }
            }
            CategoryTag(
                text: goal.category,
                color: Color(hex: goal.accentHex),
                background: Color(hex: goal.accentHex).opacity(0.12)
            )
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(GSColor.bgTertiary).frame(height: 8)
                    Capsule()
                        .fill(Color(hex: goal.accentHex))
                        .frame(width: max(8, geo.size.width * goal.progress), height: 8)
                }
            }
            .frame(height: 8)
            HStack {
                Text("进度 \(Int(goal.progress * 100))% · 第 \(goal.currentDay)/\(goal.totalDays) 天")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
                Spacer()
                Text("剩余 \(goal.remainingDays) 天")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.brand)
            }
            if !goal.goalDescription.isEmpty {
                Text(goal.goalDescription)
                    .font(GSFont.semibold(GSFont.base))
                    .foregroundStyle(GSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var milestonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "阶段计划")
            if goal.sortedMilestones.isEmpty {
                EmptyStateCard(
                    icon: .target,
                    title: "暂无阶段",
                    message: "添加阶段，把大目标拆成可推进的步骤",
                    compact: true,
                    embedded: true
                )
            }
            ForEach(goal.sortedMilestones, id: \.id) { milestone in
                HStack(spacing: 10) {
                    Button {
                        guard !isArchived else { return }
                        store.toggleMilestone(milestone, context: context)
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(milestone.isCompleted ? GSColor.brand : GSColor.border, lineWidth: 2)
                                .background(Circle().fill(milestone.isCompleted ? GSColor.brand : Color.clear))
                            if milestone.isCompleted {
                                GSIcon(name: .check, size: 10, color: .white, lineWidth: 2)
                            }
                        }
                        .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .disabled(isArchived)
                    .opacity(isArchived ? 0.55 : 1)

                    Button {
                        guard !isArchived else { return }
                        editingMilestone = milestone
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(milestone.title)
                                .font(GSFont.semibold(GSFont.lg))
                                .foregroundStyle(milestone.isCompleted ? GSColor.textSecondary : GSColor.textPrimary)
                                .strikethrough(milestone.isCompleted, color: GSColor.textSecondary)
                            if let rangeText = GSFormat.milestoneRangeLabel(milestone) {
                                Text(rangeText)
                                    .font(GSFont.semibold(GSFont.md))
                                    .foregroundStyle(GSColor.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(isArchived)

                    if !isArchived {
                        Button {
                            editingMilestone = milestone
                        } label: {
                            Text("编辑")
                                .font(GSFont.semibold(GSFont.sm))
                                .foregroundStyle(GSColor.brand)
                        }
                        .buttonStyle(.plain)
                        Button {
                            milestoneToDelete = milestone
                        } label: {
                            GSIcon(name: .circleX, size: 14, color: GSColor.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !isArchived {
                PrimaryButton(title: "添加阶段", icon: .plus, filled: false) {
                    showCreateMilestone = true
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var tasksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "关联任务")
                Spacer()
                Text("\(openTasks.count) 待完成")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
            }
            if openTasks.isEmpty {
                EmptyStateCard(
                    icon: .checkCircle,
                    title: "暂无未完成任务",
                    message: "为目标添加任务，开始推进",
                    compact: true,
                    embedded: true
                )
            } else {
                ForEach(visibleTasks, id: \.id) { task in
                    Button {
                        detailTaskID = task.id
                    } label: {
                        DetailListRow(
                            title: task.title,
                            subtitle: taskDateSubtitle(task),
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }
                if openTasks.count > 5 {
                    Button {
                        showAllTasks.toggle()
                    } label: {
                        Text(showAllTasks ? "收起" : "查看全部 \(openTasks.count) 条")
                            .font(GSFont.semibold(GSFont.base))
                            .foregroundStyle(GSColor.brand)
                    }
                    .buttonStyle(.plain)
                }
            }
            if !isArchived {
                PrimaryButton(title: "添加任务", icon: .plus, filled: false) {
                    dismiss()
                    store.openCreateSheetAfterDismiss(mode: .task, preferredGoalID: goal.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private func taskDateSubtitle(_ task: TaskItem) -> String {
        let range = GSFormat.dateRangeLabel(start: task.scheduledDate, end: task.endDate)
        return "\(range) · \(task.durationMinutes)m"
    }

    private var sessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "最近专注")
            ForEach(recentSessions, id: \.id) { session in
                DetailListRow(
                    title: "\(session.mode.title) · \(session.minutes) 分钟",
                    subtitle: GSFormat.shortDate(session.startedAt)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var actionsCard: some View {
        VStack(spacing: 10) {
            if isArchived {
                PrimaryButton(title: "取消归档") {
                    store.unarchiveGoal(goal, context: context)
                }
                DestructiveActionButton(title: "删除目标") {
                    showDeleteConfirm = true
                }
            } else {
                if !goal.isPrimary {
                    PrimaryButton(title: "设为主要目标") {
                        store.setPrimaryGoal(goal, context: context, goals: allGoals)
                    }
                }
                DestructiveActionButton(title: "归档目标") {
                    showArchiveConfirm = true
                }
            }
        }
        .frame(maxWidth: .infinity)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }
}

extension GoalMilestone: Identifiable {}
