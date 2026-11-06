import AppKit
import AVFoundation
import MediaPlayer
import Observation
import UniformTypeIdentifiers
import WebKit
import HeyDomain

// MARK: - backends

/// What the player needs from "something that can play a track".
@MainActor
private protocol Backend: AnyObject {
    var onPlaying: ((Bool) -> Void)? { get set }
    var onEnded: (() -> Void)? { get set }
    var onTime: ((Double, Double) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    func load(_ track: Track)
    func play()
    func pause()
    func stop()
    func seek(to seconds: Double)
    func setVolume(_ volume: Double)
}

/// Plays YouTube through the official IFrame Player API in a web view parked off-screen.
@MainActor
private final class YouTubeBackend: NSObject, Backend, WKScriptMessageHandler, WKNavigationDelegate {
    static let debug = ProcessInfo.processInfo.environment["HEY_DEV_LOG_MUSIC"] != nil
    var onPlaying: ((Bool) -> Void)?
    var onEnded: (() -> Void)?
    var onTime: ((Double, Double) -> Void)?
    var onError: ((String) -> Void)?
    /// The web content process died (memory pressure, a long sleep): the picture is blank until the page is loaded again.
    var onCrashed: (() -> Void)?

    private let webView: WKWebView
    private let window: NSWindow
    private var started = false
    private var pending: [String] = []     // JS waiting for the page to load
    private var ready = false
    private var volume = 70.0

