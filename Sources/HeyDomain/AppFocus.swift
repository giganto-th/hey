import Foundation

public enum AppCategory: String, Equatable, Sendable {
    case coding, reading, gaming, chatting, other

    /// Bundle id only; nothing about what is inside the window is ever looked at.
    public static func classify(bundleID: String) -> AppCategory {
        let id = bundleID.lowercased()
        let coding = ["com.apple.dt.xcode", "com.microsoft.vscode", "com.todesktop", "com.jetbrains", "com.google.android.studio",
                      "com.apple.terminal", "com.googlecode.iterm2", "com.github.githubclient", "dev.zed", "com.sublimetext"]
        let reading = ["com.apple.books", "com.apple.preview", "com.apple.news", "md.obsidian", "com.apple.notes", "com.apple.safari",
                       "com.google.chrome", "org.mozilla.firefox", "com.microsoft.word", "com.apple.ibooks"]
        let gaming = ["com.valvesoftware.steam", "com.roblox", "com.unity", "com.epicgames", "com.blizzard", "com.mojang"]
        let chatting = ["jp.naver.line", "com.apple.mobilesms", "com.tinyspeck.slackmacgap", "com.microsoft.teams", "us.zoom", "com.apple.facetime",
                        "ru.keepcoder.telegram", "com.hnc.discord"]
        func has(_ list: [String]) -> Bool { list.contains { id.hasPrefix($0) } }
        if has(coding) { return .coding }
        if has(gaming) { return .gaming }
        if has(chatting) { return .chatting }
        if has(reading) { return .reading }
        return .other
    }
}

public enum AppFocusCue: Equatable, Sendable {
    case codingStreak, readingStreak, gamingStreak
}

/// Watches which kind of app is in front and speaks up once per long stay, with a cooldown so it never nags.
public struct AppFocusEngine: Sendable {
    public var codingAfter: TimeInterval = 40 * 60
    public var readingAfter: TimeInterval = 30 * 60
    public var gamingAfter: TimeInterval = 45 * 60
    public var cooldown: TimeInterval = 60 * 60

    private var category: AppCategory = .other
    private var since: Date?
    private var fired = false
    private var lastCue: Date?

    public init() {}

    /// Call on every context tick. Idle time longer than a minute pauses the stay, so a walk away resets it.
    public mutating func tick(now: Date, frontBundleID: String?, idleSeconds: Double) -> AppFocusCue? {
        let current = frontBundleID.map(AppCategory.classify) ?? .other
        if current != category || idleSeconds >= 5 * 60 {
            category = current
            since = idleSeconds >= 5 * 60 ? nil : now
            fired = false
            return nil
        }
        if since == nil { since = now }
        guard !fired, let since else { return nil }
        let stay = now.timeIntervalSince(since)
        let cue: AppFocusCue
        switch current {
        case .coding where stay >= codingAfter: cue = .codingStreak
        case .reading where stay >= readingAfter: cue = .readingStreak
        case .gaming where stay >= gamingAfter: cue = .gamingStreak
        default: return nil
        }
        fired = true
        if let last = lastCue, now.timeIntervalSince(last) < cooldown { return nil }
        lastCue = now
        return cue
    }
}
