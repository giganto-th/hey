import Testing
import Foundation
@testable import HeyDomain

private let gmt: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "GMT")!
    return c
}()
private let day0 = Date(timeIntervalSince1970: 1_800_000_000)   // 2027-01-15 08:00 GMT

/// Returns the given values in order, then repeats the last one.
struct SequenceRandom: RandomSource {
    var values: [Double]
    private var i = 0
    init(_ values: [Double]) { self.values = values }
    mutating func next(in range: ClosedRange<Double>) -> Double {
        let v = values[min(i, values.count - 1)]
        i += 1
        return range.lowerBound + (range.upperBound - range.lowerBound) * v
    }
}

/// A random source that makes the day's quests come out as exactly `kinds`, whatever order the pool is in.
func questRNG(_ kinds: [QuestKind], stage: PetStage = .hatchling) -> SequenceRandom {
    var pool = Quest.templates(for: stage).map(\.kind)
    var values: [Double] = []
    for kind in kinds {
        let i = pool.firstIndex(of: kind)!
        values.append((Double(i) + 0.5) / Double(pool.count))
        pool.remove(at: i)
    }
    return SequenceRandom(values)
}

private func game(egg: Bool = false, pick: Double = 0, rng: (any RandomSource)? = nil,
                  _ configure: (inout SaveData) -> Void = { _ in }) -> Game {
    var pet = PetState(now: day0, calendar: gmt)
    if !egg { pet.stage = .hatchling; pet.hunger = 30; pet.favoriteFood = "honey" }
    var save = SaveData(pet: pet)
    configure(&save)
    return Game(save: save, calendar: gmt, rng: rng ?? FixedRandom(value: pick))
}

private func foods(_ g: Game) -> [String: Food] {
    Dictionary(uniqueKeysWithValues: g.pet.balance.foods.map { ($0.id, $0) })
}

@Test func eggGetsEggQuestsAndCheckInPaysOut() {
    var g = game(egg: true, rng: questRNG([.checkIn, .online, .warm], stage: .egg))
    let events = g.startSession(at: day0)
    #expect(Set(g.quests.map(\.kind)) == [.checkIn, .online, .warm])
    #expect(g.coins == 25)
    #expect(g.streak.current == 1)
    #expect(events.contains { if case .questCompleted(let q) = $0 { q.kind == .checkIn } else { false } })
}

@Test func restartingSameDayKeepsQuests() {
    var g = game()
    _ = g.startSession(at: day0)
    let before = g.quests
    var again = Game(save: g.save, calendar: gmt, rng: FixedRandom(value: 0.99))
    _ = again.startSession(at: day0.addingTimeInterval(3600))
    #expect(again.quests == before)
    #expect(again.coins == g.coins)                 // check-in is not paid twice
}

@Test func newDayAfterFourAMRollsQuests() {
    var g = game()
    _ = g.startSession(at: day0)                    // 08:00
    _ = g.advance(to: day0.addingTimeInterval(3600 * 14), sleeping: false)   // 22:00 same quest day
    let sameDay = g.quests
    _ = g.advance(to: day0.addingTimeInterval(3600 * 22), sleeping: false)   // 06:00 next day
    #expect(g.quests != sameDay)
    #expect(g.quests.allSatisfy { !$0.done })
}

@Test func finishingAllQuestsPaysBonus() {
    var g = game(rng: questRNG([.checkIn, .online, .feed]))
    _ = g.startSession(at: day0)
    var now = day0
    for _ in 0..<21 { now = now.addingTimeInterval(60); _ = g.advance(to: now, sleeping: false) }
    let rice = foods(g)["rice"]!
    _ = g.feed(rice, at: now)
    #expect(g.quests.contains { $0.kind == .feed && !$0.done })
    _ = g.feed(rice, at: now.addingTimeInterval(601))
    #expect(g.quests.allSatisfy { $0.done })
    // 20 start + 5 + 8 + 10 + 20 bonus
    #expect(g.coins == 63)
}

@Test func varietyCountsDistinctFoodsOnly() {
    var g = game(rng: questRNG([.variety, .pet, .feed])) { $0.coins = 100; $0.inventory["cookie"] = 3 }  // variety, pet, feed
    _ = g.startSession(at: day0)
    #expect(g.quests.map(\.kind) == [.variety, .pet, .feed])
    let f = foods(g)
    _ = g.feed(f["rice"]!, at: day0)
    _ = g.feed(f["rice"]!, at: day0.addingTimeInterval(601))
    #expect(g.quests[0].progress == 1)
    _ = g.feed(f["cookie"]!, at: day0.addingTimeInterval(700))
    #expect(g.quests[0].done)
}

@Test func streakGrowsHalvesAndPaysWeeklyBonus() {
    var g = game()
    for d in 0..<7 { _ = g.startSession(at: day0.addingTimeInterval(Double(d) * 86_400)) }
    #expect(g.streak.current == 7)
    #expect(g.coins == 20 + 7 * 5 + Game.streakBonus)
    _ = g.startSession(at: day0.addingTimeInterval(10 * 86_400))     // missed 2 days
    #expect(g.streak.current == 4)                                     // 7/2 + 1
    #expect(g.streak.best == 7)
}

