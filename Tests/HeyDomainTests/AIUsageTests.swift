import Testing
import Foundation
@testable import HeyDomain

private let now = Date(timeIntervalSince1970: 1_793_800_000)

@Suite struct AIUsageTests {
    @Test func parsesCodexRateLimitsFromASessionLine() throws {
        let line = #"{"timestamp":"2026-11-04T14:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{},"rate_limits":{"limit_id":"codex","primary":{"used_percent":65.0,"window_minutes":300,"resets_at":1793818753},"secondary":{"used_percent":42.0,"window_minutes":10080,"resets_at":1794368134},"credits":{"has_credits":true,"unlimited":false,"balance":"12"}}}}"#
        let usage = try #require(UsageParsers.codex(line: line))
        #expect(usage.provider == .codex)
        #expect(usage.windows.map(\.id) == ["5h", "7d"])
        #expect(usage.windows[0].usedPercent == 65)
        #expect(usage.windows[1].resetsAt == Date(timeIntervalSince1970: 1794368134))
        #expect(usage.creditsNote != nil)
        #expect(UsageParsers.codex(line: #"{"type":"event_msg","payload":{"type":"agent_message"}}"#) == nil)
        #expect(UsageParsers.codex(line: "not json rate_limits") == nil)
    }

    @Test func codexReaderFindsQuotaBeyondEightUnavailableSessions() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessions = home.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let quota = #"{"timestamp":"2026-11-04T14:00:00Z","payload":{"rate_limits":{"primary":{"used_percent":65,"window_minutes":300,"resets_at":1793818753}}}}"#
        let unavailable = #"{"payload":{"rate_limits":{"primary":null,"secondary":null}}}"#
        for index in 0..<10 {
            let url = sessions.appendingPathComponent("session-\(index).jsonl")
            try Data((index == 0 ? quota : unavailable).utf8).write(to: url)
            try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(Double(index))], ofItemAtPath: url.path)
        }
        let usage = try #require(CodexUsageReader.read(home: home))
        #expect(usage.windows.first?.usedPercent == 65)
        #expect(usage.asOf == Date(timeIntervalSince1970: 1793800800))
    }

    @Test func codexReaderReadsCompressedSessions() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessions = home.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        // zstd-compressed synthetic quota event; no real session or account information.
        // Platforms without an installed decoder still exercise the plain-session regressions.
        guard CodexUsageReader.zstdExecutable != nil else { return }
        let fixture = try #require(Data(base64Encoded: "KLUv/QRYtQMAsogcHHClzgGEvpbl7CtqWYsvXarCoNi2zabNU/phPRGBGGMsjkRJSiFIkr5XvebH7kJmoX/cT7OYgpylWdCFA9F3wwGOm1r4PYf6yC1brh3qXy+2GMW97lC/rMNE2y4cIFMz1UgDI4eUBoRI4vrGth+z1YcBAE3JzEc="))
        try fixture.write(to: sessions.appendingPathComponent("session.jsonl.zst"))
        let usage = try #require(CodexUsageReader.read(home: home))
        #expect(usage.windows.first?.usedPercent == 65)
    }

    @Test(arguments: [false, true])
    func codexReaderSupportsMixedPlainAndCompressedSessions(compressedIsNewer: Bool) throws {
        guard CodexUsageReader.zstdExecutable != nil else { return }
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessions = home.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let plain = sessions.appendingPathComponent("plain.jsonl")
        let compressed = sessions.appendingPathComponent("compressed.jsonl.zst")
        let quota = #"{"timestamp":"2026-11-04T14:00:00Z","payload":{"rate_limits":{"primary":{"used_percent":25,"window_minutes":300}}}}"#
        try Data(quota.utf8).write(to: plain)
        let fixture = try #require(Data(base64Encoded: "KLUv/QRYtQMAsogcHHClzgGEvpbl7CtqWYsvXarCoNi2zabNU/phPRGBGGMsjkRJSiFIkr5XvebH7kJmoX/cT7OYgpylWdCFA9F3wwGOm1r4PYf6yC1brh3qXy+2GMW97lC/rMNE2y4cIFMz1UgDI4eUBoRI4vrGth+z1YcBAE3JzEc="))
        try fixture.write(to: compressed)
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: plain.path)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(compressedIsNewer ? 60 : -60)], ofItemAtPath: compressed.path)
        let usage = try #require(CodexUsageReader.read(home: home))
        #expect(usage.windows.first?.usedPercent == (compressedIsNewer ? 65 : 25))
    }

    @Test func codexReaderFallsBackToPlainWhenCompressedSessionIsUnreadable() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessions = home.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let plain = sessions.appendingPathComponent("plain.jsonl")
        let compressed = sessions.appendingPathComponent("broken.jsonl.zst")
        try Data(#"{"payload":{"rate_limits":{"primary":{"used_percent":25,"window_minutes":300}}}}"#.utf8).write(to: plain)
        try Data("not a zstd stream".utf8).write(to: compressed)
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: plain.path)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(60)], ofItemAtPath: compressed.path)
        #expect(CodexUsageReader.read(home: home)?.windows.first?.usedPercent == 25)
    }

    @Test func codexReaderKeepsQuotaWhenTailStartsInsideUTF8() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessions = home.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let quota = #"{"payload":{"rate_limits":{"primary":{"used_percent":65,"window_minutes":300}}}}"#
        // The retained 400 KB starts at byte 1, in the middle of the first Thai character.
        var data = Data("ก".utf8)
        data.append(Data(repeating: 32, count: CodexUsageReader.tailLimit - quota.utf8.count - 3))
        data.append(Data(("\n" + quota).utf8))
        #expect(data.count == CodexUsageReader.tailLimit + 1)
        try data.write(to: sessions.appendingPathComponent("session.jsonl"))
        #expect(CodexUsageReader.read(home: home)?.windows.first?.usedPercent == 65)
    }

    @Test func codexReaderDoesNotInventQuotaForNullWindows() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessions = home.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        try Data(#"{"payload":{"rate_limits":{"primary":null,"secondary":null}}}"#.utf8)
            .write(to: sessions.appendingPathComponent("session.jsonl"))
        #expect(CodexUsageReader.read(home: home) == nil)
    }

    @Test func parsesClaudeUsageAndIgnoresUnknownFields() throws {
        let json = #"{"five_hour":{"utilization":29.0,"resets_at":"2026-11-04T18:10:00.418138+00:00"},"seven_day":{"utilization":57.0,"resets_at":"2026-11-09T02:00:00+00:00"},"seven_day_opus":null,"mystery":{"x":1}}"#
        let usage = try #require(UsageParsers.claude(json: Data(json.utf8), plan: "pro", now: now))
        #expect(usage.plan == "pro")
        #expect(usage.windows.map(\.id) == ["5h", "7d"])
        #expect(usage.windows[0].usedPercent == 29)
        #expect(usage.windows[0].resetsAt != nil)
        #expect(UsageParsers.claude(json: Data("{}".utf8), plan: nil, now: now) == nil)
    }

    @Test func accountsOfOneProviderAreTrackedSeparately() throws {
        let json = #"{"five_hour":{"utilization":95.0,"resets_at":"2026-11-04T18:10:00+00:00"}}"#
        let a = try #require(UsageParsers.claude(json: Data(json.utf8), plan: "pro", accountID: "a", accountLabel: "a@example.com", now: now))
        let b = try #require(UsageParsers.claude(json: Data(json.utf8), plan: "max", accountID: "b", accountLabel: "b@example.com", now: now))
        #expect(a.title == "Claude · a@example.com")
        var alerts = UsageAlerts()
        let later = Date(timeIntervalSince1970: 1_793_700_000)             // before the reset time in the JSON
        #expect(alerts.evaluate(a, now: later).map(\.level) == [80, 95].suffix(1).map { $0 })
        #expect(alerts.evaluate(b, now: later).count == 1)                 // the other account still gets its own warning
        #expect(alerts.evaluate(a, now: later).isEmpty)
        #expect(UsageText.summary(a, now: later).hasPrefix("Claude · a@example.com:"))
        #expect(ClaudeProfile.label(from: Data(#"{"account":{"email":"x@y.z","full_name":"X"}}"#.utf8)) == "x@y.z")
    }

    @Test func parsesAntigravityQuotasAndGroupsSharedOnes() throws {
        let json = #"{"userStatus":{"email":"me@example.com","userTier":{"name":"Starter"},"cascadeModelConfigData":{"clientModelConfigs":[{"label":"Gemini Flash (High)","quotaInfo":{"remainingFraction":1,"resetTime":"2026-11-11T16:00:27Z"}},{"label":"Gemini Flash (Low)","quotaInfo":{"remainingFraction":1,"resetTime":"2026-11-11T16:00:27Z"}},{"label":"Claude Sonnet","quotaInfo":{"remainingFraction":0.25,"resetTime":"2026-11-05T01:00:00Z"}},{"label":"Preview model","quotaInfo":{}}]}}}"#
        let usage = try #require(UsageParsers.antigravity(json: Data(json.utf8), now: now))
        #expect(usage.accountLabel == "me@example.com")
        #expect(usage.plan == "Starter")
        #expect(usage.accountID == "antigravity:me@example.com")
        #expect(usage.windows.count == 2)
        #expect(usage.windows[0].id == "Gemini Flash (High) +1")
        #expect(usage.windows[0].usedPercent == 0)
        #expect(usage.windows[1].usedPercent == 75)
        #expect(UsageParsers.antigravity(json: Data(#"{"userStatus":{}}"#.utf8), now: now) == nil)
    }

    @Test func readsTheEmailFromALoginJWT() {
        let payload = Data(#"{"email":"a@b.co","sub":"1"}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        #expect(UsageParsers.jwtEmail("x.\(payload).y") == "a@b.co")
        #expect(UsageParsers.jwtEmail("garbage") == nil)
    }

    @Test func aWindowPastItsResetCountsAsEmpty() {
        let w = UsageWindow(id: "5h", usedPercent: 90, resetsAt: now.addingTimeInterval(-60))
        #expect(w.isExpired(at: now))
        #expect(w.effectivePercent(at: now) == 0)
        let live = UsageWindow(id: "5h", usedPercent: 90, resetsAt: now.addingTimeInterval(600))
        #expect(live.effectivePercent(at: now) == 90)
    }

    @Test func alertsFireOncePerThresholdAndPeriod() {
        var alerts = UsageAlerts()
        let reset = now.addingTimeInterval(3600)
        func usage(_ p: Double, reset: Date) -> ProviderUsage {
            ProviderUsage(provider: .codex, windows: [UsageWindow(id: "5h", usedPercent: p, resetsAt: reset)], asOf: now)
        }
        #expect(alerts.evaluate(usage(50, reset: reset), now: now).isEmpty)
        #expect(alerts.evaluate(usage(82, reset: reset), now: now).map(\.level) == [80])
        #expect(alerts.evaluate(usage(85, reset: reset), now: now).isEmpty)               // still the same level
        #expect(alerts.evaluate(usage(96, reset: reset), now: now).map(\.level) == [95])
        #expect(alerts.evaluate(usage(99, reset: reset), now: now).isEmpty)
        let nextPeriod = now.addingTimeInterval(20_000)
        #expect(alerts.evaluate(usage(81, reset: nextPeriod), now: now).map(\.level) == [80])   // a new period warns again
        #expect(alerts.evaluate(usage(99, reset: now.addingTimeInterval(-5)), now: now).isEmpty) // expired windows never warn
    }

    @Test func thresholdsCanBeChanged() {
        var alerts = UsageAlerts(thresholds: [60, 90])
        let usage = ProviderUsage(provider: .codex, windows: [UsageWindow(id: "5h", usedPercent: 65, resetsAt: now.addingTimeInterval(600))], asOf: now)
        #expect(alerts.evaluate(usage, now: now).map(\.level) == [60])
        #expect(usage.peakPercent(at: now) == 65)
        #expect(usage.peakPercent(at: now.addingTimeInterval(700)) == 0)
    }

    @Test func summaryUsesTheEffectivePercent() {
        let usage = ProviderUsage(provider: .claude, windows: [
            UsageWindow(id: "5h", usedPercent: 29.4, resetsAt: now.addingTimeInterval(100)),
            UsageWindow(id: "7d", usedPercent: 57, resetsAt: now.addingTimeInterval(-1)),
        ], asOf: now)
        #expect(UsageText.summary(usage, now: now) == "Claude: ช่วง 5 ชั่วโมง 29% · ช่วง 7 วัน 0%")
        #expect(UsageText.until(now.addingTimeInterval(90 * 60), now: now) == "1 ชม. 30 นาที")
    }
}
