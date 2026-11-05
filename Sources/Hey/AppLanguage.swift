import AppKit
import HeyDomain

/// Picks Thai or English at launch (the choice lives in UserDefaults) and loads the English table.
enum AppLanguage {
    static var choice: LanguageChoice {
        get {
            if let forced = ProcessInfo.processInfo.environment["HEY_LANG"] {          // dev: try a language without touching the saved choice
                return forced.hasPrefix("en") ? .english : (forced.hasPrefix("th") ? .thai : .system)
            }
            return LanguageChoice(rawValue: UserDefaults.standard.string(forKey: Localization.defaultsKey) ?? "") ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Localization.defaultsKey) }
    }

    /// The language the running app was started with.
    nonisolated(unsafe) static private(set) var runningEnglish = false

    static func configure() {
        let english = choice.isEnglish(systemLanguages: Locale.preferredLanguages)
        runningEnglish = english
        var table: [String: String] = [:]
        if english {
            let candidates = [Bundle.main.resourcePath.map { $0 + "/Localization/en.json" },
                              FileManager.default.currentDirectoryPath + "/Resources/Localization/en.json"].compactMap { $0 }
            for path in candidates {
                table = Localization.loadTable(from: URL(fileURLWithPath: path))
                if !table.isEmpty { break }
            }
        }
        Localization.configure(english: english, table: table)
    }

    /// Does the saved choice differ from what the running app shows?
    static var needsRestart: Bool { choice.isEnglish(systemLanguages: Locale.preferredLanguages) != runningEnglish }

    /// Start a fresh copy of the app and quit this one (only when running from Hey.app).
    @MainActor static func relaunch() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { NSApp.terminate(nil); return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; open -n \"$0\"", Bundle.main.bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
