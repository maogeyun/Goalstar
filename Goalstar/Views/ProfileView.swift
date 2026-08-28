import SwiftUI
import SwiftData
import UserNotifications

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var context
    @Query private var goals: [Goal]
    @Query private var tasks: [TaskItem]
    @Query private var sessions: [FocusSession]
    @Query private var habits: [Habit]

    @State private var activeSheet: ProfileSheet?
    @State private var showLockSettings = false
    @State private var showProPaywall = false

    private enum ProfileSheet: Identifiable {
        case editName, reminders, theme, storage, about, privacy
        var id: Self { self }
    }

    private var streak: Int {
        habits.map(\.streak).max() ?? 0
    }

    private var totalFocus: Int {
        sessions.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        ZStack {
            PageBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    GreetingBar(title: "我的", subtitle: "账户与偏好设置", reverse: true)
                    userCard
                    achievementCard
                    menuList
                }
                .padding(.horizontal, GSSpacing.page)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            store.loadProfile(context: context)
            store.loadProStatus()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .editName:
                EditProfileSheet()
                    .environmentObject(store)
            case .reminders:
                ProfileRemindersSheet()
                    .environmentObject(store)
            case .theme:
                ProfileInfoSheet(
                    title: "主题切换",
                    message: "当前为浅色模式，与设计稿一致。深色模式将在后续版本推出。"
                )
            case .storage:
                ProfileInfoSheet(
                    title: "数据存储",
                    message: "目标、任务、习惯与专注记录保存在本机。卸载 App 后数据不会自动恢复。"
                )
            case .about:
                ProfileAboutSheet(version: appVersion) {
                    activeSheet = .privacy
                }
            case .privacy:
                ProfilePrivacySheet()
            }
        }
        .sheet(isPresented: $showProPaywall) {
            ProPaywallSheet()
                .environmentObject(store)
                .presentationDetents([.large, .medium])
        }
        .sheet(isPresented: $showLockSettings) {
            LockScreenSettingsView()
                .environmentObject(store)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    private var userCard: some View {
        Button {
            activeSheet = .editName
        } label: {
            HStack(spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [GSColor.brand, GSColor.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .overlay(
                            Text(String(store.userName.prefix(1)))
                                .font(GSFont.bold(24))
                                .foregroundStyle(.white)
                        )
                    ZStack {
                        Circle().fill(GSColor.surfaceCard).frame(width: 22, height: 22)
                        GSIcon(name: .info, size: 12, color: GSColor.textSecondary)
                    }
                    .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(store.userName)
                            .font(GSFont.semibold(GSFont.hero))
                            .foregroundStyle(GSColor.textPrimary)
                        CategoryTag(
                            text: store.isPro ? "Pro" : "免费版",
                            color: store.isPro ? GSColor.brand : GSColor.textSecondary,
                            background: store.isPro ? GSColor.brandLight : GSColor.bgTertiary,
                            compact: true
                        )
                        Text("编辑")
                            .font(GSFont.semibold(GSFont.sm))
                            .foregroundStyle(GSColor.brand)
                    }
                    Text("把每一天画进自己的星图")
                        .font(GSFont.semibold(GSFont.md))
                        .foregroundStyle(GSColor.textSecondary)
                    Text("🔥 连续打卡 \(streak) 天")
                        .font(GSFont.semibold(GSFont.sm))
                        .foregroundStyle(GSColor.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(GSColor.warningLight)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                Spacer()
                GSIcon(name: .chevronRight, size: 16, color: GSColor.textSecondary)
            }
            .gsCard(radius: GSRadius.panel, padding: 16)
        }
        .buttonStyle(.plain)
    }

    private var achievementCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "我的成就")
            HStack(spacing: GSSpacing.sm) {
                InsetStatBlock(value: "\(goals.filter(\.isCompleted).count) 个", label: "已完成目标")
                InsetStatBlock(value: GSFormat.minutesLabel(totalFocus), label: "总专注")
                InsetStatBlock(value: "\(tasks.filter(\.isCompleted).count) 个", label: "完成任务")
            }
        }
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var menuList: some View {
        VStack(spacing: 0) {
            menuRow(icon: .star, title: "Goalstar Pro", trailing: store.isPro ? "已开通" : "升级") {
                showProPaywall = true
            }
            menuRow(icon: .lock, title: "锁屏待办", trailing: AppConstants.lockWidgetEnabled ? "\(AppConstants.lockWidgetCount)条" : "关闭") {
                showLockSettings = true
            }
            menuRow(icon: .bell, title: "提醒设置", trailing: "本地通知") {
                activeSheet = .reminders
            }
            menuRow(icon: .sun, title: "主题切换", trailing: "浅色模式") {
                activeSheet = .theme
            }
            menuRow(icon: .cloud, title: "数据存储", trailing: "仅本机") {
                activeSheet = .storage
            }
            #if DEBUG
            menuRow(icon: .circleX, title: "切换 Pro（调试）", trailing: store.isPro ? "开" : "关") {
                store.setProMock(!store.isPro)
            }
            #endif
            menuRow(icon: .info, title: "关于 Goalstar", trailing: appVersion, showDivider: false) {
                activeSheet = .about
            }
        }
        .gsCard(radius: GSRadius.panel, padding: 8)
    }

    private func menuRow(
        icon: GSIconName,
        title: String,
        trailing: String?,
        showDivider: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack {
                    HStack(spacing: 12) {
                        GSIcon(name: icon, size: 20, color: GSColor.textSecondary, lineWidth: 1.9)
                        Text(title)
                            .font(GSFont.semibold(GSFont.lg))
                            .foregroundStyle(GSColor.textPrimary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        if let trailing {
                            Text(trailing)
                                .font(GSFont.semibold(GSFont.md))
                                .foregroundStyle(GSColor.textSecondary)
                                .lineLimit(1)
                        }
                        GSIcon(name: .chevronRight, size: 18, color: GSColor.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showDivider {
                Rectangle()
                    .fill(GSColor.border.opacity(0.6))
                    .frame(height: 1)
                    .padding(.leading, 46)
            }
        }
    }

}

private struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("显示名称")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
                TextField("输入昵称", text: $name)
                    .textFieldStyle(GSTextFieldStyle())
                Text("昵称仅保存在本机。")
                    .font(GSFont.semibold(GSFont.sm))
                    .foregroundStyle(GSColor.textSecondary)
                Spacer()
                PrimaryButton(title: "保存") {
                    store.updateUserName(name, context: context)
                    dismiss()
                }
            }
            .padding(16)
            .background(PageBackground())
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { name = store.userName }
        }
    }
}

