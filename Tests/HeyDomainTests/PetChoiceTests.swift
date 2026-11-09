import Testing
import Foundation
@testable import HeyDomain

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@Suite("PetChoice")
struct PetChoiceTests {
    @Test func namesAreCleaned() {
        #expect(PetName.clean("  Pip  ") == "Pip")
        #expect(PetName.clean("Hei   Hei") == "Hei Hei")
        #expect(PetName.clean("") == nil)
        #expect(PetName.clean("   \n\t ") == nil)
        #expect(PetName.clean("a\u{0007}b") == "ab")
        #expect(PetName.clean("\u{200B}") == nil)
        #expect(PetName.clean(String(repeating: "x", count: 50))?.count == PetName.maxLength)
        #expect(PetName.clean("ต๊อกน้อย") == "ต๊อกน้อย")
    }

    @Test func aFreshGameCanChooseOnceAndThenItIsLocked() {
        var game = Game(save: SaveData(pet: PetState(now: t0)))
        #expect(!game.speciesLocked)
        let chosen = game.chooseEgg(species: "shishi", name: " Mimi ")
        #expect(chosen)
        #expect(game.species == "shishi")
        #expect(game.pet.state.name == "Mimi")
        #expect(game.speciesLocked)
        let again = game.chooseEgg(species: "fluff", name: "Other")
        #expect(!again)
        #expect(game.species == "shishi" && game.pet.state.name == "Mimi")
    }

    @Test func aBlankNameFallsBackToTheKindsOwn() {
        var game = Game(save: SaveData(pet: PetState(now: t0)))
        _ = game.chooseEgg(species: "fluff", name: "   ")
        #expect(game.pet.state.name == "Shams")
    }

    @Test func anUnknownKindIsRefused() {
        var game = Game(save: SaveData(pet: PetState(now: t0)))
        let chosen = game.chooseEgg(species: "dragon", name: "X")
        #expect(!chosen)
        #expect(!game.speciesLocked)
    }

    @Test func theKindCannotBeSwitchedOnceLocked() {
        var game = Game(save: SaveData(pet: PetState(now: t0)))
        let before = game.setSpecies("shishi")          // still allowed on a fresh game
        #expect(before && game.species == "shishi")
        _ = game.chooseEgg(species: "shishi", name: nil)
        let after = game.setSpecies("heihei")
        #expect(!after)
        #expect(game.species == "shishi")
    }

    @Test func anOldSaveCountsAsChosen() throws {
        let save = SaveData(pet: PetState(now: t0))
        let data = try save.encoded()
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "speciesLocked")
        let loaded = try SaveData.decode(try JSONSerialization.data(withJSONObject: json))
        #expect(loaded.speciesLocked)
        var game = Game(save: loaded)
        let switched = game.setSpecies("fluff")
        #expect(!switched)
    }

    @Test func renamingKeepsTheKindAndIgnoresJunk() {
        var game = Game(save: SaveData(pet: PetState(now: t0)))
        _ = game.chooseEgg(species: "heihei", name: nil)
        let changed = game.renamePet("  Popo ")
        let junk = game.renamePet("   ")
        let same = game.renamePet("Popo")
        #expect(changed && game.pet.state.name == "Popo")
        #expect(!junk && !same)
        #expect(game.species == "heihei")
    }

    private func grown() -> Game {
        var s = PetState(now: t0); s.stage = .teen; s.name = "Pip"; s.xp = 400
        var save = SaveData(pet: s); save.species = "heihei"; save.speciesLocked = true; save.coins = 99
        return Game(save: save)
    }

    @Test func releasingALivingPetStartsAnEggOfTheChosenKind() {
        var game = grown()
        let released = game.releasePet(at: t0.addingTimeInterval(100), species: "shishi", name: "Neko")
        #expect(released)
        #expect(game.pet.state.stage == .egg && game.species == "shishi" && game.pet.state.name == "Neko")
        #expect(game.speciesLocked)
        #expect(game.coins == 99)
        #expect(game.memorials.count == 1)
        #expect(game.memorials[0].name == "Pip" && game.memorials[0].wasReleased && game.memorials[0].cause == nil)
    }

    @Test func releasingAnEggLeavesNoMemorial() {
        var game = Game(save: SaveData(pet: PetState(now: t0)))
        _ = game.chooseEgg(species: "heihei", name: nil)
        let released = game.releasePet(at: t0, species: "fluff", name: nil)
        #expect(released)
        #expect(game.memorials.isEmpty)
        #expect(game.species == "fluff")
    }

    @Test func aDeadPetCannotBeReleasedOnlyReplaced() {
        var s = PetState(now: t0); s.stage = .child; s.diedAt = t0; s.deathCause = .hunger
        var save = SaveData(pet: s); save.speciesLocked = true
        var game = Game(save: save)
        let released = game.releasePet(at: t0)
        #expect(!released)
        let replaced = game.hatchNewEgg(at: t0, species: "shishi", name: "Kiki")
        #expect(replaced)
        #expect(game.pet.state.name == "Kiki" && game.species == "shishi")
        #expect(game.memorials.count == 1 && !game.memorials[0].wasReleased)
    }

    @Test func theKindStaysLockedAfterANewEgg() {
        var game = grown()
        _ = game.releasePet(at: t0, species: "fluff", name: nil)
        let switched = game.setSpecies("heihei")
        #expect(!switched)
        #expect(game.species == "fluff")
    }

    @Test func aReleasedMemorialSurvivesASave() throws {
        var game = grown()
        _ = game.releasePet(at: t0, species: nil, name: nil)
        let back = try SaveData.decode(try game.save.encoded())
        #expect(back.memorials.first?.wasReleased == true)
        #expect(back.speciesLocked)
    }
}
