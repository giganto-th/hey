import Foundation

public enum ContextCue: Equatable, Sendable {
    case welcomeBack, lateNight, takeBreak
}

/// Notices what the user is up to (from how long they've been idle) and decides when the pet should speak up.
public struct ContextEngine: Sendable {
    public var lateNightFrom = 23
    public var lateNightUntil = 5
    public var welcomeBackAfter: TimeInterval = 30 * 60
    /// Idle this long counts as a real rest and restarts the "you've been sitting a while" clock.
    public var restAfter: TimeInterval = 5 * 60
    public var breakAfter: TimeInterval = 90 * 60

    private var wasAway = false
    private var activeSince: Date?
    private var lastBreakCue: Date?
    private var lateNightShownFor: Date?

    public init() {}

    public func isLateNight(hour: Int) -> Bool {
        lateNightFrom > lateNightUntil ? (hour >= lateNightFrom || hour < lateNightUntil)
                                       : (hour >= lateNightFrom && hour < lateNightUntil)
    }

    public mutating func tick(now: Date, idleSeconds: Double, calendar: Calendar = .current) -> [ContextCue] {
        var cues: [ContextCue] = []

        if idleSeconds >= welcomeBackAfter { wasAway = true }
        if wasAway, idleSeconds < 60 {
            wasAway = false
            cues.append(.welcomeBack)
        }

        if idleSeconds >= restAfter {
            activeSince = nil
        } else {
            if activeSince == nil { activeSince = now }
            if let since = activeSince, now.timeIntervalSince(since) >= breakAfter,
               lastBreakCue.map({ now.timeIntervalSince($0) >= breakAfter }) ?? true {
                lastBreakCue = now
                cues.append(.takeBreak)
            }
        }

        // Once per night, and only while the user is actually there.
        let hour = calendar.component(.hour, from: now)
        if isLateNight(hour: hour), idleSeconds < 60 {
            let night = calendar.startOfDay(for: now.addingTimeInterval(-Double(lateNightUntil) * 3600))
            if lateNightShownFor != night {
                lateNightShownFor = night
                cues.append(.lateNight)
            }
        }
        return cues
    }
}