    override init() {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 200, height: 200), configuration: config)
        // The player refuses to start in a view smaller than 200×200, so we give it that, off-screen.
        window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 200, height: 200),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = webView
        window.isReleasedWhenClosed = false
        super.init()
        config.userContentController.add(Weak(self), name: "hey")
        webView.navigationDelegate = self
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true
        // Fully off-screen windows count as hidden and WebKit freezes their page, so 1 pixel stays on-screen.
        let area = NSScreen.main?.frame ?? .zero
        window.setFrameOrigin(NSPoint(x: area.maxX - 1, y: area.minY - 199))
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.orderFrontRegardless()
        // YouTube rejects embeds that have no real http(s) origin, so the page pretends to be youtube.com.
        webView.loadHTMLString(Self.html, baseURL: URL(string: Self.origin))
    }

    /// Shows the video in `container` (the off-screen window gives it up) until `detachVideo()`.
    func attachVideo(to container: NSView) {
        if Self.debug { print("[video] attach", ObjectIdentifier(container)) }
        startIfNeeded()
        webView.removeFromSuperview()
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView, positioned: .below, relativeTo: nil)      // below any drag shield
    }

    /// Dev: what the web view shows right now, plus where the iframe sits.
    func devSnapshot(to path: String) {
        webView.evaluateJavaScript("var f=document.querySelector('iframe');JSON.stringify({f:f?f.getBoundingClientRect():null,w:innerWidth,h:innerHeight,state:window.player&&player.getPlayerState?player.getPlayerState():null,q:window.player&&player.getPlaybackQuality?player.getPlaybackQuality():null,levels:window.player&&player.getAvailableQualityLevels?player.getAvailableQualityLevels():null})") { [self] r, e in
            print("[video] js:", r ?? "nil", e.map { "\($0)" } ?? "", "super:", self.webView.superview.map { "\(type(of: $0))" } ?? "none", "window:", self.webView.window.map { "\(type(of: $0)) visible=\($0.isVisible)" } ?? "none")
        }
        webView.takeSnapshot(with: nil) { image, error in
            guard let image, let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                print("[video] snapshot failed:", error.map { "\($0)" } ?? "?"); return
            }
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }

    /// Back to the off-screen window, so the sound keeps going when nothing shows the picture.
    func detachVideo(from container: NSView) {
        if Self.debug { print("[video] detach", ObjectIdentifier(container), "owner?", webView.superview === container) }
        guard webView.superview === container else { return }      // someone else already took the picture
        webView.removeFromSuperview()
        window.contentView = webView
    }

    var videoHost: NSView? { webView.superview }

    private func run(_ js: String) {
        startIfNeeded()
        if ready { webView.evaluateJavaScript(js, completionHandler: nil) } else { pending.append(js) }
    }

    func load(_ track: Track) {
        guard case .youtube(let id) = track.source else { return }
        if !ready { pending.removeAll() }  // only the latest request matters while the page is still loading
        run("heyVolume(\(volume))")      // volume first so a muted dev run never blips
        run("heyLoad('\(id)')")
    }
    func play() { run("heyPlay()") }
    func pause() { run("heyPause()") }

    /// Tells macOS this process is doing real work, so App Nap doesn't stall the music.
    private var activity: NSObjectProtocol?
    func holdAwake(_ on: Bool) {
        if on, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled],
                                                             reason: "Playing music")
        } else if !on, let a = activity {
            ProcessInfo.processInfo.endActivity(a)
            activity = nil
        }
    }
    func stop() { run("heyStop()") }
    func seek(to seconds: Double) { run("heySeek(\(seconds))") }
    func setVolume(_ v: Double) { volume = v * 100; run("heyVolume(\(volume))") }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["t"] as? String else { return }
        if Self.debug, type != "time" { print("[yt] \(body)") }
        switch type {
        case "ready":
            ready = true
            pending.forEach { webView.evaluateJavaScript($0, completionHandler: nil) }
            pending.removeAll()
        case "state":
            switch body["v"] as? Int ?? -1 {
            case 1: holdAwake(true); onPlaying?(true)
            case 2, 3, -1, 5: holdAwake(false); onPlaying?(false)
            case 0: holdAwake(false); onPlaying?(false); onEnded?()
            default: break
            }
        case "quality":
            if Self.debug { print("[yt] quality", body["v"] ?? "nil") }
        case "time":
            onTime?(body["p"] as? Double ?? 0, body["d"] as? Double ?? 0)
        case "error":
            let code = body["v"] as? Int ?? 0
            onError?(code == 101 || code == 150 ? tr("เจ้าของวิดีโอไม่อนุญาตให้ฝังเล่น")
                     : code == 100 ? tr("ไม่พบวิดีโอ (ถูกลบหรือเป็นส่วนตัว)") : tr("เล่นวิดีโอนี้ไม่ได้ (รหัส {0})", code))
        default: break
        }
    }

    func webView(_ w: WKWebView, didFinish n: WKNavigation!) { if Self.debug { print("[yt] page loaded") } }
    func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { pageLost(tr("เชื่อมต่อ YouTube ไม่ได้ ตรวจอินเทอร์เน็ตนะ")) }
    func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { pageLost(tr("เชื่อมต่อ YouTube ไม่ได้ ตรวจอินเทอร์เน็ตนะ")) }
    func webViewWebContentProcessDidTerminate(_ w: WKWebView) {
        resetPage()
        if let onCrashed { onCrashed() } else { onError?(tr("ตัวเล่น YouTube หยุดทำงาน ลองเล่นใหม่อีกครั้ง")) }
    }

    /// Dev: kill the web content process the way the system would, to check the player recovers.
    func devCrash() { _ = webView.perform(NSSelectorFromString("_killWebContentProcessAndResetState")) }

    private func resetPage() {
        started = false
        ready = false
        pending.removeAll()
        holdAwake(false)
        onPlaying?(false)
    }

    /// The page is gone: start it afresh next time instead of queueing commands for it forever.
    private func pageLost(_ message: String) {
        resetPage()
        onError?(message)
    }

    /// YouTube wants embeds to identify themselves with a real https origin; apps use their bundle id as a host.
    private static let origin = ProcessInfo.processInfo.environment["HEY_DEV_YT_ORIGIN"] ?? "https://com.cdimac.hey"

    private static var html: String { htmlTemplate.replacingOccurrences(of: "ORIGIN", with: "'\(origin)'") }

    private static let htmlTemplate = """
    <!doctype html><html><style>html,body{margin:0;height:100%;background:#000;overflow:hidden}#p,iframe{width:100%;height:100%;pointer-events:none}</style><body><div id="p"></div><script>
    var player, ready = false, pendingId = null;
    window.onerror = function (m) { window.webkit.messageHandlers.hey.postMessage({t: 'jserror', m: String(m)}); };
    function send(o) { window.webkit.messageHandlers.hey.postMessage(o); }
    var s = document.createElement('script'); s.src = 'https://www.youtube.com/iframe_api'; document.head.appendChild(s);
    function onYouTubeIframeAPIReady() {
      player = new YT.Player('p', { width: '100%', height: '100%',
        playerVars: { origin: ORIGIN, autoplay: 1, controls: 0, playsinline: 1, rel: 0, modestbranding: 1 },
        events: {
          onReady: function () { ready = true; send({t: 'ready'}); if (pendingId) { heyLoad(pendingId); pendingId = null; } },
          onStateChange: function (e) { send({t: 'state', v: e.data}); },
          onError: function (e) { send({t: 'error', v: e.data}); } } });
    }
    // Let YouTube adapt quality to the video surface and available bandwidth.
    function heyLoad(id) { if (!ready) { pendingId = id; return; } player.loadVideoById({videoId: id}); }
    function heyPlay() { if (ready) player.playVideo(); }
    function heyPause() { if (ready) player.pauseVideo(); }
    function heyStop() { if (ready) player.stopVideo(); }
    function heySeek(t) { if (ready) player.seekTo(t, true); }
    function heyVolume(v) { if (ready) player.setVolume(v); }
    setInterval(function () {
      if (!ready || !player.getPlayerState) return;
      var st = player.getPlayerState();
      if (st === 1) send({t: 'time', p: player.getCurrentTime(), d: player.getDuration()});
    }, 1000);
    </script></body></html>
    """
}

