import Testing
import Foundation
@testable import HeyDomain

private let gmt: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "GMT")!
    return c
}()
private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private let day: TimeInterval = 86_400

private func newGame(_ rng: any RandomSource = FixedRandom(value: 0)) -> Game {
    var pet = PetState(now: t0, calendar: gmt)
    pet.stage = .hatchling
    return Game(save: SaveData(pet: pet), calendar: gmt, rng: rng)
}

private func file(_ name: String, mode: VaultMode = .copy, path: String? = nil, at: Date = t0) -> VaultItem {
    VaultItem(kind: .file, mode: mode, name: name, sourcePath: path, size: 10, addedAt: at)
}

@Test func policyChoosesModeBySizeAndKind() {
    let mb: Int64 = 1024 * 1024
    #expect(VaultPolicy.auto.mode(isFolder: false, size: 5 * mb) == .copy)
    #expect(VaultPolicy.auto.mode(isFolder: false, size: 500 * mb) == .reference)
    #expect(VaultPolicy.auto.mode(isFolder: true, size: 1) == .reference)
    #expect(VaultPolicy.alwaysCopy.mode(isFolder: true, size: 500 * mb) == .copy)
    #expect(VaultPolicy.alwaysReference.mode(isFolder: false, size: 1) == .reference)
}

@Test func addingTwiceReferencesOnlyOnceButCopiesRepeat() {
    var g = newGame()
    let ref = file("a.pdf", mode: .reference, path: "/tmp/a.pdf")
    #expect(g.addVaultItem(ref).contains { if case .vaultAdded = $0 { true } else { false } })
    var again = ref; again.id = UUID()
    #expect(g.addVaultItem(again).first.map { if case .vaultDuplicate = $0 { true } else { false } } == true)
    #expect(g.vault.count == 1)

    _ = g.addVaultItem(file("b.png", path: "/tmp/b.png"))
    _ = g.addVaultItem(file("b.png", path: "/tmp/b.png"))
    #expect(g.vault.count == 3)
}

@Test func searchMatchesNameTextTagsAndPathAllWords() {
    var g = newGame()
    _ = g.addVaultItem(file("Report-Q3.pdf", path: "/Users/me/Work/report.pdf"))
    var note = VaultItem(kind: .text, mode: .copy, name: "wifi", text: "รหัสไวไฟบ้าน 12345", addedAt: t0)
    note.id = UUID()
    _ = g.addVaultItem(note)
    let link = VaultItem(kind: .link, mode: .copy, name: "docs", text: "https://example.com/swift", addedAt: t0)
    _ = g.addVaultItem(link)
    g.setVaultTags(id: g.vault.first { $0.name == "docs" }!.id, ["Swift", "อ่านทีหลัง"])

    #expect(g.searchVault("report").count == 1)
    #expect(g.searchVault("REPORT q3").count == 1)
    #expect(g.searchVault("ไวไฟ 12345").count == 1)
    #expect(g.searchVault("swift").count == 1)               // matches tag and url
    #expect(g.searchVault("report swift").isEmpty)           // every word must match
    #expect(g.searchVault("", tag: "swift").count == 1)      // tag filter ignores case
    #expect(g.searchVault("").count == 3)
}

@Test func pinnedFirstThenNewest() {
    var g = newGame()
    _ = g.addVaultItem(file("old", at: t0))
    _ = g.addVaultItem(file("new", at: t0.addingTimeInterval(100)))
    _ = g.addVaultItem(file("pinned-old", at: t0.addingTimeInterval(-100)))
    g.setVaultPinned(id: g.vault.first { $0.name == "pinned-old" }!.id, true)
    #expect(g.searchVault().map(\.name) == ["pinned-old", "new", "old"])
}

@Test func tagsAreTrimmedAndDeduplicated() {
    var g = newGame()
    _ = g.addVaultItem(file("a"))
    let id = g.vault[0].id
    g.setVaultTags(id: id, ["  work ", "Work", "", "ด่วน", "work"])
    #expect(g.vault[0].tags == ["work", "ด่วน"])
    #expect(g.vaultTags == ["work", "ด่วน"])
}

@Test func defaultExpiryAppliesToNewItemsAndPinnedNeverExpire() {
    var g = newGame()
    g.setVaultDefaultExpiry(days: 7)
    _ = g.addVaultItem(file("temp"))
    _ = g.addVaultItem(file("keep"))
    g.setVaultPinned(id: g.vault.first { $0.name == "keep" }!.id, true)
    #expect(g.vault.first { $0.name == "temp" }!.expiresAt == t0.addingTimeInterval(7 * day))

    #expect(g.expireVault(at: t0.addingTimeInterval(6 * day)).isEmpty)
    let events = g.expireVault(at: t0.addingTimeInterval(8 * day))
    #expect(g.vault.map(\.name) == ["keep"])
    if case .vaultRemoved(let gone)? = events.first { #expect(gone.map(\.name) == ["temp"]) } else { Issue.record("no removal event") }
}

@Test func expiryRunsAsPartOfAdvance() {
    var g = newGame()
    g.setVaultDefaultExpiry(days: 1)
    _ = g.addVaultItem(file("x"))
    let events = g.advance(to: t0.addingTimeInterval(2 * day), sleeping: false)
    #expect(g.vault.isEmpty)
    #expect(events.contains { if case .vaultRemoved = $0 { true } else { false } })
}

@Test func expiryCanBeSetPerItemAndCleared() {
    var g = newGame()
    _ = g.addVaultItem(file("x"))
    let id = g.vault[0].id
    g.setVaultExpiry(id: id, days: 30, now: t0)
    #expect(g.vault[0].expiresAt == t0.addingTimeInterval(30 * day))
    g.setVaultExpiry(id: id, days: nil, now: t0)
    #expect(g.vault[0].expiresAt == nil)
}

@Test func removeReturnsItemSoItsCopyCanBeDeleted() {
    var g = newGame()
    _ = g.addVaultItem(file("x"))
    let item = g.vault[0]
    #expect(g.removeVaultItem(id: item.id) == [.vaultRemoved([item])])
    #expect(g.removeVaultItem(id: item.id).isEmpty)
}

@Test func savingToVaultCountsForItsQuest() {
    var g = newGame(questRNG([.checkIn, .online, .vault]))
    _ = g.startSession(at: t0)
    #expect(g.quests.map(\.kind) == [.checkIn, .online, .vault])
    let events = g.addVaultItem(file("a"))
    #expect(events.contains { if case .questCompleted(let q) = $0 { q.kind == .vault } else { false } })
}

@Test func vaultAndSettingsSurviveRoundTripAndOldSavesLoad() throws {
    var g = newGame()
    g.setVaultPolicy(.alwaysCopy)
    g.setVaultDefaultExpiry(days: 30)
    var item = file("a", mode: .reference, path: "/tmp/a")
    item.bookmark = Data([1, 2, 3])
    _ = g.addVaultItem(item)
    let data = try g.save.encoded()
    #expect(try SaveData.decode(data) == g.save)

    // a save written before the vault existed
    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let pet = try String(decoding: enc.encode(g.save.pet), as: UTF8.self)
    let old = try SaveData.decode(Data(#"{"coins":9,"pet":\#(pet)}"#.utf8))
    #expect(old.vault.isEmpty && old.vaultSettings == VaultSettings() && old.coins == 9)
}
