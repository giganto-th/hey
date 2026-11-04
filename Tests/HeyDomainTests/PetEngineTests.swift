import Testing
import Foundation
@testable import HeyDomain

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func hatchling(_ configure: (inout PetState) -> Void = { _ in }) -> PetEngine {
    var s = PetState(now: t0)
    s.stage = .hatchling
    s.favoriteFood = "cookie"
    configure(&s)
    return PetEngine(state: s, rng: FixedRandom(value: 0))
}

@Test func eggWarmsWhileRunningAndHatches() {
    var e = PetEngine(state: PetState(now: t0), rng: FixedRandom(value: 0))
    var events: [PetEngineEvent] = []
    var now = t0
    for _ in 0..<100 {                    // 100 one-minute ticks, daily cap 60 stops it
        now = now.addingTimeInterval(60)
        events += e.advance(to: now, sleeping: false)
    }
    #expect(e.state.stage == .egg)
    #expect(e.state.hatchProgress == 60)

    for _ in 0..<20 { events += e.pet(at: now) }   // clicks add 10 per day max
    #expect(e.state.hatchProgress == 70)

    now = now.addingTimeInterval(86_400)          // next day: cap resets
    now = now.addingTimeInterval(60)
    e.advance(to: now, sleeping: false)
    for i in 1...31 { events += e.advance(to: now.addingTimeInterval(Double(i) * 60), sleeping: false) }
    #expect(e.state.stage == .hatchling)
    #expect(events.contains(.hatched))
    #expect(e.state.favoriteFood == "rice")       // FixedRandom(0) picks the first food
}

@Test func eggDoesNotWarmWhileAppWasClosed() {
    var e = PetEngine(state: PetState(now: t0))
    e.advance(to: t0.addingTimeInterval(3 * 3600), sleeping: false)
    #expect(e.state.hatchProgress == 0)
}

@Test func statsDecayAndClamp() {
    var e = hatchling()
    e.advance(to: t0.addingTimeInterval(60), sleeping: false)   // 1 min, running
    #expect(e.state.hunger < 80 && e.state.hunger > 79.9)
    e.advance(to: t0.addingTimeInterval(120), sleeping: false)
    #expect(e.state.energy <= 100)
}

@Test func offlineCatchUpIsCappedAndRests() {
    var e = hatchling { $0.energy = 20 }
    e.advance(to: t0.addingTimeInterval(48 * 3600), sleeping: false)  // two days closed
    #expect(e.state.hunger == 80 - 4 * 8)       // capped at 8 hours
    #expect(e.state.energy == 100)              // rested while closed
}

@Test func clockGoingBackwardsDoesNothing() {
    var e = hatchling()
    e.advance(to: t0.addingTimeInterval(-3600), sleeping: false)
    #expect(e.state.hunger == 80)
    #expect(e.state.lastTickAt == t0.addingTimeInterval(-3600))
}

@Test func feedingRespectsCooldownAndFullness() {
    var e = hatchling { $0.hunger = 50 }
    let rice = e.balance.foods[0]
    #expect(e.feed(rice, at: t0).first == .fed(rice))
    #expect(e.state.hunger == 70)
    let again = e.feed(rice, at: t0.addingTimeInterval(60))
    #expect(again == [.refusedCooldown(remaining: 540)])
    e.advance(to: t0, sleeping: false)
    var full = hatchling { $0.hunger = 97 }
    #expect(full.feed(rice, at: t0) == [.refusedFull])
}

@Test func cannotFeedAnEgg() {
    var e = PetEngine(state: PetState(now: t0))
    #expect(e.feed(e.balance.foods[0], at: t0) == [.refusedEgg])
}

@Test func favoriteFoodDoublesXPAndMood() {
    var e = hatchling { $0.hunger = 50; $0.mood = 10 }
    let cookie = e.balance.foods[1]
    e.feed(cookie, at: t0)
    #expect(e.state.mood == 40)     // 10 + 15*2
    #expect(e.state.xp == 6)        // 3*2
}

@Test func starvingPetGainsHalfXP() {
    var e = hatchling { $0.hunger = 10 }
    e.feed(e.balance.foods[0], at: t0)
    #expect(e.state.xp == 1)
}

@Test func xpEvolvesStages() {
    var e = hatchling { $0.xp = 149; $0.hunger = 0 }
    let events = e.feed(e.balance.foods[2], at: t0)     // fruit: 8 xp halved to 4 while starving
    #expect(events.contains(.evolved(.child)))
    #expect(e.state.stage == .child)
}

@Test func dailyCheckInOncePerDay() {
    var e = hatchling()
    #expect(e.dailyCheckIn(at: t0).contains(.dailyCheckIn))
    #expect(e.dailyCheckIn(at: t0.addingTimeInterval(60)).isEmpty)
    #expect(e.dailyCheckIn(at: t0.addingTimeInterval(86_400 * 2)).contains(.dailyCheckIn))
}

@Test func stateSurvivesJSONRoundTrip() throws {
    var e = hatchling()
    e.feed(e.balance.foods[0], at: t0)
    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
    let back = try dec.decode(PetState.self, from: enc.encode(e.state))
    #expect(back == e.state)
}