/// Avoids WKUserContentController keeping its handler (and so the backend) alive forever.
private final class Weak: NSObject, WKScriptMessageHandler {
    weak var target: YouTubeBackend?
    init(_ target: YouTubeBackend) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        MainActor.assumeIsolated { target?.userContentController(c, didReceive: m) }
    }
}

@MainActor
private final class FileBackend: NSObject, Backend {
    var onPlaying: ((Bool) -> Void)?
    var onEnded: (() -> Void)?
    var onTime: ((Double, Double) -> Void)?
    var onError: ((String) -> Void)?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var volume: Float = 0.7
    var resolve: ((Track) -> URL?)?

    override init() {
        super.init()
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) {
            [weak self] time in
            MainActor.assumeIsolated {
                guard let self, self.player.rate > 0 else { return }
                let d = self.player.currentItem?.duration.seconds ?? 0
                self.onTime?(time.seconds, d.isFinite ? d : 0)
            }
        }
    }

    func load(_ track: Track) {
        guard let url = resolve?(track) else { onError?(tr("ไม่พบไฟล์เพลง (ถูกย้ายหรือลบ)")); return }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        let item = AVPlayerItem(url: url)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onPlaying?(false); self?.onEnded?() }
        }
        player.replaceCurrentItem(with: item)
        player.volume = volume
        player.play()
        onPlaying?(true)
    }

    func play() { player.play(); onPlaying?(true) }
    func pause() { player.pause(); onPlaying?(false) }
    func stop() { player.pause(); player.replaceCurrentItem(with: nil) }
    func seek(to s: Double) { player.seek(to: CMTime(seconds: s, preferredTimescale: 600)) }
    func setVolume(_ v: Double) { volume = Float(v); player.volume = volume }
}

// MARK: - player

@MainActor
@Observable
final class MusicPlayer {
    private(set) var nowPlaying: Track?
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var position = 0.0
    private(set) var duration = 0.0
    private(set) var errorText: String?

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored var onMessage: ((String, String?) -> Void)?
    @ObservationIgnored var logStates = false

    @ObservationIgnored private let model: GameModel
    @ObservationIgnored private var queue = PlayQueue(trackIDs: [])
    @ObservationIgnored private var youtube: YouTubeBackend?
    @ObservationIgnored private let files = FileBackend()
    @ObservationIgnored private var active: (any Backend)?
    @ObservationIgnored private var secondsHeard = 0.0
    @ObservationIgnored private var consecutiveFailures = 0
    @ObservationIgnored private var muted = false
    @ObservationIgnored private var queuePlaylistID: UUID?
    @ObservationIgnored private var loadWatchdog: DispatchWorkItem?
    @ObservationIgnored private var skipWork: DispatchWorkItem?
    @ObservationIgnored private var crashRetries = 0
    @ObservationIgnored private var resumeAt: Double?

    init(model: GameModel) {
        self.model = model
        files.resolve = { [weak self] in self?.localURL(for: $0) }
        wire(files)
        setUpRemoteCommands()
        model.observe { [weak self] _ in self?.refreshQueueIfNeeded() }
    }

