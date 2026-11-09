import Foundation

/// One reading of the machine, taken every few minutes in the background.
public struct MachineSample: Codable, Equatable, Sendable {
    public var at: Date
    public var cpu: Double          // 0...1
    public var memory: Double       // 0...1 used
    public var diskFree: Double     // bytes
    public var temperature: Double? // °C
    public init(at: Date, cpu: Double, memory: Double, diskFree: Double, temperature: Double? = nil) {
        self.at = at; self.cpu = cpu; self.memory = memory; self.diskFree = diskFree; self.temperature = temperature
    }
}

/// A week of readings, kept small: old ones fall off, and a chart asks for them averaged into a fixed number of buckets.
public struct MachineHistory: Codable, Equatable, Sendable {
    public static let keep: TimeInterval = 7 * 86_400
    public static let maxSamples = 2_500
    public private(set) var samples: [MachineSample] = []
    public init(samples: [MachineSample] = []) { self.samples = samples }

    public mutating func add(_ sample: MachineSample) {
        // A clock that went backwards must not scramble the order.
        if let last = samples.last, sample.at < last.at { samples.removeAll { $0.at >= sample.at } }
        samples.append(sample)
        let cutoff = sample.at.addingTimeInterval(-Self.keep)
        if let first = samples.firstIndex(where: { $0.at >= cutoff }), first > 0 { samples.removeFirst(first) }
        if samples.count > Self.maxSamples { samples.removeFirst(samples.count - Self.maxSamples) }
    }

    /// The last `span` seconds averaged into `buckets` equal slices, oldest first; a slice with no reading is nil.
    public func series(span: TimeInterval, buckets: Int, now: Date, _ value: (MachineSample) -> Double?) -> [Double?] {
        guard buckets > 0, span > 0 else { return [] }
        var sums = [Double](repeating: 0, count: buckets), counts = [Int](repeating: 0, count: buckets)
        let start = now.addingTimeInterval(-span)
        for s in samples where s.at >= start && s.at <= now {
            guard let v = value(s) else { continue }
            let i = min(Int(s.at.timeIntervalSince(start) / span * Double(buckets)), buckets - 1)
            sums[i] += v; counts[i] += 1
        }
        return (0..<buckets).map { counts[$0] == 0 ? nil : sums[$0] / Double(counts[$0]) }
    }
}

/// Decides which pieces of advice are worth a word from the pet: only things that need acting on, and not again for a while.
public struct MachineAlerts: Codable, Equatable, Sendable {
    private var lastSent: [String: Date] = [:]
    public init() {}

    private static func cooldown(_ area: Advice.Area) -> TimeInterval { area == .disk ? 24 * 3600 : 6 * 3600 }
    private static func key(_ area: Advice.Area) -> String { "\(area)" }

    public mutating func due(_ advice: [Advice], now: Date) -> [Advice] {
        var out: [Advice] = []
        for a in advice {
            let worthIt: Bool
            switch a.area {
            case .heat, .disk: worthIt = a.severity >= .warning
            case .memory: worthIt = a.severity == .critical
            case .cpu: worthIt = false                      // a busy CPU comes and goes; the page shows it
            }
            guard worthIt else { continue }
            if let last = lastSent[Self.key(a.area)], now.timeIntervalSince(last) < Self.cooldown(a.area) { continue }
            lastSent[Self.key(a.area)] = now
            out.append(a)
        }
        return out
    }
}
