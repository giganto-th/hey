import Testing
import Foundation
@testable import HeyDomain

private let gmt: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "GMT")!
    return c
}()
// 2027-01-15 08:00 GMT
private let morning = Date(timeIntervalSince1970: 1_800_000_000)
private func at(_ hour: Int, minute: Int = 0, day: Int = 0) -> Date {
    gmt.date(bySettingHour: hour, minute: minute, second: 0, of: morning.addingTimeInterval(Double(day) * 86_400))!
}

@Test func lateNightWindowWrapsPastMidnight() {
    let e = ContextEngine()
    for h in [23, 0, 3, 4] { #expect(e.isLateNight(hour: h), "\(h)") }
    for h in [5, 12, 22] { #expect(!e.isLateNight(hour: h), "\(h)") }
}

@Test func lateNightCueComesOncePerNightEvenAcrossMidnight() {
    var e = ContextEngine()
    #expect(e.tick(now: at(22, minute: 59), idleSeconds: 0, calendar: gmt).isEmpty)
    #expect(e.tick(now: at(23, minute: 5), idleSeconds: 0, calendar: gmt) == [.lateNight])
    #expect(e.tick(now: at(23, minute: 6), idleSeconds: 0, calendar: gmt).isEmpty)
    _ = e.tick(now: at(23, minute: 30), idleSeconds: 600, calendar: gmt)            // a rest, so no break cue muddies this test
    #expect(e.tick(now: at(1, day: 1), idleSeconds: 0, calendar: gmt).isEmpty)       // same night, after midnight
    _ = e.tick(now: at(20, day: 1), idleSeconds: 600, calendar: gmt)
    #expect(e.tick(now: at(23, minute: 30, day: 1), idleSeconds: 0, calendar: gmt) == [.lateNight])   // next night
}

@Test func noLateNightCueWhileTheUserIsAway() {
    var e = ContextEngine()
    #expect(e.tick(now: at(2), idleSeconds: 3600, calendar: gmt).isEmpty)
    #expect(e.tick(now: at(2, minute: 1), idleSeconds: 5, calendar: gmt) == [.welcomeBack, .lateNight])   // back, and it's late
}

@Test func welcomeBackOnlyAfterALongAbsence() {
    var e = ContextEngine()
    #expect(e.tick(now: at(10), idleSeconds: 10 * 60, calendar: gmt).isEmpty)        // a short pause
    #expect(e.tick(now: at(10, minute: 5), idleSeconds: 2, calendar: gmt).isEmpty)
    #expect(e.tick(now: at(11), idleSeconds: 45 * 60, calendar: gmt).isEmpty)        // gone for 45 min
    #expect(e.tick(now: at(11, minute: 1), idleSeconds: 3, calendar: gmt) == [.welcomeBack])
    #expect(e.tick(now: at(11, minute: 2), idleSeconds: 3, calendar: gmt).isEmpty)   // not again
}

@Test func takeABreakAfterLongUninterruptedUse() {
    var e = ContextEngine()
    var cues: [(Int, [ContextCue])] = []
    var now = at(9)
    for minute in 0...200 {
        now = at(9).addingTimeInterval(Double(minute) * 60)
        let c = e.tick(now: now, idleSeconds: 5, calendar: gmt)
        if !c.isEmpty { cues.append((minute, c)) }
    }
    #expect(cues.map(\.0) == [90, 180])
    #expect(cues.allSatisfy { $0.1 == [.takeBreak] })
}

@Test func aRealRestRestartsTheBreakClock() {
    var e = ContextEngine()
    _ = e.tick(now: at(9), idleSeconds: 0, calendar: gmt)
    _ = e.tick(now: at(10, minute: 20), idleSeconds: 0, calendar: gmt)             // 80 min in, no cue yet
    _ = e.tick(now: at(10, minute: 30), idleSeconds: 6 * 60, calendar: gmt)        // 6-minute rest
    #expect(e.tick(now: at(11, minute: 40), idleSeconds: 0, calendar: gmt).isEmpty)     // only 70 min since returning
}

@Test func sleepyPetDozesMoreAndWalksLess() {
    var normal = BehaviorFSM(rng: FixedRandom(value: 0.4))     // 0.4 → walk when awake
    normal.tick(dt: 3.1)
    #expect(normal.pose == .walk)

    var sleepy = BehaviorFSM(rng: FixedRandom(value: 0.4))     // 0.4 → sleep when sleepy
    sleepy.sleepy = true
    sleepy.tick(dt: 3.1)
    #expect(sleepy.pose == .sleep)
}