    /// True while a YouTube song is loaded, so there is a picture to show.
    var hasVideo: Bool {
        if case .youtube = nowPlaying?.source { return youtube != nil }
        return false
    }
    func attachVideo(to container: NSView) { youtube?.attachVideo(to: container) }
    func detachVideo(from container: NSView) { youtube?.detachVideo(from: container) }
    var videoHost: NSView? { youtube?.videoHost }
    func devSnapshot(to path: String) { youtube?.devSnapshot(to: path) }
    func devCrash() { youtube?.devCrash() }

    var currentPlaylist: Playlist? { model.game.currentPlaylist }
    var volume: Double { model.game.music.volume }

    // MARK: transport

    func play(_ track: Track, in playlist: Playlist) {
        model.perform { $0.setMusic { $0.playlistID = playlist.id }; return [] }
        rebuildQueue(for: playlist)
        queue.start(at: track.id)
        start(track)
    }

    func toggle() {
        if nowPlaying != nil, active != nil {
            if isPlaying { active?.pause() } else { active?.play() }
        } else if let playlist = currentPlaylist, let first = playlist.tracks.first {
            play(first, in: playlist)
        } else {
            onMessage?(tr("ยังไม่มีเพลงใน playlist"), "music.note.list")
        }
    }

    func next() { advance(auto: false) }

    func previous() {
        if position > 3 { seek(to: 0); return }
        guard let id = queue.previous(), let track = track(id) else { seek(to: 0); return }
        start(track)
    }

    func seek(to seconds: Double) {
        position = seconds
        active?.seek(to: seconds)
        updateNowPlaying()
    }

    func setVolume(_ v: Double) {
        model.perform { $0.setMusic { $0.volume = v }; return [] }
        applyVolume()
    }

    func toggleShuffle() {
        model.perform { $0.setMusic { $0.shuffle.toggle() }; return [] }
        reapplyQueueSettings()
    }

    func cycleRepeat() {
        model.perform { $0.setMusic { $0.repeatMode = $0.repeatMode.next }; return [] }
        reapplyQueueSettings()
    }

    func stop() {
        active?.stop()
        active = nil
        nowPlaying = nil
        isPlaying = false
        position = 0
        duration = 0
        updateNowPlaying()
        onChange?()
    }

    // MARK: adding music

    /// Returns a message if the input can't be used.
    @discardableResult
    func addYouTube(_ input: String, to playlistID: UUID) -> String? {
        guard let id = YouTubeLink.videoID(from: input) else {
            if input.contains("list=") { return tr("ยังไม่รองรับทั้งเพลย์ลิสต์ — ใส่ลิงก์วิดีโอทีละอัน") }
            return tr("ไม่ใช่ลิงก์ YouTube ที่รู้จัก")
        }
        let track = Track(source: .youtube(id: id), title: "YouTube \(id)",
                          thumbnailURL: YouTubeLink.thumbnailURL(id), addedAt: Date())
        let events = model.perform { $0.addTrack(track, to: playlistID) }
        if events.contains(where: { if case .trackAdded = $0 { true } else { false } }) {
            Task { await fetchMetadata(for: track) }
        }
        return nil
    }

    /// Adds a YouTube video to the current playlist (making one if there is none) and optionally plays it.
    @discardableResult
    func addToCurrent(_ input: String, play: Bool) -> String? {
        if model.game.currentPlaylist == nil { model.perform { $0.createPlaylist(tr("เพลงของฉัน")); return [] } }
        guard let list = model.game.currentPlaylist else { return tr("สร้างเพลย์ลิสต์ไม่สำเร็จ") }
        if let error = addYouTube(input, to: list.id) { return error }
        if play, let id = YouTubeLink.videoID(from: input),
           let fresh = model.game.playlist(id: list.id),
           let track = fresh.tracks.first(where: { $0.source == .youtube(id: id) }) {
            self.play(track, in: fresh)
        }
        return nil
    }

