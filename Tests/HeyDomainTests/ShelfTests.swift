import Testing
import Foundation
@testable import HeyDomain

private let gmt: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "GMT")!
    return c
}()
private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func newGame() -> Game {
    var pet = PetState(now: t0, calendar: gmt)
    pet.stage = .hatchling
    return Game(save: SaveData(pet: pet), calendar: gmt, rng: FixedRandom(value: 0))
}

private func file(_ path: String, at: Date = t0) -> ShelfItem {
    ShelfItem(kind: .file, name: (path as NSString).lastPathComponent, path: path, addedAt: at)
}

@Test func theShelfHoldsNewestFirst() {
    var g = newGame()
    _ = g.addToShelf(file("/a.pdf"))
    _ = g.addToShelf(ShelfItem(kind: .text, name: "note", text: "hello", addedAt: t0.addingTimeInterval(1)))
    #expect(g.shelf.map(\.name) == ["note", "a.pdf"])
}

@Test func theSameFileOnlyMovesToTheFront() {
    var g = newGame()
    _ = g.addToShelf(file("/a.pdf"))
    _ = g.addToShelf(file("/b.pdf"))
    let firstID = g.shelf[1].id
    let events = g.addToShelf(file("/a.pdf", at: t0.addingTimeInterval(60)))
    #expect(g.shelf.map(\.name) == ["a.pdf", "b.pdf"])
    #expect(g.shelf[0].id == firstID && g.shelf[0].addedAt == t0.addingTimeInterval(60))
    #expect(events.count == 1)
}

@Test func theShelfKeepsOnlyTheNewestThirty() {
    var g = newGame()
    for i in 0..<45 { _ = g.addToShelf(file("/f\(i).txt", at: t0.addingTimeInterval(Double(i)))) }
    #expect(g.shelf.count == Game.shelfLimit)
    #expect(g.shelf.first?.name == "f44.txt" && g.shelf.last?.name == "f15.txt")
}

@Test func itemsCanBeRemovedOrCleared() {
    var g = newGame()
    _ = g.addToShelf(file("/a")); _ = g.addToShelf(file("/b"))
    g.removeFromShelf(id: g.shelf[0].id)
    #expect(g.shelf.map(\.name) == ["a"])
    g.removeFromShelf(id: UUID())                       // unknown id: nothing happens
    g.clearShelf()
    #expect(g.shelf.isEmpty)
}

@Test func oldItemsFallOffTheShelfAsTimePasses() {
    var g = newGame()
    _ = g.addToShelf(file("/old", at: t0))
    _ = g.addToShelf(file("/fresh", at: t0.addingTimeInterval(20 * 3600)))
    _ = g.advance(to: t0.addingTimeInterval(25 * 3600), sleeping: false)       // default: 24 h
    #expect(g.shelf.map(\.name) == ["fresh"])
}

@Test func expiryCanBeTurnedOffOrClamped() {
    var g = newGame()
    g.setFiles { $0.shelfExpireHours = 0 }
    _ = g.addToShelf(file("/old", at: t0))
    _ = g.advance(to: t0.addingTimeInterval(1000 * 3600), sleeping: false)
    #expect(g.shelf.count == 1)
    g.setFiles { $0.shelfExpireHours = 9999 }
    #expect(g.files.shelfExpireHours == 168)
}

@Test func theDefaultDropGoesToTheVaultAndOldSettingsLoad() throws {
    #expect(FileSettings().dropDefault == .vault && FileSettings().removeAfterDragOut)
    let old = try JSONDecoder().decode(FileSettings.self, from: Data(#"{"shelfExpireHours":6}"#.utf8))
    #expect(old.dropDefault == .vault && old.shelfExpireHours == 6)
    #expect(Set(DropDestination.allCases.map(\.label)).count == 2)
}

@Test func shelfAndSettingsSurviveSavingAndOldSavesStartEmpty() throws {
    var g = newGame()
    g.setFiles { $0.dropDefault = .shelf; $0.removeAfterDragOut = false }
    _ = g.addToShelf(file("/a.pdf"))
    _ = g.addToShelf(ShelfItem(kind: .link, name: "site", text: "https://example.com", addedAt: t0))
    let data = try g.save.encoded()
    #expect(try SaveData.decode(data) == g.save)

    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let pet = try String(decoding: enc.encode(g.save.pet), as: UTF8.self)
    let old = try SaveData.decode(Data(#"{"pet":\#(pet)}"#.utf8))
    #expect(old.shelf.isEmpty && old.files == FileSettings())
}
