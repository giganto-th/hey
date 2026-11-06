import Foundation

/// Presentation preferences only; quota readings and reset rules come from UsageWindow.
public struct UsageMenuBarSettings: Codable, Equatable, Sendable {
    public enum PercentMode: String, Codable, CaseIterable, Sendable {
        case used, remaining

        public var label: String {
            switch self {
            case .used: tr("ใช้ไป")
            case .remaining: tr("คงเหลือ")
            }
        }
    }

    public var enabled = false
    /// Empty means the first available account with the requested quota window.
    public var accountIDs: [String] = []
    public var windowID = "5h"
    public var percentMode: PercentMode = .used
    public var showReset = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case enabled, accountIDs, accountID, windowID, percentMode, showReset
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        if let ids = try values.decodeIfPresent([String].self, forKey: .accountIDs) { accountIDs = ids }
        else if let legacy = try values.decodeIfPresent(String.self, forKey: .accountID), !legacy.isEmpty { accountIDs = [legacy] }
        windowID = try values.decodeIfPresent(String.self, forKey: .windowID) ?? "5h"
        percentMode = try values.decodeIfPresent(PercentMode.self, forKey: .percentMode) ?? .used
        showReset = try values.decodeIfPresent(Bool.self, forKey: .showReset) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(enabled, forKey: .enabled)
        try values.encode(accountIDs, forKey: .accountIDs)
        try values.encode(windowID, forKey: .windowID)
        try values.encode(percentMode, forKey: .percentMode)
        try values.encode(showReset, forKey: .showReset)
    }

    /// Keep selection order; never replace an unavailable selected account with another account.
    public func usages(from accounts: [ProviderUsage]) -> [ProviderUsage] {
        let available = accounts.filter { $0.windows.contains { $0.id == windowID } }
        if accountIDs.isEmpty { return Array(available.prefix(1)) }
        var seen = Set<String>()
        return accountIDs.filter { seen.insert($0).inserted }.compactMap { id in available.first { $0.accountID == id } }
    }

    public func text(for window: UsageWindow, now: Date) -> String {
        let used = Int(window.effectivePercent(at: now).rounded())
        var text = "\(percentMode == .used ? used : 100 - used)%"
        if showReset, let reset = window.resetsAt {
            if window.isExpired(at: now) { text += " · \(tr("รีเซ็ตแล้ว"))" }
            else {
                let minutes = Int((reset.timeIntervalSince(now) / 60).rounded(.up))
                text += String(format: " · ↻ %d:%02d", minutes / 60, minutes % 60)
            }
        }
        return text
    }
}