    func addFiles(_ urls: [URL], to playlistID: UUID) {
        let audio = urls.filter { url in
            UTType(filenameExtension: url.pathExtension)?.conforms(to: .audio) ?? false
        }
        if audio.count < urls.count { onMessage?(tr("ข้ามไฟล์ที่ไม่ใช่เสียง {0} ไฟล์", urls.count - audio.count), "exclamationmark.triangle.fill") }
        for url in audio {
            Task {
                let info = await Self.readTags(url)
                let track = Track(source: .file(path: url.path, bookmark: try? url.bookmarkData()),
                                  title: info.title ?? url.deletingPathExtension().lastPathComponent,
                                  artist: info.artist, duration: info.duration, addedAt: Date())
                model.perform { $0.addTrack(track, to: playlistID) }
            }
        }
    }

    // MARK: internals

    private func track(_ id: UUID) -> Track? {
        model.game.playlists.lazy.flatMap(\.tracks).first { $0.id == id }
    }

    private func rebuildQueue(for playlist: Playlist) {
        queuePlaylistID = playlist.id
        let s = model.game.music
        queue = PlayQueue(trackIDs: playlist.tracks.map(\.id), shuffle: s.shuffle, repeatMode: s.repeatMode)
    }

    private func reapplyQueueSettings() {
        let s = model.game.music
        queue.shuffle = s.shuffle
        queue.repeatMode = s.repeatMode
        if let id = queue.current { queue.start(at: id) }
    }

    /// Keeps the queue in step with edits to the playlist being played (browsing another playlist doesn't touch it).
    func refreshQueueIfNeeded() {
        guard nowPlaying != nil, let playlist = model.game.playlist(id: queuePlaylistID) else { return }
        let ids = playlist.tracks.map(\.id)
        if ids != queue.trackIDs { queue.update(trackIDs: ids) }
    }

