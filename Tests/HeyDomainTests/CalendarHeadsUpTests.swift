import Testing
import Foundation
@testable import HeyDomain

struct CalendarHeadsUpTests {
    let now = Date(timeIntervalSince1970: 2_000_000)
    func event(_ id: String, in minutes: Double, allDay: Bool = false) -> CalendarEventInfo {
        CalendarEventInfo(id: id, title: "ประชุม", start: now.addingTimeInterval(minutes * 60), isAllDay: allDay)
    }

    @Test func announcesOnlyInsideTheLeadWindow() {
        var h = CalendarHeadsUp()
        #expect(h.due([event("a", in: 30)], now: now).isEmpty)
        #expect(h.due([event("a", in: 9)], now: now).map(\.id) == ["a"])
    }

    @Test func leadTimeIsAdjustable() {
        var h = CalendarHeadsUp()
        h.leadTime = 5 * 60
        #expect(h.due([event("a", in: 9)], now: now).isEmpty)
        #expect(h.due([event("a", in: 4)], now: now).map(\.id) == ["a"])
    }

    @Test func announcesEachEventOnce() {
        var h = CalendarHeadsUp()
        #expect(h.due([event("a", in: 8)], now: now).count == 1)
        #expect(h.due([event("a", in: 5)], now: now.addingTimeInterval(180)).isEmpty)
    }

    @Test func skipsAllDayAndPastEvents() {
        var h = CalendarHeadsUp()
        #expect(h.due([event("d", in: 5, allDay: true), event("p", in: -2)], now: now).isEmpty)
    }

    @Test func lineShowsRoundedUpMinutes() {
        let e = event("a", in: 7.2)
        #expect(CalendarHeadsUp.line(for: e, now: now) == "อีก 8 นาที: ประชุม")
    }

    @Test func blankTitleReadsAsAppointment() {
        let e = CalendarEventInfo(id: "x", title: "  ", start: now.addingTimeInterval(60))
        #expect(CalendarHeadsUp.line(for: e, now: now) == "อีก 1 นาที: นัดหมาย")
    }
}

struct CalendarAgendaTests {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        return c
    }()
    // 2026-11-10 13:00 in Bangkok
    var now: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 13))! }

    func at(_ hour: Int, _ minute: Int = 0, day: Int = 10) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }
    func timed(_ id: String, _ from: Date, _ to: Date, link: URL? = nil) -> CalendarEventInfo {
        CalendarEventInfo(id: id, title: id, start: from, end: to, meetingURL: link)
    }

    @Test func keepsOngoingAndLaterTodayInOrder() {
        let events = [
            timed("later", at(16), at(17)),
            timed("ended", at(9), at(10)),
            timed("ongoing", at(12, 30), at(13, 30)),
            timed("tomorrow", at(9, day: 11), at(10, day: 11)),
        ]
        let a = CalendarAgenda(events, now: now, calendar: cal)
        #expect(a.upcoming.map(\.id) == ["ongoing", "later"])
        #expect(a.next?.id == "ongoing")
    }

    @Test func separatesAllDayEvents() {
        let holiday = CalendarEventInfo(id: "h", title: "วันหยุด", start: at(0), end: at(0, day: 11), isAllDay: true)
        let a = CalendarAgenda([holiday, timed("m", at(14), at(15))], now: now, calendar: cal)
        #expect(a.allDay.map(\.id) == ["h"])
        #expect(a.upcoming.map(\.id) == ["m"])
    }

    @Test func joinableOnlyNearTheStartOrDuring() {
        let link = URL(string: "https://meet.google.com/abc-defg-hij")!
        let soon = CalendarAgenda([timed("s", at(13, 10), at(14), link: link)], now: now, calendar: cal)
        #expect(soon.joinable(now: now)?.id == "s")
        let far = CalendarAgenda([timed("f", at(13, 40), at(14), link: link)], now: now, calendar: cal)
        #expect(far.joinable(now: now) == nil)
        let noLink = CalendarAgenda([timed("n", at(13, 5), at(14))], now: now, calendar: cal)
        #expect(noLink.joinable(now: now) == nil)
    }

    @Test func countdownText() {
        #expect(CalendarAgenda.countdown(timed("a", at(13, 25), at(14)), now: now) == "อีก 25 นาที")
        #expect(CalendarAgenda.countdown(timed("a", at(14, 5), at(15)), now: now) == "อีก 1 ชม. 5 นาที")
        #expect(CalendarAgenda.countdown(timed("a", at(15), at(16)), now: now) == "อีก 2 ชม.")
        #expect(CalendarAgenda.countdown(timed("a", at(12), at(13, 10)), now: now) == "กำลังเกิดขึ้น · เหลือ 10 นาที")
    }

    @Test func filterHidesCalendarsAndDeclined() {
        let events = [
            CalendarEventInfo(id: "a", title: "a", start: now, calendarID: "work"),
            CalendarEventInfo(id: "b", title: "b", start: now, calendarID: "birthdays"),
            CalendarEventInfo(id: "c", title: "c", start: now, calendarID: "work", declined: true),
        ]
        #expect(CalendarFilter.visible(events, hidden: ["birthdays"], skipDeclined: true).map(\.id) == ["a"])
        #expect(CalendarFilter.visible(events, hidden: [], skipDeclined: false).map(\.id) == ["a", "b", "c"])
    }
}

struct MeetingLinkTests {
    @Test func findsKnownProviders() {
        #expect(MeetingLink.find(in: ["Join: https://us02web.zoom.us/j/123456789?pwd=abc."])?.absoluteString
                == "https://us02web.zoom.us/j/123456789?pwd=abc")
        #expect(MeetingLink.find(in: ["https://meet.google.com/abc-defg-hij"])?.host == "meet.google.com")
        #expect(MeetingLink.find(in: ["<https://teams.microsoft.com/l/meetup-join/19%3ameeting_x%40thread.v2/0?context=y>"])?
            .absoluteString == "https://teams.microsoft.com/l/meetup-join/19%3ameeting_x%40thread.v2/0?context=y")
        #expect(MeetingLink.find(in: ["https://acme.webex.com/meet/someone"]) != nil)
    }

    @Test func ignoresOrdinaryLinksAndChecksInOrder() {
        #expect(MeetingLink.find(in: ["https://example.com/agenda", nil, "ห้อง 3"]) == nil)
        let found = MeetingLink.find(in: [nil, "https://meet.google.com/aaa-bbbb-ccc", "https://zoom.us/j/1"])
        #expect(found?.host == "meet.google.com")
    }
}
