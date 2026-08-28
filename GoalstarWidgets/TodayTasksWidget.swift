import WidgetKit
import SwiftUI
import AppIntents

struct TodayTasksWidget: Widget {
    let kind = AppConstants.todayWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayTasksTimelineProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("今日三件事")
        .description("在锁屏查看并勾选今日任务")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
            .systemSmall,
            .systemMedium
        ])
    }
}

struct TodayTasksWidgetView: View {
    var entry: TodayTasksEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryRectangular:
            lockScreenRectangular
        default:
            homeScreenCard
        }
    }

    private var inlineText: String {
        if !entry.enabled {
            return "锁屏待办已关闭"
        }
        if entry.privacyMode {
            return "今日 \(entry.tasks.count) 件事"
        }
        if entry.tasks.isEmpty {
            return "今日暂无任务"
        }
        return "今日 \(entry.completedCount)/\(entry.tasks.count)"
    }

    private var lockScreenRectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(entry.privacyMode ? "今日待办" : "今日三件事")
                    .font(.caption2.weight(.semibold))
                Spacer()
                if !entry.privacyMode {
                    Text("\(entry.completedCount)/\(entry.tasks.count)")
                        .font(.caption2.weight(.semibold))
                }
            }
            if !entry.enabled {
                Text("已在设置中关闭")
                    .font(.caption2)
            } else if entry.privacyMode {
                Text("今日 \(entry.tasks.count) 件事")
                    .font(.caption2)
            } else if entry.tasks.isEmpty {
                Text("添加任务开始吧")
                    .font(.caption2)
            } else {
                ForEach(entry.tasks.prefix(3)) { task in
                    Button(intent: ToggleTaskIntent(taskID: task.id)) {
                        HStack(spacing: 4) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.caption2)
                            Text(task.title)
                                .font(.caption2)
                                .lineLimit(1)
                                .strikethrough(task.isCompleted)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var homeScreenCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今日三件事")
                    .font(.headline)
                    .foregroundStyle(Color(hex: 0x4F46E5))
                Spacer()
                Text("\(entry.completedCount)/\(max(entry.tasks.count, 1))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x64748B))
            }
            if !entry.enabled {
                Text("锁屏待办已关闭")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0x64748B))
                Spacer(minLength: 0)
            } else if entry.privacyMode {
                Text("今日 \(entry.tasks.count) 件事")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x0F172A))
                Text("隐私模式已开启")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0x64748B))
                Spacer(minLength: 0)
            } else if entry.tasks.isEmpty {
                Text("今天还没有安排任务")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0x64748B))
                Spacer(minLength: 0)
            } else {
                ForEach(entry.tasks) { task in
                    Button(intent: ToggleTaskIntent(taskID: task.id)) {
                        HStack(spacing: 8) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(Color(hex: 0x4F46E5))
                            Text(task.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color(hex: 0x0F172A))
                                .lineLimit(1)
                                .strikethrough(task.isCompleted)
                            Spacer(minLength: 0)
                            if task.isPriority {
                                Image(systemName: "flame.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: 0xF59E0B))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(4)
    }
}
