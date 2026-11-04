import Foundation
import Testing
@testable import HeyDomain

private func signals(_ f: (inout PowerSignals) -> Void = { _ in }) -> PowerSignals {
    var s = PowerSignals()
    f(&s)
    return s
}

@Test func pluggedInIsFullPower() {
    let d = PowerPolicy.decide(signals())
    #expect(d.tier == .full && !d.hidePet)
}

@Test func batteryIsBalancedThenSaverWhenLow() {
    #expect(PowerPolicy.decide(signals { $0.onAC = false; $0.batteryPercent = 80 }).tier == .balanced)
    #expect(PowerPolicy.decide(signals { $0.onAC = false; $0.batteryPercent = 30 }).tier == .saver)
    #expect(PowerPolicy.decide(signals { $0.onAC = false; $0.batteryPercent = 29 }).tier == .saver)
    // low battery while charging is fine
    #expect(PowerPolicy.decide(signals { $0.onAC = true; $0.batteryPercent = 5 }).tier == .full)
}

@Test func lowPowerModeAndHeatForceSaverEvenOnAC() {
    #expect(PowerPolicy.decide(signals { $0.lowPowerMode = true }).tier == .saver)
    #expect(PowerPolicy.decide(signals { $0.thermal = .fair }).tier == .saver)
    #expect(PowerPolicy.decide(signals { $0.thermal = .nominal }).tier == .full)
}

@Test func lockedOrSleepingScreenIsDormantButPetStaysPut() {
    for f in [{ (s: inout PowerSignals) in s.screenAsleep = true }, { (s: inout PowerSignals) in s.screenLocked = true }] {
        let d = PowerPolicy.decide(signals(f))
        #expect(d.tier == .dormant && !d.hidePet)
    }
}

@Test func fullscreenHidesThePetUnlessTurnedOff() {
    let s = signals { $0.fullscreenAppActive = true }
    let d = PowerPolicy.decide(s)
    #expect(d.tier == .dormant && d.hidePet)
    var off = PowerSettings(); off.hideDuringFullscreen = false
    #expect(PowerPolicy.decide(s, settings: off).tier == .full)
}

@Test func userHidingWinsOverEverything() {
    let d = PowerPolicy.decide(signals { $0.userHidPet = true; $0.fullscreenAppActive = false })
    #expect(d.tier == .dormant && d.hidePet)
}

@Test func idleLongEnoughRestsButZeroDisablesIt() {
    #expect(PowerPolicy.decide(signals { $0.userIdleSeconds = 599 }).tier == .full)
    #expect(PowerPolicy.decide(signals { $0.userIdleSeconds = 600 }).tier == .dormant)
    var never = PowerSettings(); never.dormantAfterIdleMinutes = 0
    #expect(PowerPolicy.decide(signals { $0.userIdleSeconds = 99_999 }, settings: never).tier == .full)
}

@Test func lowerTiersNeverUseMoreFrames() {
    let tiers: [PowerTier] = [.dormant, .saver, .balanced, .full]
    for (a, b) in zip(tiers, tiers.dropFirst()) {
        #expect(a.fps.active <= b.fps.active && a.fps.still <= b.fps.still)
    }
    #expect(PowerTier.dormant.fps.active == 0 && !PowerTier.dormant.rendersPet)
    #expect(PowerTier.full.fps.still < PowerTier.full.fps.active)
}

@Test func powerSettingsAreClampedAndSurviveOldSaves() throws {
    var pet = PetState(); pet.stage = .hatchling
    var g = Game(save: SaveData(pet: pet))
    g.setPower { $0.dormantAfterIdleMinutes = 9999; $0.saverBelowBatteryPercent = 1 }
    #expect(g.power.dormantAfterIdleMinutes == 120 && g.power.saverBelowBatteryPercent == 5)
    let data = try g.save.encoded()
    #expect(try SaveData.decode(data).power == g.power)

    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let petJSON = try String(decoding: enc.encode(g.save.pet), as: UTF8.self)
    #expect(try SaveData.decode(Data(#"{"pet":\#(petJSON)}"#.utf8)).power == PowerSettings())
}

