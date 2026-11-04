import Foundation

public enum AIProvider: String, CaseIterable, Codable, Sendable, Identifiable {
    case claude, codex
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex (ChatGPT)"
        }
    }
}

/// One quota window of a subscription, e.g. "5 hours" or "7 days".
public struct UsageWindow: Equatable, Sendable, Identifiable {
    public var id: String                 // "5h", "7d", ...
    public var usedPercent: Double
    public var resetsAt: Date?

    public init(id: String, usedPercent: Double, resetsAt: Date?) {
        self.id = id; self.usedPercent = usedPercent; self.resetsAt = resetsAt
    }

    public var label: String {
        switch id {
        case "5h": tr("ช่วง 5 ชั่วโมง")
        case "7d": tr("ช่วง 7 วัน")
        case "7d-opus": tr("7 วัน (Opus)")
        case "7d-sonnet": tr("7 วัน (Sonnet)")
        default: id
        }
    }

    /// A window whose reset time has passed is empty again, whatever the last reading said.
    public func isExpired(at now: Date) -> Bool { resetsAt.map { $0 <= now } ?? false }

    public func effectivePercent(at now: Date) -> Double { isExpired(at: now) ? 0 : min(max(usedPercent, 0), 100) }
}

/// What a provider last told us about the plan.
public struct ProviderUsage: Equatable, Sendable {
    public var provider: AIProvider
    public var plan: String?
    public var windows: [UsageWindow]
    /// When the reading was taken (for Codex: the time of the last Codex session event).
    public var asOf: Date
    /// Extra balance (Codex credits), shown as text.
    public var creditsNote: String?

    public init(provider: AIProvider, plan: String? = nil, windows: [UsageWindow], asOf: Date, creditsNote: String? = nil) {
        self.provider = provider; self.plan = plan; self.windows = windows; self.asOf = asOf; self.creditsNote = creditsNote
    }
}

public enum UsageParsers {
    private static func window(id: String, minutes: Int?) -> String {
        switch minutes {
        case 300: "5h"
        case 10080: "7d"
        case let m?: m % 1440 == 0 ? "\(m / 1440)d" : "\(m / 60)h"
        default: id
        }
    }

    /// One line of a Codex session log (`~/.codex/sessions/**/rollout-*.jsonl`). Only token-count events carry `rate_limits`.
    public static func codex(line: String) -> ProviderUsage? {
        guard line.contains("rate_limits"), let data = line.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let limits = findLimits(in: root) else { return nil }
        var windows: [UsageWindow] = []
        for key in ["primary", "secondary"] {
            guard let w = limits[key] as? [String: Any], let used = (w["used_percent"] as? NSNumber)?.doubleValue else { continue }
            let minutes = (w["window_minutes"] as? NSNumber)?.intValue
            let reset = (w["resets_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
            windows.append(UsageWindow(id: window(id: key, minutes: minutes), usedPercent: used, resetsAt: reset))
        }
        guard !windows.isEmpty else { return nil }
        var note: String?
        if let credits = limits["credits"] as? [String: Any] {
            if credits["unlimited"] as? Bool == true { note = tr("เครดิตเพิ่มเติม: ไม่จำกัด") }
            else if credits["has_credits"] as? Bool == true, let balance = credits["balance"] { note = tr("เครดิตเพิ่มเติม: {0}", balance) }
        }
        let stamp = (root["timestamp"] as? String).flatMap(parseISO) ?? Date()
        return ProviderUsage(provider: .codex, plan: nil, windows: windows, asOf: stamp, creditsNote: note)
    }

    private static func findLimits(in object: Any) -> [String: Any]? {
        if let dict = object as? [String: Any] {
            if let limits = dict["rate_limits"] as? [String: Any] { return limits }
            for value in dict.values { if let found = findLimits(in: value) { return found } }
        } else if let array = object as? [Any] {
            for value in array { if let found = findLimits(in: value) { return found } }
        }
        return nil
    }

    /// The answer of Claude's plan-usage endpoint (the one Claude Code's /usage reads).
    public static func claude(json data: Data, plan: String?, now: Date) -> ProviderUsage? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var windows: [UsageWindow] = []
        for (key, id) in [("five_hour", "5h"), ("seven_day", "7d"), ("seven_day_opus", "7d-opus"), ("seven_day_sonnet", "7d-sonnet")] {
            guard let w = root[key] as? [String: Any], let used = (w["utilization"] as? NSNumber)?.doubleValue else { continue }
            let reset = (w["resets_at"] as? String).flatMap(parseISO)
            windows.append(UsageWindow(id: id, usedPercent: used, resetsAt: reset))
        }
        guard !windows.isEmpty else { return nil }
        return ProviderUsage(provider: .claude, plan: plan, windows: windows, asOf: now)
    }

    static func parseISO(_ s: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }
}

public struct UsageAlert: Equatable, Sendable {
    public var provider: AIProvider
    public var window: UsageWindow
    public var level: Int            // the threshold that was crossed, e.g. 80 or 95
}

/// Says "heads up" once per threshold per quota period, so the pet does not nag.
public struct UsageAlerts: Sendable {
    public static let thresholds = [80, 95]
    private var seen: [String: Int] = [:]          // "provider.window.resetsAt" -> highest level already announced

    public init() {}

    public mutating func evaluate(_ usage: ProviderUsage, now: Date) -> [UsageAlert] {
        var alerts: [UsageAlert] = []
        for w in usage.windows where !w.isExpired(at: now) {
            let level = Self.thresholds.filter { w.usedPercent >= Double($0) }.max() ?? 0
            let key = "\(usage.provider.rawValue).\(w.id).\(Int(w.resetsAt?.timeIntervalSince1970 ?? 0))"
            if level > (seen[key] ?? 0) {
                seen[key] = level
                alerts.append(UsageAlert(provider: usage.provider, window: w, level: level))
            }
        }
        return alerts
    }
}

public enum UsageText {
    /// "in 1 h 20 min" style text until a reset (the caller supplies the localized pieces via tr).
    public static func until(_ date: Date, now: Date) -> String {
        let seconds = max(date.timeIntervalSince(now), 0)
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 { return tr("{0} นาที", max(minutes, 1)) }
        if minutes < 48 * 60 { return tr("{0} ชม. {1} นาที", minutes / 60, minutes % 60) }
        return tr("{0} วัน {1} ชม.", minutes / 1440, (minutes % 1440) / 60)
    }

    public static func summary(_ usage: ProviderUsage, now: Date) -> String {
        let parts = usage.windows.prefix(2).map { w in
            "\(w.label) \(Int(w.effectivePercent(at: now).rounded()))%"
        }
        return "\(usage.provider.label): " + parts.joined(separator: " · ")
    }
}
