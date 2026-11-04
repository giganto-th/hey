import Testing
import Foundation
@testable import HeyDomain

@Test func aSpringReachesItsTarget() {
    var s = Spring(0)
    for _ in 0..<240 { s.update(toward: 10, dt: 1.0 / 60) }
    #expect(abs(s.value - 10) < 0.01 && abs(s.velocity) < 0.05)
}

@Test func criticalDampingNeverOvershoots() {
    var s = Spring(0)
    var peak = 0.0
    for _ in 0..<600 { s.update(toward: 1, dt: 1.0 / 60, frequency: 5, damping: 1); peak = max(peak, s.value) }
    #expect(peak <= 1.0001)
}

@Test func aBouncySpringOvershootsAndSettles() {
    var s = Spring(0)
    var peak = 0.0
    for _ in 0..<600 { s.update(toward: 1, dt: 1.0 / 60, frequency: 5, damping: 0.4); peak = max(peak, s.value) }
    #expect(peak > 1.05 && abs(s.value - 1) < 0.01)
}

@Test func aHugeFrameOrAPausedAppCannotMakeItExplode() {
    var s = Spring(0)
    s.update(toward: 5, dt: 30, frequency: 40, damping: 0.5)        // 30 s in one step, very stiff
    #expect(s.value.isFinite && abs(s.value) < 50)
    for _ in 0..<2000 { s.update(toward: 5, dt: 0.25, frequency: 40, damping: 0.5) }
    #expect(abs(s.value - 5) < 0.01)
}

@Test func theResultDoesNotDependOnHowTheTimeIsSliced() {
    var a = Spring(0), b = Spring(0)
    for _ in 0..<60 { a.update(toward: 3, dt: 1.0 / 60) }
    for _ in 0..<30 { b.update(toward: 3, dt: 1.0 / 30) }
    #expect(abs(a.value - b.value) < 0.02)
}

@Test func zeroOrNegativeTimeChangesNothing() {
    var s = Spring(2)
    s.update(toward: 9, dt: 0); s.update(toward: 9, dt: -1)
    #expect(s.value == 2 && s.velocity == 0)
}

private struct Seq: RandomSource {
    var values: [Double]; var i = 0
    mutating func next(in range: ClosedRange<Double>) -> Double {
        let v = values[min(i, values.count - 1)]; i += 1
        return range.lowerBound + (range.upperBound - range.lowerBound) * v
    }
}

@Test func idleVarietyStaysQuietThenPlaysOneMoveAndRests() {
    var v = IdleVariety(rng: Seq(values: [0.5, 0.5]), firstAfter: 2)   // 0.5 → preen
    for _ in 0..<110 { v.update(dt: 1.0 / 60, calm: true) }            // 1.8 s: still waiting
    #expect(v.move == .none)
    for _ in 0..<40 { v.update(dt: 1.0 / 60, calm: true) }
    #expect(v.move == .preen && v.progress < 1)
    for _ in 0..<130 { v.update(dt: 1.0 / 60, calm: true) }
    #expect(v.move == .none)
}

@Test func beingBusyCancelsAMoveInProgress() {
    var v = IdleVariety(rng: Seq(values: [0.1]), firstAfter: 0.1)
    for _ in 0..<20 { v.update(dt: 1.0 / 60, calm: true) }
    #expect(v.move == .lookLeft)
    v.update(dt: 1.0 / 60, calm: false)
    #expect(v.move == .none && v.progress == 0)
}

@Test func everyKindOfMoveCanBePicked() {
    var seen = Set<IdleVariety.Move>()
    for r in stride(from: 0.05, to: 1.0, by: 0.1) {
        var v = IdleVariety(rng: Seq(values: [r, 0.5]), firstAfter: 0.01)
        v.update(dt: 0.05, calm: true)
        seen.insert(v.move)
    }
    #expect(seen == [.lookLeft, .lookRight, .preen, .stretch, .shake, .peckGround])
}
