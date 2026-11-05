import Testing
@testable import HeyDomain

@Suite("SpreadLayout")
struct SpreadLayoutTests {
    @Test func nothingToLayOut() {
        #expect(SpreadLayout.slots(count: 0, width: 1000, cardWidth: 200, cardHeight: 140).slots.isEmpty)
    }

    @Test func oneSheetIsCentred() {
        let r = SpreadLayout.slots(count: 1, width: 1000, cardWidth: 200, cardHeight: 140)
        #expect(r.slots.count == 1)
        #expect(r.slots[0].x == 400)
        #expect(r.height == 140)
    }

    @Test func fewSheetsStayInOneRowAndOverlap() {
        let r = SpreadLayout.slots(count: 4, width: 1200, cardWidth: 200, cardHeight: 140)
        #expect(r.slots.allSatisfy { $0.y == 0 })
        let gap = r.slots[1].x - r.slots[0].x
        #expect(gap < 200 && gap > 40)                         // overlapping, but the left strip stays visible
    }

    @Test func manySheetsWrapAndNeverLeaveTheWidth() {
        let r = SpreadLayout.slots(count: 23, width: 900, cardWidth: 200, cardHeight: 140)
        #expect(r.slots.count == 23)
        #expect(Set(r.slots.map(\.y)).count > 1)
        #expect(r.slots.allSatisfy { $0.x >= 0 && $0.x + 200 <= 900 })
        #expect(r.height > 140)
    }

    @Test func aNarrowAreaStillGetsEverySheet() {
        let r = SpreadLayout.slots(count: 3, width: 100, cardWidth: 200, cardHeight: 140)
        #expect(r.slots.count == 3)
    }
}
