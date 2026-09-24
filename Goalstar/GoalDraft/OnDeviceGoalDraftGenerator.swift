import Foundation

enum GoalDraftSource: String {
    case model
    case template
}

enum GoalDraftOutcome {
    case cancelled
    case ready(GoalDraftDTO, source: GoalDraftSource, failureReason: String?, generateMilliseconds: Int)
}

/// On-device draft generation. No cloud inference and no ML account.
/// iOS 26+ Foundation Models when `SystemLanguageModel` is available; otherwise a language-specific template.
enum OnDeviceGoalDraftGenerator {
    static func make(
        sentence: String,
        chip: GoalContextChip?,
        language: AppLanguage
    ) async -> GoalDraftOutcome {
        let started = Date()
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let generated = try await FoundationModelsGoalDraftClient.generate(
                    sentence: sentence,
                    chip: chip,
                    language: language
                )
                if Task.isCancelled { return .cancelled }
                let merged = merge(model: generated, sentence: sentence, chip: chip, language: language)
                return .ready(
                    merged.draft,
                    source: merged.usedFallback ? .template : .model,
                    failureReason: merged.usedFallback ? "empty" : nil,
                    generateMilliseconds: milliseconds(since: started)
                )
            } catch is CancellationError {
                return .cancelled
            } catch {
                if Task.isCancelled { return .cancelled }
                let template = GoalDraftTemplates.make(sentence: sentence, chip: chip, language: language)
                return .ready(
                    template,
                    source: .template,
                    failureReason: String(describing: error),
                    generateMilliseconds: milliseconds(since: started)
                )
            }
        }
        #endif
        if Task.isCancelled { return .cancelled }
        let template = GoalDraftTemplates.make(sentence: sentence, chip: chip, language: language)
        return .ready(
            template,
            source: .template,
            failureReason: "unavailable",
            generateMilliseconds: milliseconds(since: started)
        )
    }

    private static func merge(
        model: GoalDraftDTO,
        sentence: String,
        chip: GoalContextChip?,
        language: AppLanguage
    ) -> (draft: GoalDraftDTO, usedFallback: Bool) {
        let template = GoalDraftTemplates.make(sentence: sentence, chip: chip, language: language)
        var draft = model.normalized(fallbackName: sentence)
        let missingStructure = draft.milestones.isEmpty && draft.tasks.isEmpty
        if draft.name.isEmpty {
            draft.name = template.name
        }
        if draft.milestones.isEmpty {
            draft.milestones = template.milestones
        }
        if draft.tasks.isEmpty {
            draft.tasks = template.tasks
        }
        draft.usedTemplateFallback = missingStructure
        return (draft.normalized(fallbackName: sentence), missingStructure)
    }

    private static func milliseconds(since start: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(start) * 1000))
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct GoalDraftGeneration {
    @Guide(description: "Short goal name in the requested output language. Never empty.")
    var name: String

    @Guide(description: "Two to five milestones. Titles are phases, not tasks.")
    var milestones: [GoalDraftMilestoneGeneration]

    @Guide(description: "Three to eight concrete starter tasks the person can do today.")
    var tasks: [GoalDraftTaskGeneration]
}

@available(iOS 26.0, *)
@Generable
struct GoalDraftMilestoneGeneration {
    @Guide(description: "Milestone title in the requested output language.")
    var title: String

    @Guide(description: "Optional one-line summary. Use an empty string when there is nothing to add.")
    var summary: String
}

@available(iOS 26.0, *)
@Generable
struct GoalDraftTaskGeneration {
    @Guide(description: "Concrete task title in the requested output language.")
    var title: String

    @Guide(description: "Zero-based index of the related milestone. Use -1 when none.")
    var milestoneIndex: Int
}

@available(iOS 26.0, *)
enum FoundationModelsGoalDraftClient {
    static func generate(
        sentence: String,
        chip: GoalContextChip?,
        language: AppLanguage
    ) async throws -> GoalDraftDTO {
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw GoalDraftModelError.unavailable(String(describing: reason))
        }

        let instructionsText = instructions(language: language)
        let promptText = prompt(sentence: sentence, chip: chip, language: language)
        let response = try await withTimeout(seconds: 15) {
            let session = LanguageModelSession(instructions: instructionsText)
            return try await session.respond(
                to: promptText,
                generating: GoalDraftGeneration.self
            )
        }
        return map(response.content)
    }

    private static func instructions(language: AppLanguage) -> String {
        """
        You draft a personal goal for the Goalstar app.
        Reply only as the requested structured fields.
        Output language: \(language.promptLanguageName).
        Do not ask follow-up questions. Do not coach. Do not mention that you are an AI.
        Keep the goal name short. Milestones are phases. Tasks are actions for today.
        """
    }

    private static func prompt(sentence: String, chip: GoalContextChip?, language: AppLanguage) -> String {
        var lines = [
            "Output language: \(language.promptLanguageName).",
            "User sentence: \(sentence)"
        ]
        if let chip {
            lines.append("Optional context chip: \(chip.title(language: language)). Use it only as a hint. Do not replace the user's sentence.")
        }
        lines.append("Return 2 to 5 milestones and 3 to 8 tasks. No identifiers.")
        return lines.joined(separator: "\n")
    }

    private static func map(_ generated: GoalDraftGeneration) -> GoalDraftDTO {
        let milestones = generated.milestones.enumerated().map { _, item in
            GoalDraftDTO.Milestone(id: UUID(), title: item.title, summary: item.summary)
        }
        let tasks = generated.tasks.enumerated().map { _, item in
            GoalDraftDTO.Task(
                id: UUID(),
                title: item.title,
                milestoneIndex: item.milestoneIndex >= 0 ? item.milestoneIndex : nil
            )
        }
        return GoalDraftDTO(
            id: UUID(),
            name: generated.name,
            milestones: milestones,
            tasks: tasks,
            usedTemplateFallback: false
        )
    }

    private static func withTimeout<T>(
        seconds: Double,
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw GoalDraftModelError.timedOut
            }
            guard let value = try await group.next() else {
                throw GoalDraftModelError.timedOut
            }
            group.cancelAll()
            while (try? await group.next()) != nil {}
            return value
        }
    }
}

enum GoalDraftModelError: Error {
    case unavailable(String)
    case timedOut
}
#endif
