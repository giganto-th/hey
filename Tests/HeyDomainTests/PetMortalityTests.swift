import Testing
import Foundation
@testable import HeyDomain

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func pet(_ configure: (inout PetState) -> Void = { _ in }) -> PetEngine {
    var s = PetState(now: t0)
    s.stage = .child
    configure(&s)
    return PetEngine(state: s, rng: FixedRandom(value: 0))
}

/// Advances in `hours` one-minute-sized steps' worth of time, ticking every 10 minutes like the app does.
@discardableResult
private func run(_ e: inout PetEngine, from start: Date, hours: Double, sleeping: Bool = false) -> [PetEngineEvent] {
    var events: [PetEngineEvent] = []
    var now = start
    let step = 600.0
    var t = 0.0
    while t < hours * 3600 {
        now = now.addingTimeInterval(step); t += step
        events += e.advance(to: now, sleeping: sleeping)
    }
    return events
}

@Test func aHealthyPetNeverBuildsNeglect() {
    var e = pet()
    run(&e, from: t0, hours: 10)
    #expect(e.state.neglectSeconds == nil)
    #expect(!e.state.isDead)
}

@Test func neglectOnlyCountsAfterAStatReachesZero() {
    var e = pet { $0.hunger = 8 }                    // 4/h: empty after 2 hours
    run(&e, from: t0, hours: 2)
    #expect(e.state.hunger == 0)
    #expect((e.state.neglectSeconds ?? 0) < 600)     // nothing yet, give or take a tick
    run(&e, from: t0.addingTimeInterval(2 * 3600), hours: 1)
    let hours = (e.state.neglectSeconds ?? 0) / 3600
    #expect(hours > 0.9 && hours < 1.1)
}

@Test func warningsComeBeforeDeath() {
    var e = pet { $0.hunger = 0 }
    let events = run(&e, from: t0, hours: 5)
    #expect(events.contains(.neglect(level: 1)))
    #expect(!events.contains(.neglect(level: 2)))
    #expect(!e.state.isDead)
    let more = run(&e, from: t0.addingTimeInterval(5 * 3600), hours: 4)
    #expect(more.contains(.neglect(level: 2)))
    #expect(!e.state.isDead)
}

@Test func aPetDiesAfterTwelveHoursAtZero() {
    var e = pet { $0.hunger = 0 }
    let events = run(&e, from: t0, hours: 13)
    #expect(events.contains(.died(.hunger)))
    #expect(e.state.isDead)
    #expect(e.state.deathCause == .hunger)
    #expect(e.state.diedAt != nil)
}

@Test func theCauseIsTheNeedThatRanOutFirst() {
    var e = pet { $0.mood = 0; $0.hunger = 100 }
    let events = run(&e, from: t0, hours: 13)
    #expect(events.contains(.died(.mood)))
}

@Test func feedingInTimeBringsItBack() {
    var e = pet { $0.hunger = 0 }
    run(&e, from: t0, hours: 6)
    let neglected = e.state.neglectSeconds ?? 0
    #expect(neglected > 5 * 3600)
    _ = e.feed(Balance.standard.foods[0], at: t0.addingTimeInterval(6 * 3600))
    #expect(e.state.hunger > 0)
    run(&e, from: t0.addingTimeInterval(6 * 3600), hours: 3)
    #expect((e.state.neglectSeconds ?? 0) < neglected)         // recovering, not growing
    #expect(!e.state.isDead)
}

@Test func aLongClosedGapIsCappedSoANightAwayCannotKill() {
    var e = pet { $0.hunger = 5 }
    e.advance(to: t0.addingTimeInterval(72 * 3600), sleeping: false)      // three days closed
    #expect(!e.state.isDead)
    #expect((e.state.neglectSeconds ?? 0) <= 8 * 3600)
}

@Test func mortalityCanBeSwitchedOff() {
    var e = pet { $0.hunger = 0 }
    e.mortal = false
    let events = run(&e, from: t0, hours: 20)
    #expect(!e.state.isDead)
    #expect(!events.contains { if case .died = $0 { true } else { false } })
}

@Test func eggsDoNotDie() {
    var e = PetEngine(state: PetState(now: t0))
    run(&e, from: t0, hours: 30)
    #expect(!e.state.isDead)
}

