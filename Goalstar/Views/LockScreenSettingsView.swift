import SwiftUI
import SwiftData
import WidgetKit

struct LockScreenSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @Query(sort: \TaskItem.sortOrder)
    private var allTasks: [TaskItem]

    @State private var enabled = AppConstants.lockWidgetEnabled
    @State private var count = AppConstants.lockWidgetCount
    @State private var privacy = AppConstants.lockPrivacyMode

    private var previewTasks: [TaskItem] {
        let ranked = TodayTaskRanking.ranked(allTasks)
            .filter { $0.status != .done && $0.status != .skipped }
        let candidates = ranked.filter(\.isLockCandidate)
        let source = candidates.isEmpty ? ranked : (candidates + ranked.filter { !$0.isLockCandidate })
        return Array(source.prefix(count))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $enabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("启用锁屏待办")
                                .font(GSFont.semibold(GSFont.xl))
                            Text("控制小组件是否展示今日任务")
                                .font(GSFont.semibold(GSFont.md))
                                .foregroundStyle(GSColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tint(GSColor.brand)
                    .gsCard(radius: GSRadius.panel, padding: 16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("展示数量")
                            .font(GSFont.semibold(GSFont.xl))
                            .foregroundStyle(GSColor.textPrimary)
                        HStack(spacing: 8) {
                            ForEach([1, 2, 3], id: \.self) { n in
                                Button {
                                    count = n
                                } label: {
                                    Text("\(n)")
                                        .font(GSFont.semibold(GSFont.lg))
                                        .foregroundStyle(count == n ? GSColor.brand : GSColor.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(count == n ? GSColor.brandLight : GSColor.bgTertiary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(count == n ? GSColor.brand : Color.clear, lineWidth: 1)
                                        )
                                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .gsCard(radius: GSRadius.panel, padding: 16)

                    Toggle(isOn: $privacy) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("隐私模式")
                                .font(GSFont.semibold(GSFont.xl))
                            Text("锁屏仅显示「今日 N 件事」，不展示标题")
                                .font(GSFont.semibold(GSFont.md))
                                .foregroundStyle(GSColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tint(GSColor.brand)
                    .gsCard(radius: GSRadius.panel, padding: 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("自动选择规则")
                            .font(GSFont.semibold(GSFont.xl))
                            .foregroundStyle(GSColor.textPrimary)
                        Text("与今日排序一致：置顶 → 锁屏候选 → 进行中 → 优先 → 主目标 → 创建顺序。")
                            .font(GSFont.semibold(GSFont.md))
                            .foregroundStyle(GSColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .gsCard(radius: GSRadius.panel, padding: 16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("预览")
                            .font(GSFont.semibold(GSFont.xl))
                            .foregroundStyle(GSColor.textPrimary)
                        if !enabled {
                            Text("已关闭，小组件可显示空状态提示")
                                .font(GSFont.semibold(GSFont.md))
                                .foregroundStyle(GSColor.textSecondary)
                        } else if privacy {
                            Text("今日 \(previewTasks.count) 件事")
                                .font(GSFont.semibold(GSFont.lg))
                                .foregroundStyle(GSColor.textPrimary)
                        } else if previewTasks.isEmpty {
                            Text("暂无待展示任务")
                                .font(GSFont.semibold(GSFont.md))
                                .foregroundStyle(GSColor.textSecondary)
                        } else {
                            ForEach(previewTasks, id: \.id) { task in
                                HStack(spacing: 8) {
                                    Circle().stroke(GSColor.border, lineWidth: 1.5).frame(width: 14, height: 14)
                                    Text(task.title)
                                        .font(GSFont.semibold(GSFont.base))
                                        .foregroundStyle(GSColor.textPrimary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                    .gsCard(radius: GSRadius.panel, padding: 16)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("安装说明")
                            .font(GSFont.semibold(GSFont.xl))
                            .foregroundStyle(GSColor.textPrimary)
                        Text("长按锁屏 → 自定义 → 添加小组件 → Goalstar「今日三件事」。")
                            .font(GSFont.semibold(GSFont.md))
                            .foregroundStyle(GSColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            store.setWidgetGuideDismissed(false)
                            dismiss()
                            store.selectedTab = .today
                        } label: {
                            Text("在今日页显示添加引导")
                                .font(GSFont.semibold(GSFont.base))
                                .foregroundStyle(GSColor.brand)
                        }
                        .buttonStyle(.plain)
                    }
                    .gsCard(radius: GSRadius.panel, padding: 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .background(PageBackground())
            .navigationTitle("锁屏待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        persist()
                        dismiss()
                    }
                }
            }
        }
    }

    private func persist() {
        AppConstants.lockWidgetEnabled = enabled
        AppConstants.lockWidgetCount = count
        AppConstants.lockPrivacyMode = privacy
        store.setLockScreen(enabled)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
