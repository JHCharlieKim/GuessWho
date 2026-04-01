import Foundation

enum AppLanguage: String, CaseIterable {
    case ko
    case en
    case ja
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static var current: AppLanguage {
        for identifier in Locale.preferredLanguages {
            if let language = fromPreferredLanguageIdentifier(identifier) {
                return language
            }
        }

        return .en
    }

    private static func fromPreferredLanguageIdentifier(_ identifier: String) -> AppLanguage? {
        let normalizedIdentifier = identifier.lowercased()

        if normalizedIdentifier.hasPrefix("zh-hant") ||
            normalizedIdentifier.hasPrefix("zh-tw") ||
            normalizedIdentifier.hasPrefix("zh-hk") ||
            normalizedIdentifier.hasPrefix("zh-mo") {
            return .zhHant
        }

        if normalizedIdentifier.hasPrefix("zh-hans") ||
            normalizedIdentifier.hasPrefix("zh-cn") ||
            normalizedIdentifier.hasPrefix("zh-sg") {
            return .zhHans
        }

        let locale = Locale(identifier: identifier)
        guard let languageCode = locale.language.languageCode?.identifier else {
            return nil
        }

        return AppLanguage(rawValue: languageCode)
    }
}
