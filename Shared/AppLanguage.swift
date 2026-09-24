import Foundation

/// In-app language for Goalstar 1.1. UI strings, draft prompts, and templates follow this value.
/// The first launch maps the system language once; later system changes do not overwrite the choice.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case zhHans = "zh-Hans"
    case en = "en"
    case ja = "ja"

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    /// Name shown in the language picker. These are endonyms, not translations.
    var nativeName: String {
        switch self {
        case .zhHans: return "中文"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }

    var analyticsCode: String {
        switch self {
        case .zhHans: return "zh"
        case .en: return "en"
        case .ja: return "ja"
        }
    }

    /// Language name embedded in the on-device model instructions.
    var promptLanguageName: String {
        switch self {
        case .zhHans: return "Simplified Chinese"
        case .en: return "English"
        case .ja: return "Japanese"
        }
    }

    static func matchingSystem(_ preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        for identifier in preferred {
            let lower = identifier.lowercased()
            if lower.hasPrefix("zh") { return .zhHans }
            if lower.hasPrefix("ja") { return .ja }
            if lower.hasPrefix("en") { return .en }
        }
        return .en
    }

    func localized(_ key: String.LocalizationValue, bundle host: Bundle = .main) -> String {
        String(localized: key, bundle: resourceBundle(in: host), locale: locale)
    }

    private func resourceBundle(in host: Bundle) -> Bundle {
        if let path = host.path(forResource: rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return host
    }
}

enum AppLanguagePreference {
    static let languageKey = "goalstar.appLanguage"
    static let mappedOnceKey = "goalstar.appLanguage.mapped.v1"

    static func resolve(defaults: UserDefaults = AppConstants.sharedDefaults) -> AppLanguage {
        if defaults.bool(forKey: mappedOnceKey),
           let raw = defaults.string(forKey: languageKey),
           let language = AppLanguage(rawValue: raw) {
            return language
        }
        let mapped = AppLanguage.matchingSystem()
        save(mapped, defaults: defaults)
        return mapped
    }

    static func save(_ language: AppLanguage, defaults: UserDefaults = AppConstants.sharedDefaults) {
        defaults.set(language.rawValue, forKey: languageKey)
        defaults.set(true, forKey: mappedOnceKey)
    }

    static var current: AppLanguage {
        resolve()
    }
}

enum L10n {
    static func s(_ key: String.LocalizationValue, bundle: Bundle = .main) -> String {
        AppLanguagePreference.current.localized(key, bundle: bundle)
    }

    static func f(_ key: String.LocalizationValue, _ args: CVarArg..., bundle: Bundle = .main) -> String {
        let template = s(key, bundle: bundle)
        return String(format: template, locale: AppLanguagePreference.current.locale, arguments: args)
    }
}
