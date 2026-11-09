import Foundation

/// A version such as 1.2.3, compared number by number (so 1.10.0 is newer than 1.9.0).
public struct AppVersion: Comparable, Equatable, Sendable, CustomStringConvertible {
    public let parts: [Int]

    /// Accepts "1.2.3" and "v1.2.3"; anything after a dash ("-beta") is ignored. Nil if there is no number.
    public init?(_ text: String) {
        var t = text.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("v") || t.hasPrefix("V") { t.removeFirst() }
        if let dash = t.firstIndex(of: "-") { t = String(t[..<dash]) }
        let numbers = t.split(separator: ".").map { Int($0) }
        guard !numbers.isEmpty, !numbers.contains(nil) else { return nil }
        parts = numbers.compactMap { $0 }
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0, y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    public static func == (a: AppVersion, b: AppVersion) -> Bool { !(a < b) && !(b < a) }
}

/// What a published release offers.
public struct ReleaseInfo: Equatable, Sendable {
    public var version: AppVersion
    public var tag: String
    public var notes: String
    public var pageURL: URL?
    public var downloadURL: URL
    public var sizeBytes: Int?
    /// Lower-case hex SHA-256 of the download, when the release publishes one.
    public var sha256: String?
}

public enum ReleaseFeed {
    public enum Failure: Error, Equatable { case notJSON, noDiskImage, untrustedLink }

    /// Reads GitHub's "latest release" JSON. Returns nil for a draft or pre-release. Only https links on github.com are accepted.
    public static func parse(_ data: Data) throws -> ReleaseInfo? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let tag = json["tag_name"] as? String,
              let version = AppVersion(tag) else { throw Failure.notJSON }
        if (json["draft"] as? Bool) == true || (json["prerelease"] as? Bool) == true { return nil }
        let assets = json["assets"] as? [[String: Any]] ?? []
        guard let dmg = assets.first(where: { ($0["name"] as? String)?.lowercased().hasSuffix(".dmg") == true }),
              let link = dmg["browser_download_url"] as? String, let url = URL(string: link) else { throw Failure.noDiskImage }
        guard url.scheme == "https", let host = url.host, host == "github.com" || host.hasSuffix(".github.com") else { throw Failure.untrustedLink }
        var sha: String?
        if let digest = dmg["digest"] as? String, digest.lowercased().hasPrefix("sha256:") {
            let hex = String(digest.dropFirst(7)).lowercased()
            if hex.count == 64, hex.allSatisfy({ $0.isHexDigit }) { sha = hex }
        }
        return ReleaseInfo(version: version, tag: tag, notes: (json["body"] as? String) ?? "",
                           pageURL: (json["html_url"] as? String).flatMap(URL.init(string:)),
                           downloadURL: url, sizeBytes: dmg["size"] as? Int, sha256: sha)
    }
}

/// When to look for an update: at most once a day, and never more than once per launch unless asked.
public enum UpdateSchedule {
    public static let interval: TimeInterval = 24 * 3600
    public static func isDue(lastChecked: Date?, now: Date) -> Bool {
        guard let last = lastChecked else { return true }
        return now.timeIntervalSince(last) >= interval || now < last
    }
}
