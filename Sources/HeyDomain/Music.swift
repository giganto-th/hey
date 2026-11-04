import Foundation

public enum TrackSource: Codable, Equatable, Sendable {
    case youtube(id: String)
    case file(path: String, bookmark: Data?)
}

public struct Track: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var source: TrackSource
    public var title: String
    public var artist: String?
    public var thumbnailURL: String?
    public var duration: Double?
    public var addedAt: Date

    public init(source: TrackSource, title: String, artist: String? = nil, thumbnailURL: String? = nil,
                duration: Double? = nil, addedAt: Date) {
        self.source = source; self.title = title; self.artist = artist
        self.thumbnailURL = thumbnailURL; self.duration = duration; self.addedAt = addedAt
    }

    public var isYouTube: Bool { if case .youtube = source { true } else { false } }
}

public struct Playlist: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var name: String
    public var tracks: [Track] = []
    public init(name: String) { self.name = name }
}

public enum RepeatMode: String, Codable, CaseIterable, Sendable {
    case off, all, one

    public var next: RepeatMode {
        switch self { case .off: .all; case .all: .one; case .one: .off }
    }
}

public struct MusicSettings: Codable, Equatable, Sendable {
    public var volume = 0.7
    public var shuffle = false
    public var repeatMode: RepeatMode = .off
    public var playlistID: UUID?
    /// Offer to add a YouTube link when one is copied.
    public var detectClipboard = true
    /// Offer to add the YouTube video open in the front browser tab (needs Automation permission).
    public var detectBrowser = false
    /// Experimental: ask macOS what is playing (private API) and offer it when a browser tab shows the YouTube link.
    public var detectNowPlaying = false
    /// Show the playing song as scrolling text in the menu bar.
    public var showInMenuBar = true
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case volume, shuffle, repeatMode, playlistID, detectClipboard, detectBrowser, detectNowPlaying, showInMenuBar
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 0.7
        shuffle = try c.decodeIfPresent(Bool.self, forKey: .shuffle) ?? false
        repeatMode = try c.decodeIfPresent(RepeatMode.self, forKey: .repeatMode) ?? .off
        playlistID = try c.decodeIfPresent(UUID.self, forKey: .playlistID)
        detectClipboard = try c.decodeIfPresent(Bool.self, forKey: .detectClipboard) ?? true
        detectBrowser = try c.decodeIfPresent(Bool.self, forKey: .detectBrowser) ?? false
        detectNowPlaying = try c.decodeIfPresent(Bool.self, forKey: .detectNowPlaying) ?? false
        showInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
    }
}

public enum YouTubeLink {
    /// Accepts watch / youtu.be / shorts / embed / music.youtube.com links, or a bare 11-character id.
    public static func videoID(from input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if isID(text) { return text }
        guard let url = URL(string: text) ?? URL(string: text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""),
              let host = url.host?.lowercased() else { return nil }

        if host == "youtu.be" || host == "www.youtu.be" {
            let id = url.pathComponents.dropFirst().first ?? ""
            return isID(id) ? id : nil
        }
        guard host == "youtube.com" || host.hasSuffix(".youtube.com") else { return nil }

        if let v = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first(where: { $0.name == "v" })?.value, isID(v) {
            return v
        }
        let parts = url.pathComponents
        if parts.count >= 3, ["shorts", "embed", "live", "v"].contains(parts[1]), isID(parts[2]) { return parts[2] }
        return nil
    }

