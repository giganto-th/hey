import AppKit
import Observation
import HeyDomain

/// Notices YouTube videos the user is looking at and offers to add them to the playlist.
///
/// Two sources, both optional and both privacy-conscious:
/// - the clipboard: only the text of a freshly copied YouTube link is looked at, and anything a password
///   manager marks as private is skipped;
/// - the front browser tab: only while a known browser is the front app, and only a watch-page URL is used.
@MainActor
@Observable
final class MusicDetector {
    struct Suggestion: Equatable {
        let videoID: String
        var title: String
        var source: Source
        enum Source: String {
            case clipboard, browser, nowPlaying
            /// Where the link came from, in words.
            var label: String {
                switch self {
                case .clipboard: tr("คัดลอกลิงก์")
                case .browser: tr("แท็บที่เปิดอยู่")
                case .nowPlaying: tr("กำลังเล่นอยู่")
                }
            }
        }
        var url: String { YouTubeLink.watchURL(videoID).absoluteString }
    }

    private(set) var suggestion: Suggestion?
    private(set) var browserNote: String?
    /// The song macOS says is playing (from any app), while the experimental Now Playing option is on.
    private(set) var systemSong: NowPlayingInfo?
    /// The YouTube video behind `systemSong`, when a matching browser tab was found (so it can be imported with one click).
    private(set) var systemVideoID: String?
    @ObservationIgnored var onSystemSongChange: (() -> Void)?
    @ObservationIgnored private var suppressed: (title: String, until: Date)?
    @ObservationIgnored private var systemInfo: NowPlayingInfo?
    @ObservationIgnored private var systemLastPlaying: Date?

    @ObservationIgnored var onSuggest: ((Suggestion) -> Void)?
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored var isActive: () -> Bool = { true }
    @ObservationIgnored private let model: GameModel
    @ObservationIgnored private let player: MusicPlayer
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var pasteboardCount = NSPasteboard.general.changeCount
    @ObservationIgnored private var dismissed = Set<String>()
    @ObservationIgnored private var tick = 0
    @ObservationIgnored private var expiry: DispatchWorkItem?
    @ObservationIgnored private var lastNowPlayingTitle: String?
    @ObservationIgnored private var nowPlayingBusy = false
    @ObservationIgnored private let log = ProcessInfo.processInfo.environment["HEY_DEV_LOG_MUSIC"] != nil

    init(model: GameModel, player: MusicPlayer) {
        self.model = model
        self.player = player
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        t.tolerance = 1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: answering the offer

    func accept(play: Bool) {
        guard let s = suggestion else { return }
        if let error = player.addToCurrent(s.url, play: play) { player.onMessage?(error, "exclamationmark.triangle.fill") }
        clear(dismiss: false)
    }

    func dismiss() {
        if let id = suggestion?.videoID { dismissed.insert(id) }
        clear(dismiss: true)
    }

    private func clear(dismiss: Bool) {
        expiry?.cancel()
        suggestion = nil
        onChange?()
    }

    // MARK: polling

    private func poll() {
        guard isActive() else { return }
        let settings = model.game.music
        tick += 1
        if settings.detectClipboard { checkClipboard() }
        if settings.detectBrowser, tick % 3 == 0 { checkBrowser() }
        if settings.detectNowPlaying, tick % 2 == 0 { checkNowPlaying() } else if !settings.detectNowPlaying { clearSystemSong() }
    }

    private func checkClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != pasteboardCount else { return }
        pasteboardCount = pb.changeCount
        // Password managers mark what they copy; never even read those.
        if YouTubeDetection.isPrivateClipboard(types: (pb.types ?? []).map(\.rawValue)) { return }
        guard let text = pb.string(forType: .string), text.count <= 300,
              let id = YouTubeLink.videoID(from: text) else { return }
        offer(videoID: id, title: nil, source: .clipboard)
    }

