import Foundation

/// Which language the app shows. `system` follows the first language the Mac prefers (Thai, otherwise English).
public enum LanguageChoice: String, CaseIterable, Sendable {
    case system, thai, english

    /// Is the interface English for this choice, given the Mac's preferred languages?
    public func isEnglish(systemLanguages: [String]) -> Bool {
        switch self {
        case .thai: false
        case .english: true
        case .system: !(systemLanguages.first?.hasPrefix("th") ?? false)
        }
    }
}

/// The app is written in Thai: every visible string is passed through `tr(_:)` with its Thai text as the key. In English mode the
/// key is looked up in a table (`Resources/Localization/en.json`); a missing entry falls back to the Thai text.
/// The language is chosen once at launch (changing it relaunches the app), so statics that hold strings need no refreshing.
public enum Localization {
    nonisolated(unsafe) private static var english = false
    nonisolated(unsafe) private static var table: [String: String] = [:]
    private static let lock = NSLock()

    public static let defaultsKey = "appLanguage"

    public static var isEnglish: Bool { lock.withLock { english } }

    public static func configure(english: Bool, table: [String: String]) {
        lock.withLock {
            self.english = english
            self.table = table
        }
    }

    /// The translation of a key, or the key itself in Thai mode / when the table has nothing for it.
    public static func lookup(_ key: String) -> String {
        lock.withLock { english ? (table[key] ?? key) : key }
    }

    /// Fill `{0}`, `{1}`… in a template with the arguments.
    public static func fill(_ template: String, _ args: [Any]) -> String {
        guard !args.isEmpty else { return template }
        var out = template
        for (i, arg) in args.enumerated() { out = out.replacingOccurrences(of: "{\(i)}", with: "\(arg)") }
        return out
    }

    /// Read a `{ "Thai text": "English text" }` file.
    public static func loadTable(from url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }
}

/// A visible string. The Thai text is the key; placeholders are `{0}`, `{1}`… filled from the arguments.
public func tr(_ key: String, _ args: Any...) -> String {
    Localization.fill(Localization.lookup(key), args)
}
