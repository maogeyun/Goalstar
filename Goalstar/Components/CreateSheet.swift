import SwiftUI
import SwiftData

private enum GoalCreatePhase {
    case editing
    case generating
    case confirm
}

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
    @State private var category = L10n.s("语言学习")
    @State private var emoji = "📖"
    @State private var selectedGoalID: UUID?
    @State private var selectedMilestoneID: UUID?
    @State private var priority = false
    @State private var taskStartDate = Calendar.current.startOfDay(for: Date())
    @State private var taskEndDate = Calendar.current.startOfDay(for: Date())
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var titleError: String?

    @State private var prompt = ""
    @State private var chips: Set<GoalContextChip> = []
    @State private var phase: GoalCreatePhase = .editing
    @State private var draft = GoalDraftDTO.empty
    @State private var draftBaseline = GoalDraftDTO.empty
    @State private var aiAvailable = false
    @State private var confirmNotice: String?
    @State private var confirmLimitMessage: String?
    @State private var isRegenerating = false
    @State private var showDiscard = false
    @State private var pendingDismiss = false
    @State private var pendingMode: CreateFormMode?
    @State private var generateTask: Task<Void, Never>?
    @State private var sheetOpenedAt = Date()
    @State private var didConfigure = false
    @State private var activePaywall: ProPaywallContext?
    @State private var showRegenWall = false
    @FocusState private var oneLinerFocused: Bool

    private var goalPresets: [(String, String, String)] {
        [
            (L10n.s("语言学习"), "📖", L10n.s("系统学习英语")),
            (L10n.s("工作项目"), "💼", L10n.s("推进本周关键交付")),
            (L10n.s("健康运动"), "💪", L10n.s("每周三次力量训练")),
            (L10n.s("生活习惯"), "🌱", L10n.s("早睡早起 30 天"))
        ]
    }

    private var lockToGoalMode: Bool { goals.isEmpty }
    private var showConfirm: Bool { phase == .confirm && mode == .goal }
    private var draftIsDirty: Bool { draft != draftBaseline }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !showConfirm {
                    GoalTaskSegmentedControl(
                        mode: segmentMode,
                        taskEnabled: !lockToGoalMode,
                        goalTitle: CreateFormMode.goal.segmentTitle,
                        taskTitle: CreateFormMode.task.segmentTitle
                    )
                    .padding(.horizontal, GSSpacing.page)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }

                if showConfirm {
                    ConfirmDraftView(
                        draft: $draft,
                        isRegenerating: isRegenerating,
                        remainingRegen: RegenQuotaStore.remaining(isPro: store.isPro),
                        notice: confirmNotice,
                        limitMessage: confirmLimitMessage,
                        onRegen: { startGenerate(regenerating: true) },
                        onSave: saveDraft,
                        onManual: useManualForm,
                        onUpgradeGoalLimit: { activePaywall = .goals }
                    )
                } else {
                    editingContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(PageBackground())
            .navigationTitle(showConfirm ? L10n.s("确认草稿") : navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.s("关闭")) { attemptClose() }
                }
            }
            .onAppear(perform: configureIfNeeded)
            .overlay {
                if showDiscard {
                    discardOverlay
                } else if showRegenWall {
                    regenWallOverlay
                }
            }
        }
        .sheet(item: $activePaywall) { context in
            ProPaywallSheet(context: context)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
    }

    private var navigationTitle: String {
        lockToGoalMode ? CreateFormMode.goal.title : mode.title
    }

    private var segmentMode: Binding<CreateFormMode> {
        Binding(
            get: { mode },
            set: { requestMode($0) }
        )
    }

    private var editingContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: GSSpacing.lg) {
                if mode == .task && !lockToGoalMode {
                    taskForm
                } else {
                    goalSegment
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GSSpacing.page)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private var goalSegment: some View {
        if aiAvailable {
            GoalAISection(
                prompt: $prompt,
                chips: $chips,
                presentation: phase == .generating ? .generating : .ready,
                focused: $oneLinerFocused,
                onGenerate: { startGenerate(regenerating: false) },
                onCancel: cancelGenerate
            )
            manualDivider
            if phase == .generating {
                mutedGoalSummary
            } else {
                goalForm
            }
        } else {
            unavailableBanner
            GoalAISection(
                prompt: $prompt,
                chips: $chips,
                presentation: .unavailable,
                focused: $oneLinerFocused,
                onGenerate: {},
                onCancel: {}
            )
            manualDivider
            goalForm
        }
    }

    private var unavailableBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.s("本机 AI 暂不可用"))
                .font(GSFont.semibold(GSFont.lg))
                .foregroundStyle(GSColor.textPrimary)
            Text(L10n.s("可选用分语种模板，或直接手动填写。语言切换不受影响。"))
                .font(GSFont.semibold(GSFont.md))
                .foregroundStyle(GSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(GSColor.warningLight)
        .overlay(
            RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous)
                .stroke(GSColor.warning, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous))
    }

    private var mutedGoalSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.s("类型预设 · 名称 · Emoji · 分类 · 天数 · 截止日"))
                .font(GSFont.semibold(GSFont.md))
                .foregroundStyle(GSColor.textPrimary)
            Text(L10n.s("生成时可取消，手动表单始终保留"))
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
        .opacity(0.55)
    }

    @ViewBuilder
    private var saveError: some View {
        if let titleError {
            Text(titleError)
                .font(GSFont.semibold(GSFont.lg))
                .foregroundStyle(GSColor.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
            if titleError == ProEntitlement.freeGoalLimitMessage {
                OutlineActionButton(title: L10n.s("升级 Pro")) {
                    store.requestProPaywall()
                }
            }
        }
    }

    private var manualDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(GSColor.border)
                .frame(height: 1)
            Text(L10n.s("或手动填写"))
                .font(GSFont.semibold(GSFont.md))
                .foregroundStyle(GSColor.textSecondary)
                .lineLimit(1)
                .fixedSize()
            Rectangle()
                .fill(GSColor.border)
                .frame(height: 1)
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
                DetailFieldLabel(text: L10n.s("任务名称"))
                TextField(L10n.s("例如：完成英语阅读"), text: $title)
                    .textFieldStyle(GSTextFieldStyle())
                    .onChange(of: title) { _, _ in titleError = nil }
            }

            DetailFormRow(label: L10n.s("时长（分钟）")) {
                // Match the 1.0 taskForm stepper (DetailFormRow minHeight 44). Do not stretch this row.
                HStack(spacing: 8) {
                    Text(L10n.f("%d min", minutes))
                        .font(GSFont.semibold(GSFont.lg))
                        .foregroundStyle(GSColor.textPrimary)
                        .lineLimit(1)
                    Stepper("", value: $minutes, in: 5...120, step: 5)
                        .labelsHidden()
                        .fixedSize()
                }
            }

            DatePickerFormRow(
                title: L10n.s("开始日期"),
                selection: $taskStartDate,
                range: taskDateBounds
            )
            .onChange(of: taskStartDate) { _, newValue in
                if taskEndDate < newValue { taskEndDate = newValue }
                clampTaskDatesToSelectedMilestone()
                titleError = nil
            }

            DatePickerFormRow(
                title: L10n.s("结束日期"),
                selection: $taskEndDate,
                range: taskEndDateRange
            )
            .onChange(of: taskEndDate) { _, _ in
                clampTaskDatesToSelectedMilestone()
                titleError = nil
            }

            if let range = taskDateBounds {
                Text(L10n.f("需在阶段范围内：%@", GSFormat.dateRangeLabel(start: range.lowerBound, end: range.upperBound)))
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
            }

            MenuPickerFormRow(title: L10n.s("关联目标"), selection: $selectedGoalID) {
                Text(L10n.s("无")).tag(UUID?.none)
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
                MenuPickerFormRow(title: L10n.s("关联阶段"), selection: $selectedMilestoneID) {
                    Text(L10n.s("自动（当前阶段）"))
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

            DetailFormRow(label: L10n.s("设为优先")) {
                Toggle("", isOn: $priority)
                    .labelsHidden()
                    .tint(GSColor.brand)
            }

            saveError
            PrimaryButton(title: L10n.s("保存"), height: 46) {
                save()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var goalForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                DetailFieldLabel(text: L10n.s("类型预设"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(goalPresets, id: \.0) { preset in
                            SelectableCapsuleChip(
                                title: "\(preset.1) \(preset.0)",
                                selected: category == preset.0
                            ) {
                                category = preset.0
                                emoji = preset.1
                                if title.isEmpty { title = preset.2 }
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                DetailFieldLabel(text: L10n.s("目标名称"))
                TextField(L10n.s("例如：系统学习英语"), text: $title)
                    .textFieldStyle(GSTextFieldStyle())
                    .onChange(of: title) { _, _ in titleError = nil }
            }

            VStack(alignment: .leading, spacing: 8) {
                DetailFieldLabel(text: L10n.s("分类"))
                TextField(L10n.s("语言学习"), text: $category)
                    .textFieldStyle(GSTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                DetailFieldLabel(text: L10n.s("Emoji"))
                TextField("📖", text: $emoji)
                    .textFieldStyle(GSTextFieldStyle())
            }

            DetailFormRow(label: L10n.s("计划天数")) {
                HStack(spacing: 8) {
                    Text(L10n.f("%d 天", days))
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
                title: L10n.s("截止日期（可选）"),
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

            Text(L10n.s("衡量方式：默认按任务完成推进"))
                .font(GSFont.semibold(GSFont.base, relativeTo: .caption))
                .foregroundStyle(GSColor.textSecondary)

            saveError
            PrimaryButton(title: L10n.s("保存"), height: 46) {
                save()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        sheetOpenedAt = Date()
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
        aiAvailable = OnDeviceModelAvailability.isReady
        if mode == .goal && store.createSheetEntry == .oneLiner && aiAvailable {
            oneLinerFocused = true
        }
    }

    private func requestMode(_ newMode: CreateFormMode) {
        guard newMode != mode else { return }
        if newMode == .task && lockToGoalMode { return }
        if showConfirm {
            pendingMode = newMode
            pendingDismiss = false
            if draftIsDirty {
                showDiscard = true
            } else {
                confirmDiscard()
            }
            return
        }
        if phase == .generating {
            cancelGenerate()
        }
        mode = newMode
    }

    private func attemptClose() {
        if showConfirm {
            pendingMode = nil
            if draftIsDirty {
                pendingDismiss = true
                showDiscard = true
            } else {
                GoalstarAnalytics.track("goal_ai_discard", ["edited": "false"])
                store.clearCreateSheetPreferences()
                dismiss()
            }
            return
        }
        if phase == .generating {
            cancelGenerate()
        }
        store.clearCreateSheetPreferences()
        dismiss()
    }

    private func confirmDiscard() {
        showDiscard = false
        showRegenWall = false
        GoalstarAnalytics.track("goal_ai_discard", ["edited": draftIsDirty ? "true" : "false"])
        generateTask?.cancel()
        generateTask = nil
        isRegenerating = false
        phase = .editing
        let shouldDismiss = pendingDismiss
        let nextMode = pendingMode
        pendingDismiss = false
        pendingMode = nil
        if shouldDismiss {
            store.clearCreateSheetPreferences()
            dismiss()
            return
        }
        if let nextMode {
            mode = nextMode
        }
    }

    private func startGenerate(regenerating: Bool) {
        let sentence = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sentence.isEmpty else { return }
        if regenerating && !RegenQuotaStore.canRegenerate(isPro: store.isPro) {
            GoalstarAnalytics.track("goal_ai_regen_blocked", [
                "language": AppLanguagePreference.current.analyticsCode
            ])
            showRegenWall = true
            return
        }
        GoalstarAnalytics.track(regenerating ? "goal_ai_regen_tap" : "goal_ai_generate_tap", [
            "language": AppLanguagePreference.current.analyticsCode,
            "chips": String(chips.count)
        ])
        if regenerating {
            isRegenerating = true
        } else {
            phase = .generating
        }
        let selectedChips = chips
        let language = AppLanguagePreference.current
        generateTask?.cancel()
        generateTask = Task {
            let outcome = await OnDeviceGoalDraftGenerator.make(
                sentence: sentence,
                chips: selectedChips,
                language: language
            )
            if Task.isCancelled { return }
            apply(outcome, regenerating: regenerating)
        }
    }

    private func cancelGenerate() {
        generateTask?.cancel()
        generateTask = nil
        isRegenerating = false
        if phase == .generating {
            phase = .editing
        }
    }

    private func apply(_ outcome: GoalDraftOutcome, regenerating: Bool) {
        isRegenerating = false
        switch outcome {
        case .cancelled:
            if !regenerating, phase == .generating {
                phase = .editing
            }
        case .ready(let next, let source, let reason, let milliseconds):
            var properties = [
                "language": AppLanguagePreference.current.analyticsCode,
                "generate_ms": String(milliseconds),
                "source": source.rawValue
            ]
            if source == .template {
                if let reason { properties["fail_reason"] = reason }
                GoalstarAnalytics.track("goal_ai_generate_fail", properties)
                GoalstarAnalytics.track("goal_ai_fallback_template", properties)
            } else {
                GoalstarAnalytics.track("goal_ai_generate_ok", properties)
            }
            if regenerating {
                RegenQuotaStore.record(isPro: store.isPro)
            }
            draft = next
            draftBaseline = next
            confirmLimitMessage = nil
            confirmNotice = next.usedTemplateFallback ? L10n.s("已使用模板草稿，可继续修改后保存") : nil
            phase = .confirm
            mode = .goal
        }
    }

    private func useManualForm() {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { title = name }
        phase = .editing
        isRegenerating = false
        confirmNotice = nil
        showRegenWall = false
        mode = .goal
    }

    private func keepEditingDraft() {
        showDiscard = false
        pendingDismiss = false
        pendingMode = nil
    }

    private func saveDraft() {
        let edited = draft != draftBaseline
        switch store.createGoalFromDraft(draft, context: context) {
        case .success(let id):
            let elapsed = Int(Date().timeIntervalSince(sheetOpenedAt) * 1000)
            GoalstarAnalytics.track("goal_ai_edit_before_save", [
                "edited": edited ? "true" : "false"
            ])
            GoalstarAnalytics.track("goal_ai_confirm_save", [
                "create_to_save_ms": String(elapsed),
                "fallback": draft.usedTemplateFallback ? "true" : "false",
                "language": AppLanguagePreference.current.analyticsCode
            ])
            store.scheduleGoalDetail(id)
            store.clearCreateSheetPreferences()
            dismiss()
        case .failure(.emptyName):
            confirmLimitMessage = L10n.s("请输入目标名称")
        case .failure(.goalLimit):
            confirmLimitMessage = ProEntitlement.freeGoalLimitMessage
        case .failure(.persistence):
            confirmLimitMessage = L10n.s("保存失败，请重试")
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            titleError = mode == .goal || lockToGoalMode ? L10n.s("请输入目标名称") : L10n.s("请输入任务名称")
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
                category: category.isEmpty ? L10n.s("综合") : category,
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

    private var discardOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.s("放弃草稿？"))
                    .font(GSFont.semibold(GSFont.title))
                    .foregroundStyle(GSColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(L10n.s("您已修改内容。关闭确认卡将不写入目标 / 阶段 / 任务。"))
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Button(action: keepEditingDraft) {
                    Text(L10n.s("继续编辑"))
                        .font(GSFont.semibold(GSFont.xl))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(GSColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: GSRadius.panel, style: .continuous))
                }
                .buttonStyle(.plain)
                Button(action: confirmDiscard) {
                    Text(L10n.s("放弃草稿"))
                        .font(GSFont.semibold(GSFont.xl))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(GSColor.danger)
                        .clipShape(RoundedRectangle(cornerRadius: GSRadius.panel, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(GSColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: GSRadius.panel, style: .continuous))
            .padding(.horizontal, 28)
        }
    }

    private var regenWallOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.s("今日再生成次数已用完"))
                    .font(GSFont.semibold(GSFont.title))
                    .foregroundStyle(GSColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(L10n.s("免费每日 3 次再生成已用尽。升级 Pro 可无限再生成。"))
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Text(L10n.s("无限再生成（与目标数量上限分开计量）"))
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    showRegenWall = false
                    activePaywall = .regen
                } label: {
                    Text(L10n.s("升级 Pro"))
                        .font(GSFont.semibold(GSFont.xl))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(GSColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: GSRadius.panel, style: .continuous))
                }
                .buttonStyle(.plain)
                Button {
                    showRegenWall = false
                } label: {
                    Text(L10n.s("保留当前草稿并继续编辑"))
                        .font(GSFont.semibold(GSFont.base))
                        .foregroundStyle(GSColor.brand)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.plain)
                Button(action: useManualForm) {
                    Text(L10n.s("改用手动填写"))
                        .font(GSFont.semibold(GSFont.base))
                        .foregroundStyle(GSColor.brand)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
                Text(L10n.s("不挡保存 · 不挡手动"))
                    .font(GSFont.regular(GSFont.sm))
                    .foregroundStyle(GSColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
            .background(GSColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: GSRadius.panel, style: .continuous))
            .padding(.horizontal, 28)
        }
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
                        title: L10n.s("明天还没有安排"),
                        message: L10n.s("今晚可以先规划明天的三件事"),
                        actionTitle: L10n.s("添加任务")
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
                            SectionHeader(title: L10n.s("明日任务"))
                            ForEach(tomorrowTasks, id: \.id) { task in
                                HStack(spacing: 12) {
                                    Circle()
                                        .stroke(GSColor.border, lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(GSFont.semibold(GSFont.lg))
                                            .foregroundStyle(GSColor.textPrimary)
                                        Text(L10n.f("%d 分钟", task.durationMinutes))
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
            .navigationTitle(L10n.s("明日预览"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.s("关闭")) { dismiss() }
                }
            }
        }
    }
}
