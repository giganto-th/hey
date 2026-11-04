import Foundation

public struct CalendarEventInfo: Equatable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var isAllDay: Bool
    public init(id: String, title: String, start: Date, isAllDay: Bool = false) {
        self.id = id; self.title = title; self.start = start; self.isAllDay = isAllDay
    }
}

/// Picks which upcoming events deserve a heads-up, once each. Only titles and times are used.
public struct CalendarHeadsUp: Sendable {
    public var leadTime: TimeInterval = 10 * 60
    private var announced: Set<String> = []

    public init() {}

    public static func line(for event: CalendarEventInfo, now: Date) -> String {
        let minutes = max(1, Int((event.start.timeIntervalSince(now) / 60).rounded(.up)))
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = title.isEmpty ? tr("นัดหมาย") : String(title.prefix(40))
        return tr("อีก {0} นาที: {1}", minutes, name)
    }

    public mutating func due(_ events: [CalendarEventInfo], now: Date) -> [CalendarEventInfo] {
        // Forget events that already started so the set stays small.
        announced = announced.filter { id in events.contains { $0.id == id } }
        let due = events
            .filter { !$0.isAllDay && $0.start > now && $0.start.timeIntervalSince(now) <= leadTime && !announced.contains($0.id) }
            .sorted { $0.start < $1.start }
        due.forEach { announced.insert($0.id) }
        return due
    }
}
