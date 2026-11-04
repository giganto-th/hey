import Testing
import Foundation
@testable import HeyDomain

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }

private func sample(_ t: Double, keys: UInt32 = 0, idle: Double = 0, battery: Int? = 80, ac: Bool = true,
                    thermal: ThermalLevel = .nominal, locked: Bool = false) -> ActivitySample {
    ActivitySample(time: at(t), keyCount: keys, idleSeconds: idle, batteryPercent: battery, onAC: ac, thermal: thermal, screenLocked: locked)
}

/// Feed one sample per second, `perSecond` keys each, for `seconds` seconds starting at `from`.
private func type(_ r: inout ActivityReactor, from: Int, seconds: Int, perSecond: UInt32, startKeys: UInt32 = 0) -> [Reaction] {
    var out: [Reaction] = []
    for i in 0...seconds { out += r.update(sample(Double(from + i), keys: startKeys + UInt32(i) * perSecond)) }
    return out
}

// MARK: typing

@Test func slowAndFastTypingAreTold() {
    var r = ActivityReactor()
    _ = r.update(sample(0, keys: 0))
    _ = r.update(sample(1, keys: 2))
    #expect(r.ambient == .typingSlow)
    _ = r.update(sample(2, keys: 12))
    #expect(r.ambient == .typingFast && r.keyRate == 10)
}

@Test func typingMoodLingersBrieflyThenEnds() {
    var r = ActivityReactor()
    _ = r.update(sample(0, keys: 0))
    _ = r.update(sample(1, keys: 5))
    #expect(r.ambient != .none)
    _ = r.update(sample(2, keys: 5))
    _ = r.update(sample(3, keys: 5))                 // 2 s after the last key: still counts
    #expect(r.ambient == .typingFast || r.ambient == .typingSlow)
    _ = r.update(sample(5, keys: 5))                 // 4 s: over
    #expect(r.ambient == .none)
}

@Test func keyCounterWrappingAroundDoesNotLookLikeAFlood() {
    var r = ActivityReactor()
    _ = r.update(sample(0, keys: UInt32.max - 2))
    _ = r.update(sample(1, keys: 3))                 // wrapped: 6 presses
    #expect(r.keyRate == 6)
}

@Test func aCounterResetIsIgnored() {
    var r = ActivityReactor()
    _ = r.update(sample(0, keys: 5_000_000))
    _ = r.update(sample(1, keys: 10))                // went "backwards" = huge wrapped delta
    #expect(r.keyRate == 0 && r.ambient == .none)
}

@Test func sustainedFastTypingEarnsOneCompliment() {
    var r = ActivityReactor()
    let cues = type(&r, from: 0, seconds: 40, perSecond: 6)
    #expect(cues.filter { $0 == .fastTypist }.count == 1)
    let later = type(&r, from: 41, seconds: 20, perSecond: 6, startKeys: 6 * 41)
    #expect(!later.contains(.fastTypist))            // cooldown
}

@Test func shortBurstsDoNotCountAsFastTypist() {
    var r = ActivityReactor()
    let cues = type(&r, from: 0, seconds: 6, perSecond: 7)
    #expect(!cues.contains(.fastTypist))
}

@Test func typingMoodCanBeSwitchedOff() {
    var r = ActivityReactor()
    var s = ReactionSettings(); s.typing = false
    _ = r.update(sample(0, keys: 0), settings: s)
    _ = r.update(sample(1, keys: 9), settings: s)
    #expect(r.ambient == .none)
}

// MARK: battery

@Test func lowBatteryWarnsOnceThenCriticalOnce() {
    var r = ActivityReactor()
    var all: [Reaction] = []
    for (i, pct) in [30, 22, 20, 19, 18, 12, 10, 9, 8].enumerated() {
        all += r.update(sample(Double(i), battery: pct, ac: false))
    }
    #expect(all == [.lowBattery(percent: 20), .criticalBattery(percent: 10)])
    #expect(r.ambient == .criticalBattery)
}

@Test func lowBatteryMoodNeedsBeingOnBattery() {
    var r = ActivityReactor()
    _ = r.update(sample(0, battery: 15, ac: true))
    #expect(r.ambient == .none)
    _ = r.update(sample(1, battery: 15, ac: false))
    #expect(r.ambient == .lowBattery)
}

@Test func pluggingInAnnouncesAndRearmsWarnings() {
    var r = ActivityReactor()
    _ = r.update(sample(0, battery: 18, ac: false))
    #expect(r.update(sample(1, battery: 18, ac: true)) == [.pluggedIn])
    // a new discharge cycle: say it was unplugged, and warn about the low level again
    #expect(r.update(sample(2, battery: 19, ac: false)) == [.unplugged(percent: 19), .lowBattery(percent: 19)])
    #expect(r.update(sample(3, battery: 18, ac: false)).isEmpty)                              // but only once
}

@Test func fullyChargedIsAnnouncedOncePerPlugIn() {
    var r = ActivityReactor()
    _ = r.update(sample(0, battery: 98, ac: true))
    #expect(r.update(sample(1, battery: 100, ac: true)) == [.fullyCharged])
    #expect(r.update(sample(2, battery: 100, ac: true)).isEmpty)
}

