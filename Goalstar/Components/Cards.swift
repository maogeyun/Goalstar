import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var size: CGFloat = 72
    var lineWidth: CGFloat = 7
    var trackColor: Color = GSColor.brand200.opacity(0.55)
    var fillColor: Color = GSColor.brand
    var centerText: String?

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(fillColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let centerText {
                Text(centerText)
                    .font(GSFont.semibold(size >= 100 ? 28 : GSFont.title))
                    .foregroundStyle(GSColor.textPrimary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct MetricChip: View {
    var icon: GSIconName
    var text: String
    var tint: Color
    var background: Color

    var body: some View {
        HStack(spacing: 4) {
            GSIcon(name: icon, size: 12, color: tint)
            Text(text)
                .font(GSFont.semibold(GSFont.md))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(background)
        .clipShape(Capsule())
    }
}

struct CategoryTag: View {
    var text: String
    var color: Color = GSColor.brand
    var background: Color = GSColor.brandLight
    var compact: Bool = false

    var body: some View {
        Text(text)
            .font(GSFont.semibold(compact ? GSFont.xs : GSFont.base, relativeTo: .caption))
            .foregroundStyle(color)
            .padding(.horizontal, compact ? 6 : 12)
            .padding(.vertical, compact ? 3 : 7)
            .frame(minHeight: compact ? 22 : 32)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: GSRadius.tag, style: .continuous))
    }
}

struct DetailFieldLabel: View {
    var text: String

    var body: some View {
        Text(text)
            .font(GSFont.semibold(GSFont.base, relativeTo: .caption))
            .foregroundStyle(GSColor.textSecondary)
    }
}

struct DetailFormRow<Content: View>: View {
    var label: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if let label {
                HStack(spacing: 12) {
                    Text(label)
                        .font(GSFont.semibold(GSFont.lg))
                        .foregroundStyle(GSColor.textPrimary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    content()
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack {
                    content()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
        .background(GSColor.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous))
    }
}

/// Left title + right date/time picker in one row (shared across create/edit forms).
struct DatePickerFormRow: View {
    var title: String
    @Binding var selection: Date
    var range: ClosedRange<Date>? = nil
    var components: DatePickerComponents = [.date]

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(GSFont.semibold(GSFont.lg))
                .foregroundStyle(GSColor.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 8)
            picker
                .labelsHidden()
                .tint(GSColor.brand)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
        .background(GSColor.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous))
    }

    @ViewBuilder
    private var picker: some View {
        if let range {
            DatePicker("", selection: $selection, in: range, displayedComponents: components)
        } else {
            DatePicker("", selection: $selection, displayedComponents: components)
        }
    }
}

/// Left title + right menu picker; selected value stays single-line and trailing-aligned.
struct MenuPickerFormRow<Selection: Hashable, Content: View>: View {
    var title: String
    @Binding var selection: Selection
    @ViewBuilder var content: () -> Content

    var body: some View {
        DetailFormRow(label: title) {
            Picker(title, selection: $selection) {
                content()
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(GSColor.brand)
        }
    }
}

struct DetailListRow: View {
    var title: String
    var subtitle: String? = nil
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(GSFont.semibold(GSFont.lg))
                .foregroundStyle(GSColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let subtitle {
                Text(subtitle)
                    .font(GSFont.semibold(GSFont.sm))
                    .foregroundStyle(GSColor.textSecondary)
            }
            if showsChevron {
                GSIcon(name: .chevronRight, size: 14, color: GSColor.textSecondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

struct DestructiveActionButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .font(GSFont.semibold(GSFont.lg))
                .foregroundStyle(GSColor.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(GSColor.dangerLight)
                .clipShape(RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct TaskCardView: View {
    let task: TaskItem
    var onToggle: () -> Void
    var onPlay: () -> Void
    var onTap: (() -> Void)? = nil

    private var isDone: Bool { task.status == .done }
    private var isSkipped: Bool { task.status == .skipped }
    private var isActionable: Bool { !task.status.isDoneLike }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .stroke(checkboxStroke, lineWidth: 2)
                            .background(Circle().fill(checkboxFill))
                        if isDone {
                            GSIcon(name: .check, size: 12, color: .white, lineWidth: 2)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .opacity(isSkipped ? 0.5 : 1)
                    .padding(10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(-10)

                if !isDone && !isSkipped {
                    if task.isPinned {
                        GSIcon(name: .star, size: 14, color: GSColor.brand, lineWidth: 1.6)
                    } else if task.isPriority {
                        GSIcon(name: .flame, size: 16, color: GSColor.warning, lineWidth: 1.6)
                    }
                }
            }

            Button {
                onTap?()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(GSFont.semibold(GSFont.xl))
                            .foregroundStyle(titleColor)
                            .strikethrough(isDone || isSkipped, color: GSColor.textSecondary)
                            .lineLimit(1)
                        if task.status == .inProgress {
                            CategoryTag(
                                text: "进行中",
                                color: GSColor.brand,
                                background: GSColor.brandLight,
                                compact: true
                            )
                        } else if isDone {
                            CategoryTag(
                                text: "已完成",
                                color: GSColor.successDark,
                                background: GSColor.successLight,
                                compact: true
                            )
                        } else if isSkipped {
                            CategoryTag(
                                text: "已跳过",
                                color: GSColor.textSecondary,
                                background: GSColor.bgTertiary,
                                compact: true
                            )
                        }
                    }
                    if task.goal != nil || task.displayMilestone != nil {
                        HStack(spacing: 6) {
                            if let goal = task.goal {
                                CategoryTag(
                                    text: "\(goal.emoji) \(goal.name)",
                                    color: isDone ? GSColor.textSecondary : Color(hex: goal.accentHex),
                                    background: isDone
                                        ? GSColor.bgTertiary
                                        : Color(hex: goal.accentHex).opacity(0.12),
                                    compact: true
                                )
                            }
                            if let milestone = task.displayMilestone {
                                CategoryTag(
                                    text: milestone.title,
                                    color: GSColor.textSecondary,
                                    background: GSColor.bgTertiary,
                                    compact: true
                                )
                            }
                        }
                    }
                    if !Calendar.current.isDate(task.scheduledDate, inSameDayAs: task.endDate) {
                        Text(GSFormat.dateRangeLabel(start: task.scheduledDate, end: task.endDate))
                            .font(GSFont.semibold(GSFont.md))
                            .foregroundStyle(GSColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Text("\(task.durationMinutes) min")
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
                if isActionable {
                    Button(action: onPlay) {
                        ZStack {
                            Circle().fill(GSColor.brand)
                            GSIcon(name: .play, size: 14, color: .white, lineWidth: 1.8)
                        }
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: GSRadius.card, style: .continuous))
        .shadow(color: GSColor.cardShadow, radius: isDone ? 4 : 6, x: 0, y: isDone ? 2 : 4)
    }

    private var titleColor: Color {
        if isDone || isSkipped { return GSColor.textSecondary }
        return GSColor.textPrimary
    }

    private var checkboxStroke: Color {
        if isDone { return GSColor.success }
        if isSkipped { return GSColor.border }
        return GSColor.border
    }

    private var checkboxFill: Color {
        if isDone { return GSColor.success }
        return Color.clear
    }

    private var cardBackground: Color {
        if isDone { return GSColor.successLight }
        if isSkipped { return GSColor.bgTertiary }
        return GSColor.surfaceCard
    }

    private var cardBorder: Color {
        if isDone { return GSColor.success.opacity(0.28) }
        if isSkipped { return GSColor.border }
        return Color.clear
    }
}

struct GoalCardView: View {
    let goal: Goal
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: goal.accentHex))
                        .frame(width: 8, height: 8)
                    Text(goal.name)
                        .font(GSFont.semibold(GSFont.xxl))
                        .foregroundStyle(GSColor.textPrimary)
                }
                Spacer()
                Text("\(Int(goal.progress * 100))%")
                    .font(GSFont.semibold(GSFont.xl))
                    .foregroundStyle(GSColor.textPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(GSColor.bgTertiary).frame(height: 8)
                    Capsule()
                        .fill(Color(hex: goal.accentHex))
                        .frame(width: max(8, geo.size.width * goal.progress), height: 8)
                }
            }
            .frame(height: 8)

            if !compact {
                HStack {
                    Text("第 \(goal.currentDay) / \(goal.totalDays) 天")
                        .font(GSFont.semibold(GSFont.md))
                        .foregroundStyle(GSColor.textSecondary)
                    Spacer()
                    CategoryTag(
                        text: "\(goal.emoji) \(goal.category)",
                        color: Color(hex: goal.accentHex),
                        background: Color(hex: goal.accentHex).opacity(0.12),
                        compact: true
                    )
                }
            }
        }
        .gsCard(radius: GSRadius.card, padding: 16)
    }
}

struct MetricCard: View {
    var icon: GSIconName
    var value: String
    var label: String
    var tint: Color = GSColor.brand

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GSIcon(name: icon, size: 18, color: tint)
            Text(value)
                .font(GSFont.semibold(GSFont.xxl))
                .foregroundStyle(GSColor.textPrimary)
            Text(label)
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.card, padding: 12)
    }
}

struct OutlineActionButton: View {
    var title: String
    var height: CGFloat = 40
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GSFont.semibold(GSFont.base))
                .foregroundStyle(GSColor.brand)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(GSColor.brandLight.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous)
                        .stroke(GSColor.brand.opacity(0.35), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateCard: View {
    var icon: GSIconName
    var title: String
    var message: String
    var actionTitle: String? = nil
    var compact: Bool = false
    var embedded: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: compact ? 10 : 16) {
            ZStack {
                Circle()
                    .fill(GSColor.brandLight)
                    .frame(width: compact ? 56 : 88, height: compact ? 56 : 88)
                GSIcon(name: icon, size: compact ? 24 : 40, color: GSColor.brand)
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(GSFont.semibold(compact ? GSFont.xl : GSFont.title))
                    .foregroundStyle(GSColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(GSFont.semibold(compact ? GSFont.md : GSFont.lg))
                    .foregroundStyle(GSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                if compact {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(GSFont.semibold(GSFont.base))
                            .foregroundStyle(GSColor.brand)
                    }
                    .buttonStyle(.plain)
                } else {
                    PrimaryButton(title: actionTitle, action: action)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .modifier(EmptyStateCardStyle(compact: compact, embedded: embedded))
    }
}

private struct EmptyStateCardStyle: ViewModifier {
    var compact: Bool
    var embedded: Bool

    func body(content: Content) -> some View {
        if embedded {
            content
        } else {
            content.gsCard(radius: GSRadius.panel, padding: compact ? 16 : 20)
        }
    }
}

struct InsetStatBlock: View {
    var value: String
    var label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(GSFont.semibold(GSFont.hero))
                .foregroundStyle(GSColor.textPrimary)
            Text(label)
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GSSpacing.md)
        .background(GSColor.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: GSRadius.control, style: .continuous))
    }
}

struct CompactCapsuleButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GSFont.semibold(GSFont.base))
                .foregroundStyle(GSColor.textOnPrimary)
                .padding(.horizontal, GSSpacing.base)
                .padding(.vertical, GSSpacing.sm)
                .background(GSColor.brand)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton: View {
    var title: String
    var icon: GSIconName? = nil
    var filled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    GSIcon(name: icon, size: 22, color: filled ? .white : GSColor.brand, lineWidth: 2)
                }
                Text(title)
                    .font(GSFont.semibold(GSFont.xxl))
            }
            .foregroundStyle(filled ? Color.white : GSColor.brand)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(filled ? GSColor.brand : GSColor.brandLight.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: GSRadius.panel, style: .continuous)
                    .stroke(GSColor.brand, lineWidth: filled ? 0 : 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: GSRadius.panel, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: GSRadius.panel, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct FABButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(GSColor.brand)
                    .frame(width: 54, height: 54)
                    .shadow(color: GSColor.brand.opacity(0.35), radius: 10, x: 0, y: 6)
                GSIcon(name: .plus, size: 24, color: .white, lineWidth: 2.2)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("新建")
    }
}

