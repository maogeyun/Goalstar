import SwiftUI
import SwiftData

struct DataView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore

    @Query private var goals: [Goal]
    @Query private var tasks: [TaskItem]
    @Query private var habits: [Habit]
    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]
    @Query private var checkIns: [HabitCheckIn]

    @State private var detailGoalID: UUID?
    @State private var isRefreshing = false

    private var rangeSessions: [FocusSession] {
        let cal = Calendar.current
        let now = Date()
        return sessions.filter { session in
            guard session.isCompleted else { return false }
            switch store.dataPeriod {
            case .week:
                return cal.isDate(session.startedAt, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return cal.isDate(session.startedAt, equalTo: now, toGranularity: .month)
            case .year:
                return cal.isDate(session.startedAt, equalTo: now, toGranularity: .year)
            }
        }
    }

    private var focusMinutes: Int { rangeSessions.reduce(0) { $0 + $1.minutes } }
    private var completedTasksCount: Int { Metrics.completedTasks(in: tasks, period: store.dataPeriod) }
    private var checkInDays: Int { Metrics.habitStreakMax(in: habits) }
    private var completionRate: Int { Metrics.completionRate(in: tasks, period: store.dataPeriod) }
    private var isEmptyPeriod: Bool { focusMinutes == 0 && completedTasksCount == 0 }

    private var weekBars: [CGFloat] {
        Metrics.weeklyFocusHoursByWeekday(in: sessions)
    }

    private var todayWeekdayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    private var peakHour: Int? {
        Metrics.peakFocusHour(in: sessions)
    }

    private var reviewAdvice: String {
        Metrics.weeklyReviewAdvice(
            completionRate: completionRate,
            focusMinutes: focusMinutes,
            streak: checkInDays
        )
    }

    private var detailGoal: Goal? {
        guard let detailGoalID else { return nil }
        return goals.first { $0.id == detailGoalID }
    }

    var body: some View {
        ZStack {
            PageBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    if isRefreshing {
                        DataPageSkeleton()
                    } else {
                        GreetingBar(
                            title: "数据洞察",
                            subtitle: "用数据看见坚持的力量",
                            reverse: true
                        )

                        periodPicker
                        if isEmptyPeriod {
                            EmptyStateCard(
                                icon: .barChart,
                                title: "这个周期还没有数据",
                                message: "去今日完成第一件事，数据会在这里生长。",
                                actionTitle: "去今日"
                            ) {
                                store.selectedTab = .today
                            }
                        } else {
                            metricsGrid
                            reviewCard
                            if let hour = peakHour {
                                peakHourCard(hour)
                            }
                            trendCard
                            heatmapCard
                        }
                        if !isEmptyPeriod {
                            rankingSection
                        }
                    }
                }
                .padding(.horizontal, GSSpacing.page)
                .padding(.top, 8)
                .padding(.bottom, GSSpacing.tabContentBottom)
            }
            .skeletonRefreshable(isRefreshing: $isRefreshing) {
                await store.refreshDataPage(context: context, goals: goals, tasks: tasks)
            }
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
                    allTasks: tasks,
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
    }

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(DataPeriod.allCases) { period in
                Button {
                    store.dataPeriod = period
                } label: {
                    Text(period.title)
                        .font(GSFont.semibold(GSFont.base))
                        .foregroundStyle(store.dataPeriod == period ? GSColor.brand : GSColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(store.dataPeriod == period ? GSColor.surfaceCard : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
                        .shadow(color: store.dataPeriod == period ? GSColor.cardShadow : .clear, radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(GSColor.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
    }

    private var metricsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                bigMetric(icon: .clock, value: GSFormat.minutesLabel(focusMinutes), label: "专注总时长", tint: GSColor.brand)
                bigMetric(icon: .check, value: "\(completedTasksCount) 个", label: "完成任务", tint: GSColor.success)
            }
            HStack(spacing: 10) {
                bigMetric(icon: .flame, value: "\(checkInDays) 天", label: "打卡天数", tint: GSColor.warning)
                bigMetric(icon: .percent, value: "\(completionRate)%", label: "完成率", tint: GSColor.accent)
            }
        }
    }

    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.dataPeriod == .week ? "本周复盘" : "\(store.dataPeriod.title)复盘")
                .font(GSFont.semibold(GSFont.xl))
                .foregroundStyle(GSColor.textPrimary)
            Text("完成 \(completedTasksCount) 个任务 · 专注 \(GSFormat.hoursLabel(focusMinutes)) · 最长连续打卡 \(checkInDays) 天")
                .font(GSFont.semibold(GSFont.md))
                .foregroundStyle(GSColor.textSecondary)
            Text(reviewAdvice)
                .font(GSFont.semibold(GSFont.lg))
                .foregroundStyle(GSColor.textPrimary)
        }
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private func peakHourCard(_ hour: Int) -> some View {
        let end = (hour + 2) % 24
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(GSColor.brandLight).frame(width: 36, height: 36)
                GSIcon(name: .timer, size: 16, color: GSColor.brand)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("最高效时段")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
                Text(String(format: "%02d:00–%02d:00", hour, end))
                    .font(GSFont.semibold(GSFont.xl))
                    .foregroundStyle(GSColor.textPrimary)
            }
            Spacer()
        }
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private func bigMetric(icon: GSIconName, value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                Circle().fill(tint.opacity(0.12)).frame(width: 28, height: 28)
                GSIcon(name: icon, size: 14, color: tint)
            }
            Text(value)
                .font(GSFont.semibold(GSFont.hero))
                .foregroundStyle(GSColor.textPrimary)
            Text(label)
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.card, padding: 12)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("近7天专注趋势")
                    .font(GSFont.semibold(GSFont.xl))
                    .foregroundStyle(GSColor.textPrimary)
                Spacer()
                Text("固定近7天")
                    .font(GSFont.semibold(GSFont.sm))
                    .foregroundStyle(GSColor.textSecondary)
            }
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(weekBars.enumerated()), id: \.offset) { idx, value in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(value > 0 ? (idx == todayWeekdayIndex ? GSColor.brand : GSColor.brand200) : GSColor.bgTertiary)
                            .frame(width: 20, height: max(20, 20 + value * 60))
                        Text(["一", "二", "三", "四", "五", "六", "日"][idx])
                            .font(GSFont.semibold(10))
                            .foregroundStyle(GSColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 116)
        }
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("习惯记录热力图")
                    .font(GSFont.semibold(GSFont.xl))
                    .foregroundStyle(GSColor.textPrimary)
                Spacer()
                Text("最近4周 · 上：本周 / 下：更早")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
            }

            HStack {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { d in
                    Text(d)
                        .font(GSFont.semibold(GSFont.sm))
                        .foregroundStyle(GSColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                }
            }

            ForEach(0..<4, id: \.self) { week in
                HStack {
                    ForEach(0..<7, id: \.self) { day in
                        let level = heatLevel(week: week, day: day)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(heatColor(level))
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                    }
                }
            }

            HStack(spacing: 4) {
                Spacer()
                Text("少").font(GSFont.semibold(10)).foregroundStyle(GSColor.textSecondary)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatColor(level))
                        .frame(width: 14, height: 14)
                }
                Text("多").font(GSFont.semibold(10)).foregroundStyle(GSColor.textSecondary)
            }
        }
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private func heatColor(_ level: Int) -> Color {
        switch level {
        case 0: return GSColor.bgTertiary
        case 1: return GSColor.brand200.opacity(0.35)
        case 2: return GSColor.brand200.opacity(0.65)
        case 3: return GSColor.brand.opacity(0.7)
        default: return GSColor.brand
        }
    }

    private func heatLevel(week: Int, day: Int) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let todayIdx = (weekday + 5) % 7
        let rowStart = cal.date(byAdding: .day, value: -(todayIdx + week * 7), to: today) ?? today
        guard let cellDate = cal.date(byAdding: .day, value: day, to: rowStart) else { return 0 }

        let fromCheckIns = checkIns.filter { cal.isDate($0.date, inSameDayAs: cellDate) }.count
        if fromCheckIns > 0 {
            return min(4, fromCheckIns)
        }
        // Fallback for legacy rows without HabitCheckIn history
        let fromLast = habits.filter { habit in
            guard let checkIn = habit.lastCheckIn else { return false }
            return cal.isDate(checkIn, inSameDayAs: cellDate)
        }.count
        return min(4, fromLast)
    }

    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "目标进度排行")
            let ranked = goals.filter { !$0.isCompleted }.sorted { $0.progress > $1.progress }
            if ranked.isEmpty {
                EmptyStateCard(
                    icon: .target,
                    title: "暂无目标排行",
                    message: "创建目标后可在此查看进度排行",
                    compact: true
                )
            } else {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { idx, goal in
                    Button {
                        store.openGoalDetail(goal)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(goal.name)
                                    .font(GSFont.semibold(GSFont.lg))
                                    .foregroundStyle(GSColor.textPrimary)
                                Spacer()
                                Text("\(Int(goal.progress * 100))%")
                                    .font(GSFont.semibold(GSFont.lg))
                                    .foregroundStyle(GSColor.textPrimary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(GSColor.bgTertiary).frame(height: 6)
                                    Capsule()
                                        .fill(Color(hex: goal.accentHex))
                                        .frame(width: max(6, geo.size.width * goal.progress), height: 6)
                                }
                            }
                            .frame(height: 6)
                            HStack {
                                Text("\(goal.emoji) \(goal.category)")
                                    .font(GSFont.semibold(GSFont.sm))
                                    .foregroundStyle(GSColor.textSecondary)
                                Spacer()
                                Text("No.\(idx + 1)")
                                    .font(GSFont.semibold(GSFont.sm))
                                    .foregroundStyle(GSColor.textSecondary)
                            }
                        }
                        .gsCard(radius: GSRadius.card, padding: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
