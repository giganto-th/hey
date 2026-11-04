import Testing
import Foundation
@testable import HeyDomain

private let gmt: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "GMT")!
    return c
}()
private let t0 = Date(timeIntervalSince1970: 1_800_000_000)   // 2027-01-15 08:00:00 GMT

private func newGame(_ rng: any RandomSource = FixedRandom(value: 0)) -> Game {
    var pet = PetState(now: t0, calendar: gmt)
    pet.stage = .hatchling
    return Game(save: SaveData(pet: pet), calendar: gmt, rng: rng)
}

@Test func fileNamesAreReadableAndTyped() {
    #expect(CaptureNaming.fileName(for: .screenshot, at: t0, calendar: gmt) == "Screenshot 2027-01-15 08.00.00.png")
    #expect(CaptureNaming.fileName(for: .screenRecording, at: t0, calendar: gmt) == "Screen Recording 2027-01-15 08.00.00.mp4")
    #expect(CaptureNaming.fileName(for: .photo, at: t0, calendar: gmt).hasSuffix(".jpg"))
    #expect(CaptureNaming.fileName(for: .video, at: t0, calendar: gmt).hasSuffix(".mov"))
    #expect(!CaptureNaming.fileName(for: .video, at: t0, calendar: gmt).contains(":"))
}

@Test func mediaIsKeptNewestFirstAndCanBeRemoved() {
    var g = newGame()
    _ = g.addMedia(MediaItem(kind: .screenshot, path: "/a.png", createdAt: t0))
    _ = g.addMedia(MediaItem(kind: .video, path: "/b.mov", createdAt: t0.addingTimeInterval(60), duration: 5))
    _ = g.addMedia(MediaItem(kind: .photo, path: "/c.jpg", createdAt: t0.addingTimeInterval(-60)))
    #expect(g.media.map(\.path) == ["/b.mov", "/a.png", "/c.jpg"])
    let b = g.media[0]
    #expect(g.removeMedia(id: b.id) == [.mediaRemoved(b)])
    #expect(g.removeMedia(id: b.id).isEmpty)
    #expect(g.media.count == 2)
}

@Test func capturingCountsForItsQuest() {
    var g = newGame(questRNG([.checkIn, .online, .capture]))
    _ = g.startSession(at: t0)
    #expect(g.quests.map(\.kind) == [.checkIn, .online, .capture])
    let events = g.addMedia(MediaItem(kind: .screenshot, path: "/a.png", createdAt: t0))
    #expect(events.contains { if case .questCompleted(let q) = $0 { q.kind == .capture } else { false } })
}

@Test func countdownIsClamped() {
    var g = newGame()
    g.setCapture { $0.countdown = 99 }
    #expect(g.capture.countdown == 10)
    g.setCapture { $0.countdown = -4 }
    #expect(g.capture.countdown == 0)
}

@Test func mediaAndSettingsSurviveRoundTripAndOldSavesLoad() throws {
    var g = newGame()
    g.setCapture { $0.recordMicrophone = true; $0.countdown = 5 }
    _ = g.addMedia(MediaItem(kind: .screenRecording, path: "/r.mp4", createdAt: t0, duration: 12.5))
    let data = try g.save.encoded()
    #expect(try SaveData.decode(data) == g.save)

    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let pet = try String(decoding: enc.encode(g.save.pet), as: UTF8.self)
    let old = try SaveData.decode(Data(#"{"coins":4,"pet":\#(pet)}"#.utf8))
    #expect(old.media.isEmpty && old.capture == CaptureSettings())
}
