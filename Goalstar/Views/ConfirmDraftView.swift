import SwiftUI

/// Editable confirm card inside CreateSheet. Nothing is written until Save.
struct ConfirmDraftView: View {
    @Binding var draft: GoalDraftDTO
    var isRegenerating: Bool
    var remainingRegen: Int?
    var notice: String?
    var limitMessage: String?
    var onRegen: () -> Void
    var onSave: () -> Void
    var onManual: () -> Void
    var onUpgradeGoalLimit: () -> Void

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    if let notice, !notice.isEmpty {
                        Text(notice)
                            .font(GSFont.semibold(GSFont.md))
                            .foregroundStyle(GSColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    nameCard
                    milestonesCard
                    tasksCard

                    if let limitMessage, !limitMessage.isEmpty {
                        Text(limitMessage)
                            .font(GSFont.semibold(GSFont.lg))
                            .foregroundStyle(GSColor.danger)
                            .fixedSize(horizontal: false, vertical: true)
                        if limitMessage == ProEntitlement.freeGoalLimitMessage {
                            OutlineActionButton(title: L10n.s("升级 Pro"), action: onUpgradeGoalLimit)
                        }
                    }
                }
                .padding(.horizontal, GSSpacing.page)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            bottomBar
        }
        .background(PageBackground())
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailFieldLabel(text: L10n.s("目标名称"))
            TextField(L10n.s("例如：系统学习英语"), text: $draft.name)
                .textFieldStyle(GSTextFieldStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var milestonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: L10n.s("阶段"))
                Spacer()
                Text("\(draft.milestones.count)/\(GoalDraftDTO.maxMilestones)")
                    .font(GSFont.semibold(GSFont.sm))
                    .foregroundStyle(GSColor.textSecondary)
            }
            ForEach($draft.milestones) { $milestone in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField(L10n.s("阶段名称"), text: $milestone.title)
                            .textFieldStyle(GSTextFieldStyle())
                        deleteButton {
                            removeMilestone(id: milestone.id)
                        }
                    }
                    TextField(L10n.s("简述（可选）"), text: $milestone.summary)
                        .textFieldStyle(GSTextFieldStyle())
                }
            }
            if draft.milestones.count < GoalDraftDTO.maxMilestones {
                OutlineActionButton(title: L10n.s("添加阶段")) {
                    draft.milestones.append(
                        GoalDraftDTO.Milestone(id: UUID(), title: "", summary: "")
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var tasksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: L10n.s("任务"))
                Spacer()
                Text("\(draft.tasks.count)/\(GoalDraftDTO.maxTasks)")
                    .font(GSFont.semibold(GSFont.sm))
                    .foregroundStyle(GSColor.textSecondary)
            }
            ForEach($draft.tasks) { $task in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField(L10n.s("任务名称"), text: $task.title)
                            .textFieldStyle(GSTextFieldStyle())
                        deleteButton {
                            draft.tasks.removeAll { $0.id == task.id }
                        }
                    }
                    if !draft.milestones.isEmpty {
                        MenuPickerFormRow(title: L10n.s("所属阶段"), selection: milestoneBinding(for: $task)) {
                            Text(L10n.s("无")).tag(Optional<UUID>.none)
                            ForEach(draft.milestones) { milestone in
                                Text(milestone.title.isEmpty ? L10n.s("未命名阶段") : milestone.title)
                                    .tag(Optional(milestone.id))
                            }
                        }
                    }
                }
            }
            if draft.tasks.count < GoalDraftDTO.maxTasks {
                OutlineActionButton(title: L10n.s("添加任务")) {
                    draft.tasks.append(GoalDraftDTO.Task(id: UUID(), title: "", milestoneIndex: nil))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Text(regenCaption)
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            OutlineActionButton(
                title: isRegenerating ? L10n.s("正在生成草稿…") : L10n.s("再生成"),
                action: onRegen
            )
            .disabled(isRegenerating)
            PrimaryButton(title: L10n.s("保存"), filled: !trimmedName.isEmpty && !isRegenerating, action: onSave)
                .disabled(trimmedName.isEmpty || isRegenerating)
                .opacity(trimmedName.isEmpty ? 0.45 : 1)
            Button(action: onManual) {
                Text(L10n.s("改用手动填写"))
                    .font(GSFont.semibold(GSFont.lg))
                    .foregroundStyle(GSColor.brand)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.plain)
            .disabled(isRegenerating)
        }
        .padding(.horizontal, GSSpacing.page)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(GSColor.surfaceCard)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(GSColor.border)
                .frame(height: 1)
        }
    }

    private var regenCaption: String {
        if let remainingRegen {
            if remainingRegen == 0 {
                return L10n.s("今日再生成次数已用完")
            }
            return L10n.f("还可再生成 %d 次", remainingRegen)
        }
        return L10n.s("再生成不限次数")
    }

    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(L10n.s("删除"))
                .font(GSFont.semibold(GSFont.md))
                .foregroundStyle(GSColor.danger)
        }
        .buttonStyle(.plain)
    }

    private func removeMilestone(id: UUID) {
        guard let index = draft.milestones.firstIndex(where: { $0.id == id }) else { return }
        draft.milestones.remove(at: index)
        draft.tasks = draft.tasks.map { task in
            var copy = task
            guard let milestoneIndex = copy.milestoneIndex else { return copy }
            if milestoneIndex == index {
                copy.milestoneIndex = nil
            } else if milestoneIndex > index {
                copy.milestoneIndex = milestoneIndex - 1
            }
            return copy
        }
    }

    private func milestoneBinding(for task: Binding<GoalDraftDTO.Task>) -> Binding<UUID?> {
        Binding(
            get: {
                guard let index = task.wrappedValue.milestoneIndex,
                      draft.milestones.indices.contains(index) else { return nil }
                return draft.milestones[index].id
            },
            set: { newID in
                task.wrappedValue.milestoneIndex = draft.milestones.firstIndex { $0.id == newID }
            }
        )
    }
}
