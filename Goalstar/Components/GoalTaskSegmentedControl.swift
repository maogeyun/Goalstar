import SwiftUI

/// Goal | Task switch. The task segment stays locked when there is no active goal.
/// Width is the parent minus 16 on each side. No caption is rendered under the control.
struct GoalTaskSegmentedControl: View {
    @Binding var mode: CreateFormMode
    var taskEnabled: Bool
    var goalTitle: String
    var taskTitle: String

    var body: some View {
        HStack(spacing: 4) {
            segment(.goal, title: goalTitle, enabled: true)
            segment(.task, title: taskTitle, enabled: taskEnabled)
        }
        .padding(3)
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .background(GSColor.bgTertiary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func segment(_ item: CreateFormMode, title: String, enabled: Bool) -> some View {
        let selected = mode == item
        return Button {
            guard enabled else { return }
            mode = item
        } label: {
            Text(title)
                .font(GSFont.medium(GSFont.lg))
                .foregroundStyle(foreground(selected: selected, enabled: enabled))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: Color(hex: 0x0F1729).opacity(0.08), radius: 2, x: 0, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func foreground(selected: Bool, enabled: Bool) -> Color {
        if !enabled { return GSColor.textSecondary.opacity(0.45) }
        return selected ? GSColor.textPrimary : GSColor.textSecondary
    }
}
