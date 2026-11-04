import Testing
import Foundation
import CoreGraphics
@testable import HeyDomain

private let screen = CGRect(x: 0, y: 40, width: 1440, height: 820)       // visible area above the Dock

private func plan(_ x: Double, _ y: Double, petRadius: Double = 60, items: Int = 7, in s: CGRect = screen) -> RadialLayout {
    RadialLayoutPlanner.plan(.init(petCenter: CGPoint(x: x, y: y), petRadius: petRadius, screen: s, maxItems: items))
}

private func buttonRects(_ l: RadialLayout, count: Int) -> [CGRect] {
    let h = l.buttonSize / 2
    return l.centers(count: count).map { CGRect(x: $0.x - h, y: $0.y - h, width: l.buttonSize, height: l.buttonSize) }
}

/// The properties every layout must have, wherever the pet is.
private func expectSound(_ l: RadialLayout, count: Int = 7, petRadius: Double = 60, in s: CGRect = screen, sourceLocation: SourceLocation = #_sourceLocation) {
    let safe = s.insetBy(dx: 8, dy: 8)
    let rects = buttonRects(l, count: count)
    for (i, r) in rects.enumerated() {
        #expect(safe.contains(r), "button \(i) leaves the screen: \(r)", sourceLocation: sourceLocation)
        // never on top of the pet
        let d = hypot(r.midX - l.petCenter.x, r.midY - l.petCenter.y)
        #expect(d >= petRadius + l.buttonSize / 2, "button \(i) covers the pet", sourceLocation: sourceLocation)
    }
    for i in rects.indices { for j in rects.indices where j > i {
        let d = hypot(rects[i].midX - rects[j].midX, rects[i].midY - rects[j].midY)
        #expect(d >= l.buttonSize - 0.5, "buttons \(i) and \(j) overlap", sourceLocation: sourceLocation)
    } }
    #expect(safe.contains(l.header), "header leaves the screen", sourceLocation: sourceLocation)
    for (i, r) in rects.enumerated() { #expect(!r.intersects(l.header), "header covers button \(i)", sourceLocation: sourceLocation) }
    #expect(l.bounds.contains(l.header) && rects.allSatisfy { l.bounds.contains($0) }, "window doesn't hold everything", sourceLocation: sourceLocation)
}

@Test func petAtTheBottomFansStraightUp() {
    let l = plan(720, 130)
    expectSound(l)
    #expect(abs(l.centerAngle - .pi / 2) < 0.001)
}

@Test func petAtTheLeftEdgeFansTowardTheMiddleOfTheScreen() {
    let l = plan(60, 130)
    expectSound(l)
    #expect(cos(l.centerAngle) > 0.2, "arc should lean right, away from the edge")
}

@Test func petAtTheRightEdgeFansLeft() {
    let l = plan(1380, 130)
    expectSound(l)
    #expect(cos(l.centerAngle) < -0.2)
}

@Test func petAtTheTopHangsTheMenuBelowIt() {
    let l = plan(720, 800)
    expectSound(l)
    #expect(sin(l.centerAngle) < 0, "arc should hang below the pet")
}

@Test func petInEveryCornerStillFits() {
    for (x, y) in [(50.0, 80.0), (1390.0, 80.0), (50.0, 820.0), (1390.0, 820.0)] { expectSound(plan(x, y)) }
}

@Test func petPerchedOnAWindowInTheMiddleOfTheScreen() {
    expectSound(plan(700, 450))
    expectSound(plan(300, 600))
}

@Test func everyPetSizeAndPageSizeWorksAcrossTheScreen() {
    for radius in [40.0, 60.0, 85.0] {
        for items in [3, 5, 6, 7] {
            for x in stride(from: 40.0, through: 1400.0, by: 170.0) {
                for y in stride(from: 80.0, through: 840.0, by: 190.0) {
                    expectSound(plan(x, y, petRadius: radius, items: items), count: items, petRadius: radius)
                }
            }
        }
    }
}

@Test func buttonsHugTheirNeighboursAndThePetWhenThereIsRoom() {
    let l = plan(720, 450, petRadius: 60, items: 6)       // pet in the open
    let c = l.centers(count: 6)
    for (a, b) in zip(c, c.dropFirst()) {
        let d = hypot(a.x - b.x, a.y - b.y)
        #expect(d < l.buttonSize + 14, "neighbours should nearly touch, got \(d)")
    }
    // close to the pet: the inner edge of the buttons is within ~20pt of its body
    #expect(l.radius - l.buttonSize / 2 - 60 < 24)
    #expect(l.arcs.count == 1)
}

@Test func atTheBottomOfTheScreenTheArcOnlyGrowsAsMuchAsItMust() {
    let l = plan(720, 100, petRadius: 60, items: 7)
    #expect(l.arcs.count == 1)
    #expect(l.radius < 60 + l.buttonSize / 2 + 10 + 70, "arc is much farther from the pet than it needs to be: \(l.radius)")
    expectSound(l)
}

@Test func aPetInACornerGetsASecondArcInsteadOfFarAwayButtons() {
    let l = plan(60, 100, petRadius: 60, items: 7)         // bottom-left corner, just above the Dock
    expectSound(l)
    #expect(l.arcs.count >= 1)
    let farthest = l.centers(count: 7).map { hypot($0.x - l.petCenter.x, $0.y - l.petCenter.y) }.max() ?? 0
    #expect(farthest < 330, "the farthest button is \(farthest)pt from the pet")
}

@Test func menuOrderIsKeptWithinAnArc() {
    let l = plan(720, 130, items: 7)
    let c = l.centers(count: 7)
    #expect(c.count == 7)
    #expect(c[0].x < c[c.count - 1].x)                       // left to right when the arc opens upward
}

@Test func fewerButtonsStayClusteredInTheMiddleOfTheSameArc() {
    let l = plan(720, 130, items: 7)
    let three = l.centers(count: 3)
    #expect(abs(three[1].x - l.petCenter.x) < 1)                 // the middle one is straight above
    #expect(three[0].x < three[1].x && three[1].x < three[2].x)   // left to right
}

@Test func aTinyScreenStillGivesAnAnswerWithoutCrashing() {
    let tiny = CGRect(x: 0, y: 0, width: 360, height: 300)
    let l = plan(180, 60, in: tiny)
    #expect(l.centers(count: 7).count == 7)
    #expect(l.bounds.width > 0)
}

@Test func theSameInputGivesTheSameLayout() {
    #expect(plan(300, 200) == plan(300, 200))
}
