import SwiftUI

enum GoalAIPresentation {
    case ready
    case generating
    case unavailable
}

/// One-liner block on the goal segment. Context chips only enrich the on-device prompt.
/// They never write the 1.0 type preset, category, or emoji.
struct GoalAISection: View {
    @Binding var prompt: String
    @Binding var chips: Set<GoalContextChip>
    var presentation: GoalAIPresentation
    var focused: FocusState<Bool>.Binding
    var onGenerate: () -> Void
    var onCancel: () -> Void

    private var canGenerate: Bool {
        presentation == .ready
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        switch presentation {
        case .unavailable:
            unavailableCard
        case .ready, .generating:
            entryCard
        }
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.s("一句话生成（暂不可用）"))
                .font(GSFont.semibold(GSFont.xl))
                .foregroundStyle(GSColor.textPrimary)
            Text(L10n.s("设备支持且模型可用时可重试"))
                .font(GSFont.semibold(GSFont.md))
                .foregroundStyle(GSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
        .opacity(0.55)
    }

    private var entryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.s("一句话生成"))
                    .font(GSFont.semibold(GSFont.xl))
                    .foregroundStyle(GSColor.textPrimary)
                Text(L10n.s("用一句话描述你想达成的目标，本机生成可编辑阶段与任务。"))
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField(
                L10n.s("例：三个月内通过 CET-6，每周阅读 5 篇文章"),
                text: $prompt,
                axis: .vertical
            )
            .lineLimit(2...4)
            .font(GSFont.semibold(GSFont.xl))
            .foregroundStyle(GSColor.textPrimary)
            .padding(12)
            .frame(minHeight: 72, alignment: .topLeading)
            .background(GSColor.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous))
            .focused(focused)
            .disabled(presentation == .generating)
            .submitLabel(.done)

            Text(L10n.s("可选情境（可多选）"))
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.textSecondary)

            HStack(spacing: 8) {
                ForEach(GoalContextChip.allCases) { item in
                    SelectableCapsuleChip(
                        title: item.title(language: AppLanguagePreference.current),
                        selected: chips.contains(item)
                    ) {
                        toggle(item)
                    }
                    .disabled(presentation == .generating)
                }
            }

            if presentation == .generating {
                generatingButton
                fullWidthOutline(title: L10n.s("取消"), action: onCancel)
                Text(L10n.s("阶段 ≤5 · 任务 ≤8 · 可取消回手动"))
                    .font(GSFont.semibold(GSFont.sm))
                    .foregroundStyle(GSColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                PrimaryButton(
                    title: L10n.s("生成草稿"),
                    filled: canGenerate,
                    height: 46,
                    action: onGenerate
                )
                .disabled(!canGenerate)
                .opacity(canGenerate ? 1 : 0.45)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.s("首次生成免费 · 再生成每日 3 次（与目标数上限分开）"))
                        .font(GSFont.semibold(GSFont.sm))
                    Text(L10n.s("仅在设备端运行，不上传内容"))
                        .font(GSFont.regular(GSFont.sm))
                }
                .foregroundStyle(GSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var generatingButton: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(.white)
            Text(L10n.s("正在生成草稿…"))
                .font(GSFont.semibold(GSFont.xl))
        }
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(GSColor.brand.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: GSRadius.panel, style: .continuous))
    }

    private func fullWidthOutline(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(GSFont.semibold(GSFont.xl))
                .foregroundStyle(GSColor.brand)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(GSColor.surfaceCard)
                .overlay(
                    RoundedRectangle(cornerRadius: GSRadius.panel, style: .continuous)
                        .stroke(GSColor.brand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: GSRadius.panel, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ item: GoalContextChip) {
        if chips.contains(item) {
            chips.remove(item)
        } else {
            chips.insert(item)
        }
    }
}

struct SelectableCapsuleChip: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GSFont.semibold(GSFont.base))
                .foregroundStyle(selected ? Color.white : GSColor.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 32)
                .background(selected ? GSColor.brand : GSColor.bgTertiary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