private struct ProfileRemindersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var tasksEnabled = AppConstants.sharedDefaults.object(forKey: AppConstants.notifyTasksEnabledKey) as? Bool ?? true
    @State private var habitsEnabled = AppConstants.sharedDefaults.object(forKey: AppConstants.notifyHabitsEnabledKey) as? Bool ?? true
    @State private var taskTime = defaultDate(hourKey: AppConstants.notifyTasksHourKey, minuteKey: AppConstants.notifyTasksMinuteKey, hour: 8, minute: 0)
    @State private var habitTime = defaultDate(hourKey: AppConstants.notifyHabitsHourKey, minuteKey: AppConstants.notifyHabitsMinuteKey, hour: 21, minute: 0)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    authCard

                    Toggle(isOn: $tasksEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("今日任务提醒")
                                .font(GSFont.semibold(GSFont.xl))
                            Text("每天提醒未完成的今日三件事")
                                .font(GSFont.semibold(GSFont.md))
                                .foregroundStyle(GSColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tint(GSColor.brand)
                    .gsCard(radius: GSRadius.panel, padding: 16)

                    if tasksEnabled {
                        DatePickerFormRow(
                            title: "提醒时间",
                            selection: $taskTime,
                            components: .hourAndMinute
                        )
                        .gsCard(radius: GSRadius.panel, padding: 16)
                    }

                    Toggle(isOn: $habitsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("习惯提醒（数据页查看记录）")
                                .font(GSFont.semibold(GSFont.xl))
                            Text("每日本地通知；可在今日页完成习惯打卡，记录见数据页热力图")
                                .font(GSFont.semibold(GSFont.md))
                                .foregroundStyle(GSColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tint(GSColor.brand)
                    .gsCard(radius: GSRadius.panel, padding: 16)

                    if habitsEnabled {
                        DatePickerFormRow(
                            title: "提醒时间",
                            selection: $habitTime,
                            components: .hourAndMinute
                        )
                        .gsCard(radius: GSRadius.panel, padding: 16)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("本地通知")
                            .font(GSFont.semibold(GSFont.xl))
                            .foregroundStyle(GSColor.textPrimary)
                        Text("任务与习惯提醒在此设置。锁屏小组件请到「我的 → 锁屏待办」。")
                            .font(GSFont.semibold(GSFont.md))
                            .foregroundStyle(GSColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .gsCard(radius: GSRadius.panel, padding: 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .background(PageBackground())
            .navigationTitle("提醒设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        saveAndReschedule()
                        dismiss()
                    }
                }
            }
            .task {
                authStatus = await NotificationScheduler.authorizationStatus()
            }
        }
    }

    private var authCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(authTitle)
                .font(GSFont.semibold(GSFont.xl))
                .foregroundStyle(GSColor.textPrimary)
            Text(authSubtitle)
                .font(GSFont.semibold(GSFont.md))
                .foregroundStyle(GSColor.textSecondary)
            if authStatus == .notDetermined {
                PrimaryButton(title: "开启通知权限") {
                    Task {
                        let ok = await NotificationScheduler.requestAuthorization()
                        authStatus = await NotificationScheduler.authorizationStatus()
                        if ok { saveAndReschedule() }
                    }
                }
            } else if authStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("前往系统设置")
                        .font(GSFont.semibold(GSFont.base))
                        .foregroundStyle(GSColor.brand)
                }
                .buttonStyle(.plain)
            }
        }
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var authTitle: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return "通知权限已开启"
        case .denied: return "通知权限已关闭"
        default: return "需要通知权限"
        }
    }

    private var authSubtitle: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return "将按你设定的时间发送本地提醒"
        case .denied: return "请在系统设置中允许 Goalstar 发送通知"
        default: return "开启后可接收任务与习惯的每日提醒"
        }
    }

    private func saveAndReschedule() {
        let cal = Calendar.current
        let defaults = AppConstants.sharedDefaults
        defaults.set(tasksEnabled, forKey: AppConstants.notifyTasksEnabledKey)
        defaults.set(habitsEnabled, forKey: AppConstants.notifyHabitsEnabledKey)
        defaults.set(cal.component(.hour, from: taskTime), forKey: AppConstants.notifyTasksHourKey)
        defaults.set(cal.component(.minute, from: taskTime), forKey: AppConstants.notifyTasksMinuteKey)
        defaults.set(cal.component(.hour, from: habitTime), forKey: AppConstants.notifyHabitsHourKey)
        defaults.set(cal.component(.minute, from: habitTime), forKey: AppConstants.notifyHabitsMinuteKey)
        store.refreshReminderBodies(context: context)
    }

    private static func defaultDate(hourKey: String, minuteKey: String, hour: Int, minute: Int) -> Date {
        let defaults = AppConstants.sharedDefaults
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = defaults.object(forKey: hourKey) as? Int ?? hour
        comps.minute = defaults.object(forKey: minuteKey) as? Int ?? minute
        return Calendar.current.date(from: comps) ?? Date()
    }
}

