import AppKit
import EventKit
import HeyDomain

/// Read-only look at today's calendar. Events stay in memory only; nothing is stored or sent anywhere.
/// Notes and locations are read just to find a video-call link, never kept or shown.
@MainActor @Observable
final class CalendarService {
    static let enabledKey = "calendarHeadsUp"
    static let leadKey = "calendarLeadMinutes"
    static let hiddenKey = "calendarHidden"
    static let skipDeclinedKey = "calendarSkipDeclined"

    struct CalendarChoice: Identifiable {
        let id: String
        let title: String
        let source: String
        let color: NSColor
    }

    enum Access { case off, notAllowed, ready }

    private(set) var isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    private(set) var access: Access = .off
    /// Today's events (and the next half hour past midnight), already filtered by the settings.
    private(set) var events: [CalendarEventInfo] = []
    private(set) var calendars: [CalendarChoice] = []
    private(set) var hidden = Set(UserDefaults.standard.stringArray(forKey: hiddenKey) ?? [])
    private(set) var leadMinutes = UserDefaults.standard.object(forKey: leadKey) as? Int ?? 10
    private(set) var skipDeclined = UserDefaults.standard.object(forKey: skipDeclinedKey) as? Bool ?? true

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var headsUp = CalendarHeadsUp()
    @ObservationIgnored private var lastFetch = Date.distantPast
    @ObservationIgnored private var allEvents: [CalendarEventInfo] = []

    init() {
        headsUp.leadTime = TimeInterval(leadMinutes * 60)
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh(force: true) }
        }
        refresh(force: true)
    }

    func agenda(now: Date = Date()) -> CalendarAgenda { CalendarAgenda(events, now: now) }

    // MARK: settings

    /// Turning it on asks macOS for read access; a refusal turns it back off.
    func setEnabled(_ on: Bool) async {
        isEnabled = on
        UserDefaults.standard.set(on, forKey: Self.enabledKey)
        if on, EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            if !granted { isEnabled = false; UserDefaults.standard.set(false, forKey: Self.enabledKey) }
        }
        refresh(force: true)
    }

    func setLead(minutes: Int) {
        leadMinutes = minutes
        headsUp.leadTime = TimeInterval(minutes * 60)
        UserDefaults.standard.set(minutes, forKey: Self.leadKey)
    }

    func setSkipDeclined(_ on: Bool) {
        skipDeclined = on
        UserDefaults.standard.set(on, forKey: Self.skipDeclinedKey)
        applyFilter()
    }

    func setShown(_ shown: Bool, calendarID: String) {
        if shown { hidden.remove(calendarID) } else { hidden.insert(calendarID) }
        UserDefaults.standard.set(Array(hidden), forKey: Self.hiddenKey)
        applyFilter()
    }

    /// Asks again if macOS never asked (e.g. a fresh install), otherwise opens Privacy › Calendars.
    func openPrivacySettings() {
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            Task { await setEnabled(true) }
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func join(_ event: CalendarEventInfo) {
        if let url = event.meetingURL { NSWorkspace.shared.open(url) }
    }

    // MARK: reading

    /// Re-reads the calendar at most once a minute unless forced (settings change, the calendar database changed).
    func refresh(now: Date = Date(), force: Bool = false) {
        let status = EKEventStore.authorizationStatus(for: .event)
        access = !isEnabled ? .off : (status == .fullAccess ? .ready : .notAllowed)
        guard access == .ready else { allEvents = []; events = []; calendars = []; return }
        guard force || now.timeIntervalSince(lastFetch) >= 60 else { return }
        lastFetch = now

        calendars = store.calendars(for: .event)
            .map { CalendarChoice(id: $0.calendarIdentifier, title: $0.title, source: $0.source?.title ?? "", color: NSColor(cgColor: $0.cgColor) ?? .systemGray) }
            .sorted { ($0.source, $0.title) < ($1.source, $1.title) }
        let dayStart = Calendar.current.startOfDay(for: now)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? now.addingTimeInterval(86_400)
        let end = max(dayEnd, now.addingTimeInterval(30 * 60))     // late at night the heads-up still sees just past midnight
        let predicate = store.predicateForEvents(withStart: dayStart, end: end, calendars: nil)
        allEvents = store.events(matching: predicate).map(Self.info)
        applyFilter()
    }

    /// Events about to start that deserve a heads-up right now (each once).
    func dueEvents(now: Date = Date()) -> [CalendarEventInfo] {
        refresh(now: now)
        guard access == .ready else { return [] }
        return headsUp.due(events, now: now)
    }

    private func applyFilter() {
        events = CalendarFilter.visible(allEvents, hidden: hidden, skipDeclined: skipDeclined)
    }

    private static func info(_ e: EKEvent) -> CalendarEventInfo {
        let declined = e.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
        return CalendarEventInfo(
            // Repeating events share one identifier, so the start time keeps each occurrence apart.
            id: (e.eventIdentifier ?? e.title ?? "") + "\(e.startDate.timeIntervalSince1970)",
            title: e.title ?? "", start: e.startDate, end: e.endDate, isAllDay: e.isAllDay,
            calendarID: e.calendar?.calendarIdentifier ?? "",
            meetingURL: MeetingLink.find(in: [e.url?.absoluteString, e.location, e.notes]),
            declined: declined)
    }
}
