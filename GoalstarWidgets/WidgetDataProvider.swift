import Foundation
import SwiftData
import WidgetKit

struct TodayTaskEntryItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let isPriority: Bool
}

struct TodayTasksEntry: TimelineEntry {
    let date: Date
    let tasks: [TodayTaskEntryItem]
    let completedCount: Int
    let privacyMode: Bool
    let enabled: Bool
}

enum WidgetDataProvider {
    static func loadTodayTasks() -> [TodayTaskEntryItem] {
        guard AppConstants.lockWidgetEnabled else { return [] }
        guard let container = SharedPersistence.makeSharedContainer() else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.sortOrder)])
        let all = (try? context.fetch(descriptor)) ?? []
        let count = AppConstants.lockWidgetCount
        let ranked = TodayTaskRanking.ranked(all)
        let open = ranked.filter { $0.status != .done && $0.status != .skipped }
        let lockFirst = open.filter(\.isLockCandidate)
        let ordered = lockFirst.isEmpty ? open : (lockFirst + open.filter { !$0.isLockCandidate })
        return Array(ordered.prefix(count)).map {
            TodayTaskEntryItem(
                id: $0.id,
                title: $0.title,
                isCompleted: false,
                isPriority: $0.isPriority || $0.isPinned
            )
        }
    }

    static func makeEntry(date: Date = Date()) -> TodayTasksEntry {
        let tasks = loadTodayTasks()
        return TodayTasksEntry(
            date: date,
            tasks: tasks,
            completedCount: tasks.filter(\.isCompleted).count,
            privacyMode: AppConstants.lockPrivacyMode,
            enabled: AppConstants.lockWidgetEnabled
        )
    }
}

struct TodayTasksTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayTasksEntry {
        TodayTasksEntry(
            date: Date(),
            tasks: [
                TodayTaskEntryItem(id: UUID(), title: "完成英语阅读", isCompleted: false, isPriority: true),
                TodayTaskEntryItem(id: UUID(), title: "力量训练", isCompleted: false, isPriority: false)
            ],
            completedCount: 0,
            privacyMode: false,
            enabled: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayTasksEntry) -> Void) {
        completion(WidgetDataProvider.makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayTasksEntry>) -> Void) {
        let entry = WidgetDataProvider.makeEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}
