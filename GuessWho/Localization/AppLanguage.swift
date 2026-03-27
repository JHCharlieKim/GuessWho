import Foundation

enum AppLanguage: String, CaseIterable {
    case ko
    case en

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static var current: AppLanguage {
        for identifier in Locale.preferredLanguages {
            let locale = Locale(identifier: identifier)
            if let languageCode = locale.language.languageCode?.identifier,
               let language = AppLanguage(rawValue: languageCode) {
                return language
            }
        }

        return .en
    }
}
