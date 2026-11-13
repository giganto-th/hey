import Foundation

/// The days a month calendar shows: whole weeks from the one holding the 1st to the one holding the last day,
/// starting on the calendar's first weekday (Sunday or Monday, per the Mac's region).
public struct MonthGrid: Equatable, Sendable {
    /// Midnight of the month's 1st.
    public let month: Date
    public let days: [Date]

    public init(containing date: Date, calendar: Calendar = .current) {
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
        month = first
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let cells = Int(ceil(Double(lead + count) / 7)) * 7
        let start = calendar.date(byAdding: .day, value: -lead, to: first) ?? first
        days = (0..<cells).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// From the first shown day to the midnight after the last one.
    public func range(calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = days.first ?? month
        let end = days.last.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) } ?? month
        return (start, end)
    }

    public func isInMonth(_ day: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(day, equalTo: month, toGranularity: .month)
    }

    /// The seven days of the week holding `date`, starting on the calendar's first weekday.
    public static func week(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let day = calendar.startOfDay(for: date)
        let lead = (calendar.component(.weekday, from: day) - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -lead, to: day) ?? day
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Where a timed event sits in one day's column, in hours from midnight (clipped to that day), for a time grid.
    public static func hours(of event: CalendarEventInfo, on day: Date, calendar: Calendar = .current) -> (start: Double, end: Double)? {
        let dayStart = calendar.startOfDay(for: day)
        guard !event.isAllDay, let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
              event.start < dayEnd, event.end > dayStart || event.end == event.start && event.start >= dayStart else { return nil }
        let s = max(event.start, dayStart).timeIntervalSince(dayStart) / 3600
        let e = min(event.end, dayEnd).timeIntervalSince(dayStart) / 3600
        return (s, max(e, s + 0.25))
    }

    /// Side-by-side lanes for overlapping events in one day column, like Google Calendar: (lane, lanes in that cluster) per event id.
    public static func lanes(_ spans: [(id: String, start: Double, end: Double)]) -> [String: (lane: Int, of: Int)] {
        var result: [String: (Int, Int)] = [:]
        var cluster: [(id: String, lane: Int)] = []
        var laneEnds: [Double] = []
        var clusterEnd = -Double.infinity
        func close() { let n = laneEnds.count; for c in cluster { result[c.id] = (c.lane, n) }; cluster = []; laneEnds = [] }
        for s in spans.sorted(by: { ($0.start, $0.end) < ($1.start, $1.end) }) {
            if s.start >= clusterEnd { close() }
            let lane = laneEnds.firstIndex { $0 <= s.start } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(s.end) } else { laneEnds[lane] = s.end }
            cluster.append((s.id, lane))
            clusterEnd = max(clusterEnd, s.end)
        }
        close()
        return result
    }

    /// The short weekday names in display order (อา จ อ ... or Mon Tue ...).
    public static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    /// Events touching `day` (an all-day or multi-day event shows on every day it covers), all-day first, then by start.
    public static func events(_ events: [CalendarEventInfo], on day: Date, calendar: Calendar = .current) -> [CalendarEventInfo] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events.filter { $0.start < end && ($0.end > start || ($0.end == $0.start && $0.start >= start)) }
            .sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
    }
}
