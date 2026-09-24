import SwiftUI

/// Editable confirm card inside CreateSheet. Nothing is written until Save.
/// The list scrolls above a sticky footer (再生成 / 保存 / 改用手动).
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

    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    Text(L10n.s("保存前可编辑 · 取消不落库 · AI 保存一次写入 Goal+阶段+任务"))
                        .font(GSFont.semibold(GSFont.sm))
                        .foregroundStyle(GSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let notice, !notice.isEmpty {
                        Text(notice)
                            .font(GSFont.semibold(GSFont.md))
                            .foregroundStyle(GSColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    nameCard
                    structureSection

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PageBackground())
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DetailFieldLabel(text: L10n.s("目标名称"))
                Spacer(minLength: 8)
                Button(L10n.s("编辑")) { nameFocused = true }
                    .font(GSFont.semibold(GSFont.base))
                    .foregroundStyle(GSColor.brand)
                    .buttonStyle(.plain)
            }
            TextField(L10n.s("例如：系统学习英语"), text: $draft.name)
                .textFieldStyle(GSTextFieldStyle())
                .focused($nameFocused)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var structureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.s("阶段与任务（阶段≤5 · 任务≤8）"))
                .font(GSFont.semibold(GSFont.md))
                .foregroundStyle(GSColor.textSecondary)

            ForEach(draft.milestones) { milestone in
                if let index = draft.milestones.firstIndex(where: { $0.id == milestone.id }) {
                    milestoneCard(index: index)
                }
            }

            let unassigned = draft.tasks.filter { $0.milestoneIndex == nil }
            if !unassigned.isEmpty {
                unassignedCard
            }

            if draft.milestones.isEmpty && draft.tasks.count < GoalDraftDTO.maxTasks {
                addLink(title: L10n.s("添加任务")) {
                    draft.tasks.append(GoalDraftDTO.Task(id: UUID(), title: "", milestoneIndex: nil))
                }
            }

            if draft.milestones.count < GoalDraftDTO.maxMilestones {
                addLink(title: L10n.s("添加阶段")) {
                    draft.milestones.append(
                        GoalDraftDTO.Milestone(id: UUID(), title: "", summary: "")
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func milestoneCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("≡")
                    .font(GSFont.semibold(GSFont.lg))
                    .foregroundStyle(GSColor.textSecondary)
                    .accessibilityHidden(true)
                TextField(L10n.s("阶段名称"), text: $draft.milestones[index].title)
                    .textFieldStyle(GSTextFieldStyle())
                deleteButton {
                    removeMilestone(id: draft.milestones[index].id)
                }
            }
            TextField(L10n.s("简述（可选）"), text: $draft.milestones[index].summary)
                .textFieldStyle(GSTextFieldStyle())

            ForEach(draft.tasks.filter { $0.milestoneIndex == index }) { task in
                taskRow(taskID: task.id)
            }

            if draft.tasks.count < GoalDraftDTO.maxTasks {
                addLink(title: L10n.s("添加任务")) {
                    draft.tasks.append(
                        GoalDraftDTO.Task(id: UUID(), title: "", milestoneIndex: index)
                    )
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GSColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous)
                .stroke(GSColor.border, lineWidth: 1)
        )
    }

    private var unassignedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.s("未归入阶段"))
                .font(GSFont.semibold(GSFont.md))
                .foregroundStyle(GSColor.textSecondary)
            ForEach(draft.tasks.filter { $0.milestoneIndex == nil }) { task in
                VStack(alignment: .leading, spacing: 4) {
                    taskRow(taskID: task.id)
                    if !draft.milestones.isEmpty {
                        milestoneMenu(taskID: task.id)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GSColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous)
                .stroke(GSColor.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func taskRow(taskID: UUID) -> some View {
        if let taskIndex = draft.tasks.firstIndex(where: { $0.id == taskID }) {
            HStack(spacing: 8) {
                Text("≡")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
                    .accessibilityHidden(true)
                TextField(L10n.s("任务名称"), text: $draft.tasks[taskIndex].title)
                    .font(GSFont.semibold(GSFont.xl))
                    .foregroundStyle(GSColor.textPrimary)
                deleteButton {
                    draft.tasks.removeAll { $0.id == taskID }
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(GSColor.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: onRegen) {
                    HStack(spacing: 6) {
                        if isRegenerating {
                            ProgressView()
                                .controlSize(.small)
                                .tint(GSColor.brand)
                        }
                        Text(isRegenerating ? L10n.s("正在生成草稿…") : L10n.s("再生成"))
                            .font(GSFont.semibold(GSFont.base))
                    }
                    .foregroundStyle(GSColor.brand)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(GSColor.brandLight)
                    .overlay(Capsule().stroke(GSColor.brand, lineWidth: 1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isRegenerating)

                Spacer(minLength: 8)

                Text(quotaLabel)
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
                    .lineLimit(1)
            }

            PrimaryButton(
                title: L10n.s("保存"),
                filled: !trimmedName.isEmpty && !isRegenerating,
                height: 46,
                action: onSave
            )
            .disabled(trimmedName.isEmpty || isRegenerating)
            .opacity(trimmedName.isEmpty ? 0.45 : 1)

            Button(action: onManual) {
                Text(L10n.s("改用手动填写（只建目标壳，不写阶段/任务）"))
                    .font(GSFont.semibold(GSFont.base))
                    .foregroundStyle(GSColor.brand)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(isRegenerating)
        }
        .padding(.horizontal, GSSpacing.page)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(GSColor.surfaceCard)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(GSColor.border)
                .frame(height: 1)
        }
    }

    private var quotaLabel: String {
        if let remainingRegen {
            return L10n.f("今日剩余 %d/3", remainingRegen)
        }
        return L10n.s("不限次数")
    }

    private func milestoneMenu(taskID: UUID) -> some View {
        Menu {
            ForEach(Array(draft.milestones.enumerated()), id: \.element.id) { index, milestone in
                Button(milestone.title.isEmpty ? L10n.s("未命名阶段") : milestone.title) {
                    guard let taskIndex = draft.tasks.firstIndex(where: { $0.id == taskID }) else { return }
                    draft.tasks[taskIndex].milestoneIndex = index
                }
            }
        } label: {
            Text(L10n.s("所属阶段"))
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.brand)
        }
    }

    private func addLink(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("+ \(title)")
                .font(GSFont.semibold(GSFont.base))
                .foregroundStyle(GSColor.brand)
        }
        .buttonStyle(.plain)
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
}
