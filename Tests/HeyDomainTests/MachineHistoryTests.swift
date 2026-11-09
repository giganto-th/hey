import Foundation
import Testing
@testable import HeyDomain

@Suite("MachineHistory")
struct MachineHistoryTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func sample(_ offset: TimeInterval, cpu: Double = 0.5, temp: Double? = nil) -> MachineSample {
        MachineSample(at: t0.addingTimeInterval(offset), cpu: cpu, memory: 0.5, diskFree: 1e11, temperature: temp)
    }

    @Test func oldReadingsFallOff() {
        var h = MachineHistory()
        h.add(sample(0)); h.add(sample(3600))
        h.add(sample(8 * 86_400))
        #expect(h.samples.count == 1)
    }

    @Test func sizeIsCapped() {
        var h = MachineHistory()
        for i in 0..<(MachineHistory.maxSamples + 50) { h.add(sample(Double(i) * 10)) }
        #expect(h.samples.count == MachineHistory.maxSamples)
    }

    @Test func aClockGoingBackwardsKeepsOrder() {
        var h = MachineHistory()
        h.add(sample(100)); h.add(sample(200)); h.add(sample(150))
        #expect(h.samples.map(\.at) == h.samples.map(\.at).sorted())
    }

    @Test func seriesAveragesIntoBucketsAndLeavesGapsNil() {
        var h = MachineHistory()
        h.add(sample(-3500, cpu: 0.2)); h.add(sample(-3400, cpu: 0.4))     // first half of the hour
        let s = h.series(span: 3600, buckets: 2, now: t0) { $0.cpu }
        #expect(s.count == 2)
        #expect(abs((s[0] ?? -1) - 0.3) < 1e-9)
        #expect(s[1] == nil)
    }

    @Test func missingTemperatureIsSkippedNotZero() {
        var h = MachineHistory()
        h.add(sample(-100, temp: nil))
        #expect(h.series(span: 3600, buckets: 1, now: t0) { $0.temperature } == [nil])
    }

    private func advice(_ area: Advice.Area, _ severity: Advice.Severity) -> Advice {
        Advice(area: area, severity: severity, kind: .throttled)
    }

    @Test func alertsSpeakOnlyForThingsToActOn() {
        var alerts = MachineAlerts()
        let due = alerts.due([advice(.cpu, .critical), advice(.memory, .warning), advice(.disk, .info), advice(.heat, .warning)], now: t0)
        #expect(due.map(\.area) == [.heat])
    }

    @Test func alertsWaitBeforeRepeating() {
        var alerts = MachineAlerts()
        #expect(alerts.due([advice(.heat, .critical)], now: t0).count == 1)
        #expect(alerts.due([advice(.heat, .critical)], now: t0.addingTimeInterval(3600)).isEmpty)
        #expect(alerts.due([advice(.heat, .critical)], now: t0.addingTimeInterval(7 * 3600)).count == 1)
    }

    @Test func diskWaitsADay() {
        var alerts = MachineAlerts()
        _ = alerts.due([advice(.disk, .critical)], now: t0)
        #expect(alerts.due([advice(.disk, .critical)], now: t0.addingTimeInterval(10 * 3600)).isEmpty)
        #expect(alerts.due([advice(.disk, .critical)], now: t0.addingTimeInterval(25 * 3600)).count == 1)
    }
}