    /// Browser tab titles look like "(3) Song name - YouTube"; keep just the song name.
    public static func cleanTabTitle(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("("), let close = t.firstIndex(of: ")"), t[t.index(after: t.startIndex)..<close].allSatisfy(\.isNumber) {
            t = String(t[t.index(after: close)...]).trimmingCharacters(in: .whitespaces)       // unread-notification count
        }
        for suffix in [" - YouTube Music", " - YouTube"] where t.hasSuffix(suffix) {
            t = String(t.dropLast(suffix.count))
            break
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    public static func watchURL(_ id: String) -> URL { URL(string: "https://www.youtube.com/watch?v=\(id)")! }
    public static func thumbnailURL(_ id: String) -> String { "https://i.ytimg.com/vi/\(id)/mqdefault.jpg" }

    private static func isID(_ s: String) -> Bool {
        s.count == 11 && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }
}

/// Decides which track plays next. Knows nothing about audio.
public struct PlayQueue: Sendable {
    public private(set) var trackIDs: [UUID]
    public var shuffle: Bool
    public var repeatMode: RepeatMode
    private var order: [Int] = []
    private var position: Int?
    private var rng: any RandomSource

    public init(trackIDs: [UUID], shuffle: Bool = false, repeatMode: RepeatMode = .off,
                rng: any RandomSource = SystemRandom()) {
        self.trackIDs = trackIDs
        self.shuffle = shuffle
        self.repeatMode = repeatMode
        self.rng = rng
    }

    public var current: UUID? { position.map { trackIDs[order[$0]] } }

    /// Starts at `id`; with shuffle on, the rest follow in random order.
    public mutating func start(at id: UUID) {
        guard let index = trackIDs.firstIndex(of: id) else { position = nil; return }
        order = Array(trackIDs.indices)
        if shuffle {
            var rest = order.filter { $0 != index }
            var i = rest.count - 1
            while i > 0 {                                    // Fisher–Yates
                let j = min(Int(rng.next(in: 0...Double(i + 1))), i)
                rest.swapAt(i, j)
                i -= 1
            }
            order = [index] + rest
            position = 0
        } else {
            position = index
        }
    }

    /// `auto` = the track ended by itself (repeat-one repeats); otherwise the user pressed next.
    public mutating func next(auto: Bool) -> UUID? {
        guard let p = position else { return nil }
        if auto, repeatMode == .one { return current }
        if p + 1 < order.count { position = p + 1; return current }
        if repeatMode == .all, !order.isEmpty { position = 0; return current }
        position = nil
        return nil
    }

    public mutating func previous() -> UUID? {
        guard let p = position else { return nil }
        if p > 0 { position = p - 1 } else if repeatMode == .all { position = order.count - 1 }
        return current
    }

    /// Call after the playlist was edited; keeps playing the same track if it still exists.
    public mutating func update(trackIDs newIDs: [UUID]) {
        let playing = current
        trackIDs = newIDs
        if let playing, newIDs.contains(playing) { start(at: playing) } else { position = nil; order = [] }
    }
}


public enum YouTubeDetection {
    /// A link is worth offering unless it is already in a playlist, was just turned down, or is already on offer.
    public static func shouldSuggest(videoID: String, playlists: [Playlist], dismissed: Set<String>, current: String?) -> Bool {
        guard videoID != current, !dismissed.contains(videoID) else { return false }
        return !playlists.contains { $0.tracks.contains { $0.source == .youtube(id: videoID) } }
    }

    /// Bundle ids of browsers we know how to ask for the front tab.
    public static let browsers: [String: String] = [
        "com.apple.Safari": "Safari",
        "com.google.Chrome": "Google Chrome",
        "company.thebrowser.Browser": "Arc",
        "com.brave.Browser": "Brave Browser",
        "com.microsoft.edgemac": "Microsoft Edge",
    ]

    /// Pasteboard types that password managers and the system use to mark "don't look at this".
    public static let privateClipboardTypes: Set<String> = [
        "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType",
        "com.agilebits.onepassword",
    ]

    public static func isPrivateClipboard(types: [String]) -> Bool {
        !privateClipboardTypes.isDisjoint(with: Set(types))
    }
}


public enum MarqueeText {
    public static let maxLength = 120

    /// One line for the menu bar: "Title — Artist", whitespace collapsed, capped in length.
    public static func display(title: String, artist: String?) -> String {
        func clean(_ s: String) -> String { s.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        let t = clean(title)
        let a = artist.map(clean) ?? ""
        var line = a.isEmpty || t.localizedCaseInsensitiveContains(a) ? t : "\(t) — \(a)"
        if line.isEmpty { line = "…" }
        if line.count > maxLength { line = String(line.prefix(maxLength - 1)) + "…" }
        return line
    }
}
