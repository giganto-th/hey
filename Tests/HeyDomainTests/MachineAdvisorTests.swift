import Testing
@testable import HeyDomain

@Suite("MachineAdvisor")
struct MachineAdvisorTests {
    private func healthy() -> MachineSnapshot {
        var s = MachineSnapshot()
        s.cpuAverage = 0.2; s.memoryUsedFraction = 0.5
        s.diskFree = 200 * MachineAdvisor.gigabyte; s.diskTotal = 500 * MachineAdvisor.gigabyte
        s.cpuTemperature = 45
        return s
    }

    @Test func aHealthyMachineSaysSo() {
        #expect(MachineAdvisor.advise(healthy()).map(\.kind) == [.allGood])
    }

    @Test func sustainedCPUNamesTheBusyProcessOnlyWhenOneStandsOut() {
        var s = healthy(); s.cpuAverage = 0.9; s.topCPUName = "Xcode"; s.topCPUPercent = 300
        #expect(MachineAdvisor.advise(s).first?.kind == .cpuBusy(process: "Xcode", percent: 300))
        s.topCPUPercent = 30
        #expect(MachineAdvisor.advise(s).first?.kind == .cpuBusy(process: nil, percent: 30))
    }

    @Test func aBriefSpikeIsNotAdvice() {
        var s = healthy(); s.cpu = 1.0; s.cpuAverage = 0.4
        #expect(MachineAdvisor.advise(s).map(\.kind) == [.allGood])
    }

    @Test func memoryPressureOutranksSwap() {
        var s = healthy(); s.memoryPressure = .critical; s.swapUsed = 8 * MachineAdvisor.gigabyte
        let advice = MachineAdvisor.advise(s)
        #expect(advice.count == 1)
        #expect(advice.first?.severity == .critical)
    }

    @Test func swapAloneIsOnlyInformation() {
        var s = healthy(); s.swapUsed = 6 * MachineAdvisor.gigabyte
        #expect(MachineAdvisor.advise(s).first?.severity == .info)
    }

    @Test func diskThresholdsUseBytesOrShareWhicheverIsWorse() {
        var s = healthy(); s.diskFree = 40 * MachineAdvisor.gigabyte     // 8 % of 500 GB
        #expect(MachineAdvisor.advise(s).first?.severity == .warning)
        s.diskFree = 8 * MachineAdvisor.gigabyte
        #expect(MachineAdvisor.advise(s).first?.severity == .critical)
        s.diskTotal = 4_000 * MachineAdvisor.gigabyte; s.diskFree = 150 * MachineAdvisor.gigabyte     // 3.75 % of a big disk
        #expect(MachineAdvisor.advise(s).first?.severity == .critical)
    }

    @Test func heatUsesTheTemperatureWhenKnownAndTheSystemLevelOtherwise() {
        var s = healthy(); s.cpuTemperature = 90
        #expect(MachineAdvisor.advise(s).first?.kind == .hot(celsius: 90))
        s.cpuTemperature = nil; s.thermal = .serious
        #expect(MachineAdvisor.advise(s).first?.kind == .throttled)
    }

    @Test func mostUrgentComesFirst() {
        var s = healthy(); s.swapUsed = 6 * MachineAdvisor.gigabyte; s.cpuTemperature = 97
        #expect(MachineAdvisor.advise(s).first?.severity == .critical)
    }

    @Test func pressureLevelsMapFromSysctl() {
        #expect(MemoryPressure(sysctl: 1) == .normal)
        #expect(MemoryPressure(sysctl: 2) == .warning)
        #expect(MemoryPressure(sysctl: 4) == .critical)
    }
}
