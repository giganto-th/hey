import Testing
@testable import HeyDomain

struct FixedRandom: RandomSource {
    var value: Double
    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * value
    }
}

@Test func idleBecomesWalkAfterDuration() {
    var fsm = BehaviorFSM(rng: FixedRandom(value: 0.1))
    fsm.tick(dt: 3.1)
    #expect(fsm.pose == .walk)
}

@Test func clickMakesHappyThenIdle() {
    var fsm = BehaviorFSM(rng: FixedRandom(value: 0.9))
    fsm.send(.clicked)
    #expect(fsm.pose == .happy)
    fsm.tick(dt: 1.6)
    #expect(fsm.pose == .idle)
}

@Test func grabReleaseLandCycle() {
    var fsm = BehaviorFSM(rng: FixedRandom(value: 0.9))
    fsm.send(.grabbed)
    #expect(fsm.pose == .carried)
    fsm.tick(dt: 100)
    #expect(fsm.pose == .carried)
    fsm.send(.released)
    #expect(fsm.pose == .falling)
    fsm.send(.clicked)
    #expect(fsm.pose == .falling)
    fsm.send(.landed)
    #expect(fsm.pose == .idle)
}

@Test func zigzagIsAStroke() {
    var d = StrokeDetector()
    var hit = false
    var x = 0.0, t = 0.0, dir = 1.0
    for i in 0..<12 {
        if i % 3 == 0 { dir = -dir }
        x += dir * 10; t += 0.05
        if d.move(x: x, at: t) { hit = true }
    }
    #expect(hit)
}

@Test func straightLineIsNotAStroke() {
    var d = StrokeDetector()
    var hit = false
    for i in 0..<40 where d.move(x: Double(i) * 10, at: Double(i) * 0.05) { hit = true }
    #expect(!hit)
}

@Test func fastShakeIsNotAStroke() {
    var d = StrokeDetector()
    var hit = false
    var dir = 1.0
    for i in 0..<20 {
        dir = -dir
        if d.move(x: dir * 80, at: Double(i) * 0.01) { hit = true }
    }
    #expect(!hit)
}

@Test func feedingMakesThePetEatThenSettle() {
    var fsm = BehaviorFSM(rng: FixedRandom(value: 0.9))
    fsm.send(.fed)
    #expect(fsm.pose == .eat)
    fsm.tick(dt: 2.1)
    #expect(fsm.pose == .idle)
}

@Test func eatingIsIgnoredWhileBeingCarried() {
    var fsm = BehaviorFSM(rng: FixedRandom(value: 0.9))
    fsm.send(.grabbed)
    fsm.send(.fed)
    #expect(fsm.pose == .carried)
}
