import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore
    @Query(sort: \Goal.createdAt)
    private var goals: [Goal]
    @Query(sort: \TaskItem.sortOrder)
    private var allTasks: [TaskItem]
    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]

    @State private var detailGoalID: UUID?
    @State private var goalToArchive: Goal?
    @State private var isRefreshing = false

    private var active: [Goal] { goals.filter { !$0.isCompleted } }
    private var completed: [Goal] { goals.filter(\.isCompleted) }

    private var detailGoal: Goal? {
        guard let detailGoalID else { return nil }
        return goals.first { $0.id == detailGoalID }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PageBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    if isRefreshing {
                        GoalsPageSkeleton()
                    } else {
                        GreetingBar(
                            title: "我的目标",
                            subtitle: "共 \(active.count) 个进行中 · \(completed.count) 个已归档",
                            reverse: true
                        )

                        if active.isEmpty {
                            emptyState
                        } else {
                            overviewCard
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "进行中的目标")
                                ForEach(active, id: \.id) { goal in
                                    Button {
                                        detailGoalID = goal.id
                                    } label: {
                                        GoalCardView(goal: goal)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button {
                                            store.setPrimaryGoal(goal, context: context, goals: goals)
                                        } label: {
                                            Label("设为主要目标", systemImage: "star")
                                        }
                                        Button(role: .destructive) {
                                            goalToArchive = goal
                                        } label: {
                                            Label("归档", systemImage: "archivebox")
                                        }
                                    }
                                }
                            }
                        }

                        if !completed.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "已归档的目标")
                                ForEach(completed, id: \.id) { goal in
                                    Button {
                                        detailGoalID = goal.id
                                    } label: {
                                        completedRow(goal)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, GSSpacing.page)
                .padding(.top, 8)
                .padding(.bottom, GSSpacing.tabContentBottomWithFAB)
            }
            .skeletonRefreshable(isRefreshing: $isRefreshing) {
                await store.refreshGoalsPage(context: context, goals: goals, tasks: allTasks)
            }

            FABButton { store.openCreateSheet(mode: .goal) }
                .padding(.trailing, GSSpacing.page)
                .padding(.bottom, GSSpacing.page)
        }
        .onChange(of: store.showGoalDetail) { _, show in
            if show, let id = store.selectedGoalID {
                detailGoalID = id
                store.showGoalDetail = false
            }
        }
        .onAppear {
            if store.showGoalDetail, let id = store.selectedGoalID {
                detailGoalID = id
                store.showGoalDetail = false
            }
        }
        .sheet(isPresented: Binding(
            get: { detailGoalID != nil && detailGoal != nil },
            set: { if !$0 { detailGoalID = nil } }
        )) {
            if let goal = detailGoal {
                GoalDetailView(
                    goal: goal,
                    allGoals: goals,
                    allTasks: allTasks,
                    sessions: sessions
                )
                .environmentObject(store)
            }
        }
        .onChange(of: detailGoalID) { _, id in
            if let id, goals.first(where: { $0.id == id }) == nil {
                detailGoalID = nil
            }
        }
        .confirmationDialog("归档后目标将移至已归档列表", isPresented: Binding(
            get: { goalToArchive != nil },
            set: { if !$0 { goalToArchive = nil } }
        ), titleVisibility: .visible) {
            if let goal = goalToArchive {
                Button("归档目标", role: .destructive) {
                    store.archiveGoal(goal, context: context)
                    goalToArchive = nil
                }
            }
            Button("取消", role: .cancel) {
                goalToArchive = nil
            }
        }
    }

    private var emptyState: some View {
        EmptyStateCard(
            icon: .target,
            title: "还没有进行中的目标",
            message: "创建目标后，今日任务会更有方向",
            actionTitle: "创建目标"
        ) {
            store.openCreateSheet(mode: .goal)
        }
        .padding(.top, 40)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "目标总览")
                Spacer()
                Text("本周 \(active.first.map { Int($0.weeklyRate * 100) } ?? 0)%")
                    .font(GSFont.semibold(GSFont.base))
                    .foregroundStyle(GSColor.textSecondary)
            }
            HStack(spacing: GSSpacing.sm) {
                InsetStatBlock(value: "\(active.count)", label: "进行中")
                InsetStatBlock(value: "\(completed.count)", label: "已归档")
                InsetStatBlock(value: "\(goals.count)", label: "全部")
            }
        }
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private func completedRow(_ goal: Goal) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(GSColor.successLight).frame(width: 24, height: 24)
                GSIcon(name: .check, size: 14, color: GSColor.success, lineWidth: 2)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(GSFont.semibold(GSFont.xl))
                    .foregroundStyle(GSColor.textPrimary)
                HStack(spacing: 6) {
                    Text("进度 \(Int(goal.progress * 100))%")
                        .font(GSFont.semibold(GSFont.sm))
                        .foregroundStyle(GSColor.textSecondary)
                    Circle().fill(GSColor.textSecondary).frame(width: 4, height: 4)
                    if let date = goal.completedAt {
                        Text("归档于 \(GSFormat.shortDate(date))")
                            .font(GSFont.semibold(GSFont.sm))
                            .foregroundStyle(GSColor.textSecondary)
                    }
                }
            }
            Spacer()
            CategoryTag(
                text: "\(goal.emoji) \(goal.category)",
                color: Color(hex: goal.accentHex),
                background: Color(hex: goal.accentHex).opacity(0.12),
                compact: true
            )
        }
        .gsCard(radius: GSRadius.card, padding: 16)
    }
}