    private func start(_ track: Track) {
        skipWork?.cancel()
        loadWatchdog?.cancel()
        errorText = nil
        nowPlaying = track
        isPlaying = false
        isLoading = true
        position = 0
        duration = track.duration ?? 0
        active?.stop()

        let backend: any Backend
        switch track.source {
        case .youtube:
            if youtube == nil { let y = YouTubeBackend(); wire(y); y.onCrashed = { [weak self] in self?.recoverFromCrash() }; youtube = y }
            backend = youtube!
        case .file:
            backend = files
        }
        active = backend
        applyVolume()
        backend.load(track)
        let watchdog = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.isLoading, self.nowPlaying?.id == track.id else { return }
                self.failed(tr("โหลดเพลงไม่ขึ้น ตรวจอินเทอร์เน็ตนะ"))
            }
        }
        loadWatchdog = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: watchdog)
        updateNowPlaying()
        onChange?()
    }

    private func advance(auto: Bool) {
        guard let id = queue.next(auto: auto), let track = track(id) else {
            if auto { stop() }
            return
        }
        start(track)
    }

    private func applyVolume() {
        let v = muted ? 0 : volume
        youtube?.setVolume(v)
        files.setVolume(v)
    }

    private func wire(_ backend: some Backend) {
        backend.onPlaying = { [weak self] playing in
            guard let self else { return }
            isPlaying = playing
            if playing {
                isLoading = false; consecutiveFailures = 0
                if let at = resumeAt { resumeAt = nil; active?.seek(to: at) }
            }
            if logStates { print("[music] playing=\(playing) t=\(position)") }
            updateNowPlaying()
            onChange?()
        }
        backend.onEnded = { [weak self] in self?.advance(auto: true) }
        backend.onTime = { [weak self] pos, dur in
            guard let self else { return }
            position = pos
            if pos > 10 { crashRetries = 0 }
            if dur > 0, dur != duration { duration = dur; learnDuration(dur) }
            if logStates { print("[music] t=\(Int(pos))/\(Int(dur))") }
            countListening()
            updateNowPlaying()
        }
        backend.onError = { [weak self] message in self?.failed(message) }
    }

    /// The picture went blank because the web page's process died: load the song again and carry on from where it was.
    private func recoverFromCrash() {
        guard let track = nowPlaying, case .youtube = track.source, crashRetries < 3 else {
            failed(tr("ตัวเล่น YouTube หยุดทำงาน ลองเล่นใหม่อีกครั้ง")); return
        }
        crashRetries += 1
        let at = position
        start(track)
        resumeAt = at > 3 ? at : nil
    }

    private func failed(_ message: String) {
        errorText = message
        isLoading = false
        isPlaying = false
        consecutiveFailures += 1
        onMessage?(message, "exclamationmark.triangle.fill")
        if logStates { print("[music] error: \(message)") }
        onChange?()
        // Skip to the next track, but don't spin through a whole broken playlist forever.
        guard consecutiveFailures < max(queue.trackIDs.count, 1) else { return }
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.advance(auto: true) } }
        skipWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func learnDuration(_ d: Double) {
        guard let t = nowPlaying, t.duration == nil || abs((t.duration ?? 0) - d) > 1 else { return }
        model.perform { $0.updateTrack(id: t.id, title: nil, artist: nil, thumbnailURL: nil, duration: d); return [] }
    }

    /// One minute of listening counts toward the daily music quest.
    private func countListening() {
        secondsHeard += 1
        if secondsHeard >= 60 {
            secondsHeard = 0
            model.performQuietly { $0.recordListening(minutes: 1) }
        }
    }

    private func localURL(for track: Track) -> URL? {
        guard case .file(let path, let bookmark) = track.source else { return nil }
        if FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
        guard let bookmark else { return nil }
        var stale = false
        let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        return url.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
    }

    func fileExists(_ track: Track) -> Bool { track.isYouTube || localURL(for: track) != nil }

    struct OEmbed: Decodable { var title: String?; var author_name: String?; var thumbnail_url: String? }

    /// Title, channel and thumbnail from YouTube's public oEmbed endpoint; nil when offline or unavailable.
    static func oEmbed(videoID id: String) async -> OEmbed? {
        var comps = URLComponents(string: "https://www.youtube.com/oembed")!
        comps.queryItems = [.init(name: "url", value: YouTubeLink.watchURL(id).absoluteString), .init(name: "format", value: "json")]
        guard let url = comps.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(OEmbed.self, from: data)
    }

    private func fetchMetadata(for track: Track) async {
        guard case .youtube(let id) = track.source, let info = await Self.oEmbed(videoID: id) else { return }
        model.perform {
            $0.updateTrack(id: track.id, title: info.title, artist: info.author_name,
                           thumbnailURL: info.thumbnail_url, duration: nil)
            return []
        }
    }

    private static func readTags(_ url: URL) async -> (title: String?, artist: String?, duration: Double?) {
        let asset = AVURLAsset(url: url)
        var title: String?, artist: String?
        if let items = try? await asset.load(.commonMetadata) {
            for item in items {
                switch item.commonKey {
                case .commonKeyTitle: title = try? await item.load(.stringValue)
                case .commonKeyArtist: artist = try? await item.load(.stringValue)
                default: break
                }
            }
        }
        let d = (try? await asset.load(.duration))?.seconds
        return (title, artist, d.flatMap { $0.isFinite ? $0 : nil })
    }

    // MARK: system integration (media keys, Control Center)

    private func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard let t = nowPlaying else { center.nowPlayingInfo = nil; center.playbackState = .stopped; return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: t.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let a = t.artist { info[MPMediaItemPropertyArtist] = a }
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused
    }

    private func setUpRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        func bind(_ command: MPRemoteCommand, _ action: @escaping @MainActor (MusicPlayer) -> Void) {
            command.isEnabled = true
            command.addTarget { [weak self] _ in
                DispatchQueue.main.async { MainActor.assumeIsolated { if let self { action(self) } } }
                return .success
            }
        }
        bind(c.togglePlayPauseCommand) { $0.toggle() }
        bind(c.playCommand) { if !$0.isPlaying { $0.toggle() } }
        bind(c.pauseCommand) { if $0.isPlaying { $0.toggle() } }
        bind(c.nextTrackCommand) { $0.next() }
        bind(c.previousTrackCommand) { $0.previous() }
        c.changePlaybackPositionCommand.isEnabled = true
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let t = e.positionTime
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.seek(to: t) } }
            return .success
        }
    }

    // MARK: dev

    /// Plays a YouTube id silently so the hidden player can be verified without sound.
    func devPlay(videoID: String) {
        logStates = true
        muted = true
        if model.game.currentPlaylist == nil { model.perform { $0.createPlaylist("dev"); return [] } }
        guard let pid = model.game.currentPlaylist?.id else { return }
        addYouTube(videoID, to: pid)
        if let list = model.game.playlist(id: pid),
           let track = list.tracks.first(where: { $0.source == .youtube(id: videoID) }) {
            play(track, in: list)
        }
    }
}
