import Foundation
import Testing
@testable import HeyDomain

@Suite struct UsageResetsTests {
    private let now = Date(timeIntervalSince1970: 1_793_800_000)

    private func usage(_ windows: [UsageWindow], account: String = "a") -> ProviderUsage {
        ProviderUsage(provider: .claude, accountID: account, windows: windows, asOf: now)
    }

    @Test func nextIsTheEarliestUsedWindowAhead() {
        let u = usage([UsageWindow(id: "5h", usedPercent: 30, resetsAt: now + 600),
                       UsageWindow(id: "7d", usedPercent: 10, resetsAt: now + 90_000),
                       UsageWindow(id: "7d-opus", usedPercent: 50, resetsAt: now + 60)])
        #expect(UsageResets().next(in: [u], now: now) == now + 600)
    }

    @Test func unusedWindowsAreNotCelebrated() {
        let u = usage([UsageWindow(id: "5h", usedPercent: 0, resetsAt: now + 600)])
        var resets = UsageResets()
        #expect(resets.next(in: [u], now: now) == nil)
        #expect(resets.due(in: [u], now: now + 700).isEmpty)
    }

    @Test func eachResetFiresOnce() {
        let u = usage([UsageWindow(id: "5h", usedPercent: 30, resetsAt: now)])
        var resets = UsageResets()
        let first = resets.due(in: [u], now: now + 5)
        #expect(first == [UsageReset(provider: .claude, accountID: "a", windowID: "5h", at: now)])
        #expect(resets.due(in: [u], now: now + 10).isEmpty)
    }

    @Test func lateResetsPassQuietly() {
        let u = usage([UsageWindow(id: "7d", usedPercent: 30, resetsAt: now)])
        var resets = UsageResets()
        #expect(resets.due(in: [u], now: now + UsageResets.lateLimit + 1).isEmpty)
    }

    @Test func weeklyIsTold() {
        #expect(UsageReset(provider: .codex, accountID: "x", windowID: "7d", at: now).isWeekly)
        #expect(!UsageReset(provider: .codex, accountID: "x", windowID: "5h", at: now).isWeekly)
    }
}
