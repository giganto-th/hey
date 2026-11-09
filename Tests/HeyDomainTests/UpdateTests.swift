import Testing
import Foundation
@testable import HeyDomain

@Suite("Update")
struct UpdateTests {
    @Test func versionsCompareNumerically() throws {
        let a = try #require(AppVersion("1.9.0")), b = try #require(AppVersion("1.10.0"))
        #expect(a < b)
        #expect(try #require(AppVersion("v1.2.3")) == #require(AppVersion("1.2.3")))
        #expect(try #require(AppVersion("1.2")) == #require(AppVersion("1.2.0")))
        #expect(try #require(AppVersion("2.0.0")) > #require(AppVersion("1.99.99")))
        #expect(try #require(AppVersion("1.2.3-beta")) == #require(AppVersion("1.2.3")))
    }

    @Test func notAVersionIsNil() {
        #expect(AppVersion("") == nil)
        #expect(AppVersion("latest") == nil)
        #expect(AppVersion("1.x.3") == nil)
    }

    private func release(tag: String = "v1.3.0", draft: Bool = false, pre: Bool = false, url: String = "https://github.com/giganto-th/hey/releases/download/v1.3.0/Hey-1.3.0.dmg",
                         digest: String? = "sha256:" + String(repeating: "ab", count: 32), asset: String = "Hey-1.3.0.dmg") -> Data {
        var a: [String: Any] = ["name": asset, "browser_download_url": url, "size": 123]
        if let digest { a["digest"] = digest }
        let json: [String: Any] = ["tag_name": tag, "body": "Notes", "html_url": "https://github.com/giganto-th/hey/releases/tag/v1.3.0",
                                   "draft": draft, "prerelease": pre, "assets": [a]]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    @Test func aReleaseIsReadFromGitHubJSON() throws {
        let info = try #require(try ReleaseFeed.parse(release()))
        #expect(info.version.description == "1.3.0")
        #expect(info.downloadURL.lastPathComponent == "Hey-1.3.0.dmg")
        #expect(info.sha256 == String(repeating: "ab", count: 32))
        #expect(info.notes == "Notes")
        #expect(info.sizeBytes == 123)
    }

    @Test func draftsAndPrereleasesAreIgnored() throws {
        #expect(try ReleaseFeed.parse(release(draft: true)) == nil)
        #expect(try ReleaseFeed.parse(release(pre: true)) == nil)
    }

    @Test func aMissingOrBadDigestMeansNoHash() throws {
        #expect(try #require(try ReleaseFeed.parse(release(digest: nil))).sha256 == nil)
        #expect(try #require(try ReleaseFeed.parse(release(digest: "sha256:xyz"))).sha256 == nil)
        #expect(try #require(try ReleaseFeed.parse(release(digest: "md5:" + String(repeating: "a", count: 32)))).sha256 == nil)
    }

    @Test func onlyGitHubHttpsLinksAreTrusted() {
        #expect(throws: ReleaseFeed.Failure.untrustedLink) { try ReleaseFeed.parse(release(url: "http://github.com/x/Hey.dmg")) }
        #expect(throws: ReleaseFeed.Failure.untrustedLink) { try ReleaseFeed.parse(release(url: "https://evil.example.com/Hey.dmg")) }
        #expect(throws: ReleaseFeed.Failure.untrustedLink) { try ReleaseFeed.parse(release(url: "https://github.com.evil.com/Hey.dmg")) }
    }

    @Test func aReleaseWithoutADiskImageIsAnError() {
        #expect(throws: ReleaseFeed.Failure.noDiskImage) { try ReleaseFeed.parse(release(asset: "source.zip")) }
    }

    @Test func garbageIsNotJSON() {
        #expect(throws: ReleaseFeed.Failure.notJSON) { try ReleaseFeed.parse(Data("hello".utf8)) }
    }

    @Test func checksHappenAtMostDaily() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(UpdateSchedule.isDue(lastChecked: nil, now: now))
        #expect(!UpdateSchedule.isDue(lastChecked: now.addingTimeInterval(-3600), now: now))
        #expect(UpdateSchedule.isDue(lastChecked: now.addingTimeInterval(-90_000), now: now))
        #expect(UpdateSchedule.isDue(lastChecked: now.addingTimeInterval(3600), now: now))      // clock moved back
    }
}
