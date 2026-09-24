import SwiftUI
import SwiftData
import UIKit
import UserNotifications

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if notification.request.identifier == FocusEndNotifier.notificationID {
            return [.banner, .sound]
        }
        return [.banner, .sound]
    }
}

@main
struct GoalstarApp: App {
    @StateObject private var store = AppStore()
    @State private var showSplash = true
    private let container = Persistence.makeContainer()
    private let notificationDelegate = AppNotificationDelegate()

    init() {
        // Keep the first SwiftUI frame aligned with the static launch screen.
        UIWindow.appearance().backgroundColor = UIColor(named: "LaunchScreenBackground")
        let tabBar = UITabBar.appearance()
        tabBar.tintColor = UIColor(GSColor.brandDeep)
        tabBar.unselectedItemTintColor = UIColor(Color(hex: 0x1A1A1A))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                    .environmentObject(store)
                    .modelContainer(container)
                    .preferredColorScheme(.light)
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView()
                        .transition(
                            .asymmetric(
                                insertion: .opacity,
                                removal: .opacity.combined(with: .scale(scale: 0.98))
                            )
                        )
                        .zIndex(1)
                }
            }
            .background(PageBackground())
            .animation(.easeOut(duration: 0.35), value: showSplash)
            .onAppear {
                UNUserNotificationCenter.current().delegate = notificationDelegate
                Persistence.seedIfNeeded(context: container.mainContext)
                applyLaunchArguments(context: container.mainContext)
                store.loadProfile(context: container.mainContext)
                store.startStoreKit()
                store.refreshReminderBodies(context: container.mainContext)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                    showSplash = false
                }
            }
        }
    }

    private func applyLaunchArguments(context: ModelContext) {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-tab"), args.indices.contains(idx + 1) {
            switch args[idx + 1] {
            case "goals": store.selectedTab = .goals
            case "focus": store.selectedTab = .focus
            case "data": store.selectedTab = .data
            case "profile": store.selectedTab = .profile
            default: store.selectedTab = .today
            }
        }
        #if DEBUG
        if args.contains("-seedDemo") {
            Persistence.seedDemoData(context: context)
        }
        #endif
    }
}

struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<Goal> { !$0.isCompleted }, sort: \Goal.createdAt)
    private var goals: [Goal]
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]

    var body: some View {
        rootTabView
        .ignoresSafeArea(.keyboard)
        .onChange(of: store.showFinishFocusConfirm) { wasShowing, isShowing in
            if wasShowing, !isShowing {
                store.handleFinishFocusConfirmDismissed(context: context, goals: goals)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            store.reconcileFocusFromLiveActivityIfNeeded()
            store.consumePendingEndFocusFromLiveActivity(goals: goals)
        }
        .onAppear {
            store.loadProfile(context: context)
            store.reconcileFocusFromLiveActivityIfNeeded()
            store.consumePendingEndFocusFromLiveActivity(goals: goals)
        }
        .sheet(isPresented: $store.showCreateSheet, onDismiss: {
            store.clearCreateSheetPreferences()
            DispatchQueue.main.async {
                store.presentPendingProPaywallIfNeeded()
                store.presentPendingCreateSheetIfNeeded()
            }
        }) {
            CreateSheet()
                .environmentObject(store)
                .presentationDetents([.large, .medium])
        }
        .sheet(isPresented: $store.showProPaywall) {
            ProPaywallSheet()
                .environmentObject(store)
                .presentationDetents([.large, .medium])
        }
        .sheet(isPresented: $store.showTomorrowPreview, onDismiss: {
            DispatchQueue.main.async {
                store.presentPendingCreateSheetIfNeeded()
            }
        }) {
            TomorrowPreviewSheet()
                .environmentObject(store)
                .presentationDetents([PresentationDetent.medium])
        }
        .onChange(of: store.pendingCreateAfterDismiss) { _, pending in
            guard pending, !store.showCreateSheet, !store.showTomorrowPreview else { return }
            DispatchQueue.main.async {
                store.presentPendingCreateSheetIfNeeded()
            }
        }
        .alert("数据提示", isPresented: Binding(
            get: { store.lastSaveError != nil },
            set: { if !$0 { store.lastSaveError = nil } }
        )) {
            Button("知道了", role: .cancel) {
                store.lastSaveError = nil
            }
        } message: {
            if let error = store.lastSaveError {
                Text(error)
            }
        }
        .confirmationDialog(
            "当前有进行中的专注，是否放弃并开始新的专注？",
            isPresented: $store.showInterruptFocusConfirm,
            titleVisibility: .visible
        ) {
            Button("放弃并开始", role: .destructive) {
                store.confirmInterruptFocus(andStartPendingTask: true, allTasks: tasks)
            }
            Button("取消", role: .cancel) {
                store.cancelInterruptFocus()
            }
        }
        .confirmationDialog("确定放弃本次专注？", isPresented: $store.showAbandonFocusConfirm, titleVisibility: .visible) {
            Button("放弃", role: .destructive) {
                store.abandonFocus()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("未保存的计时时长将不会写入记录。")
        }
        .confirmationDialog(
            store.activeFocusTaskTitle == nil ? "结束本次专注？" : "结束专注并处理任务",
            isPresented: $store.showFinishFocusConfirm,
            titleVisibility: .visible
        ) {
            if store.activeFocusTaskTitle != nil {
                Button("结束并完成任务") {
                    store.finishFocus(completeTask: true, context: context, goals: goals, tasks: tasks)
                }
                Button("仅结束专注") {
                    store.finishFocus(completeTask: false, context: context, goals: goals, tasks: tasks)
                }
            } else {
                Button("结束并保存记录") {
                    store.finishFocus(completeTask: false, context: context, goals: goals, tasks: tasks)
                }
            }
            Button("放弃本次", role: .destructive) {
                store.abandonFocus()
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let title = store.activeFocusTaskTitle {
                Text("当前任务：\(title)")
            } else {
                Text("已计时时长将写入专注记录")
            }
        }
    }

    private var rootTabView: some View {
        Group {
            if #available(iOS 18.0, *) {
                modernTabs
            } else {
                legacyTabs
            }
        }
        .modifier(RootTabBarChrome())
    }

    @available(iOS 18.0, *)
    private var modernTabs: some View {
        TabView(selection: $store.selectedTab) {
            Tab(value: AppStore.AppTab.today) {
                tabPage(.today)
            } label: {
                tabLabel(.today)
            }
            Tab(value: AppStore.AppTab.goals) {
                tabPage(.goals)
            } label: {
                tabLabel(.goals)
            }
            Tab(value: AppStore.AppTab.focus) {
                tabPage(.focus)
            } label: {
                tabLabel(.focus)
            }
            Tab(value: AppStore.AppTab.data) {
                tabPage(.data)
            } label: {
                tabLabel(.data)
            }
            Tab(value: AppStore.AppTab.profile) {
                tabPage(.profile)
            } label: {
                tabLabel(.profile)
            }
        }
    }

    private var legacyTabs: some View {
        TabView(selection: $store.selectedTab) {
            tabPage(.today)
                .tabItem { tabLabel(.today) }
                .tag(AppStore.AppTab.today)
            tabPage(.goals)
                .tabItem { tabLabel(.goals) }
                .tag(AppStore.AppTab.goals)
            tabPage(.focus)
                .tabItem { tabLabel(.focus) }
                .tag(AppStore.AppTab.focus)
            tabPage(.data)
                .tabItem { tabLabel(.data) }
                .tag(AppStore.AppTab.data)
            tabPage(.profile)
                .tabItem { tabLabel(.profile) }
                .tag(AppStore.AppTab.profile)
        }
    }

    /// Only the selected page is mounted, matching the previous switch.
    /// TabView would otherwise build every page and fire their `onAppear` early.
    @ViewBuilder
    private func tabPage(_ tab: AppStore.AppTab) -> some View {
        Group {
            if store.selectedTab == tab {
                switch tab {
                case .today: TodayView()
                case .goals: GoalsView()
                case .focus: FocusView()
                case .data: DataView()
                case .profile: ProfileView()
                }
            } else {
                PageBackground()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tabLabel(_ tab: AppStore.AppTab) -> some View {
        Label {
            Text(tab.title)
        } icon: {
            GSTabSymbol.image(tab)
        }
    }
}

/// iOS 26: system Liquid Glass capsule. Reduce Transparency swaps that capsule
/// for the solid plate in the dual-state frame. A custom bar background would
/// replace both. Older systems get the solid system tab bar.
private struct RootTabBarChrome: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(GSColor.surfaceCard, for: .tabBar)
        }
    }
}
