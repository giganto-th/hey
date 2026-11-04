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
}
