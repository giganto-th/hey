import EventKit
import HeyDomain

/// Read-only look at the next half hour of the user's calendar. Nothing is stored or sent anywhere.
@MainActor
final class CalendarService {
    static let enabledKey = "calendarHeadsUp"

    private let store = EKEventStore()
    private var headsUp = CalendarHeadsUp()

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Asks macOS for read access (only when the user turns the option on).
    static func requestAccess() async -> Bool {
        do { return try await EKEventStore().requestFullAccessToEvents() } catch { return false }
    }

    /// Lines to announce right now, one per event that is about to start.
    func dueLines(now: Date = Date()) -> [String] {
        guard Self.isEnabled, EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let predicate = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(30 * 60), calendars: nil)
        let events = store.events(matching: predicate).map {
            CalendarEventInfo(id: ($0.eventIdentifier ?? $0.title ?? "") + "\($0.startDate.timeIntervalSince1970)",
                              title: $0.title ?? "", start: $0.startDate, isAllDay: $0.isAllDay)
        }
        return headsUp.due(events, now: now).map { CalendarHeadsUp.line(for: $0, now: now) }
    }
}
