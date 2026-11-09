import Testing
@testable import HeyDomain

@Suite("SystemMetrics")
struct SystemMetricsTests {
    @Test func cpuUsageIsBusyShareOfTheInterval() {
        let a = CPUTicks(user: 100, system: 50, idle: 800, nice: 0)
        let b = CPUTicks(user: 160, system: 70, idle: 870, nice: 0)      // 60 + 20 busy, 70 idle
        let usage = CPUTicks.usage(from: a, to: b)
        #expect(abs(usage - 80.0 / 150.0) < 1e-9)
    }

    @Test func noTimePassedIsZeroNotNaN() {
        let a = CPUTicks(user: 1, system: 1, idle: 1, nice: 0)
        #expect(CPUTicks.usage(from: a, to: a) == 0)
    }

    @Test func backwardsCountersReadAsIdle() {
        let a = CPUTicks(user: 500, system: 500, idle: 500, nice: 0)
        let b = CPUTicks(user: 10, system: 10, idle: 600, nice: 0)
        #expect(CPUTicks.usage(from: a, to: b) == 0)
    }

    @Test func fullyBusyIsOne() {
        let a = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let b = CPUTicks(user: 90, system: 10, idle: 0, nice: 0)
        #expect(CPUTicks.usage(from: a, to: b) == 1)
    }

    @Test func rateIsBytesOverSeconds() {
        #expect(RateMeter.perSecond(old: 1_000, new: 5_000, seconds: 2) == 2_000)
        #expect(RateMeter.perSecond(old: 5, new: 5, seconds: 1) == 0)
        #expect(RateMeter.perSecond(old: 0, new: 100, seconds: 0) == 0)
    }

    @Test func aWrappedThirtyTwoBitCounterIsNotNegative() {
        let wrap = UInt64(UInt32.max) + 1
        let rate = RateMeter.perSecond(old: wrap - 100, new: 300, seconds: 1)
        #expect(rate == 400)
    }

    @Test func historyKeepsTheLatestReadings() {
        var h = History(capacity: 3)
        for v in [1.0, 2, 3, 4, 5] { h.add(v) }
        #expect(h.values == [3, 4, 5])
        #expect(h.latest == 5)
        #expect(h.peak == 5)
        #expect(h.average == 4)
    }

    @Test func emptyHistoryIsSafe() {
        let h = History(capacity: 5)
        #expect(h.latest == nil && h.peak == 0 && h.average == 0)
    }

    @Test func sizesReadNaturally() {
        #expect(ByteText.size(512) == "512 B")
        #expect(ByteText.size(1536) == "1.5 KB")
        #expect(ByteText.size(5 * 1_048_576) == "5.0 MB")
        #expect(ByteText.size(250 * 1_073_741_824) == "250 GB")
        #expect(ByteText.speed(2048) == "2.0 KB/s")
        #expect(ByteText.size(-5) == "0 B")
    }
}
