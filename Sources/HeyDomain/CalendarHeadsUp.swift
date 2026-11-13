import Foundation

public struct CalendarEventInfo: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    /// Which of the Mac's calendars it belongs to (EventKit's calendar identifier).
    public var calendarID: String
    /// A Zoom / Meet / Teams / Webex link found in the event, if any.
    public var meetingURL: URL?
    /// The user answered "no" to the invitation.
    public var declined: Bool

    public init(id: String, title: String, start: Date, end: Date? = nil, isAllDay: Bool = false,
                calendarID: String = "", meetingURL: URL? = nil, declined: Bool = false) {
        self.id = id; self.title = title; self.start = start; self.end = max(end ?? start, start)
        self.isAllDay = isAllDay; self.calendarID = calendarID; self.meetingURL = meetingURL; self.declined = declined
    }

    public var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? tr("นัดหมาย") : t
    }

    public func isOngoing(at now: Date) -> Bool { !isAllDay && start <= now && now < end }
}

/// Picks which upcoming events deserve a heads-up, once each. Only titles and times are used.
public struct CalendarHeadsUp: Sendable {
    public static let leadChoices = [5, 10, 15]
    public var leadTime: TimeInterval = 10 * 60
    private var announced: Set<String> = []

    public init() {}

    public static func line(for event: CalendarEventInfo, now: Date) -> String {
        let minutes = max(1, Int((event.start.timeIntervalSince(now) / 60).rounded(.up)))
        return tr("อีก {0} นาที: {1}", minutes, String(event.displayTitle.prefix(40)))
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

/// What the "today" views show: the next timed event, the rest of the day, and the all-day items.
public struct CalendarAgenda: Equatable, Sendable {
    /// How early before the start a join button is offered prominently.
    public static let joinWindow: TimeInterval = 15 * 60

    public var allDay: [CalendarEventInfo]
    /// Timed events that have not ended yet and start before the end of today, soonest first (ongoing ones included).
    public var upcoming: [CalendarEventInfo]

    public var next: CalendarEventInfo? { upcoming.first }

    public init(_ events: [CalendarEventInfo], now: Date, calendar: Calendar = .current) {
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now.addingTimeInterval(86_400)
        allDay = events.filter { $0.isAllDay && $0.start < dayEnd && $0.end > dayStart }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        upcoming = events.filter { !$0.isAllDay && $0.end > now && $0.start < dayEnd }
            .sorted { ($0.start, $0.end) < ($1.start, $1.end) }
    }

    /// The one event to offer a join button for: has a link and is ongoing or starts within the join window.
    public func joinable(now: Date) -> CalendarEventInfo? {
        upcoming.first { $0.meetingURL != nil && $0.start.timeIntervalSince(now) <= Self.joinWindow && $0.end > now }
    }

    /// "in 25 min", "in 1 hr 5 min", or "now · 10 min left".
    public static func countdown(_ event: CalendarEventInfo, now: Date) -> String {
        if event.isOngoing(at: now) { return tr("กำลังเกิดขึ้น · เหลือ {0}", duration(event.end.timeIntervalSince(now))) }
        return tr("อีก {0}", duration(event.start.timeIntervalSince(now)))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        if minutes < 60 { return tr("{0} นาที", minutes) }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? tr("{0} ชม.", h) : tr("{0} ชม. {1} นาที", h, m)
    }
}

public enum CalendarFilter {
    /// Drops events from calendars the user switched off and, if asked, invitations they declined.
    public static func visible(_ events: [CalendarEventInfo], hidden: Set<String>, skipDeclined: Bool) -> [CalendarEventInfo] {
        events.filter { !hidden.contains($0.calendarID) && !(skipDeclined && $0.declined) }
    }
}

/// Finds a video-call link in an event's URL, location or notes.
public enum MeetingLink {
    // Known providers only, so an ordinary web link in the notes is never offered as "join".
    private static let pattern = try! NSRegularExpression(pattern: [
        #"https://(?:[\w-]+\.)*zoom\.us/(?:j|my|w|s)/[^\s<>"'()\[\]]+"#,
        #"https://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}(?:\?[^\s<>"'()\[\]]*)?"#,
        #"https://teams\.microsoft\.com/l/meetup-join/[^\s<>"'()\[\]]+"#,
        #"https://teams\.live\.com/meet/[^\s<>"'()\[\]]+"#,
        #"https://(?:[\w-]+\.)*webex\.com/(?:meet/|join/|[\w-]+/j\.php\?)[^\s<>"'()\[\]]+"#,
    ].joined(separator: "|"), options: [.caseInsensitive])

    /// The first link found, checking the texts in order (put the event's own URL first).
    public static func find(in texts: [String?]) -> URL? {
        for case let text? in texts {
            let range = NSRange(text.startIndex..., in: text)
            guard let match = pattern.firstMatch(in: text, range: range), let r = Range(match.range, in: text) else { continue }
            var link = String(text[r])
            while let last = link.last, ".,;:!?".contains(last) { link.removeLast() }
            if let url = URL(string: link) { return url }
        }
        return nil
    }
}
