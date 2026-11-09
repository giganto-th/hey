import Darwin
import Foundation
import Observation
import HeyDomain

/// Reads how this Mac is doing (CPU, memory, disk, network, the biggest processes) and what Hey! itself costs.
/// It samples only while the machine page is open, so it costs nothing the rest of the time.
@MainActor @Observable
final class SystemStats {
    struct ProcessRow: Identifiable, Equatable {
        let pid: Int32
        let name: String
        let cpu: Double          // percent of one core, as ps reports it
        let memory: Double       // bytes resident
        var id: Int32 { pid }
    }

    // machine
    let chip: String
    let model: String
    let physicalCores: Int
    let logicalCores: Int
    let totalMemory: Double
    let osVersion: String

    // live
    private(set) var cpu = 0.0
    private(set) var cores: [Double] = []
    private(set) var cpuHistory = History(capacity: 60)
    private(set) var memoryUsed = 0.0
    private(set) var memoryWired = 0.0
    private(set) var memoryCompressed = 0.0
    private(set) var memoryCached = 0.0
    private(set) var swapUsed = 0.0
    private(set) var swapTotal = 0.0
    private(set) var memoryHistory = History(capacity: 60)
    private(set) var diskFree = 0.0
    private(set) var diskTotal = 0.0
    private(set) var netIn = 0.0
    private(set) var netOut = 0.0
    private(set) var netInHistory = History(capacity: 60)
    private(set) var netOutHistory = History(capacity: 60)
    private(set) var heyCPU = 0.0
    private(set) var heyMemory = 0.0
    private(set) var topByCPU: [ProcessRow] = []
    private(set) var topByMemory: [ProcessRow] = []
    private(set) var uptime: TimeInterval = 0

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastCores: [CPUTicks] = []
    @ObservationIgnored private var lastNet: [String: (inBytes: UInt64, outBytes: UInt64)] = [:]
    @ObservationIgnored private var lastSample: Date?
    @ObservationIgnored private var lastRusage: (cpuSeconds: Double, at: Date)?
    @ObservationIgnored private var tick = 0
    @ObservationIgnored private var psRunning = false

