import Foundation
import Testing
@testable import HeyDomain

@Suite struct UsageMenuBarTests {
    private let now = Date(timeIntervalSince1970: 1_793_800_000)

    @Test func defaultsPreserveLogoOnly() throws {
        let settings = UsageMenuBarSettings()
        #expect(!settings.enabled)
        #expect(settings.accountIDs.isEmpty)
        #expect(settings.windowID == "5h")
        #expect(settings.percentMode == .used)
        #expect(!settings.showReset)
        #expect(try JSONDecoder().decode(UsageMenuBarSettings.self, from: JSONEncoder().encode(settings)) == settings)
    }

    @Test func usedAndRemainingAreComplementaryWithoutLabels() {
        var settings = UsageMenuBarSettings()
        let window = UsageWindow(id: "5h", usedPercent: 42.6, resetsAt: nil)
        #expect(settings.text(for: window, now: now) == "43%")
        settings.percentMode = .remaining
        #expect(settings.text(for: window, now: now) == "57%")
    }

    @Test func resetCountdownRoundsUpAndCanBeHidden() {
        var settings = UsageMenuBarSettings()
        let window = UsageWindow(id: "5h", usedPercent: 43, resetsAt: now.addingTimeInterval(5_401))
        #expect(settings.text(for: window, now: now) == "43%")
        settings.showReset = true
        #expect(settings.text(for: window, now: now) == "43% · ↻ 1:31")
        #expect(settings.text(for: window, now: now.addingTimeInterval(1)) == "43% · ↻ 1:30")
        #expect(settings.text(for: window, now: now.addingTimeInterval(5_400)) == "43% · ↻ 0:01")
    }

    @Test func expiredAndMissingResetsUseExistingQuotaRules() {
        var settings = UsageMenuBarSettings()
        settings.showReset = true
        let window = UsageWindow(id: "5h", usedPercent: 90, resetsAt: now)
        #expect(settings.text(for: window, now: now) == "0% · รีเซ็ตแล้ว")
        settings.percentMode = .remaining
        #expect(settings.text(for: window, now: now) == "100% · รีเซ็ตแล้ว")
        #expect(settings.text(for: UsageWindow(id: "5h", usedPercent: 90, resetsAt: nil), now: now) == "10%")
    }

    @Test(arguments: [-10.0, 110.0]) func clampsPercentToValidRange(percent: Double) {
        var settings = UsageMenuBarSettings()
        let window = UsageWindow(id: "5h", usedPercent: percent, resetsAt: nil)
        #expect(settings.text(for: window, now: now) == "\(percent < 0 ? 0 : 100)%")
        settings.percentMode = .remaining
        #expect(settings.text(for: window, now: now) == "\(percent < 0 ? 100 : 0)%")
    }

    @Test func selectsMultipleAccountsInSelectionOrderWithoutDuplicatesOrFallback() {
        let model = ProviderUsage(provider: .antigravity, accountID: "a", windows: [UsageWindow(id: "model", usedPercent: 20, resetsAt: nil)], asOf: now)
        let first = ProviderUsage(provider: .claude, accountID: "b", windows: [UsageWindow(id: "5h", usedPercent: 40, resetsAt: nil)], asOf: now)
        let second = ProviderUsage(provider: .claude, accountID: "c", windows: [UsageWindow(id: "5h", usedPercent: 80, resetsAt: nil)], asOf: now)
        let codex = ProviderUsage(provider: .codex, accountID: "d", windows: [UsageWindow(id: "5h", usedPercent: 60, resetsAt: nil)], asOf: now)
        let accounts = [model, first, second, codex]
        var settings = UsageMenuBarSettings()
        #expect(settings.usages(from: accounts) == [model])      // Antigravity has no named periods, so it always qualifies
        settings.accountIDs = ["c", "b", "d", "c", "missing", "a"]
        #expect(settings.usages(from: accounts) == [second, first, codex, model])
        #expect(settings.usages(from: [model, first]) == [first, model])
        settings.accountIDs = ["missing"]
        #expect(settings.usages(from: accounts).isEmpty)
        settings.windowID = "7d"
        #expect(settings.usages(from: accounts).isEmpty)
        settings.accountIDs = ["a"]
        settings.windowID = "model"
        #expect(settings.usages(from: accounts) == [model])
    }

    @Test func customizedSettingsSurviveRelaunch() throws {
        var settings = UsageMenuBarSettings()
        settings.enabled = true
        settings.accountIDs = ["work", "home"]
        settings.windowID = "7d"
        settings.percentMode = .remaining
        settings.showReset = true
        #expect(try JSONDecoder().decode(UsageMenuBarSettings.self, from: JSONEncoder().encode(settings)) == settings)
    }

    @Test(arguments: ["", "work"]) func migratesSingleAccountPreferences(accountID: String) throws {
        let data = try JSONSerialization.data(withJSONObject: ["enabled": true, "accountID": accountID, "windowID": "5h", "percentMode": "remaining", "showReset": true])
        let settings = try JSONDecoder().decode(UsageMenuBarSettings.self, from: data)
        #expect(settings.accountIDs == (accountID.isEmpty ? [] : [accountID]))
        #expect(settings.enabled)
        #expect(settings.percentMode == .remaining)
        #expect(settings.showReset)
    }

    private func usage(_ provider: AIProvider, id: String, _ windows: [UsageWindow]) -> ProviderUsage {
        ProviderUsage(provider: provider, accountID: id, accountLabel: nil, plan: nil, windows: windows, asOf: now)
    }

    @Test func antigravityShowsItsFullestModelQuotaWhateverPeriodIsChosen() {
        var settings = UsageMenuBarSettings()
        settings.enabled = true
        let agy = usage(.antigravity, id: "antigravity:a@b.c", [
            UsageWindow(id: "Gemini 3.8 Flash +5", usedPercent: 18, resetsAt: nil),
            UsageWindow(id: "Claude Sonnet", usedPercent: 64, resetsAt: nil),
        ])
        #expect(settings.window(in: agy, now: now)?.id == "Claude Sonnet")
        #expect(settings.usages(from: [agy]).count == 1)
    }

    @Test func namedPeriodsStillMatchExactlyForClaudeAndCodex() {
        var settings = UsageMenuBarSettings()
        let claude = usage(.claude, id: "c", [UsageWindow(id: "5h", usedPercent: 10, resetsAt: nil), UsageWindow(id: "7d", usedPercent: 50, resetsAt: nil)])
        #expect(settings.window(in: claude, now: now)?.id == "5h")
        settings.windowID = "30d"
        #expect(settings.window(in: claude, now: now) == nil)      // no fallback to another period for these
        #expect(settings.usages(from: [claude]).isEmpty)
    }
}