private struct ProfileInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(message)
                    .font(GSFont.semibold(GSFont.lg))
                    .foregroundStyle(GSColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
            }
            .background(PageBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private struct ProfileAboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let version: String
    var onPrivacy: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(GSColor.brandLight)
                        .frame(width: 72, height: 72)
                    GSIcon(name: .star, size: 36, color: GSColor.brand)
                }
                VStack(spacing: 6) {
                    Text("Goalstar")
                        .font(GSFont.semibold(22))
                        .foregroundStyle(GSColor.textPrimary)
                    Text(version)
                        .font(GSFont.semibold(GSFont.md))
                        .foregroundStyle(GSColor.textSecondary)
                }
                Text("把每一天画进自己的星图。Goalstar 帮助你管理目标、今日三件事、习惯打卡与专注时刻。")
                    .font(GSFont.semibold(GSFont.lg))
                    .foregroundStyle(GSColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button(action: onPrivacy) {
                    Text("查看隐私政策")
                        .font(GSFont.semibold(GSFont.lg))
                        .foregroundStyle(GSColor.brand)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(GSColor.brandLight.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(GSColor.brand, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(20)
            .background(PageBackground())
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private struct ProfilePrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    privacySection("数据存储", "目标、任务、习惯、专注记录与昵称保存在设备本地。我们不运营自有服务器存储你的内容。")
                    privacySection("网络与追踪", "本 App 不收集个人身份信息用于广告，不使用第三方追踪 SDK。")
                    privacySection("通知", "本地通知仅在设备上调度，用于任务与习惯提醒，不会上传到我们的服务器。")
                    privacySection("UserDefaults / App Group", "用于保存提醒开关、锁屏引导偏好等本地设置，并与 Widget 共享（可用时）。")
                    privacySection("联系方式", "如有隐私相关问题，请通过 App Store 产品页开发者联系方式与我们沟通。")
                    Text("最后更新：2026 年 8 月 27 日")
                        .font(GSFont.semibold(GSFont.sm))
                        .foregroundStyle(GSColor.textSecondary)
                        .padding(.top, 8)
                }
                .padding(16)
            }
            .background(PageBackground())
            .navigationTitle("隐私政策")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func privacySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(GSFont.semibold(GSFont.xl))
                .foregroundStyle(GSColor.textPrimary)
            Text(body)
                .font(GSFont.semibold(GSFont.lg))
                .foregroundStyle(GSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.card, padding: 14)
    }
}