    init() {
        chip = Self.sysctlString("machdep.cpu.brand_string") ?? "Apple silicon"
        model = Self.sysctlString("hw.model") ?? ""
        physicalCores = Int(Self.sysctlInt("hw.physicalcpu") ?? 0)
        logicalCores = Int(Self.sysctlInt("hw.logicalcpu") ?? 0)
        totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    }

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        sample()
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.sample() } }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate(); timer = nil
        lastCores = []; lastNet = [:]; lastSample = nil; lastRusage = nil     // the next start measures from scratch
    }

    // MARK: sampling

    private func sample() {
        let now = Date()
        let seconds = lastSample.map { now.timeIntervalSince($0) } ?? 0
        sampleCPU()
        sampleMemory()
        sampleDisk()
        sampleNetwork(seconds: seconds)
        sampleSelf(now: now)
        uptime = ProcessInfo.processInfo.systemUptime
        lastSample = now
        tick += 1
        if tick % 3 == 1 { refreshProcesses() }          // ps is a whole process to launch, so not every time
    }

    private func sampleCPU() {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS, let info else { return }
        defer { vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)) }
        var now: [CPUTicks] = []
        for i in 0..<Int(count) {
            let base = i * Int(CPU_STATE_MAX)
            now.append(CPUTicks(user: UInt64(info[base + Int(CPU_STATE_USER)]), system: UInt64(info[base + Int(CPU_STATE_SYSTEM)]),
                                idle: UInt64(info[base + Int(CPU_STATE_IDLE)]), nice: UInt64(info[base + Int(CPU_STATE_NICE)])))
        }
        if lastCores.count == now.count {
            cores = zip(lastCores, now).map { CPUTicks.usage(from: $0, to: $1) }
            let totalOld = lastCores.reduce(CPUTicks(user: 0, system: 0, idle: 0, nice: 0)) { CPUTicks(user: $0.user &+ $1.user, system: $0.system &+ $1.system, idle: $0.idle &+ $1.idle, nice: $0.nice &+ $1.nice) }
            let totalNew = now.reduce(CPUTicks(user: 0, system: 0, idle: 0, nice: 0)) { CPUTicks(user: $0.user &+ $1.user, system: $0.system &+ $1.system, idle: $0.idle &+ $1.idle, nice: $0.nice &+ $1.nice) }
            cpu = CPUTicks.usage(from: totalOld, to: totalNew)
            cpuHistory.add(cpu)
        }
        lastCores = now
    }

    private func sampleMemory() {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return }
        let page = Double(getpagesize())
        memoryWired = Double(stats.wire_count) * page
        memoryCompressed = Double(stats.compressor_page_count) * page
        memoryCached = Double(stats.inactive_count + stats.speculative_count) * page
        memoryUsed = (Double(stats.active_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)) * page
        memoryHistory.add(totalMemory > 0 ? min(memoryUsed / totalMemory, 1) : 0)
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 { swapUsed = Double(swap.xsu_used); swapTotal = Double(swap.xsu_total) }
    }

    private func sampleDisk() {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys) else { return }
        diskTotal = Double(v.volumeTotalCapacity ?? 0)
        diskFree = Double(v.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    private func sampleNetwork(seconds: Double) {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return }
        defer { freeifaddrs(head) }
        var current: [String: (inBytes: UInt64, outBytes: UInt64)] = [:]
        var p: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = p {
            defer { p = ifa.pointee.ifa_next }
            guard let addr = ifa.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK), let data = ifa.pointee.ifa_data else { continue }
            let flags = Int32(ifa.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            let d = data.assumingMemoryBound(to: if_data.self).pointee
            current[String(cString: ifa.pointee.ifa_name)] = (UInt64(d.ifi_ibytes), UInt64(d.ifi_obytes))
        }
        if seconds > 0 {
            var inRate = 0.0, outRate = 0.0
            for (name, now) in current {
                guard let before = lastNet[name] else { continue }
                inRate += RateMeter.perSecond(old: before.inBytes, new: now.inBytes, seconds: seconds)
                outRate += RateMeter.perSecond(old: before.outBytes, new: now.outBytes, seconds: seconds)
            }
            netIn = inRate; netOut = outRate
            netInHistory.add(inRate); netOutHistory.add(outRate)
        }
        lastNet = current
    }

    private func sampleSelf(now: Date) {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let ok = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        if ok == KERN_SUCCESS { heyMemory = Double(info.phys_footprint) }
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        func seconds(_ t: timeval) -> Double { Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000 }
        let cpuSeconds = seconds(usage.ru_utime) + seconds(usage.ru_stime)
        if let last = lastRusage, now.timeIntervalSince(last.at) > 0 {
            heyCPU = max(cpuSeconds - last.cpuSeconds, 0) / now.timeIntervalSince(last.at) * 100
        }
        lastRusage = (cpuSeconds, now)
    }

    // MARK: processes

    private func refreshProcesses() {
        guard !psRunning else { return }
        psRunning = true
        Task.detached(priority: .utility) {
            let rows = Self.runPS()
            await MainActor.run {
                self.psRunning = false
                guard !rows.isEmpty else { return }
                self.topByCPU = Array(rows.sorted { $0.cpu > $1.cpu }.prefix(6))
                self.topByMemory = Array(rows.sorted { $0.memory > $1.memory }.prefix(6))
            }
        }
    }

    nonisolated private static func runPS() -> [ProcessRow] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-Ao", "pid=,pcpu=,rss=,comm="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4, let pid = Int32(parts[0]), let cpu = Double(parts[1]), let rss = Double(parts[2]) else { return nil }
            let name = String(parts[3]).split(separator: "/").last.map(String.init) ?? String(parts[3])
            return ProcessRow(pid: pid, name: name, cpu: cpu, memory: rss * 1024)
        }
    }

    // MARK: sysctl

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    private static func sysctlInt(_ name: String) -> Int64? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}