@Test func alreadyFullAtLaunchStaysQuiet() {
    var r = ActivityReactor()
    _ = r.update(sample(0, battery: 100, ac: true))
    #expect(r.update(sample(1, battery: 100, ac: true)).isEmpty)
}

@Test func batteryHoveringAroundTheLimitDoesNotNagAgain() {
    var r = ActivityReactor()
    var warnings = 0
    for (i, pct) in [21, 20, 21, 20, 21, 20, 21, 20].enumerated() {
        warnings += r.update(sample(Double(i), battery: pct, ac: false)).filter {
            if case .lowBattery = $0 { true } else { false } }.count
    }
    #expect(warnings == 1)
}

@Test func noBatteryMeansNoBatteryReactions() {
    var r = ActivityReactor()
    #expect(r.update(sample(0, battery: nil, ac: true)).isEmpty)
    #expect(r.update(sample(1, battery: nil, ac: false)).isEmpty)
}

@Test func batteryReactionsCanBeSwitchedOff() {
    var r = ActivityReactor()
    var s = ReactionSettings(); s.battery = false
    _ = r.update(sample(0, battery: 50, ac: false), settings: s)
    #expect(r.update(sample(1, battery: 5, ac: false), settings: s).isEmpty && r.ambient == .none)
}

// MARK: heat, dozing, lock

@Test func overheatingSpeaksOncePerWhile() {
    var r = ActivityReactor()
    #expect(r.update(sample(0, thermal: .serious)) == [.overheating])
    #expect(r.ambient == .hot)
    #expect(r.update(sample(30, thermal: .serious)).isEmpty)
    #expect(r.update(sample(700, thermal: .serious)) == [.overheating])
}

@Test func dozeOffAfterIdleAndWakeUpWhenBack() {
    var r = ActivityReactor()
    #expect(r.update(sample(0, idle: 100)).isEmpty)
    #expect(r.update(sample(80, idle: 180)) == [.dozeOff])
    #expect(r.ambient == .dozing)
    #expect(r.update(sample(90, idle: 190)).isEmpty)
    #expect(r.update(sample(100, idle: 2)) == [.wakeUp])
    #expect(r.ambient == .none)
}

@Test func lockedScreenIsQuiet() {
    var r = ActivityReactor()
    _ = r.update(sample(0, keys: 0))
    #expect(r.update(sample(1, keys: 50, battery: 5, ac: false, locked: true)).isEmpty)
    #expect(r.ambient == .none)
}

@Test func everythingOffMeansSilence() {
    var r = ActivityReactor()
    var s = ReactionSettings(); s.enabled = false
    #expect(r.update(sample(0, battery: 3, ac: false, thermal: .critical), settings: s).isEmpty)
    #expect(r.ambient == .none)
}

@Test func worriedAndTypingPetsStayPutOthersMayWander() {
    #expect(AmbientMotion.typingFast.keepsPetStill && AmbientMotion.criticalBattery.keepsPetStill && AmbientMotion.dozing.keepsPetStill)
    #expect(!AmbientMotion.none.keepsPetStill && !AmbientMotion.lowBattery.keepsPetStill && !AmbientMotion.hot.keepsPetStill)
}

// MARK: gaze, fsm, settings

@Test func petLooksAtNearbyPointerOnly() {
    #expect(Gaze.facingRight(pointerX: 500, petCenterX: 300, pointerDistance: 200) == true)
    #expect(Gaze.facingRight(pointerX: 100, petCenterX: 300, pointerDistance: 200) == false)
    #expect(Gaze.facingRight(pointerX: 500, petCenterX: 300, pointerDistance: 900) == nil)     // too far
    #expect(Gaze.facingRight(pointerX: 310, petCenterX: 300, pointerDistance: 20) == nil)      // right on top of it
}

@Test func petOnlyTurnsToLookWhileStandingStill() {
    var fsm = BehaviorFSM(rng: FixedRandom(value: 0.1))
    fsm.face(right: false)
    #expect(!fsm.facingRight)
    fsm.tick(dt: 3.1)                                 // starts walking
    #expect(fsm.pose == .walk)
    let facing = fsm.facingRight
    fsm.face(right: !facing)
    #expect(fsm.facingRight == facing)
}

@Test func wakeEndsSleepOnly() {
    var fsm = BehaviorFSM(rng: FixedRandom(value: 0.9))
    fsm.send(.tired)
    #expect(fsm.pose == .sleep)
    fsm.send(.wake)
    #expect(fsm.pose == .idle)
    fsm.send(.clicked)                                 // happy: waking must not cut that short
    fsm.send(.wake)
    #expect(fsm.pose == .happy)
}

@Test func reactionSettingsDefaultOnAndSurviveOldSaves() throws {
    var pet = PetState(); pet.stage = .hatchling
    var g = Game(save: SaveData(pet: pet))
    g.setReactions { $0.typing = false }
    let data = try g.save.encoded()
    #expect(try SaveData.decode(data).reactions.typing == false)
    let old = try JSONDecoder().decode(ReactionSettings.self, from: Data(#"{"enabled":false}"#.utf8))
    #expect(!old.enabled && old.typing && old.battery && old.curious && old.appStreaks)
}
