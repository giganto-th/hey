import Testing
import Foundation
@testable import HeyDomain

private func json(_ s: String) -> Data { Data(s.utf8) }

@Test func parsesTheHelperOutput() {
    let line = #"{"title":"back number - 瞬き (full)","artist":"BackNumberVEVO","album":"","rate":1.000,"duration":251.5,"elapsed":12.25}"#
    let info = NowPlayingInfo.parse(json(line + "\n"))
    #expect(info == NowPlayingInfo(title: "back number - 瞬き (full)", artist: "BackNumberVEVO", rate: 1, duration: 251.5, elapsed: 12.25))
    #expect(info?.isPlaying == true)
}

@Test func pausedIsNotPlaying() {
    #expect(NowPlayingInfo.parse(json(#"{"title":"x","artist":null,"album":null,"rate":0.000,"duration":null,"elapsed":null}"#))?.isPlaying == false)
}

@Test func errorsAndEmptyTitlesGiveNothing() {
    for bad in [#"{"error":"empty"}"#, #"{"error":"unavailable"}"#, #"{"title":null,"rate":1}"#, #"{"title":"   ","rate":1}"#, "not json", ""] {
        #expect(NowPlayingInfo.parse(json(bad)) == nil, "\(bad)")
    }
}

@Test func onlyTheLastLineCountsAndEscapesSurvive() {
    let out = "noise from perl\n" + #"{"title":"say \"hi\"\nthere","rate":1}"# + "\n"
    #expect(NowPlayingInfo.parse(json(out))?.title == "say \"hi\"\nthere")
}

private let tabs = [
    BrowserTab(url: "https://mail.example.com/inbox", title: "Inbox"),
    BrowserTab(url: "https://www.youtube.com/watch?v=aaaaaaaaaaa", title: "(2) back number - 瞬き (full) - YouTube"),
    BrowserTab(url: "https://www.youtube.com/watch?v=bbbbbbbbbbb", title: "Lofi beats to study to - YouTube"),
]

@Test func findsTheTabCarryingTheSong() {
    let np = NowPlayingInfo(title: "back number - 瞬き (full)", rate: 1)
    #expect(NowPlayingMatcher.youtubeID(for: np, tabs: tabs) == "aaaaaaaaaaa")
    #expect(NowPlayingMatcher.youtubeID(for: NowPlayingInfo(title: "LOFI  beats to study to", rate: 1), tabs: tabs) == "bbbbbbbbbbb")   // case + spacing
}

@Test func adsAndUnknownTitlesMatchNothing() {
    #expect(NowPlayingMatcher.youtubeID(for: NowPlayingInfo(title: "ข้อเสนอ Black Friday | Hostinger", rate: 1), tabs: tabs) == nil)
    #expect(NowPlayingMatcher.youtubeID(for: NowPlayingInfo(title: "Inbox", rate: 1), tabs: tabs) == nil)    // not a YouTube tab
    #expect(NowPlayingMatcher.youtubeID(for: NowPlayingInfo(title: "anything", rate: 1), tabs: []) == nil)
}

@Test func sameVideoInTwoTabsStillMatchesButDifferentVideosAreAmbiguous() {
    let dup = tabs + [BrowserTab(url: "https://youtu.be/aaaaaaaaaaa", title: "back number - 瞬き (full) - YouTube")]
    #expect(NowPlayingMatcher.youtubeID(for: NowPlayingInfo(title: "back number - 瞬き (full)", rate: 1), tabs: dup) == "aaaaaaaaaaa")
    let clash = tabs + [BrowserTab(url: "https://www.youtube.com/watch?v=ccccccccccc", title: "back number - 瞬き (full) - YouTube")]
    #expect(NowPlayingMatcher.youtubeID(for: NowPlayingInfo(title: "back number - 瞬き (full)", rate: 1), tabs: clash) == nil)
}

@Test func truncatedTitlesMatchOnlyWhenLongEnough() {
    let long = [BrowserTab(url: "https://www.youtube.com/watch?v=ddddddddddd", title: "A very long song title that goes on and on - YouTube")]
    #expect(NowPlayingMatcher.youtubeID(for: NowPlayingInfo(title: "A very long song title that goes on", rate: 1), tabs: long) == "ddddddddddd")
    let short = [BrowserTab(url: "https://www.youtube.com/watch?v=eeeeeeeeeee", title: "Song one - YouTube")]
    #expect(NowPlayingMatcher.youtubeID(for: NowPlayingInfo(title: "Song", rate: 1), tabs: short) == nil)
}

@Test func nowPlayingDetectionIsOffByDefaultAndOldSettingsLoad() throws {
    #expect(!MusicSettings().detectNowPlaying)
    let old = try JSONDecoder().decode(MusicSettings.self, from: Data(#"{"detectBrowser":true}"#.utf8))
    #expect(old.detectBrowser && !old.detectNowPlaying)
}

// MARK: showing the system's song on the bar

@Test func aPlayingSongIsShownAndAPausedOneLingersBriefly() {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    let playing = NowPlayingInfo(title: "x", rate: 1)
    let paused = NowPlayingInfo(title: "x", rate: 0)
    #expect(NowPlayingDisplay.shouldShow(playing, lastPlayingAt: nil, now: t0))
    #expect(NowPlayingDisplay.shouldShow(paused, lastPlayingAt: t0, now: t0.addingTimeInterval(20)))
    #expect(!NowPlayingDisplay.shouldShow(paused, lastPlayingAt: t0, now: t0.addingTimeInterval(31)))
}

@Test func nothingPlayingOrNeverPlayedShowsNothing() {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(!NowPlayingDisplay.shouldShow(nil, lastPlayingAt: t0, now: t0))
    #expect(!NowPlayingDisplay.shouldShow(NowPlayingInfo(title: "stale", rate: 0), lastPlayingAt: nil, now: t0))   // paused long before we started looking
}
