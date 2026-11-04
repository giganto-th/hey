import Foundation
import Testing
@testable import HeyDomain

@Test func musicTypingAndFocusResumeFromCurrentSignals() {
    var s = CompanionSignals()
    let settings = MotionSettings()
    s.musicPlaying = true
    #expect(CompanionMotion.resolve(s, settings: settings, now: 10).activity == .dancing)
    s.lastKeyAt = 10
    #expect(CompanionMotion.resolve(s, settings: settings, now: 11).showsKeyboard)
    s.focusing = true
    #expect(CompanionMotion.resolve(s, settings: settings, now: 12).activity == .quietTyping)
    #expect(CompanionMotion.resolve(s, settings: settings, now: 13).activity == .focusing)
    s.focusing = false
    #expect(CompanionMotion.resolve(s, settings: settings, now: 14).activity == .dancing)
    s.musicPlaying = false
    #expect(CompanionMotion.resolve(s, settings: settings, now: 15).activity == .idle)
}

@Test func interruptingTypingNeverLeavesAKeyboardOnCarriedOrFallingPet() {
    var s = CompanionSignals()
    s.musicPlaying = true; s.lastKeyAt = 10
    for pose in [PetPose.carried, .falling] {
        s.pose = pose
        let decision = CompanionMotion.resolve(s, settings: MotionSettings(), now: 11)
        #expect(!decision.showsKeyboard)
        #expect(decision.activity == (pose == .carried ? .carried : .falling))
    }
    s.pose = .idle
    #expect(CompanionMotion.resolve(s, settings: MotionSettings(), now: 14).activity == .dancing)
}

@Test func menuAndDropOverrideTypingButCannotInterruptPhysics() {
    var s = CompanionSignals(); s.lastKeyAt = 1; s.musicPlaying = true
    s.menuOpen = true
    #expect(CompanionMotion.resolve(s, settings: MotionSettings(), now: 2).activity == .attentive)
    s.menuOpen = false; s.dropActive = true
    #expect(CompanionMotion.resolve(s, settings: MotionSettings(), now: 2).activity == .attentive)
    s.pose = .carried
    #expect(CompanionMotion.resolve(s, settings: MotionSettings(), now: 2).activity == .carried)
}

@Test func reducedMotionKeepsActivityMeaningWithoutLooping() {
    var s = CompanionSignals(); s.musicPlaying = true; s.lastKeyAt = 1
    var settings = MotionSettings()
    s.systemReduceMotion = true
    let reduced = CompanionMotion.resolve(s, settings: settings, now: 2)
    #expect(reduced.activity == .typing && !reduced.animates && reduced.showsKeyboard)
    settings.level = .full
    #expect(CompanionMotion.resolve(s, settings: settings, now: 2).animates)
    settings.level = .reduced; s.systemReduceMotion = false
    #expect(!CompanionMotion.resolve(s, settings: settings, now: 2).animates)
}

@Test func turningOffTypingImmediatelyReturnsToMusic() {
    var s = CompanionSignals(); s.lastKeyAt = 10; s.musicPlaying = true
    s.typingEnabled = false
    #expect(CompanionMotion.resolve(s, settings: MotionSettings(), now: 10.1).activity == .dancing)
    var settings = MotionSettings(); settings.dance = false
    #expect(CompanionMotion.resolve(s, settings: settings, now: 10.1).activity == .idle)
}

@Test func thermalCeilingAndDormancyOverrideActivities() {
    var s = CompanionSignals(); s.lastKeyAt = 10; s.musicPlaying = true
    s.ambient = .hot
    #expect(CompanionMotion.resolve(s, settings: MotionSettings(), now: 11).activity == .worried)
    s.tier = .dormant
    let d = CompanionMotion.resolve(s, settings: MotionSettings(), now: 11)
    #expect(d.activity == .dormant && !d.animates && !d.showsKeyboard)
}

@Test func eggsNeverAcquireKeyboardOrDanceAndFutureKeyTimesAreIgnored() {
    var s = CompanionSignals(); s.isEgg = true; s.musicPlaying = true; s.lastKeyAt = 10
    let egg = CompanionMotion.resolve(s, settings: MotionSettings(), now: 10)
    #expect(egg.activity == .egg && !egg.showsKeyboard)
    s.isEgg = false; s.musicPlaying = false
    #expect(CompanionMotion.resolve(s, settings: MotionSettings(), now: 9).activity == .idle)
}

@Test func sustainedTypingSpeedsUpWithoutExceedingAnimationCeiling() {
    var s = CompanionSignals(); s.lastKeyAt = 10; s.fastTyping = true
    let fast = CompanionMotion.resolve(s, settings: MotionSettings(), now: 11)
    s.fastTyping = false
    let slow = CompanionMotion.resolve(s, settings: MotionSettings(), now: 11)
    #expect(fast.cyclesPerSecond > slow.cyclesPerSecond && fast.cyclesPerSecond <= 3)
    s.tier = .saver
    #expect(CompanionMotion.resolve(s, settings: MotionSettings(), now: 11).amplitude <= 0.3)
}

@Test func explicitActionsFinishBeforeReturningToAmbientActivity() {
    var s = CompanionSignals(); s.lastKeyAt = 10; s.musicPlaying = true
    s.pose = .eat
    #expect(CompanionMotion.resolve(s, settings: MotionSettings(), now: 11).activity == .eating)
    s.pose = .happy
    #expect(CompanionMotion.resolve(s, settings: MotionSettings(), now: 11).activity == .pleased)
}

@Test func settlingStopsWalkingWithoutBreakingCarriedOrEatingStates() {
    var fsm = BehaviorFSM(rng: FixedRandom(value: 0.1))
    fsm.tick(dt: 4); #expect(fsm.pose == .walk)
    fsm.settle(); #expect(fsm.pose == .idle)
    fsm.send(.grabbed); fsm.settle(); #expect(fsm.pose == .carried)
    fsm.send(.released); fsm.settle(); #expect(fsm.pose == .falling)
    fsm.send(.landed); fsm.send(.fed); fsm.settle(); #expect(fsm.pose == .eat)
}

@Test func motionSettingsRoundTripAndMissingKeysDefault() throws {
    var g = Game(save: SaveData(pet: PetState()))
    g.setMotion { $0.level = .gentle; $0.dance = false; $0.roam = false }
    let save = try SaveData.decode(g.save.encoded())
    #expect(save.motion.level == .gentle && !save.motion.dance && !save.motion.roam)
    let partial = try JSONDecoder().decode(MotionSettings.self, from: Data(#"{"dance":false}"#.utf8))
    #expect(partial.level == .system && !partial.dance && partial.roam)
}

@Test func tokMigrationPreservesProgressAndCustomNamesAndIsIdempotent() throws {
    var data = SaveData(pet: PetState()); data.version = 1; data.species = "tok"
    data.pet.name = "ต๊อก"; data.coins = 342; data.pet.xp = 75
    let migrated = try SaveData.decode(data.encoded())
    #expect(migrated.species == "heihei" && migrated.pet.name == "Hei Hei")
    #expect(migrated.coins == 342 && migrated.pet.xp == 75 && migrated.version == 2)
    #expect(try SaveData.decode(migrated.encoded()) == migrated)
    data.pet.name = "กุ๊กไก่"
    #expect(try SaveData.decode(data.encoded()).pet.name == "กุ๊กไก่")
}
