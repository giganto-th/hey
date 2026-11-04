import Testing
import Foundation
@testable import HeyDomain

@Suite struct PetActionsTests {
    @Test func doubleClickMakesAGrownBirdFlapButOthersJustCheer() {
        var adult = BehaviorFSM(); adult.canFly = true
        adult.send(.doubleClicked)
        #expect(adult.pose == .flap)
        var chick = BehaviorFSM()
        chick.send(.doubleClicked)
        #expect(chick.pose == .happy)
    }

    @Test func pokingASleeperStartlesIt() {
        var fsm = BehaviorFSM()
        fsm.send(.tired)
        fsm.send(.clicked)
        #expect(fsm.pose == .startled)
    }

    @Test func shakenThenDroppedEndsDizzy() {
        var fsm = BehaviorFSM()
        fsm.send(.grabbed); fsm.send(.shaken); fsm.send(.released); fsm.send(.landed)
        #expect(fsm.pose == .dizzy)
        var calm = BehaviorFSM()
        calm.send(.grabbed); calm.send(.released); calm.send(.landed)
        #expect(calm.pose == .idle)
    }

    @Test func dizzyBirdIgnoresPetting() {
        var fsm = BehaviorFSM()
        fsm.send(.grabbed); fsm.send(.shaken); fsm.send(.released); fsm.send(.landed)
        fsm.send(.clicked)
        #expect(fsm.pose == .dizzy)
    }

    @Test func onlyGrownBirdsPracticeFlight() {
        var young = BehaviorFSM(rng: FixedRandom(value: 0.05))
        young.tick(dt: 10)
        #expect(young.pose != .flap)
        var adult = BehaviorFSM(rng: FixedRandom(value: 0.05)); adult.canFly = true
        adult.tick(dt: 10)
        #expect(adult.pose == .flap)
    }

    @Test func flapSometimesBecomesAShortFlight() {
        var adult = BehaviorFSM(rng: FixedRandom(value: 0.2)); adult.canFly = true
        adult.send(.doubleClicked)
        adult.tick(dt: 10)
        #expect(adult.pose == .fly)
        adult.tick(dt: 10)
        #expect(adult.pose == .idle)
    }

    @Test func newActionsReachThePresentation() {
        func activity(_ pose: PetPose) -> CompanionActivity {
            var s = CompanionSignals(); s.pose = pose
            return CompanionMotion.resolve(s, settings: MotionSettings(), now: 0).activity
        }
        #expect(activity(.startled) == .startled)
        #expect(activity(.dizzy) == .dizzy)
        #expect(activity(.flap) == .flapping)
        #expect(activity(.fly) == .flying)
        var s = CompanionSignals(); s.pose = .fly
        #expect(!CompanionMotion.resolve(s, settings: MotionSettings(), now: 0).holdsPosition)
    }
}

@Suite struct CheerAndGreetingTests {
    @Test func cheerMakesAGrownBirdFlapAndOthersHop() {
        var adult = BehaviorFSM(); adult.canFly = true
        adult.send(.cheered)
        #expect(adult.pose == .flap)
        var chick = BehaviorFSM()
        chick.send(.cheered)
        #expect(chick.pose == .happy)
    }

    @Test func cheerDoesNotWakeASleeperOrInterruptDizziness() {
        var sleeper = BehaviorFSM()
        sleeper.send(.tired)
        sleeper.send(.cheered)
        #expect(sleeper.pose == .sleep)
    }

    @Test func greetingFollowsTheHour() {
        #expect(Greeting.line(hour: 8).symbol == "sunrise.fill")
        #expect(Greeting.line(hour: 12).symbol == "sun.max.fill")
        #expect(Greeting.line(hour: 15).symbol == "cloud.sun.fill")
        #expect(Greeting.line(hour: 19).symbol == "sunset.fill")
        #expect(Greeting.line(hour: 2).symbol == "moon.stars.fill")
        #expect(Greeting.line(hour: 23) == Greeting.line(hour: 0))
        #expect(Set((0..<24).map { Greeting.line(hour: $0).text }).count == 5)
    }
}

@Suite struct PetSpeciesTests {
    @Test func switchingSpeciesRenamesOnlyADefaultName() {
        var game = Game(save: SaveData(pet: PetState(now: Date(timeIntervalSince1970: 0), calendar: Calendar(identifier: .gregorian))), calendar: Calendar(identifier: .gregorian), rng: FixedRandom(value: 0.5))
        #expect(game.species == "heihei")
        game.setSpecies("fluff")
        #expect(game.species == "fluff")
        #expect(game.pet.state.name == "Shams")
        game.renamePet("Mochi")
        game.setSpecies("heihei")
        #expect(game.pet.state.name == "Mochi")
    }

    @Test func unknownSpeciesIsIgnored() {
        var game = Game(save: SaveData(pet: PetState(now: Date(timeIntervalSince1970: 0), calendar: Calendar(identifier: .gregorian))), calendar: Calendar(identifier: .gregorian), rng: FixedRandom(value: 0.5))
        game.setSpecies("dragon")
        #expect(game.species == "heihei")
    }
}

@Test func anOldFooSaveIsRenamedShams() throws {
    var save = SaveData(pet: PetState(now: Date(timeIntervalSince1970: 0), calendar: Calendar(identifier: .gregorian)))
    save.species = "fluff"
    save.pet.name = "Foo"
    #expect(try SaveData.decode(save.encoded()).pet.name == "Shams")
}