@Test func aDeadPetRefusesCareAndStaysDead() {
    var e = pet { $0.hunger = 0 }
    run(&e, from: t0, hours: 13)
    #expect(e.state.isDead)
    let food = Balance.standard.foods[0]
    #expect(e.feedRefusal(food, at: t0) == .refusedDead)
    let fed = e.feed(food, at: t0.addingTimeInterval(14 * 3600))
    let petted = e.pet(at: t0.addingTimeInterval(14 * 3600))
    #expect(fed == [.refusedDead])
    #expect(petted == [.refusedDead])
    let xp = e.state.xp
    _ = e.grantXP(50)
    #expect(e.state.xp == xp)
}

@Test func hoursUntilDeathCountsDown() {
    var e = pet { $0.hunger = 0 }
    #expect(e.hoursUntilDeath == nil)
    run(&e, from: t0, hours: 4)
    let left = e.hoursUntilDeath ?? 0
    #expect(left > 7 && left < 9)
}

@Test func hatchingANewEggKeepsWhatThePlayerOwns() {
    var save = SaveData(pet: {
        var s = PetState(now: t0); s.stage = .teen; s.name = "Pip"; s.xp = 500; s.hunger = 0; return s
    }())
    save.coins = 321
    save.species = "shishi"
    var game = Game(save: save)
    _ = game.advance(to: t0.addingTimeInterval(13 * 3600), sleeping: false)
    // the engine ticks in bounded steps in the app; drive it the same way
    var now = t0
    for _ in 0..<80 { now = now.addingTimeInterval(600); _ = game.advance(to: now, sleeping: false) }
    #expect(game.pet.state.isDead)
    let reborn = game.hatchNewEgg(at: now.addingTimeInterval(60))
    #expect(reborn)
    #expect(game.pet.state.stage == .egg)
    #expect(!game.pet.state.isDead)
    #expect(game.pet.state.name == "Shi Shi")
    #expect(game.coins == 321)
    #expect(game.memorials.count == 1)
    #expect(game.memorials[0].name == "Pip" && game.memorials[0].cause == .hunger && game.memorials[0].species == "shishi")
}

@Test func aLivingPetCannotBeReplaced() {
    var game = Game(save: SaveData(pet: PetState(now: t0)))
    let replaced = game.hatchNewEgg(at: t0)
    #expect(!replaced)
    #expect(game.memorials.isEmpty)
}

@Test func theNewEggCanBeAnotherKind() {
    var save = SaveData(pet: { var s = PetState(now: t0); s.stage = .child; s.hunger = 0; return s }())
    save.species = "heihei"
    var game = Game(save: save)
    var now = t0
    for _ in 0..<100 { now = now.addingTimeInterval(600); _ = game.advance(to: now, sleeping: false) }
    let reborn = game.hatchNewEgg(at: now, species: "fluff")
    #expect(reborn)
    #expect(game.species == "fluff")
    #expect(game.pet.state.name == "Shams")
}

@Test func anOldSaveWithoutTheNewFieldsStillLoads() throws {
    var save = SaveData(pet: PetState(now: t0))
    save.coins = 7
    let data = try save.encoded()
    var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    json.removeValue(forKey: "care"); json.removeValue(forKey: "memorials")
    var pet = try #require(json["pet"] as? [String: Any])
    for k in ["neglectSeconds", "diedAt", "deathCause"] { pet.removeValue(forKey: k) }
    json["pet"] = pet
    let old = try JSONSerialization.data(withJSONObject: json)
    let loaded = try SaveData.decode(old)
    #expect(loaded.coins == 7)
    #expect(loaded.care.mortal)
    #expect(loaded.memorials.isEmpty)
    #expect(!loaded.pet.isDead)
}

@Test func deathAndMemorialsSurviveASaveRoundTrip() throws {
    var save = SaveData(pet: { var s = PetState(now: t0); s.diedAt = t0; s.deathCause = .energy; s.neglectSeconds = 50_000; return s }())
    save.memorials = [PetMemorial(name: "A", species: "heihei", stage: .adult, bornAt: t0, diedAt: t0.addingTimeInterval(86_400 * 3), cause: .mood, xp: 9)]
    save.care.mortal = false
    let back = try SaveData.decode(try save.encoded())
    #expect(back.pet.isDead && back.pet.deathCause == .energy)
    #expect(back.memorials.first?.daysLived == 3)
    #expect(!back.care.mortal)
}
