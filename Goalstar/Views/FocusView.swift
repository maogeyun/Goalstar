import SwiftUI
import SwiftData
import ActivityKit
import UserNotifications

struct FocusView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore

    @Query(filter: #Predicate<Goal> { !$0.isCompleted }, sort: \Goal.createdAt)
    private var goals: [Goal]

    @Query(sort: \TaskItem.sortOrder)
    private var tasks: [TaskItem]

    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]

    @State private var liveActivityDenied = false
    @State private var notificationsDenied = false

    private var selectedGoal: Goal? {
        store.focusLinkedGoal(in: goals)
    }

    private var todayMinutes: Int {
        sessions.filter { Calendar.current.isDateInToday($0.startedAt) && $0.isCompleted }
            .reduce(0) { $0 + $1.minutes }
    }

    private var displaySeconds: Int {
        store.focusMode.isCountUp ? store.focusElapsed : store.focusRemaining
    }

    private var progress: Double {
        if store.focusMode.isCountUp {
            let target = Double(max(store.focusTargetMinutes, 1) * 60)
            return min(1, Double(store.focusElapsed) / target)
        }
        let total = Double(max(store.focusTargetMinutes, 1) * 60)
        return 1 - Double(store.focusRemaining) / total
    }

    private var statusLabel: String {
        if store.isFocusRunning { return "专注中" }
        if store.focusMode.isCountUp {
            return store.focusElapsed > 0 ? "已暂停" : "准备开始"
        }
        let full = store.focusTargetMinutes * 60
        return store.focusRemaining < full ? "已暂停" : "准备开始"
    }

    private var primaryFocusButtonTitle: String {
        if store.isFocusRunning { return "暂停" }
        if statusLabel == "已暂停" { return "继续" }
        return "开始"
    }

    var body: some View {
        ZStack {
            PageBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    GreetingBar(
                        title: "专注时刻",
                        subtitle: "保持节奏，完成今日投入",
                        reverse: true
                    )

                    if goals.isEmpty {
                        emptyGoalsHint
                    }

                    if liveActivityDenied || notificationsDenied {
                        permissionBanner
                    }

                    timerCard
                    modesSection
                    if store.focusMode == .custom {
                        customDurationSection
                    }
                    goalSelector
                    summaryRow
                    recentRecords
                }
                .padding(.horizontal, GSSpacing.page)
                .padding(.top, 8)
                .padding(.bottom, GSSpacing.tabContentBottom)
            }
        }
        .onAppear {
            store.consumePendingAutoStartFocus(context: context, goals: goals)
            refreshPermissionState()
        }
    }

    private func refreshPermissionState() {
        liveActivityDenied = !ActivityAuthorizationInfo().areActivitiesEnabled
        Task {
            let status = await NotificationScheduler.authorizationStatus()
            await MainActor.run {
                notificationsDenied = status == .denied
            }
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if liveActivityDenied {
                Text("实时活动未开启")
                    .font(GSFont.semibold(GSFont.lg))
                    .foregroundStyle(GSColor.textPrimary)
                Text("锁屏/Dynamic Island 专注计时可能不可用。可在「设置 → Goalstar → 实时活动」中开启。")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
            }
            if notificationsDenied {
                if liveActivityDenied { Divider().padding(.vertical, 4) }
                Text("通知权限未开启")
                    .font(GSFont.semibold(GSFont.lg))
                    .foregroundStyle(GSColor.textPrimary)
                Text("倒计时结束时可能收不到提醒。可在「设置 → Goalstar → 通知」中开启。")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.card, padding: 14)
    }

    private var canFinishFocus: Bool {
        store.isFocusRunning || store.focusElapsed > 0 || (
            !store.focusMode.isCountUp && store.focusRemaining < store.focusTargetMinutes * 60
        )
    }

    private var canAbandonFocus: Bool { canFinishFocus }

    private var emptyGoalsHint: some View {
        EmptyStateCard(
            icon: .target,
            title: "还没有目标",
            message: "可以先自由专注，建议稍后再创建目标以便复盘。",
            actionTitle: "去创建目标",
            compact: true
        ) {
            store.openCreateSheet(mode: .goal)
        }
    }

    private var timerCard: some View {
        VStack(spacing: 16) {
            if let title = store.activeFocusTaskTitle {
                VStack(spacing: 4) {
                    Text(title)
                        .font(GSFont.semibold(GSFont.xxl))
                        .foregroundStyle(GSColor.textPrimary)
                        .multilineTextAlignment(.center)
                    if let goal = selectedGoal {
                        Text("\(goal.emoji) \(goal.name)")
                            .font(GSFont.semibold(GSFont.md))
                            .foregroundStyle(GSColor.textSecondary)
                    }
                }
            }

            ZStack {
                ProgressRing(
                    progress: progress,
                    size: 160,
                    lineWidth: 10,
                    centerText: nil
                )
                VStack(spacing: 4) {
                    Text(GSFormat.timer(displaySeconds))
                        .font(GSFont.bold(GSFont.timer))
                        .monospacedDigit()
                        .foregroundStyle(GSColor.textPrimary)
                    Text(statusLabel)
                        .font(GSFont.semibold(GSFont.md))
                        .foregroundStyle(GSColor.textSecondary)
                }
            }

            HStack(spacing: 12) {
                Button {
                    store.requestFinishFocus(goals: goals)
                } label: {
                    Text("结束")
                        .font(GSFont.semibold(GSFont.lg))
                        .foregroundStyle(canFinishFocus ? GSColor.textSecondary : GSColor.textSecondary)
                        .frame(width: 64, height: 40)
                        .background(canFinishFocus ? GSColor.bgTertiary : GSColor.bgTertiary.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canFinishFocus)

                Button {
                    store.startFocus(context: context, goals: goals)
                } label: {
                    HStack(spacing: 8) {
                        GSIcon(
                            name: store.isFocusRunning ? .circleX : .play,
                            size: 20,
                            color: GSColor.textOnPrimary,
                            lineWidth: 2
                        )
                        Text(primaryFocusButtonTitle)
                            .font(GSFont.semibold(GSFont.xl))
                    }
                    .foregroundStyle(GSColor.textOnPrimary)
                    .frame(width: 120, height: 45)
                    .background(GSColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: GSRadius.play, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: GSRadius.play, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    store.requestAbandonFocus()
                } label: {
                    Text("放弃")
                        .font(GSFont.semibold(GSFont.lg))
                        .foregroundStyle(canAbandonFocus ? GSColor.danger : GSColor.textSecondary)
                        .frame(width: 64, height: 40)
                        .background(canAbandonFocus ? GSColor.dangerLight : GSColor.bgTertiary.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canAbandonFocus)
            }
        }
        .frame(maxWidth: .infinity)
        .gsCard(radius: GSRadius.panel, padding: 20)
    }

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "选择专注模式")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(FocusMode.allCases) { mode in
                    Button {
                        store.selectFocusMode(mode)
                    } label: {
                        HStack(spacing: 6) {
                            GSIcon(
                                name: mode.icon,
                                size: 18,
                                color: store.focusMode == mode ? GSColor.brand : GSColor.textSecondary,
                                lineWidth: 1.9
                            )
                            Text(mode.title)
                                .font(GSFont.semibold(GSFont.base))
                                .foregroundStyle(store.focusMode == mode ? GSColor.brand : GSColor.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(store.focusMode == mode ? GSColor.brandLight : GSColor.bgTertiary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(store.focusMode == mode ? GSColor.brand : GSColor.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isFocusRunning)
                }
            }
        }
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var customDurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "倒计时时长")
            Stepper("\(store.focusTargetMinutes) 分钟", value: Binding(
                get: { store.focusTargetMinutes },
                set: { newValue in
                    store.focusTargetMinutes = newValue
                    if !store.isFocusRunning {
                        store.focusRemaining = newValue * 60
                    }
                }
            ), in: 5...120, step: 5)
            .font(GSFont.semibold(GSFont.lg))
            .foregroundStyle(GSColor.textPrimary)
            .gsCard(radius: GSRadius.panel, padding: 16)
        }
    }

    private var goalSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(GSColor.brand).frame(width: 8, height: 8)
                    Text("关联到目标")
                        .font(GSFont.semibold(GSFont.lg))
                        .foregroundStyle(GSColor.textPrimary)
                }
                Spacer()
                Menu {
                    Button("自由专注") {
                        store.selectedFocusGoalID = nil
                    }
                    ForEach(goals, id: \.id) { goal in
                        Button("\(goal.emoji) \(goal.name)") {
                            store.selectedFocusGoalID = goal.id
                        }
                    }
                } label: {
                    GSIcon(name: .chevronRight, size: 16, color: GSColor.textSecondary)
                }
            }

            if let goal = selectedGoal {
                HStack {
                    Text("\(goal.emoji) \(goal.name)")
                        .font(GSFont.semibold(GSFont.lg))
                        .foregroundStyle(GSColor.textPrimary)
                    Text("已达成 \(Int(goal.progress * 100))%")
                        .font(GSFont.semibold(GSFont.sm))
                        .foregroundStyle(GSColor.textSecondary)
                    Spacer()
                    Text("第 \(goal.currentDay) / \(goal.totalDays) 天")
                        .font(GSFont.semibold(GSFont.sm))
                        .foregroundStyle(GSColor.textSecondary)
                }
                .padding(12)
                .background(GSColor.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("自由专注（不关联目标）")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GSColor.bgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            MetricCard(icon: .chartPie, value: GSFormat.minutesLabel(todayMinutes), label: "今日专注")
            MetricCard(icon: .timer, value: "\(sessions.filter { Calendar.current.isDateInToday($0.startedAt) && $0.isCompleted }.count)", label: "今日次数", tint: GSColor.accent)
            MetricCard(icon: .checkCircle, value: GSFormat.minutesLabel(sessions.filter(\.isCompleted).prefix(7).reduce(0) { $0 + $1.minutes }), label: "近7天", tint: GSColor.success)
        }
    }

    private var recentRecords: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "最近记录")
            let completed = sessions.filter(\.isCompleted)
            if completed.isEmpty {
                EmptyStateCard(
                    icon: .clock,
                    title: "暂无专注记录",
                    message: "完成一次专注后，记录会出现在这里",
                    compact: true
                )
            } else {
                ForEach(completed.prefix(3), id: \.id) { session in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(GSColor.brandLight).frame(width: 32, height: 32)
                            GSIcon(name: .clock, size: 14, color: GSColor.brand)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.goal.map { "\($0.emoji) \($0.name)" } ?? "自由专注")
                                .font(GSFont.semibold(GSFont.lg))
                                .foregroundStyle(GSColor.textPrimary)
                            Text("\(session.mode.title) · \(session.minutes) 分钟")
                                .font(GSFont.semibold(GSFont.sm))
                                .foregroundStyle(GSColor.textSecondary)
                        }
                        Spacer()
                        Text(GSFormat.time(session.startedAt))
                            .font(GSFont.semibold(GSFont.md))
                            .foregroundStyle(GSColor.textSecondary)
                    }
                    .gsCard(radius: GSRadius.card, padding: 14)
                }
            }
        }
    }
}
