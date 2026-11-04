import Testing
import Foundation
@testable import HeyDomain

struct AppFocusTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func classifiesByBundleID() {
        #expect(AppCategory.classify(bundleID: "com.apple.dt.Xcode") == .coding)
        #expect(AppCategory.classify(bundleID: "com.valvesoftware.steam") == .gaming)
        #expect(AppCategory.classify(bundleID: "jp.naver.line") == .chatting)
        #expect(AppCategory.classify(bundleID: "com.example.unknown") == .other)
    }

    @Test func codingStreakFiresOnceAfterLongStay() {
        var e = AppFocusEngine()
        #expect(e.tick(now: t0, frontBundleID: "com.apple.dt.Xcode", idleSeconds: 0) == nil)
        #expect(e.tick(now: t0.addingTimeInterval(39 * 60), frontBundleID: "com.apple.dt.Xcode", idleSeconds: 0) == nil)
        #expect(e.tick(now: t0.addingTimeInterval(41 * 60), frontBundleID: "com.apple.dt.Xcode", idleSeconds: 0) == .codingStreak)
        #expect(e.tick(now: t0.addingTimeInterval(90 * 60), frontBundleID: "com.apple.dt.Xcode", idleSeconds: 0) == nil)
    }

    @Test func switchingAppsRestartsTheStay() {
        var e = AppFocusEngine()
        _ = e.tick(now: t0, frontBundleID: "com.apple.dt.Xcode", idleSeconds: 0)
        _ = e.tick(now: t0.addingTimeInterval(30 * 60), frontBundleID: "com.example.other", idleSeconds: 0)
        #expect(e.tick(now: t0.addingTimeInterval(45 * 60), frontBundleID: "com.apple.dt.Xcode", idleSeconds: 0) == nil)
    }

    @Test func cooldownBlocksBackToBackCues() {
        var e = AppFocusEngine()
        _ = e.tick(now: t0, frontBundleID: "com.apple.dt.Xcode", idleSeconds: 0)
        #expect(e.tick(now: t0.addingTimeInterval(41 * 60), frontBundleID: "com.apple.dt.Xcode", idleSeconds: 0) == .codingStreak)
        _ = e.tick(now: t0.addingTimeInterval(42 * 60), frontBundleID: "com.valvesoftware.steam", idleSeconds: 0)
        #expect(e.tick(now: t0.addingTimeInterval(90 * 60), frontBundleID: "com.valvesoftware.steam", idleSeconds: 0) == nil)
    }

    @Test func longIdleResetsTheStay() {
        var e = AppFocusEngine()
        _ = e.tick(now: t0, frontBundleID: "com.apple.dt.Xcode", idleSeconds: 0)
        _ = e.tick(now: t0.addingTimeInterval(20 * 60), frontBundleID: "com.apple.dt.Xcode", idleSeconds: 600)
        #expect(e.tick(now: t0.addingTimeInterval(45 * 60), frontBundleID: "com.apple.dt.Xcode", idleSeconds: 0) == nil)
    }
}
