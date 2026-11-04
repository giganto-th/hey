import Testing
import Foundation
@testable import HeyDomain

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private let gmt: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "GMT")!
    return c
}()

private func newGame(_ rng: any RandomSource = FixedRandom(value: 0)) -> Game {
    var pet = PetState(now: t0, calendar: gmt)
    pet.stage = .hatchling
    return Game(save: SaveData(pet: pet), calendar: gmt, rng: rng)
}

private func yt(_ id: String, _ title: String = "t") -> Track {
    Track(source: .youtube(id: id), title: title, addedAt: t0)
}

// MARK: links

@Test func parsesYouTubeLinks() {
    let id = "dQw4w9WgXcQ"
    let inputs = [
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://youtube.com/watch?v=dQw4w9WgXcQ&t=42s&list=PL123",
        "https://m.youtube.com/watch?feature=share&v=dQw4w9WgXcQ",
        "https://music.youtube.com/watch?v=dQw4w9WgXcQ&si=abc",
        "https://youtu.be/dQw4w9WgXcQ?si=xyz",
        "https://www.youtube.com/shorts/dQw4w9WgXcQ",
        "https://www.youtube.com/embed/dQw4w9WgXcQ",
        "  dQw4w9WgXcQ  ",
    ]
    for input in inputs { #expect(YouTubeLink.videoID(from: input) == id, "\(input)") }
}

@Test func rejectsNonYouTubeInput() {
    #expect(YouTubeLink.videoID(from: "https://example.com/watch?v=dQw4w9WgXcQ") == nil)
    #expect(YouTubeLink.videoID(from: "https://notyoutube.com/watch?v=dQw4w9WgXcQ") == nil)
    #expect(YouTubeLink.videoID(from: "https://www.youtube.com/playlist?list=PL123") == nil)
    #expect(YouTubeLink.videoID(from: "https://www.youtube.com/watch?v=short") == nil)
    #expect(YouTubeLink.videoID(from: "hello world") == nil)
    #expect(YouTubeLink.videoID(from: "") == nil)
}

// MARK: queue

private func ids(_ n: Int) -> [UUID] { (0..<n).map { _ in UUID() } }

@Test func queuePlaysInOrderThenStops() {
    let t = ids(3)
    var q = PlayQueue(trackIDs: t)
    q.start(at: t[0])
    #expect(q.current == t[0])
    #expect(q.next(auto: true) == t[1])
    #expect(q.next(auto: true) == t[2])
    #expect(q.next(auto: true) == nil)
    #expect(q.current == nil)
}

@Test func repeatAllWrapsAndRepeatOneOnlyOnAutoAdvance() {
    let t = ids(2)
    var q = PlayQueue(trackIDs: t, repeatMode: .all)
    q.start(at: t[1])
    #expect(q.next(auto: true) == t[0])
    q.repeatMode = .one
    #expect(q.next(auto: true) == t[0])              // song ended: play it again
    #expect(q.next(auto: false) == t[1])             // user pressed next: really go on
}

@Test func previousStopsAtTheStartUnlessRepeatingAll() {
    let t = ids(3)
    var q = PlayQueue(trackIDs: t)
    q.start(at: t[1])
    #expect(q.previous() == t[0])
    #expect(q.previous() == t[0])
    q.repeatMode = .all
    #expect(q.previous() == t[2])
}

@Test func shuffleStartsOnChosenTrackAndVisitsEachOnce() {
    let t = ids(6)
    var q = PlayQueue(trackIDs: t, shuffle: true, rng: SequenceRandom([0.9, 0.1, 0.5, 0.3, 0.7]))
    q.start(at: t[3])
    var seen = [q.current!]
    while let n = q.next(auto: true) { seen.append(n) }
    #expect(seen.first == t[3])
    #expect(Set(seen) == Set(t) && seen.count == 6)
}

@Test func editingThePlaylistKeepsTheCurrentTrack() {
    let t = ids(4)
    var q = PlayQueue(trackIDs: t)
    q.start(at: t[2])
    q.update(trackIDs: [t[0], t[2], t[3]])           // t[1] removed
    #expect(q.current == t[2])
    #expect(q.next(auto: true) == t[3])
    q.update(trackIDs: [t[0]])                        // playing track removed
    #expect(q.current == nil)
}

// MARK: playlists

@Test func createRenameDeletePlaylists() {
    var g = newGame()
    let a = g.createPlaylist("  ทำงาน ")
    let b = g.createPlaylist("")
    #expect(g.playlists.map(\.name) == ["ทำงาน", "เพลย์ลิสต์ใหม่"])
    #expect(g.music.playlistID == b)
    g.renamePlaylist(id: a, to: "  ")                 // blank rename ignored
    g.renamePlaylist(id: a, to: "โฟกัส")
    #expect(g.playlist(id: a)?.name == "โฟกัส")
    g.deletePlaylist(id: b)
    #expect(g.music.playlistID == a && g.currentPlaylist?.id == a)
}

@Test func duplicatesAreRejectedPerPlaylist() {
    var g = newGame()
    let a = g.createPlaylist("A"), b = g.createPlaylist("B")
    #expect(g.addTrack(yt("aaaaaaaaaaa"), to: a).first.map { if case .trackAdded = $0 { true } else { false } } == true)
    #expect(g.addTrack(yt("aaaaaaaaaaa"), to: a).first.map { if case .trackDuplicate = $0 { true } else { false } } == true)
    #expect(g.addTrack(yt("aaaaaaaaaaa"), to: b).count == 1)          // another playlist is fine
    let f1 = Track(source: .file(path: "/m/x.mp3", bookmark: nil), title: "x", addedAt: t0)
    var f2 = f1; f2.id = UUID(); f2.source = .file(path: "/m/x.mp3", bookmark: Data([1]))
    _ = g.addTrack(f1, to: a)
    #expect(g.addTrack(f2, to: a).first.map { if case .trackDuplicate = $0 { true } else { false } } == true)
    #expect(g.playlist(id: a)?.tracks.count == 2)
}

@Test func moveRemoveAndUpdateTracks() {
    var g = newGame()
    let a = g.createPlaylist("A")
    let tracks = (0..<3).map { yt("id\($0)xxxxxxxx", "t\($0)") }
    for t in tracks { _ = g.addTrack(t, to: a) }
    g.moveTrack(in: a, from: 0, to: 2)
    #expect(g.playlist(id: a)!.tracks.map(\.title) == ["t1", "t2", "t0"])
    g.moveTrack(in: a, from: 9, to: 0)                // out of range: ignored
    g.updateTrack(id: tracks[1].id, title: "Real title", artist: "Channel", thumbnailURL: "u", duration: 215)
    #expect(g.playlist(id: a)!.tracks[0].title == "Real title" && g.playlist(id: a)!.tracks[0].duration == 215)
    g.updateTrack(id: tracks[1].id, title: "", artist: nil, thumbnailURL: nil, duration: 0)   // blanks don't erase
    #expect(g.playlist(id: a)!.tracks[0].title == "Real title" && g.playlist(id: a)!.tracks[0].duration == 215)
    g.removeTrack(id: tracks[1].id, from: a)
    #expect(g.playlist(id: a)!.tracks.count == 2)
}

@Test func volumeIsClamped() {
    var g = newGame()
    g.setMusic { $0.volume = 4 }
    #expect(g.music.volume == 1)
    g.setMusic { $0.volume = -1 }
    #expect(g.music.volume == 0)
}

@Test func listeningMinutesFinishTheMusicQuest() {
    var g = newGame(questRNG([.checkIn, .online, .music]))
    _ = g.startSession(at: t0)
    #expect(g.quests.map(\.kind) == [.checkIn, .online, .music])
    var events: [GameEvent] = []
    for _ in 0..<10 { events += g.recordListening(minutes: 1) }
    #expect(events.contains { if case .questCompleted(let q) = $0 { q.kind == .music } else { false } })
}

@Test func playlistsSurviveRoundTripAndOldSavesLoad() throws {
    var g = newGame()
    let a = g.createPlaylist("A")
    _ = g.addTrack(Track(source: .file(path: "/m/x.mp3", bookmark: Data([9])), title: "x", duration: 61, addedAt: t0), to: a)
    _ = g.addTrack(yt("dQw4w9WgXcQ"), to: a)
    g.setMusic { $0.shuffle = true; $0.repeatMode = .all }
    let data = try g.save.encoded()
    #expect(try SaveData.decode(data) == g.save)

    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let pet = try String(decoding: enc.encode(g.save.pet), as: UTF8.self)
    let old = try SaveData.decode(Data(#"{"coins":3,"pet":\#(pet)}"#.utf8))
    #expect(old.playlists.isEmpty && old.music == MusicSettings())
}

// MARK: detection

@Test func tabTitlesAreCleanedUp() {
    #expect(YouTubeLink.cleanTabTitle("Never Gonna Give You Up - YouTube") == "Never Gonna Give You Up")
    #expect(YouTubeLink.cleanTabTitle("(3) Lofi beats - YouTube") == "Lofi beats")
    #expect(YouTubeLink.cleanTabTitle("(12) Song - YouTube Music") == "Song")
    #expect(YouTubeLink.cleanTabTitle("(Live) Song - YouTube") == "(Live) Song")          // not a count
    #expect(YouTubeLink.cleanTabTitle("  plain title ") == "plain title")
}

@Test func suggestionsSkipKnownDismissedAndCurrent() {
    var g = newGame()
    let a = g.createPlaylist("A")
    _ = g.addTrack(yt("aaaaaaaaaaa"), to: a)
    let lists = g.playlists
    #expect(YouTubeDetection.shouldSuggest(videoID: "bbbbbbbbbbb", playlists: lists, dismissed: [], current: nil))
    #expect(!YouTubeDetection.shouldSuggest(videoID: "aaaaaaaaaaa", playlists: lists, dismissed: [], current: nil))   // already saved
    #expect(!YouTubeDetection.shouldSuggest(videoID: "bbbbbbbbbbb", playlists: lists, dismissed: ["bbbbbbbbbbb"], current: nil))
    #expect(!YouTubeDetection.shouldSuggest(videoID: "bbbbbbbbbbb", playlists: lists, dismissed: [], current: "bbbbbbbbbbb"))
    #expect(YouTubeDetection.shouldSuggest(videoID: "bbbbbbbbbbb", playlists: [], dismissed: [], current: nil))      // no playlists yet
}

@Test func onlyKnownBrowsersAndPrivateClipboardsAreRecognised() {
    #expect(YouTubeDetection.browsers["com.apple.Safari"] == "Safari")
    #expect(YouTubeDetection.browsers["com.example.Notes"] == nil)
    #expect(YouTubeDetection.isPrivateClipboard(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]))
    #expect(!YouTubeDetection.isPrivateClipboard(types: ["public.utf8-plain-text"]))
}

@Test func detectionDefaultsAndOldMusicSettingsStillLoad() throws {
    #expect(MusicSettings().detectClipboard && !MusicSettings().detectBrowser)
    let old = try JSONDecoder().decode(MusicSettings.self, from: Data(#"{"volume":0.3,"shuffle":true,"repeatMode":"all"}"#.utf8))
    #expect(old.volume == 0.3 && old.shuffle && old.repeatMode == .all && old.detectClipboard && !old.detectBrowser)
    var g = newGame()
    g.setMusic { $0.detectBrowser = true; $0.detectClipboard = false }
    let data = try g.save.encoded()
    let back = try SaveData.decode(data)
    #expect(back.music.detectBrowser && !back.music.detectClipboard)
}

// MARK: menu-bar marquee text

@Test func marqueeLineJoinsTitleAndArtistOnce() {
    #expect(MarqueeText.display(title: "瞬き", artist: "back number") == "瞬き — back number")
    #expect(MarqueeText.display(title: "back number - 瞬き", artist: "back number") == "back number - 瞬き")   // artist already in the title
    #expect(MarqueeText.display(title: "Song", artist: nil) == "Song")
    #expect(MarqueeText.display(title: "Song", artist: "  ") == "Song")
}

@Test func marqueeLineIsOneLineAndNotTooLong() {
    #expect(MarqueeText.display(title: "Line one\n  line   two\t!", artist: nil) == "Line one line two !")
    let long = MarqueeText.display(title: String(repeating: "ก", count: 400), artist: nil)
    #expect(long.count == MarqueeText.maxLength && long.hasSuffix("…"))
    #expect(MarqueeText.display(title: "  ", artist: nil) == "…")
}

@Test func menuBarSettingDefaultsOnAndOldSettingsLoad() throws {
    #expect(MusicSettings().showInMenuBar)
    let old = try JSONDecoder().decode(MusicSettings.self, from: Data(#"{"volume":0.5}"#.utf8))
    #expect(old.showInMenuBar)
    let off = try JSONDecoder().decode(MusicSettings.self, from: Data(#"{"showInMenuBar":false}"#.utf8))
    #expect(!off.showInMenuBar)
}
