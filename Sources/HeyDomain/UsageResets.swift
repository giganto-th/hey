import Foundation

/// A quota window that has just started over (the 5-hour or the weekly one), worth a small celebration.
public struct UsageReset: Equatable, Sendable {
    public var provider: AIProvider
    public var accountID: String
    public var windowID: String
    public var at: Date

    public init(provider: AIProvider, accountID: String, windowID: String, at: Date) {
        self.provider = provider; self.accountID = accountID; self.windowID = windowID; self.at = at
    }

    /// "5 hours" or "week": the only two windows that are celebrated.
    public var isWeekly: Bool { windowID.hasPrefix("7d") }
}

/// Knows when the next quota reset is due and which resets have been celebrated, so each one fires once.
public struct UsageResets: Sendable {
    /// Windows that count: the 5-hour and the weekly one. Model-only weekly windows (Opus, Sonnet) reset together with the main one.
    public static let windowIDs: Set<String> = ["5h", "7d"]
    /// A reset found later than this (the Mac was asleep, the app was closed) is old news and passes quietly.
    public static let lateLimit: TimeInterval = 15 * 60

    private var celebrated: Set<String> = []

    public init() {}

    private static func key(_ usage: ProviderUsage, _ window: UsageWindow, _ at: Date) -> String {
        "\(usage.accountID)|\(window.id)|\(Int(at.timeIntervalSince1970))"
    }

    private static func candidates(_ usages: [ProviderUsage]) -> [(ProviderUsage, UsageWindow, Date)] {
        usages.flatMap { usage in
            usage.windows.compactMap { w in
                guard windowIDs.contains(w.id), w.usedPercent > 0, let at = w.resetsAt else { return nil }    // nothing used: nothing to celebrate
                return (usage, w, at)
            }
        }
    }

    /// The earliest reset still ahead, to set a timer for.
    public func next(in usages: [ProviderUsage], now: Date) -> Date? {
        Self.candidates(usages).map(\.2).filter { $0 > now }.min()
    }

    /// Resets that have come due (at most `lateLimit` ago) and were not celebrated yet. Marks them celebrated.
    public mutating func due(in usages: [ProviderUsage], now: Date) -> [UsageReset] {
        var result: [UsageReset] = []
        for (usage, window, at) in Self.candidates(usages) where at <= now {
            let key = Self.key(usage, window, at)
            guard celebrated.insert(key).inserted, now.timeIntervalSince(at) <= Self.lateLimit else { continue }
            result.append(UsageReset(provider: usage.provider, accountID: usage.accountID, windowID: window.id, at: at))
        }
        return result
    }
}
