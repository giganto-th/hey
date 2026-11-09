import Foundation

/// What the machine page knows at one moment. The advisor reads only this, so its rules can be tested without touching the system.
public struct MachineSnapshot: Equatable, Sendable {
    public var cpu = 0.0                    // 0...1, now
    public var cpuAverage = 0.0             // 0...1, over the last minute
    public var topCPUName: String?
    public var topCPUPercent = 0.0          // percent of one core
    public var memoryUsedFraction = 0.0     // 0...1
    public var memoryPressure = MemoryPressure.normal
    public var swapUsed = 0.0               // bytes
    public var topMemoryName: String?
    public var topMemoryBytes = 0.0
    public var diskFree = 0.0               // bytes
    public var diskTotal = 0.0
    public var reclaimable = 0.0            // bytes a scan found that can be cleared, 0 when not scanned
    public var cpuTemperature: Double?      // °C, nil when this Mac does not tell
    public var thermal = ThermalLevel.nominal
    public init() {}
}

public enum MemoryPressure: Int, Comparable, Sendable {
    case normal = 0, warning, critical
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    /// From `kern.memorystatus_vm_pressure_level` (1 normal, 2 warning, 4 critical).
    public init(sysctl level: Int) { self = level >= 4 ? .critical : level >= 2 ? .warning : .normal }
}

public struct Advice: Equatable, Identifiable, Sendable {
    public enum Area: Sendable { case cpu, memory, disk, heat }
    public enum Severity: Int, Comparable, Sendable {
        case info = 0, warning, critical
        public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    }
    public enum Kind: Equatable, Sendable {
        case cpuBusy(process: String?, percent: Double)
        case memoryPressure(process: String?, bytes: Double)
        case swapHeavy(bytes: Double)
        case diskLow(free: Double, reclaimable: Double)
        case hot(celsius: Double)
        case throttled
        case allGood
    }
    public let area: Area
    public let severity: Severity
    public let kind: Kind
    public var id: String { "\(area)-\(kind)" }
}

/// Turns the numbers into a short list of things worth doing, most urgent first.
public enum MachineAdvisor {
    public static let gigabyte = 1_073_741_824.0

    public static func advise(_ s: MachineSnapshot) -> [Advice] {
        var out: [Advice] = []

        if s.cpuAverage >= 0.85 {
            let culprit = s.topCPUPercent >= 50 ? s.topCPUName : nil
            out.append(Advice(area: .cpu, severity: s.cpuAverage >= 0.95 ? .critical : .warning,
                              kind: .cpuBusy(process: culprit, percent: s.topCPUPercent)))
        }

        if s.memoryPressure >= .warning || s.memoryUsedFraction >= 0.92 {
            let culprit = s.topMemoryBytes >= gigabyte ? s.topMemoryName : nil
            out.append(Advice(area: .memory, severity: s.memoryPressure == .critical ? .critical : .warning,
                              kind: .memoryPressure(process: culprit, bytes: s.topMemoryBytes)))
        } else if s.swapUsed >= 4 * gigabyte {
            out.append(Advice(area: .memory, severity: .info, kind: .swapHeavy(bytes: s.swapUsed)))
        }

        if s.diskTotal > 0 {
            let fraction = s.diskFree / s.diskTotal
            if s.diskFree < 10 * gigabyte || fraction < 0.05 {
                out.append(Advice(area: .disk, severity: .critical, kind: .diskLow(free: s.diskFree, reclaimable: s.reclaimable)))
            } else if s.diskFree < 25 * gigabyte || fraction < 0.10 {
                out.append(Advice(area: .disk, severity: .warning, kind: .diskLow(free: s.diskFree, reclaimable: s.reclaimable)))
            }
        }

        if let t = s.cpuTemperature, t >= 85 {
            out.append(Advice(area: .heat, severity: t >= 95 ? .critical : .warning, kind: .hot(celsius: t)))
        } else if s.thermal >= .serious {
            out.append(Advice(area: .heat, severity: s.thermal == .critical ? .critical : .warning, kind: .throttled))
        }

        if out.isEmpty { return [Advice(area: .cpu, severity: .info, kind: .allGood)] }
        return out.sorted { $0.severity > $1.severity }
    }
}
