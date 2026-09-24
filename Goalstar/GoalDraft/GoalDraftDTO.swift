import Foundation

/// Optional context chip. It only enriches the on-device prompt and template.
/// It does not change the 1.0 goal preset / category fields.
enum GoalDraftSaveFailure: Equatable {
    case emptyName
    case goalLimit
    case persistence
}

enum GoalContextChip: String, CaseIterable, Identifiable {
    case work
    case study
    case health
    case life

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .work: return language.localized("工作")
        case .study: return language.localized("学习")
        case .health: return language.localized("健康")
        case .life: return language.localized("生活")
        }
    }
}

/// Editable draft. Not a SwiftData model. IDs exist only so the confirm card can edit rows.
struct GoalDraftDTO: Equatable, Identifiable {
    static let maxMilestones = 5
    static let maxTasks = 8

    var id: UUID
    var name: String
    var milestones: [Milestone]
    var tasks: [Task]
    var usedTemplateFallback: Bool

    struct Milestone: Equatable, Identifiable {
        var id: UUID
        var title: String
        var summary: String
    }

    struct Task: Equatable, Identifiable {
        var id: UUID
        var title: String
        var milestoneIndex: Int?
    }

    static let empty = GoalDraftDTO(
        id: UUID(),
        name: "",
        milestones: [],
        tasks: [],
        usedTemplateFallback: false
    )

    func normalized(fallbackName: String) -> GoalDraftDTO {
        var copy = self
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = fallbackName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.name = Self.clipped(trimmedName.isEmpty ? fallback : trimmedName)
        copy.milestones = Array(
            milestones
                .map { item in
                    var milestone = item
                    milestone.title = milestone.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    milestone.summary = milestone.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                    return milestone
                }
                .filter { !$0.title.isEmpty }
                .prefix(Self.maxMilestones)
        )
        copy.tasks = Array(
            tasks.compactMap { item -> Task? in
                var task = item
                task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !task.title.isEmpty else { return nil }
                if let index = task.milestoneIndex, copy.milestones.indices.contains(index) == false {
                    task.milestoneIndex = nil
                }
                return task
            }
            .prefix(Self.maxTasks)
        )
        return copy
    }

    static func clipped(_ text: String, limit: Int = 40) -> String {
        if text.count <= limit { return text }
        return String(text.prefix(limit))
    }
}
