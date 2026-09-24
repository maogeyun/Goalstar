import SwiftUI

/// One-liner block mounted only on the goal segment of CreateSheet.
struct GoalAISection: View {
    @Binding var prompt: String
    @Binding var chip: GoalContextChip?
    var isGenerating: Bool
    var notice: String?
    var focused: FocusState<Bool>.Binding
    var onGenerate: () -> Void
    var onCancel: () -> Void

    private var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                DetailFieldLabel(text: L10n.s("用一句话描述你的目标"))
                TextField(L10n.s("例如：三个月学会晨跑"), text: $prompt)
                    .textFieldStyle(GSTextFieldStyle())
                    .focused(focused)
                    .submitLabel(.done)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(GoalContextChip.allCases) { item in
                        Button {
                            chip = chip == item ? nil : item
                        } label: {
                            CategoryTag(
                                text: item.title(language: AppLanguagePreference.current),
                                color: chip == item ? GSColor.brand : GSColor.textPrimary,
                                background: chip == item ? GSColor.brandLight : GSColor.bgTertiary
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if isGenerating {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(GSColor.brand)
                    Text(L10n.s("正在生成草稿…"))
                        .font(GSFont.semibold(GSFont.lg))
                        .foregroundStyle(GSColor.textSecondary)
                    Spacer(minLength: 0)
                }
                OutlineActionButton(title: L10n.s("取消"), action: onCancel)
            } else {
                PrimaryButton(title: L10n.s("生成草稿"), filled: canGenerate, action: onGenerate)
                    .disabled(!canGenerate)
                    .opacity(canGenerate ? 1 : 0.45)
            }

            if let notice, !notice.isEmpty {
                Text(notice)
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }
}
