import Testing
import Foundation
@testable import HeyDomain

@Test func seekDecidesDirectionAndArrival() {
    #expect(Seek.decide(petX: 100, targetX: 300, reach: 20) == .toward(right: true))
    #expect(Seek.decide(petX: 300, targetX: 100, reach: 20) == .toward(right: false))
    #expect(Seek.decide(petX: 100, targetX: 115, reach: 20) == .arrived)
    #expect(Seek.decide(petX: 100, targetX: 80, reach: 20) == .arrived)
}

@Test func seekingFsmWalksUntilSettled() {
    var fsm = BehaviorFSM(rng: FixedRandom(value: 0.9))
    fsm.seek(right: false)
    #expect(fsm.pose == .walk)
    #expect(fsm.facingRight == false)
    #expect(fsm.isSeeking)
    fsm.tick(dt: 600)
    #expect(fsm.pose == .walk)                 // the random pick never interrupts a seek
    fsm.settle()
    #expect(fsm.pose == .idle)
    #expect(!fsm.isSeeking)
}

@Test func seekWakesASleeperButNotACarriedOrFallingPet() {
    var sleeper = BehaviorFSM(rng: FixedRandom(value: 0.9))
    sleeper.send(.tired)
    #expect(sleeper.pose == .sleep)
    sleeper.seek(right: true)
    #expect(sleeper.pose == .walk)

    var carried = BehaviorFSM(rng: FixedRandom(value: 0.9))
    carried.send(.grabbed)
    carried.seek(right: true)
    #expect(carried.pose == .carried)
}

@Test func peckIsAShortMeal() {
    var fsm = BehaviorFSM(rng: FixedRandom(value: 0.9))
    fsm.send(.pecked)
    #expect(fsm.pose == .eat)
    fsm.tick(dt: 1.0)
    #expect(fsm.pose == .idle)
}

@Test func bubblesSpawnDriftBounceAndPop() {
    var field = BubbleField(rng: FixedRandom(value: 0.5))
    field.spawn(5, minX: 0, maxX: 1000)
    #expect(field.bubbles.count == 5)
    #expect(field.bubbles.allSatisfy { BubbleField.heightRange.contains($0.baseHeight) })

    var edge = BubbleField(rng: FixedRandom(value: 0.99))       // fast, heading right, near the right edge
    edge.spawn(1, minX: 0, maxX: 1000)
    for _ in 0..<2000 { edge.step(dt: 0.05, minX: 0, maxX: 1000) }
    #expect(edge.bubbles[0].x >= 0 && edge.bubbles[0].x <= 1000)

    let id = field.bubbles[2].id
    let first = field.pop(id)
    let second = field.pop(id)
    #expect(first)
    #expect(!second)
    #expect(field.bubbles.count == 4)
    #expect(field.popped == 1)
}

@Test func bubbleFieldIsCappedAndFindsTheNearest() {
    var field = BubbleField(rng: SequenceRandom([0.5, 0.5, 0.1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.9, 0.5, 0.5, 0.5]))
    field.spawn(2, minX: 0, maxX: 1000)
    let x0 = field.bubbles[0].x, x1 = field.bubbles[1].x
    #expect(x0 < x1)
    #expect(field.nearest(toX: x0 - 50)?.id == field.bubbles[0].id)
    #expect(field.nearest(toX: x1 + 50)?.id == field.bubbles[1].id)
    var big = BubbleField(rng: FixedRandom(value: 0.5))
    big.spawn(100, minX: 0, maxX: 100)
    #expect(big.bubbles.count == BubbleField.maxBubbles)
    big.clear()
    #expect(big.isEmpty)
}

@Test func feedRefusalMatchesWhatFeedWouldDo() {
    let day0 = Date(timeIntervalSince1970: 1_700_000_000)
    var pet = PetState(now: day0, calendar: .init(identifier: .gregorian))
    pet.stage = .hatchling; pet.hunger = 30
    var g = Game(save: SaveData(pet: pet), calendar: .init(identifier: .gregorian), rng: FixedRandom(value: 0))
    let free = g.pet.balance.foods.first { $0.price == 0 }!
    #expect(g.feedRefusal(free, at: day0) == nil)
    _ = g.feed(free, at: day0)
    if case .pet(.refusedCooldown)? = g.feedRefusal(free, at: day0) {} else { Issue.record("expected a cooldown refusal") }
    let paid = g.pet.balance.foods.first { $0.price > 0 }!
    if case .noStock? = g.feedRefusal(paid, at: day0) {} else { Issue.record("expected no stock") }
}

@Test func bubbleTotalsUnlockAchievementsAndOldSavesStillLoad() throws {
    let day0 = Date(timeIntervalSince1970: 1_700_000_000)
    var g = Game(save: SaveData(pet: PetState(now: day0, calendar: .init(identifier: .gregorian))),
                 calendar: .init(identifier: .gregorian), rng: FixedRandom(value: 0))
    g.recordBubbles(20)
    let events = g.checkAchievements(at: day0)
    #expect(events.contains { if case .achievementUnlocked(let a) = $0 { a.id == "bubble20" } else { false } })
    #expect(g.stats.bubblesPopped == 20)

    // a stats record from before the bubbles existed keeps its other totals
    let old = #"{"feeds":7,"pets":3}"#.data(using: .utf8)!
    let stats = try JSONDecoder().decode(LifetimeStats.self, from: old)
    #expect(stats.feeds == 7 && stats.pets == 3 && stats.bubblesPopped == 0)
}
