import Foundation
import Testing
@testable import HeyDomain

@Suite struct MonthGridTests {
    private func calendar(firstWeekday: Int) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        c.firstWeekday = firstWeekday
        return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ c: Calendar) -> Date {
        c.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func novemberStartingSunday() {
        let c = calendar(firstWeekday: 1)
        let grid = MonthGrid(containing: date(2026, 11, 13, 10, c), calendar: c)
        // 1 Nov 2026 is a Sunday: no leading days, 30 days -> 5 weeks
        #expect(grid.days.count == 35)
        #expect(grid.days.first == date(2026, 11, 1, 0, c))
        #expect(grid.isInMonth(grid.days[29], calendar: c))
        #expect(!grid.isInMonth(grid.days[30], calendar: c))
    }

    @Test func mondayFirstAddsLeadingDays() {
        let c = calendar(firstWeekday: 2)
        let grid = MonthGrid(containing: date(2026, 11, 13, 10, c), calendar: c)
        #expect(grid.days.first == date(2026, 10, 26, 0, c))
        #expect(grid.days.count % 7 == 0)
        #expect(MonthGrid.weekdaySymbols(calendar: c).count == 7)
    }

    @Test func weekStartsOnFirstWeekday() {
        let c = calendar(firstWeekday: 2)
        let week = MonthGrid.week(containing: date(2026, 11, 13, 15, c), calendar: c)
        #expect(week.count == 7)
        #expect(week.first == date(2026, 11, 9, 0, c))
    }

    @Test func timedEventHoursAndLanes() {
        let c = calendar(firstWeekday: 1)
        let call = CalendarEventInfo(id: "c", title: "Call", start: date(2026, 11, 13, 9, c), end: date(2026, 11, 13, 10, c).addingTimeInterval(1800))
        let h = MonthGrid.hours(of: call, on: date(2026, 11, 13, 0, c), calendar: c)
        #expect(h?.start == 9 && h?.end == 10.5)
        let lanes = MonthGrid.lanes([("a", 9, 10.5), ("b", 10, 11), ("c", 12, 13)])
        #expect(lanes["a"]! == (0, 2) && lanes["b"]! == (1, 2) && lanes["c"]! == (0, 1))
    }

    @Test func eventsCoverEveryDayTheyTouch() {
        let c = calendar(firstWeekday: 1)
        let trip = CalendarEventInfo(id: "t", title: "Trip", start: date(2026, 11, 12, 0, c), end: date(2026, 11, 14, 0, c), isAllDay: true)
        let call = CalendarEventInfo(id: "c", title: "Call", start: date(2026, 11, 13, 9, c), end: date(2026, 11, 13, 10, c))
        let on13 = MonthGrid.events([call, trip], on: date(2026, 11, 13, 0, c), calendar: c)
        #expect(on13.map(\.id) == ["t", "c"])
        #expect(MonthGrid.events([call, trip], on: date(2026, 11, 14, 0, c), calendar: c).isEmpty)
    }
}
