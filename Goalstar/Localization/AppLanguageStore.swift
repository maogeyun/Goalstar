import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class AppLanguageStore: ObservableObject {
    @Published private(set) var language: AppLanguage

    init() {
        let resolved = AppLanguagePreference.resolve()
        language = resolved
        GoalstarAnalytics.track("app_language", [
            "language": resolved.analyticsCode,
            "source": "launch"
        ])
    }

    func set(_ language: AppLanguage) {
        guard language != self.language else { return }
        AppLanguagePreference.save(language)
        self.language = language
        GoalstarAnalytics.track("app_language", [
            "language": language.analyticsCode,
            "source": "settings"
        ])
        WidgetCenter.shared.reloadAllTimelines()
    }
}
