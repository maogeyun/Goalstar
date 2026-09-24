import Foundation

/// Language-specific template drafts used when the on-device model is missing, fails, or times out.
/// Copy is in code so fallback still matches the UI language if the string catalog has not been built.
enum GoalDraftTemplates {
    static func make(sentence: String, chip: GoalContextChip?, language: AppLanguage) -> GoalDraftDTO {
        let pack = pack(for: chip, language: language)
        let milestones = pack.milestones.map { item in
            GoalDraftDTO.Milestone(id: UUID(), title: item.title, summary: item.summary)
        }
        let tasks = pack.tasks.enumerated().map { index, title in
            GoalDraftDTO.Task(
                id: UUID(),
                title: title,
                milestoneIndex: milestones.isEmpty ? nil : min(index, milestones.count - 1)
            )
        }
        return GoalDraftDTO(
            id: UUID(),
            name: name(from: sentence, language: language),
            milestones: milestones,
            tasks: tasks,
            usedTemplateFallback: true
        )
    }

    private static func name(from sentence: String, language: AppLanguage) -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback: String
        switch language {
        case .zhHans: fallback = "我的新目标"
        case .en: fallback = "My new goal"
        case .ja: fallback = "新しい目標"
        }
        return GoalDraftDTO.clipped(trimmed.isEmpty ? fallback : trimmed)
    }

    private struct Pack {
        var milestones: [(title: String, summary: String)]
        var tasks: [String]
    }

    private static func pack(for chip: GoalContextChip?, language: AppLanguage) -> Pack {
        switch language {
        case .zhHans: return zh(chip)
        case .en: return en(chip)
        case .ja: return ja(chip)
        }
    }

    private static func zh(_ chip: GoalContextChip?) -> Pack {
        switch chip {
        case .work:
            return Pack(
                milestones: [
                    ("对齐结果", "用一句话写清这次要交付什么"),
                    ("做出关键一步", "先完成最小可交付"),
                    ("收尾复盘", "记下阻塞和下一步")
                ],
                tasks: ["写下本周要交付的结果", "列出今天能推进的最小一步", "专注推进 25 分钟", "记下阻塞点并指定下一步"]
            )
        case .study:
            return Pack(
                milestones: [
                    ("划定范围", "只学今天能消化的一小段"),
                    ("反复练习", "用短时专注把内容过一遍"),
                    ("小测验收", "用自己的话讲出来")
                ],
                tasks: ["划定今天要学的一小段", "专注学习 25 分钟", "用自己的话复述一遍", "记下还不会的问题"]
            )
        case .health:
            return Pack(
                milestones: [
                    ("选一个最小动作", "今天就能开始的版本"),
                    ("稳住节奏", "固定一个时间完成"),
                    ("看到变化", "记下身体感受")
                ],
                tasks: ["定一个今天就能做的最小动作", "完成 25 分钟活动", "记下身体感受", "安排明天的同一时间"]
            )
        case .life:
            return Pack(
                milestones: [
                    ("选一个习惯", "缩成 10 分钟也能做的版本"),
                    ("连续做一次", "今天先完成，不追求完美"),
                    ("让它变轻松", "提前准备好明天要用的东西")
                ],
                tasks: ["把习惯缩成 10 分钟版本", "今天完成一次", "准备好明天需要的东西", "晚上记下感受"]
            )
        case nil:
            return Pack(
                milestones: [
                    ("明确起点", "写成一句可执行的完成标准"),
                    ("稳定推进", "今天先做最小的一步"),
                    ("验收收尾", "回顾结果并决定下一步")
                ],
                tasks: ["写下这个目标的完成标准", "安排今天的第一个 25 分钟", "去掉一个会拖后腿的干扰", "记下明天的下一步"]
            )
        }
    }

    private static func en(_ chip: GoalContextChip?) -> Pack {
        switch chip {
        case .work:
            return Pack(
                milestones: [
                    ("Align the outcome", "Write the delivery in one sentence"),
                    ("Ship a small piece", "Finish the smallest useful step"),
                    ("Close the loop", "Note the blocker and the next step")
                ],
                tasks: ["Write this week's outcome in one sentence", "List the smallest step you can do today", "Focus on it for 25 minutes", "Write down the blocker and the next step"]
            )
        case .study:
            return Pack(
                milestones: [
                    ("Set the scope", "Pick a slice you can finish today"),
                    ("Practice", "Go through it in a short focus block"),
                    ("Check yourself", "Explain it in your own words")
                ],
                tasks: ["Pick the small slice to study today", "Study for 25 minutes", "Explain it in your own words", "Write down what is still unclear"]
            )
        case .health:
            return Pack(
                milestones: [
                    ("Pick a tiny action", "A version you can start today"),
                    ("Keep the slot", "Do it at the same time"),
                    ("Notice the change", "Write down how you feel")
                ],
                tasks: ["Choose a tiny action for today", "Move for 25 minutes", "Note how your body feels", "Block the same time tomorrow"]
            )
        case .life:
            return Pack(
                milestones: [
                    ("Choose one habit", "Shrink it to a 10-minute version"),
                    ("Do it once", "Finish today without perfecting it"),
                    ("Make it easier", "Set out what tomorrow needs")
                ],
                tasks: ["Shrink the habit to 10 minutes", "Do it once today", "Prepare what you need tomorrow", "Write down how it felt tonight"]
            )
        case nil:
            return Pack(
                milestones: [
                    ("Name the finish line", "One sentence you can act on"),
                    ("Take the first step", "Do the smallest piece today"),
                    ("Review", "Decide the next step")
                ],
                tasks: ["Write the finish line in one sentence", "Schedule the first 25 minutes today", "Remove one distraction", "Write tomorrow's next step"]
            )
        }
    }

    private static func ja(_ chip: GoalContextChip?) -> Pack {
        switch chip {
        case .work:
            return Pack(
                milestones: [
                    ("成果を一言にする", "今回届けたいものを書く"),
                    ("小さな一歩を終える", "今日できる最小の成果にする"),
                    ("振り返る", "詰まりと次の一歩を残す")
                ],
                tasks: ["今週の成果を一文で書く", "今日進められる最小の一歩を書く", "25分集中して進める", "詰まりと次の一歩をメモする"]
            )
        case .study:
            return Pack(
                milestones: [
                    ("範囲を決める", "今日消化できる一小節だけ"),
                    ("繰り返す", "短い集中で一度通す"),
                    ("自分の言葉で確認", "説明できるか試す")
                ],
                tasks: ["今日学ぶ範囲を小さく決める", "25分集中して学ぶ", "自分の言葉で説明してみる", "まだ分からない点を書く"]
            )
        case .health:
            return Pack(
                milestones: [
                    ("最小の行動を決める", "今日始められる形にする"),
                    ("時間を固定する", "同じ時刻に一度やる"),
                    ("変化を見る", "体の感覚を残す")
                ],
                tasks: ["今日できる最小の行動を決める", "25分からだを動かす", "体の感覚をメモする", "明日の同じ時間を確保する"]
            )
        case .life:
            return Pack(
                milestones: [
                    ("習慣を一つ選ぶ", "10分でもできる形にする"),
                    ("一度やる", "完璧より今日終える"),
                    ("続けやすくする", "明日の準備を先に置く")
                ],
                tasks: ["習慣を10分版にする", "今日一度やってみる", "明日必要なものを準備する", "夜に感想を書く"]
            )
        case nil:
            return Pack(
                milestones: [
                    ("ゴールを一文にする", "実行できる完了条件を書く"),
                    ("最初の一歩", "今日いちばん小さい行動をする"),
                    ("振り返る", "次の一歩を決める")
                ],
                tasks: ["完了条件を一文で書く", "今日の最初の25分を確保する", "邪魔になるものを一つ減らす", "明日の次の一歩を書く"]
            )
        }
    }
}
