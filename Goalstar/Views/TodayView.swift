import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore

    @Query(filter: #Predicate<Goal> { !$0.isCompleted }, sort: \Goal.createdAt)
    private var activeGoals: [Goal]

    @Query(sort: \TaskItem.sortOrder)
    private var allTasks: [TaskItem]

    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]

    @State private var detailTaskID: UUID?
    @State private var widgetBannerHiddenThisSession = false
    @State private var taskToDelete: TaskItem?
    @State private var isRefreshing = false

    private var rankedToday: [TaskItem] { TodayTaskRanking.ranked(allTasks) }
    private var pendingTasks: [TaskItem] {
        rankedToday.filter { $0.status != .done && $0.status != .skipped }
    }
    private var completedTasks: [TaskItem] {
        rankedToday.filter { $0.status == .done }
    }
    private var skippedTasks: [TaskItem] {
        rankedToday.filter { $0.status == .skipped }
    }
    private var actionable: [TaskItem] { rankedToday.filter { $0.status != .skipped } }

    private var completedCount: Int { completedTasks.count }
    private var allComplete: Bool {
        !actionable.isEmpty && pendingTasks.isEmpty
    }
    private var noGoals: Bool { activeGoals.isEmpty }
    private var hasGoalsNoTasks: Bool { !activeGoals.isEmpty && rankedToday.filter { $0.status != .skipped }.isEmpty }

    private var detailTask: TaskItem? {
        guard let detailTaskID else { return nil }
        return allTasks.first { $0.id == detailTaskID }
    }

    private var todayFocusMinutes: Int {
        sessions
            .filter { Calendar.current.isDateInToday($0.startedAt) && $0.isCompleted }
            .reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PageBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    if isRefreshing {
                        TodayPageSkeleton()
                    } else {
                        GreetingBar(
                            title: "\(GSFormat.greeting())，\(store.userName)",
                            subtitle: GSFormat.dateLine()
                        )

                        if noGoals {
                            emptyNoGoals
                        } else if hasGoalsNoTasks {
                            emptyNoTasks
                        } else if allComplete {
                            completeState
                        } else {
                            mainState
                        }
                    }
                }
                .padding(.horizontal, GSSpacing.page)
                .padding(.top, 8)
                .padding(.bottom, GSSpacing.tabContentBottomWithFAB)
            }
            .skeletonRefreshable(isRefreshing: $isRefreshing) {
                await store.refreshTodayPage(context: context, goals: activeGoals, tasks: allTasks)
            }

            if !noGoals {
                FABButton { store.openCreateSheet() }
                    .padding(.trailing, GSSpacing.page)
                    .padding(.bottom, GSSpacing.page)
            }
        }
        .onAppear {
            store.refreshWidgetGuideVisibility()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            store.refreshWidgetGuideVisibility()
        }
        .sheet(isPresented: Binding(
            get: { detailTaskID != nil && detailTask != nil },
            set: { if !$0 { detailTaskID = nil } }
        )) {
            if let task = detailTask {
                TaskDetailSheet(task: task, goals: activeGoals, allTasks: allTasks)
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
            }
        }
        .onChange(of: detailTaskID) { _, id in
            if let id, allTasks.first(where: { $0.id == id }) == nil {
                detailTaskID = nil
            }
        }
        .confirmationDialog("确定删除此任务？", isPresented: Binding(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        ), titleVisibility: .visible) {
            if let task = taskToDelete {
                Button("删除任务", role: .destructive) {
                    store.deleteTask(task, context: context)
                    taskToDelete = nil
                }
            }
            Button("取消", role: .cancel) {
                taskToDelete = nil
            }
        } message: {
            Text("删除后不可恢复。")
        }
    }

    // MARK: - States

    private var emptyNoGoals: some View {
        EmptyStateCard(
            icon: .star,
            title: "还没有目标",
            message: "创建第一个目标，开始绘制你的星图",
            actionTitle: "创建我的第一个目标"
        ) {
            store.openCreateSheet(mode: .goal)
        }
        .padding(.top, 80)
    }

    private var emptyNoTasks: some View {
        VStack(alignment: .leading, spacing: GSSpacing.lg) {
            if !store.widgetGuideDismissed && !widgetBannerHiddenThisSession {
                widgetPromoBanner
            }
            progressCard
            EmptyStateCard(
                icon: .checkCircle,
                title: "今天还没有任务",
                message: "为目标添加今日任务，开始推进",
                actionTitle: "添加今日任务"
            ) {
                store.openCreateSheet(mode: .task)
            }
        }
    }

    private var completeState: some View {
        VStack(alignment: .leading, spacing: GSSpacing.lg) {
            progressCard
            celebrationCard
            if !completedTasks.isEmpty {
                completedTasksSection
            }
        }
    }

    private var mainState: some View {
        VStack(alignment: .leading, spacing: GSSpacing.lg) {
            if !store.widgetGuideDismissed && !widgetBannerHiddenThisSession {
                widgetPromoBanner
            }
            progressCard
            if !pendingTasks.isEmpty {
                pendingTasksSection
            }
            if !skippedTasks.isEmpty {
                skippedTasksSection
            }
            if !completedTasks.isEmpty {
                completedTasksSection
            }
        }
    }

    // MARK: - Sections

    private var progressCard: some View {
        let total = max(actionable.count, 1)
        let rate = Double(completedCount) / Double(total)
        return HStack(alignment: .center, spacing: 20) {
            ProgressRing(
                progress: actionable.isEmpty ? 0 : rate,
                size: 72,
                centerText: "\(completedCount) / \(actionable.count)"
            )
            VStack(alignment: .leading, spacing: 8) {
                Text(allComplete ? "今天的星图已点亮完成" : "星图绘制进度已达 \(Int(rate * 100))%")
                    .font(GSFont.semibold(GSFont.xl))
                    .foregroundStyle(GSColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    MetricChip(
                        icon: .clock,
                        text: GSFormat.focusChip(todayFocusMinutes),
                        tint: GSColor.brand,
                        background: GSColor.brandLight
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var pendingTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "今日任务", trailing: "\(pendingTasks.count)")
            LazyVStack(spacing: 8) {
                ForEach(pendingTasks, id: \.id) { task in
                    taskRow(task)
                }
            }
        }
    }

    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "已完成", trailing: "\(completedTasks.count)")
            LazyVStack(spacing: 8) {
                ForEach(completedTasks, id: \.id) { task in
                    taskRow(task)
                }
            }
        }
    }

    private var skippedTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "已跳过", trailing: "\(skippedTasks.count)")
            LazyVStack(spacing: 8) {
                ForEach(skippedTasks, id: \.id) { task in
                    taskRow(task)
                }
            }
        }
    }

    @ViewBuilder
    private func taskRow(_ task: TaskItem) -> some View {
        TaskCardView(
            task: task,
            onToggle: {
                guard task.status != .skipped else { return }
                store.toggleTask(task, context: context, goals: activeGoals, allTasks: allTasks)
            },
            onPlay: {
                guard !task.status.isDoneLike else { return }
                store.markInProgress(task, context: context)
                store.startFocusForTask(task)
            },
            onTap: { detailTaskID = task.id }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            if task.status != .done {
                Button {
                    store.completeTask(task, context: context, goals: activeGoals, allTasks: allTasks)
                } label: {
                    Label("完成", systemImage: "checkmark.circle")
                }
            } else {
                Button {
                    store.uncompleteTask(task, context: context, goals: activeGoals, allTasks: allTasks)
                } label: {
                    Label("标为未完成", systemImage: "arrow.uturn.backward.circle")
                }
            }
            Button {
                store.deferTask(task, context: context)
            } label: {
                Label("延后到明天", systemImage: "calendar.badge.clock")
            }
            Button {
                store.pinTask(task, context: context)
            } label: {
                Label(task.isPinned ? "取消置顶" : "置顶", systemImage: "pin")
            }
            Button {
                store.setLockCandidate(task, context: context)
            } label: {
                Label(task.isLockCandidate ? "取消锁屏候选" : "设为锁屏候选", systemImage: "lock")
            }
            if task.status != .done {
                Button {
                    store.markInProgress(task, context: context)
                } label: {
                    Label("标为进行中", systemImage: "play.circle")
                }
            }
            Button(role: .destructive) {
                taskToDelete = task
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var widgetPromoBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                GSIcon(name: .lock, size: 20, color: GSColor.brand)
                Text("把今日三件事放到锁屏")
                    .font(GSFont.semibold(GSFont.xl))
                    .foregroundStyle(GSColor.textPrimary)
            }
            Text("长按锁屏 → 自定义 → 添加小组件 → 选择 Goalstar「今日三件事」，即可查看并勾选任务。")
                .font(GSFont.semibold(GSFont.base))
                .foregroundStyle(GSColor.textSecondary)
            HStack(spacing: GSSpacing.sm) {
                Button {
                    widgetBannerHiddenThisSession = true
                } label: {
                    Text("我知道了")
                        .font(GSFont.semibold(GSFont.base))
                        .foregroundStyle(GSColor.textOnPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(GSColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
                }
                .buttonStyle(.plain)

                OutlineActionButton(title: "不再提示", height: 36) {
                    store.setWidgetGuideDismissed(true)
                }
            }
        }
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var celebrationCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(GSColor.brandLight).frame(width: 56, height: 56)
                GSIcon(name: .star, size: 28, color: GSColor.brand)
            }
            VStack(spacing: 6) {
                Text("今天的任务都完成了")
                    .font(GSFont.semibold(GSFont.title))
                    .foregroundStyle(GSColor.textPrimary)
                Text("你已经为目标投入了 \(GSFormat.hoursLabel(todayFocusMinutes))，很棒的一天。")
                    .font(GSFont.semibold(GSFont.lg))
                    .foregroundStyle(GSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                OutlineActionButton(title: "继续专注", height: 40) {
                    store.continueFreeFocus()
                }
                OutlineActionButton(title: "明日预览", height: 40) { store.showTomorrowPreview = true }
            }
        }
        .frame(maxWidth: .infinity)
        .gsCard(radius: GSRadius.panel, padding: 18)
    }
}
