import AppIntents
import Foundation
import SwiftData
import WidgetKit

struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "切换任务完成状态"
    static var description = IntentDescription("在锁屏 Widget 中勾选或取消今日任务")

    @Parameter(title: "任务 ID")
    var taskID: String

    init() {}

    init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: taskID),
              let container = SharedPersistence.makeSharedContainer() else {
            return .result()
        }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskItem>()
        guard let task = try context.fetch(descriptor).first(where: { $0.id == uuid }) else {
            return .result()
        }
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil
        task.statusRaw = task.isCompleted ? TaskStatus.done.rawValue : TaskStatus.todo.rawValue

        if let goal = task.goal {
            let allTasks = try context.fetch(descriptor)
            Metrics.refreshGoalStats(goal, tasks: allTasks)
        }
        try context.save()
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.todayWidgetKind)
        return .result()
    }
}
