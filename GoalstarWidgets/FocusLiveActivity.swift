import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            lockScreenView(context: context)
                .padding(12)
                .activityBackgroundTint(Color(hex: 0xEEF2FF))
                .activitySystemActionForegroundColor(Color(hex: 0x4F46E5))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.modeTitle, systemImage: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: 0x4F46E5))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerLabel(context: context)
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(Color(hex: 0x0F172A))
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 64, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let goal = context.state.goalName {
                            Text(goal)
                                .font(.caption)
                                .foregroundStyle(Color(hex: 0x64748B))
                        }
                        if let task = context.state.taskTitle {
                            Text(task)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                        }
                        HStack(spacing: 8) {
                            Text(context.state.isRunning ? "专注中" : "已暂停")
                                .font(.caption2)
                                .foregroundStyle(Color(hex: 0x4F46E5))
                            Spacer(minLength: 0)
                            controlButtons(isRunning: context.state.isRunning)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Color(hex: 0x4F46E5))
            } compactTrailing: {
                timerLabel(context: context)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color(hex: 0x4F46E5))
                    .frame(minWidth: 40, alignment: .trailing)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(Color(hex: 0x4F46E5))
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<FocusActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(hex: 0xC7D2FE), lineWidth: 6)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: progress(context))
                    .stroke(Color(hex: 0x4F46E5), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)
                timerLabel(context: context)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color(hex: 0x0F172A))
                    .minimumScaleFactor(0.7)
                    .frame(width: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.modeTitle)
                    .font(.headline)
                    .foregroundStyle(Color(hex: 0x0F172A))
                if let goal = context.state.goalName {
                    Text(goal)
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0x64748B))
                        .lineLimit(1)
                }
                if let task = context.state.taskTitle {
                    Text(task)
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: 0x64748B))
                        .lineLimit(1)
                }
                Text(context.state.isRunning ? "专注中" : "已暂停")
                    .font(.caption)
                    .foregroundStyle(Color(hex: 0x4F46E5))
            }

            Spacer(minLength: 0)

            controlButtons(isRunning: context.state.isRunning)
        }
    }

    @ViewBuilder
    private func controlButtons(isRunning: Bool) -> some View {
        HStack(spacing: 12) {
            if isRunning {
                Button(intent: PauseFocusIntent()) {
                    Label("暂停", systemImage: "pause.fill")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
            } else {
                Button(intent: ResumeFocusIntent()) {
                    Label("继续", systemImage: "play.fill")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }

            Button(intent: EndFocusIntent()) {
                Label("结束", systemImage: "stop.fill")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
        .tint(Color(hex: 0x4F46E5))
    }

    @ViewBuilder
    private func timerLabel(context: ActivityViewContext<FocusActivityAttributes>) -> some View {
        let state = context.state
        let isCountUp = context.attributes.isCountUp
        if state.isRunning {
            if isCountUp, let start = state.countUpStartDate {
                Text(timerInterval: start...Date.distantFuture, countsDown: false, showsHours: false)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
            } else if let end = state.timerEndDate {
                let span = max(1, state.frozenSeconds)
                let start = end.addingTimeInterval(TimeInterval(-span))
                Text(timerInterval: start...end, countsDown: true, showsHours: false)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
            } else {
                Text(timerText(state.frozenSeconds))
                    .monospacedDigit()
            }
        } else {
            Text(timerText(state.frozenSeconds))
                .monospacedDigit()
        }
    }

    private func progress(_ context: ActivityViewContext<FocusActivityAttributes>) -> Double {
        let total = Double(max(1, context.attributes.targetMinutes) * 60)
        let seconds = Double(context.state.displaySeconds(isCountUp: context.attributes.isCountUp))
        if context.attributes.isCountUp {
            return min(1, seconds / total)
        }
        return max(0, min(1, 1 - seconds / total))
    }

    private func timerText(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        let s = max(0, seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
