import Foundation

enum AppLanguage: String, CaseIterable {
    case ja
    case en

    var displayName: String {
        switch self {
        case .ja: return "日本語"
        case .en: return "English"
        }
    }
}

@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
            loadBundle()
        }
    }

    private var bundle: Bundle = .main

    private init() {
        // Load saved language or detect from device
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: saved) {
            currentLanguage = lang
        } else {
            let preferred = Locale.preferredLanguages.first ?? "en"
            currentLanguage = preferred.hasPrefix("ja") ? .ja : .en
        }
        loadBundle()
    }

    private func loadBundle() {
        if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
           let b = Bundle(path: path) {
            bundle = b
        } else {
            bundle = .main
        }
    }

    func l(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Format string with arguments: lang.l("key", args: count)
    func l(_ key: String, args: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, arguments: args)
    }
}
