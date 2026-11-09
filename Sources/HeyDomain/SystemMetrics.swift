import Foundation

/// The arithmetic behind the machine-stats page, kept free of system calls so it can be tested.

/// Cumulative CPU ticks of one core (or the whole machine) as the kernel reports them.
public struct CPUTicks: Equatable, Sendable {
    public var user: UInt64, system: UInt64, idle: UInt64, nice: UInt64
    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user; self.system = system; self.idle = idle; self.nice = nice
    }
    public var total: UInt64 { user &+ system &+ idle &+ nice }

    /// Fraction of the time between two readings that was spent busy (0...1). Counters that went backwards read as idle.
    public static func usage(from old: CPUTicks, to new: CPUTicks) -> Double {
        func delta(_ a: UInt64, _ b: UInt64) -> UInt64 { b >= a ? b - a : 0 }
        let busy = delta(old.user, new.user) + delta(old.system, new.system) + delta(old.nice, new.nice)
        let idle = delta(old.idle, new.idle)
        let all = busy + idle
        return all == 0 ? 0 : min(Double(busy) / Double(all), 1)
    }
}

/// Bytes per second from a counter that is read now and then. 32-bit interface counters wrap, so a drop is treated as a wrap, not a reset.
public enum RateMeter {
    public static func perSecond(old: UInt64, new: UInt64, seconds: Double, wrapAt: UInt64 = UInt64(UInt32.max) + 1) -> Double {
        guard seconds > 0 else { return 0 }
        let delta = new >= old ? new - old : (wrapAt > old ? wrapAt - old + new : 0)
        return Double(delta) / seconds
    }
}

/// The last N readings of one number, oldest first, for a small chart.
public struct History: Equatable, Sendable {
    public private(set) var values: [Double] = []
    public let capacity: Int
    public init(capacity: Int) { self.capacity = max(capacity, 1) }
    public mutating func add(_ value: Double) {
        values.append(value)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
    }
    public var latest: Double? { values.last }
    public var peak: Double { values.max() ?? 0 }
    public var average: Double { values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }
}

/// Plain-language size and speed text.
public enum ByteText {
    public static func size(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var v = max(bytes, 0), i = 0
        while v >= 1024, i < units.count - 1 { v /= 1024; i += 1 }
        return i == 0 ? "\(Int(v)) B" : String(format: v >= 100 ? "%.0f %@" : "%.1f %@", v, units[i])
    }
    public static func speed(_ bytesPerSecond: Double) -> String { size(bytesPerSecond) + "/s" }
}