@Test func shopBuyFeedConsume() {
    var g = game()
    let f = foods(g)
    #expect(g.buy(f["cookie"]!) == [.bought(f["cookie"]!)])
    #expect(g.coins == 12 && g.stock(of: f["cookie"]!) == 1)
    #expect(g.buy(f["honey"]!) == [.insufficientCoins(f["honey"]!)])
    #expect(g.coins == 12)
    #expect(g.feed(f["fruit"]!, at: day0) == [.noStock(f["fruit"]!)])
    _ = g.feed(f["cookie"]!, at: day0)
    #expect(g.stock(of: f["cookie"]!) == 0)
}

@Test func refusedFeedKeepsTheItem() {
    var g = game { $0.pet.hunger = 99; $0.inventory["cookie"] = 1 }
    let cookie = foods(g)["cookie"]!
    #expect(g.feed(cookie, at: day0) == [.pet(.refusedFull)])
    #expect(g.stock(of: cookie) == 1)
}

@Test func freeFoodIsUnlimitedStock() {
    let g = game()
    #expect(g.stock(of: foods(g)["rice"]!) == .max)
}

@Test func saveRoundTripAndLegacyMigration() throws {
    var g = game()
    _ = g.startSession(at: day0)
    let data = try g.save.encoded()
    let restored = try SaveData.decode(data)
    #expect(restored == g.save)

    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let legacy = try enc.encode(g.save.pet)                            // old pet.json shape
    let migrated = try SaveData.decode(legacy)
    #expect(migrated.pet == g.save.pet)
    #expect(migrated.coins == 20 && migrated.quests.isEmpty)
}

@Test func oldSaveWithPlaceholderNameBecomesHeiHeiButCustomNamesStay() throws {
    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    func load(name: String, extra: String = "") throws -> SaveData {
        var pet = PetState(now: day0, calendar: gmt); pet.name = name
        let petJSON = String(decoding: try enc.encode(pet), as: UTF8.self)
        return try SaveData.decode(Data(#"{"pet":\#(petJSON)\#(extra)}"#.utf8))
    }
    let old = try load(name: "Hey")
    #expect(old.species == "heihei" && old.pet.name == "Hei Hei")
    #expect(try load(name: "Pookie").pet.name == "Pookie")
    #expect(try load(name: "Hey", extra: #","species":"blob""#).pet.name == "Hey")      // an explicit species is never renamed
    #expect(PetState().name == "Hei Hei")
    let previous = try load(name: "Hei Hei", extra: #","species":"heihei""#)
    #expect(previous.species == "heihei" && previous.pet.name == "Hei Hei")
    #expect(try load(name: "Pookie", extra: #","species":"heihei""#).pet.name == "Pookie")
}

// MARK: damaged saves

private func saveJSON(_ extra: String) throws -> Data {
    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let pet = String(decoding: try enc.encode(PetState(now: day0, calendar: gmt)), as: UTF8.self)
    return Data(#"{"coins":61,"pet":\#(pet)\#(extra)}"#.utf8)
}

@Test func oneDamagedListItemIsSkippedAndEverythingElseSurvives() throws {
    let good = #"{"id":"11111111-1111-1111-1111-111111111111","text":"ok","colorIndex":0,"pinned":false,"createdAt":"2027-01-15T08:00:00Z","updatedAt":"2027-01-15T08:00:00Z"}"#
    let save = try SaveData.decode(saveJSON(#","reminders":[{"text":"broken"}],"notes":[{"nonsense":1},\#(good)]"#))
    #expect(save.coins == 61)
    #expect(save.reminders.isEmpty)
    #expect(save.notes.map(\.text) == ["ok"])
}

@Test func aSectionOfTheWrongTypeFallsBackAlone() throws {
    let save = try SaveData.decode(saveJSON(#","music":"not an object","inventory":[1,2],"streak":{"current":"x"}"#))
    #expect(save.coins == 61)
    #expect(save.music == MusicSettings() && save.inventory.isEmpty && save.streak == StreakState())
}

@Test func withoutAPetTheSaveIsUnreadable() {
    #expect(throws: (any Error).self) { try SaveData.decode(Data(#"{"coins":5}"#.utf8)) }
}

// MARK: guide and feeding answers

@Test func guideTipsComeOnceAndFitTheStage() {
    var g = game(egg: true)
    var tips: [GuideTip] = []
    while let t = g.nextGuideTip() { tips.append(t) }
    #expect(tips == [.warmEgg, .openMenu, .dropFiles])         // an egg can't eat yet
    #expect(g.nextGuideTip() == nil)
    let again = try? SaveData.decode(g.save.encoded())
    #expect(again?.guide == g.save.guide)
}

@Test func clickingAnEggReportsProgressThenTheDailyLimit() {
    var g = game(egg: true)
    #expect(g.pet(at: day0).contains(.pet(.eggWarmed(progress: 2, needed: 100))))
    for _ in 0..<4 { _ = g.pet(at: day0) }
    #expect(g.pet(at: day0).contains(.pet(.eggWarmEnoughToday)))
}

@Test func cooldownIsReportedInMinutes() {
    var g = game()
    let rice = g.pet.balance.foods[0]
    #expect(g.pet.cooldownRemaining(rice, at: day0) == 0)
    _ = g.feed(rice, at: day0)
    #expect(g.pet.cooldownRemaining(rice, at: day0.addingTimeInterval(100)) == 500)
    #expect(DurationText.wait(500) == "อีก 9 นาที")
    #expect(DurationText.wait(3 * 3600) == "อีก 3 ชั่วโมง")
}
