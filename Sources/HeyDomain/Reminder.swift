import Foundation

public enum RepeatRule: Codable, Equatable, Sendable {
    case none, daily, weekly
    case everyMinutes(Int)

    public var label: String {
        switch self {
        case .none: "ครั้งเดียว"
        case .daily: "ทุกวัน"
        case .weekly: "ทุกสัปดาห์"
        case .everyMinutes(let n): "ทุก \(n) นาที"
        }
    }
}

public struct Reminder: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var text: String
    /// The scheduled time (for repeating reminders, the occurrence that is next in line).
    public var anchor: Date
    /// When to ring next; differs from `anchor` while nagging or snoozed.
    public var nextFire: Date
    public var repeatRule: RepeatRule = .none
    public var ringing = false
    public var nags = 0
    public var doneAt: Date?
    public var createdAt: Date

    public var isActive: Bool { doneAt == nil }
}

public struct Note: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var text = ""
    public var colorIndex = 0
    public var pinned = false
    public var x: Double?
    public var y: Double?
    public var createdAt: Date
    public var updatedAt: Date
}
