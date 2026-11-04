import Foundation

/// What macOS says is playing right now (the same thing Control Center shows).
public struct NowPlayingInfo: Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var rate: Double
    public var duration: Double?
    public var elapsed: Double?

    public init(title: String, artist: String? = nil, rate: Double = 0, duration: Double? = nil, elapsed: Double? = nil) {
        self.title = title; self.artist = artist; self.rate = rate; self.duration = duration; self.elapsed = elapsed
    }

    public var isPlaying: Bool { rate > 0 }

    /// Parses the single JSON line the helper prints. Anything unusable (errors, no title) gives nil.
    public static func parse(_ data: Data) -> NowPlayingInfo? {
        struct Raw: Decodable {
            var title: String?; var artist: String?; var rate: Double?
            var duration: Double?; var elapsed: Double?; var error: String?
        }
        guard let line = String(data: data, encoding: .utf8)?
                .split(whereSeparator: \.isNewline).last.map(String.init),
              let raw = try? JSONDecoder().decode(Raw.self, from: Data(line.utf8)),
              raw.error == nil, let title = raw.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return nil }
        let artist = raw.artist.flatMap { $0.isEmpty ? nil : $0 }
        return NowPlayingInfo(title: title, artist: artist, rate: raw.rate ?? 0, duration: raw.duration, elapsed: raw.elapsed)
    }
}

public struct BrowserTab: Equatable, Sendable {
    public var url: String
    public var title: String
    public init(url: String, title: String) { self.url = url; self.title = title }
}

public enum NowPlayingMatcher {
    /// Finds the YouTube video behind a now-playing title by looking for the browser tab that carries it.
    /// Returns nil when nothing matches, or when two different videos match equally (ads, duplicates).
    public static func youtubeID(for info: NowPlayingInfo, tabs: [BrowserTab]) -> String? {
        let wanted = normalize(info.title)
        guard !wanted.isEmpty else { return nil }

        var exact = Set<String>()
        var loose = Set<String>()
        for tab in tabs {
            guard let id = YouTubeLink.videoID(from: tab.url) else { continue }
            let t = normalize(YouTubeLink.cleanTabTitle(tab.title))
            if t == wanted { exact.insert(id) }
            else if wanted.count >= 12, t.count >= 12, t.hasPrefix(wanted) || wanted.hasPrefix(t) { loose.insert(id) }
        }
        if exact.count == 1 { return exact.first }
        if exact.isEmpty, loose.count == 1 { return loose.first }
        return nil
    }

    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

public enum NowPlayingDisplay {
    /// A song that was paused a moment ago stays on the bar (as paused) for this long, then disappears.
    public static let pauseGrace: TimeInterval = 30

    public static func shouldShow(_ info: NowPlayingInfo?, lastPlayingAt: Date?, now: Date) -> Bool {
        guard let info else { return false }
        if info.isPlaying { return true }
        guard let last = lastPlayingAt else { return false }
        return now.timeIntervalSince(last) <= pauseGrace
    }
}