struct GSTabBar: View {
    @Binding var selection: AppStore.AppTab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(GSColor.border)
                .frame(height: 1)
            HStack(spacing: 0) {
                ForEach(AppStore.AppTab.allCases) { tab in
                    Button {
                        selection = tab
                    } label: {
                        VStack(spacing: 4) {
                            GSIcon(
                                name: tab.icon,
                                size: 20,
                                color: selection == tab ? GSColor.brandDeep : GSColor.textSecondary,
                                lineWidth: selection == tab ? 2 : 1.6
                            )
                            Text(tab.title)
                                .font(GSFont.semibold(GSFont.xs + 2))
                                .foregroundStyle(selection == tab ? GSColor.brandDeep : GSColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 49)
            .padding(.horizontal, 12)
        }
        .background(GSColor.surfaceCard.ignoresSafeArea(edges: .bottom))
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(GSFont.semibold(GSFont.xxl))
                .foregroundStyle(GSColor.textPrimary)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(GSFont.semibold(GSFont.md))
                    .foregroundStyle(GSColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GreetingBar: View {
    var title: String
    var subtitle: String
    var reverse: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if reverse {
                Text(title)
                    .font(GSFont.semibold(GSFont.hero))
                    .foregroundStyle(GSColor.textPrimary)
                Text(subtitle)
                    .font(GSFont.semibold(GSFont.base))
                    .foregroundStyle(GSColor.textSecondary)
            } else {
                Text(subtitle)
                    .font(GSFont.semibold(GSFont.base))
                    .foregroundStyle(GSColor.textSecondary)
                Text(title)
                    .font(GSFont.semibold(GSFont.hero))
                    .foregroundStyle(GSColor.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
