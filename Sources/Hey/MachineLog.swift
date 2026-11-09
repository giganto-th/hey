import Darwin
import Foundation
import Observation
import HeyDomain

/// Every few minutes, in the background, writes down how busy and how warm the Mac is (a week of it, a few hundred KB at most), and
/// lets the pet say so when something needs acting on. One reading is a handful of system calls, so it costs next to nothing.
@MainActor @Observable
final class MachineLog {
    private(set) var history: MachineHistory
    @ObservationIgnored private var alerts = MachineAlerts()
    @ObservationIgnored private let url: URL
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var sensors: ThermalSensors?
    @ObservationIgnored private var lastTicks: (busy: UInt64, total: UInt64)?
    @ObservationIgnored var onAlert: ((Advice) -> Void)?
    @ObservationIgnored static let interval: TimeInterval = 300

    init(directory: URL) {
        url = directory.appendingPathComponent("machine-history.json")
        history = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder.iso.decode(MachineHistory.self, from: $0) } ?? MachineHistory()
    }

    func start() {
        guard timer == nil else { return }
        sensors = ThermalSensors()
        lastTicks = readTicks()                                       // the first reading only sets the baseline
        let t = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.sample() } }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in MainActor.assumeIsolated { self?.sample() } }
    }

    func sample(now: Date = Date()) {
        guard let cpu = cpuSinceLast() else { return }
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        let volume = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys)
        let free = Double(volume?.volumeAvailableCapacityForImportantUsage ?? 0)
        let total = Double(volume?.volumeTotalCapacity ?? 0)
        let temperature = sensors?.read()?.cpu
        let memory = Self.memoryUsedFraction()
        history.add(MachineSample(at: now, cpu: cpu, memory: memory, diskFree: free, temperature: temperature))
        save()

        var snapshot = MachineSnapshot()
        snapshot.cpu = cpu; snapshot.cpuAverage = cpu
        snapshot.memoryUsedFraction = memory
        snapshot.memoryPressure = Self.pressure()
        snapshot.diskFree = free; snapshot.diskTotal = total
        snapshot.cpuTemperature = temperature
        snapshot.thermal = ThermalLevel(rawValue: ProcessInfo.processInfo.thermalState.rawValue) ?? .nominal
        for advice in alerts.due(MachineAdvisor.advise(snapshot), now: now) { onAlert?(advice) }
    }

    private func save() {
        guard let data = try? JSONEncoder.iso.encode(history) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: readings

    private func readTicks() -> (busy: UInt64, total: UInt64)? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return nil }
        let user = UInt64(info.cpu_ticks.0), system = UInt64(info.cpu_ticks.1), idle = UInt64(info.cpu_ticks.2), nice = UInt64(info.cpu_ticks.3)
        return (user + system + nice, user + system + idle + nice)
    }

    private func cpuSinceLast() -> Double? {
        guard let now = readTicks() else { return nil }
        defer { lastTicks = now }
        guard let before = lastTicks, now.total > before.total else { return nil }
        return min(Double(now.busy &- before.busy) / Double(now.total - before.total), 1)
    }

    private static func memoryUsedFraction() -> Double {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let used = (Double(stats.active_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)) * Double(getpagesize())
        return min(used / Double(ProcessInfo.processInfo.physicalMemory), 1)
    }

    private static func pressure() -> MemoryPressure {
        var level = 0
        var size = MemoryLayout<Int>.size
        return sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 ? MemoryPressure(sysctl: level) : .normal
    }
}

private extension JSONEncoder {
    static var iso: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }
}
private extension JSONDecoder {
    static var iso: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