// MARK: perches

private let window = Surface(id: 1, minX: 400, maxX: 1000, top: 500)
private let higher = Surface(id: 2, minX: 300, maxX: 900, top: 700)

@Test func droppingPetLandsOnTheHighestWindowItPassesThrough() {
    #expect(Perches.landing(fromY: 800, toY: 0, centerX: 600, surfaces: [window, higher])?.id == 2)
    #expect(Perches.landing(fromY: 650, toY: 0, centerX: 600, surfaces: [window, higher])?.id == 1)   // already below the higher one
}

@Test func petMissesWindowsItIsNotOverOrDoesNotReach() {
    #expect(Perches.landing(fromY: 800, toY: 0, centerX: 100, surfaces: [window]) == nil)             // beside it
    #expect(Perches.landing(fromY: 800, toY: 520, centerX: 600, surfaces: [window]) == nil)           // stops above it
    #expect(Perches.landing(fromY: 400, toY: 0, centerX: 600, surfaces: [window]) == nil)             // starts below it
    #expect(Perches.landing(fromY: 800, toY: 0, centerX: 405, surfaces: [window]) == nil)             // too close to the edge (margin)
}

@Test func risingIsNotLanding() {
    #expect(Perches.landing(fromY: 0, toY: 800, centerX: 600, surfaces: [window]) == nil)
}

@Test func climbTargetsMustBeAboveNearbyAndWideEnough() {
    var rng: any RandomSource = FixedRandom(value: 0)
    let tooHigh = Surface(id: 3, minX: 0, maxX: 800, top: 2000)
    let tooFar = Surface(id: 4, minX: 3000, maxX: 4000, top: 500)
    let narrow = Surface(id: 5, minX: 500, maxX: 600, top: 500)
    let below = Surface(id: 6, minX: 0, maxX: 800, top: 10)
    let ok = Perches.climbTarget(centerX: 600, bottomY: 0, surfaces: [tooHigh, tooFar, narrow, below, window], rng: &rng)
    #expect(ok?.id == 1)
    #expect(Perches.climbTarget(centerX: 600, bottomY: 0, surfaces: [tooHigh, tooFar, narrow, below], rng: &rng) == nil)
}

@Test func climbTargetIsChosenAmongTheOptions() {
    var low: any RandomSource = FixedRandom(value: 0)
    var high: any RandomSource = FixedRandom(value: 0.99)
    #expect(Perches.climbTarget(centerX: 600, bottomY: 250, surfaces: [window, higher], rng: &low)?.id == 1)
    #expect(Perches.climbTarget(centerX: 600, bottomY: 250, surfaces: [window, higher], rng: &high)?.id == 2)
}

@Test func clampKeepsThePetOnTheWindowTop() {
    #expect(Perches.clamp(centerX: 0, to: window) == 420)
    #expect(Perches.clamp(centerX: 5000, to: window) == 980)
    #expect(Perches.clamp(centerX: 700, to: window) == 700)
}

@Test func perchingFollowsTheTier() {
    #expect(PowerTier.full.allowsPerching && PowerTier.balanced.allowsPerching)
    #expect(!PowerTier.saver.allowsPerching && !PowerTier.dormant.allowsPerching)
}

@Test func oldPowerSettingsWithoutWalkOnWindowsStillLoad() throws {
    let s = try JSONDecoder().decode(PowerSettings.self, from: Data(#"{"hideDuringFullscreen":false,"dormantAfterIdleMinutes":5,"saverBelowBatteryPercent":40}"#.utf8))
    #expect(s.walkOnWindows && !s.hideDuringFullscreen && s.dormantAfterIdleMinutes == 5)
}