    private func checkBrowser() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundle = app.bundleIdentifier, let name = YouTubeDetection.browsers[bundle] else { return }
        switch Self.frontTab(of: name) {
        case .tab(let url, let title):
            browserNote = nil
            guard let id = YouTubeLink.videoID(from: url) else { return }
            offer(videoID: id, title: YouTubeLink.cleanTabTitle(title), source: .browser)
        case .denied:
            if browserNote == nil {
                browserNote = tr("ยังไม่ได้อนุญาตให้ Hey! ควบคุม {0} — เปิดใน การตั้งค่าระบบ › ความเป็นส่วนตัว › ระบบอัตโนมัติ", name)
                player.onMessage?(tr("ต้องอนุญาตการเข้าถึง {0}", name), "exclamationmark.triangle.fill")
                onChange?()
            }
        case .none:
            break
        }
    }

    /// What macOS says is playing, matched to the browser tab that shows it (the system gives a title, not a link).
    private func checkNowPlaying() {
        guard !nowPlayingBusy else { return }
        nowPlayingBusy = true
        Task {
            defer { nowPlayingBusy = false }
            let info = await NowPlayingReader.read()
            if log { print("[detect] now playing:", info.map { "\($0.title) (rate \($0.rate))" } ?? "nothing readable") }
            publishSystemSong(info)
            guard let info, info.isPlaying else { return }
            guard info.title != lastNowPlayingTitle else { return }       // already looked at this one
            lastNowPlayingTitle = info.title
            systemVideoID = nil
            switch BrowserTabs.all() {
            case .denied(let browser):
                if browserNote == nil {
                    browserNote = tr("ยังไม่ได้อนุญาตให้ Hey! ควบคุม {0} — เปิดใน การตั้งค่าระบบ › ความเป็นส่วนตัว › ระบบอัตโนมัติ", browser)
                    onChange?()
                }
            case .tabs(let tabs):
                guard let id = NowPlayingMatcher.youtubeID(for: info, tabs: tabs) else {
                    if log { print("[detect] now playing \"\(info.title)\": no matching YouTube tab") }
                    return
                }
                systemVideoID = id
                onSystemSongChange?()
                offer(videoID: id, title: info.title, source: .nowPlaying)
            }
        }
    }

    /// Keeps `systemSong` current for the menu bar and tells it when it changes.
    private func publishSystemSong(_ info: NowPlayingInfo?) {
        let now = Date()
        systemInfo = info
        if info?.isPlaying == true { systemLastPlaying = now }
        var shown = NowPlayingDisplay.shouldShow(info, lastPlayingAt: systemLastPlaying, now: now) ? info : nil
        // "Stop" was pressed: keep the song off the bar until it is really silent, and until a different song starts.
        if let hidden = suppressed, let current = shown {
            if current.title != hidden.title || (current.isPlaying && now > hidden.until) { suppressed = nil }
            else { shown = nil }
        }
        if shown == nil, info?.title != lastNowPlayingTitle { systemVideoID = nil }
        guard shown != systemSong else { return }
        systemSong = shown
        onSystemSongChange?()
    }

    /// Stops what another app is playing (a browser tab, for instance) and takes it off the menu bar.
    /// The pause is a media-key press, the same as the keyboard's play/pause key.
    func stopSystemSong() {
        guard let song = systemSong else { return }
        if song.isPlaying { MediaKey.playPause() }
        suppressed = (song.title, Date().addingTimeInterval(6))
        systemSong = nil
        onSystemSongChange?()
    }

    /// Plays or pauses what another app is playing.
    func toggleSystemSong() { MediaKey.playPause() }

    /// Adds the song the system is playing to the current playlist, when its YouTube link is known.
    func importSystemSong() {
        guard let id = systemVideoID else { return }
        if let error = player.addToCurrent(YouTubeLink.watchURL(id).absoluteString, play: false) {
            player.onMessage?(error, "exclamationmark.triangle.fill")
        } else {
            player.onMessage?(tr("เพิ่มเข้าเพลย์ลิสต์แล้ว"), "music.note.list")
            systemVideoID = nil
            onSystemSongChange?()
        }
    }

    /// True when the playing system song has a known video that is not in a playlist yet.
    var canImportSystemSong: Bool {
        guard let id = systemVideoID else { return false }
        return YouTubeDetection.shouldSuggest(videoID: id, playlists: model.game.playlists, dismissed: [], current: nil)
    }

    /// Called when the option is switched off so a stale song doesn't stay on the bar.
    func clearSystemSong() {
        guard systemSong != nil else { return }
        systemSong = nil; systemInfo = nil
        onSystemSongChange?()
    }

    private func offer(videoID: String, title: String?, source: Suggestion.Source) {
        guard YouTubeDetection.shouldSuggest(videoID: videoID, playlists: model.game.playlists,
                                             dismissed: dismissed, current: suggestion?.videoID) else { return }
        if log { print("[detect] \(source.rawValue): \(videoID)") }
        let known = title.flatMap { $0.isEmpty ? nil : $0 }
        // A copied link has no title yet; fetch it so the offer can say what the song is.
        Task {
            let resolved: String
            if let known { resolved = known }
            else { resolved = await MusicPlayer.oEmbed(videoID: videoID)?.title ?? "YouTube \(videoID)" }
            show(Suggestion(videoID: videoID, title: resolved, source: source))
        }
    }

    private func show(_ s: Suggestion) {
        guard YouTubeDetection.shouldSuggest(videoID: s.videoID, playlists: model.game.playlists,
                                             dismissed: dismissed, current: suggestion?.videoID) else { return }
        suggestion = s
        expiry?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.dismiss() } }   // ignored = turned down
        expiry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: work)
        if log { print("[detect] offering: \(s.title)") }
        onSuggest?(s)
        onChange?()
    }

    // MARK: asking the browser

    private enum TabResult { case tab(url: String, title: String), denied, none }

    /// URL and title of the front window's active tab. Needs the user's Automation permission, which macOS asks for once.
    private static func frontTab(of browser: String) -> TabResult {
        let script: String
        if browser == "Safari" {
            script = "with timeout of 1 second\ntell application \"Safari\" to return {URL of current tab of front window, name of current tab of front window}\nend timeout"
        } else {
            script = "with timeout of 1 second\ntell application \"\(browser)\" to return {URL of active tab of front window, title of active tab of front window}\nend timeout"
        }
        var error: NSDictionary?
        guard let result = NSAppleScript(source: script)?.executeAndReturnError(&error) else {
            if (error?[NSAppleScript.errorNumber] as? Int) == -1743 { return .denied }
            return .none                                  // no window open, or the script failed: nothing to offer
        }
        guard result.numberOfItems >= 2,
              let url = result.atIndex(1)?.stringValue, let title = result.atIndex(2)?.stringValue else { return .none }
        return .tab(url: url, title: title)
    }
}

/// The keyboard's play/pause key, sent to whatever app currently owns media playback.
enum MediaKey {
    static func playPause() {
        let keyPlay = 16           // NX_KEYTYPE_PLAY
        func post(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = (keyPlay << 16) | ((down ? 0xa : 0xb) << 8)
            NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                               context: nil, subtype: 8, data1: data1, data2: -1)?.cgEvent?.post(tap: .cghidEventTap)
        }
        post(down: true)
        post(down: false)
    }
}
