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
    @ObservationIgnored private var rangeCache: [String: [CalendarEventInfo]] = [:]
    /// Bumped when the calendar database changes, so the month page reads again.
    private(set) var revision = 0

    init() {
        headsUp.leadTime = TimeInterval(leadMinutes * 60)
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rangeCache.removeAll(); self?.revision += 1; self?.refresh(force: true) }
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
        if Self.demo { access = .ready; allEvents = Self.demoEvents(now); applyFilter(); return }
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

    /// Every visible event between two dates (a month grid, a week). Read when a page asks and kept until the calendar changes,
    /// so flipping back and forth costs nothing.
    func events(from start: Date, to end: Date) -> [CalendarEventInfo] {
        _ = revision                                                   // re-read when the calendar database changes
        guard access == .ready else { return [] }
        let key = "\(start.timeIntervalSince1970)-\(end.timeIntervalSince1970)"
        let all: [CalendarEventInfo]
        if Self.demo { return Self.demoEvents(start).filter { $0.start < end && $0.end > start } }
        if let cached = rangeCache[key] { all = cached } else {
            all = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil)).map(Self.info)
            if rangeCache.count > 8 { rangeCache.removeAll() }
            rangeCache[key] = all
        }
        return CalendarFilter.visible(all, hidden: hidden, skipDeclined: skipDeclined)
    }

    func color(of calendarID: String) -> NSColor {
        if Self.demo { return calendarID == "work" ? .systemBlue : calendarID == "shared" ? .systemGreen : .systemOrange }
        return calendars.first { $0.id == calendarID }?.color ?? .systemBlue
    }

    /// Apple's Calendar app, to add or change an event (Hey! only reads).
    func openCalendarApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
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

    // MARK: dev only

    /// `HEY_DEV=1 HEY_DEV_CALENDAR_DEMO=1`: made-up events for screenshots, without calendar access.
    private static let demo = ProcessInfo.processInfo.environment["HEY_DEV"] != nil && ProcessInfo.processInfo.environment["HEY_DEV_CALENDAR_DEMO"] != nil

    private static func demoEvents(_ around: Date) -> [CalendarEventInfo] {
        let cal = Calendar.current
        let week = MonthGrid.week(containing: around)
        func at(_ d: Int, _ h: Double, _ len: Double, _ title: String, _ id: String, allDay: Bool = false) -> CalendarEventInfo {
            let s = week[d].addingTimeInterval(h * 3600)
            return CalendarEventInfo(id: "\(title)\(d)", title: title, start: allDay ? week[d] : s,
                                     end: allDay ? cal.date(byAdding: .day, value: 1, to: week[d])! : s.addingTimeInterval(len * 3600),
                                     isAllDay: allDay, calendarID: id, meetingURL: id == "work" ? URL(string: "https://meet.google.com/x") : nil)
        }
        return [at(1, 9, 1, "Daily standup", "work"), at(2, 9, 1, "Daily standup", "work"), at(3, 9, 1, "Daily standup", "work"),
                at(1, 10.5, 2, "Design review", "work"), at(1, 11, 1, "Lunch with Ploy", "shared"),
                at(2, 14, 1.5, "Sprint planning", "work"), at(3, 13, 1, "Dentist", "home"), at(4, 16, 2, "Team outing", "shared"),
                at(5, 0, 0, "Holiday", "shared", allDay: true), at(4, 20, 1, "Gym", "home")]
    }
}
