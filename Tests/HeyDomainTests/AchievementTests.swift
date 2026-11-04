import Testing
import Foundation
@testable import HeyDomain

private let gmt: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "GMT")!
    return c
}()
private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func newGame(stage: PetStage = .hatchling) -> Game {
    var pet = PetState(now: t0, calendar: gmt)
    pet.stage = stage
    pet.hunger = 10
    return Game(save: SaveData(pet: pet), calendar: gmt, rng: FixedRandom(value: 0))
}

private func unlocked(_ g: Game) -> Set<String> { Set(g.achievements.keys) }

@Test func catalogIsWellFormed() {
    let ids = Achievement.all.map(\.id)
    #expect(Set(ids).count == ids.count)
    for a in Achievement.all { #expect(a.goal > 0 && a.reward > 0 && !a.title.isEmpty && !a.detail.isEmpty) }
}

@Test func hatchedPetUnlocksAndPaysOnce() {
    var g = newGame()
    let coins = g.coins
    let first = g.checkAchievements(at: t0)
    #expect(first.contains(.achievementUnlocked(Achievement.all.first { $0.id == "hatch" }!.info)))
    #expect(g.coins == coins + 10)
    #expect(g.checkAchievements(at: t0.addingTimeInterval(60)).isEmpty)       // never twice
    #expect(g.coins == coins + 10)
}

@Test func eggUnlocksNothing() {
    var g = newGame(stage: .egg)
    #expect(g.checkAchievements(at: t0).isEmpty)
}

@Test func feedingCountsOnlySuccessfulFeeds() {
    var g = newGame()
    let rice = g.pet.balance.foods[0]
    _ = g.feed(rice, at: t0)
    _ = g.feed(rice, at: t0.addingTimeInterval(10))                             // cooldown: refused
    #expect(g.stats.feeds == 1)
    let cookie = g.pet.balance.foods[1]
    _ = g.feed(cookie, at: t0)                                                  // not in stock: refused
    #expect(g.stats.feeds == 1)
}

@Test func tenFeedsUnlockTheFeedAchievement() {
    var g = newGame()
    let rice = g.pet.balance.foods[0]
    var now = t0
    for _ in 0..<10 {
        now = now.addingTimeInterval(700)                                       // past the rice cooldown
        _ = g.advance(to: now, sleeping: false)
        _ = g.feed(rice, at: now)
        // keep the pet hungry enough to accept food
        var s = g.save; s.pet.hunger = 20; g = Game(save: s, calendar: gmt, rng: FixedRandom(value: 0))
    }
    #expect(g.stats.feeds == 10)
    #expect(g.checkAchievements(at: now).contains { if case .achievementUnlocked(let a) = $0 { a.id == "feed10" } else { false } })
}

@Test func otherCountersTick() {
    var g = newGame()
    _ = g.pet(at: t0)
    _ = g.creditPomodoro(session: 1)
    g.addReminder("x", at: t0, now: t0)
    _ = g.addVaultItem(VaultItem(kind: .text, mode: .copy, name: "a", text: "a", addedAt: t0))
    _ = g.addMedia(MediaItem(kind: .photo, path: "/a", createdAt: t0))
    _ = g.recordListening(minutes: 1.5)
    #expect(g.stats.pets == 1 && g.stats.pomodoros == 1 && g.stats.remindersSet == 1)
    #expect(g.stats.vaultAdds == 1 && g.stats.captures == 1 && g.stats.musicMinutes == 1.5)
}

@Test func eggClicksDoNotCountAsPetting() {
    var g = newGame(stage: .egg)
    _ = g.pet(at: t0)
    #expect(g.stats.pets == 0)
}

@Test func miniGameRewardIsCappedAndNeverNegative() {
    #expect(MiniGame.reward(score: -5) == 0)
    #expect(MiniGame.reward(score: 9) == 4)
    #expect(MiniGame.reward(score: 500) == MiniGame.maxRewardPerPlay)
}

@Test func onlyTheFirstPlaysEachDayPayAndItResetsNextDay() {
    var g = newGame()
    let start = g.coins
    for i in 0..<MiniGame.maxRewardedPlaysPerDay {
        let events = g.finishMiniGame(score: 10, at: t0.addingTimeInterval(Double(i)))
        #expect(events == [.miniGameFinished(score: 10, reward: 5)])
    }
    #expect(g.coins == start + 15 && g.miniGamePlaysLeft(at: t0) == 0)
    #expect(g.finishMiniGame(score: 40, at: t0.addingTimeInterval(100)) == [.miniGameFinished(score: 40, reward: 0)])
    #expect(g.coins == start + 15)
    #expect(g.stats.miniGameBest == 40)                                          // the record still counts

    let tomorrow = t0.addingTimeInterval(86_400)
    #expect(g.miniGamePlaysLeft(at: tomorrow) == MiniGame.maxRewardedPlaysPerDay)
    #expect(g.finishMiniGame(score: 10, at: tomorrow) == [.miniGameFinished(score: 10, reward: 5)])
}

@Test func statsAndUnlocksSurviveSavingAndOldSavesStartEmpty() throws {
    var g = newGame()
    _ = g.pet(at: t0)
    _ = g.checkAchievements(at: t0)
    let data = try g.save.encoded()
    let back = try SaveData.decode(data)
    #expect(back == g.save && back.achievements["hatch"] == t0)

    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let pet = try String(decoding: enc.encode(g.save.pet), as: UTF8.self)
    let old = try SaveData.decode(Data(#"{"pet":\#(pet)}"#.utf8))
    #expect(old.stats == LifetimeStats() && old.achievements.isEmpty)
}
