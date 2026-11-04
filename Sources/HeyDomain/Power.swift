import Foundation

public enum ThermalLevel: Int, Codable, Comparable, Sendable {
    case nominal = 0, fair, serious, critical
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// What the Mac is doing right now, as far as energy is concerned.
public struct PowerSignals: Equatable, Sendable {
    public var onAC = true
    public var isCharging = false
    public var batteryPercent: Int?
    public var lowPowerMode = false
    public var thermal: ThermalLevel = .nominal
    public var screenAsleep = false
    public var screenLocked = false
    public var fullscreenAppActive = false
    public var userHidPet = false
    public var userIdleSeconds = 0.0
    public init() {}
}

public struct PowerSettings: Codable, Equatable, Sendable {
    public var hideDuringFullscreen = true
    public var dormantAfterIdleMinutes = 10
    public var saverBelowBatteryPercent = 30
    /// Let the pet climb onto other apps' windows (needs polling the window list, so it is off in saver mode).
    public var walkOnWindows = true
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case hideDuringFullscreen, dormantAfterIdleMinutes, saverBelowBatteryPercent, walkOnWindows
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hideDuringFullscreen = try c.decodeIfPresent(Bool.self, forKey: .hideDuringFullscreen) ?? true
        dormantAfterIdleMinutes = try c.decodeIfPresent(Int.self, forKey: .dormantAfterIdleMinutes) ?? 10
        saverBelowBatteryPercent = try c.decodeIfPresent(Int.self, forKey: .saverBelowBatteryPercent) ?? 30
        walkOnWindows = try c.decodeIfPresent(Bool.self, forKey: .walkOnWindows) ?? true
    }
}

public enum PowerTier: Int, Comparable, Sendable, CustomStringConvertible {
    case dormant = 0, saver, balanced, full

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    public var label: String {
        switch self {
        case .full: "เต็มกำลัง"
        case .balanced: "สมดุล"
        case .saver: "ประหยัด"
        case .dormant: "พัก"
        }
    }
    public var description: String { label }

    /// Frames per second while the pet is moving, and while it just sits.
    public var fps: (active: Int, still: Int) {
        switch self {
        case .full: (24, 6)
        case .balanced: (18, 5)
        case .saver: (12, 3)
        case .dormant: (0, 0)
        }
    }

    public var rendersPet: Bool { self != .dormant }

    /// Window-top walking polls the window list, so only the fuller tiers do it.
    public var allowsPerching: Bool { self >= .balanced }
}

public struct PowerDecision: Equatable, Sendable {
    public var tier: PowerTier
    public var reason: String
    /// The pet window should disappear entirely (fullscreen app, hidden by the user).
    public var hidePet: Bool

    public init(tier: PowerTier, reason: String, hidePet: Bool) {
        self.tier = tier; self.reason = reason; self.hidePet = hidePet
    }
}

public enum PowerPolicy {
    public static func decide(_ s: PowerSignals, settings: PowerSettings = PowerSettings()) -> PowerDecision {
        if s.userHidPet { return .init(tier: .dormant, reason: "ซ่อนสัตว์เลี้ยงอยู่", hidePet: true) }
        if s.screenAsleep || s.screenLocked { return .init(tier: .dormant, reason: "หน้าจอดับ/ล็อก", hidePet: false) }
        if s.fullscreenAppActive && settings.hideDuringFullscreen {
            return .init(tier: .dormant, reason: "มีแอปเต็มจอ", hidePet: true)
        }
        if settings.dormantAfterIdleMinutes > 0, s.userIdleSeconds >= Double(settings.dormantAfterIdleMinutes) * 60 {
            return .init(tier: .dormant, reason: "ไม่ได้ใช้เครื่องนาน", hidePet: false)
        }
        if s.lowPowerMode { return .init(tier: .saver, reason: "Low Power Mode", hidePet: false) }
        if s.thermal >= .fair { return .init(tier: .saver, reason: "เครื่องร้อน", hidePet: false) }
        if !s.onAC, let pct = s.batteryPercent, pct <= settings.saverBelowBatteryPercent {
            return .init(tier: .saver, reason: "แบตเหลือ \(pct)%", hidePet: false)
        }
        if !s.onAC { return .init(tier: .balanced, reason: "ใช้แบตเตอรี่", hidePet: false) }
        return .init(tier: .full, reason: "เสียบปลั๊ก", hidePet: false)
    }
}

/// A flat top edge a pet can stand on (normally the title bar of another app's window).
public struct Surface: Equatable, Sendable, Identifiable {
    public var id: Int
    public var minX: Double
    public var maxX: Double
    /// y of the top edge, bottom-left origin (like NSScreen coordinates).
    public var top: Double

    public init(id: Int, minX: Double, maxX: Double, top: Double) {
        self.id = id; self.minX = minX; self.maxX = maxX; self.top = top
    }

    public var width: Double { maxX - minX }
    public func contains(x: Double, margin: Double = 0) -> Bool { x >= minX + margin && x <= maxX - margin }
}

public enum Perches {
    /// The highest surface the pet passes through while dropping from `fromY` to `toY`, if any.
    public static func landing(fromY: Double, toY: Double, centerX: Double, surfaces: [Surface], margin: Double = 16) -> Surface? {
        guard toY <= fromY else { return nil }
        return surfaces
            .filter { $0.contains(x: centerX, margin: margin) && $0.top <= fromY + 0.5 && $0.top >= toY - 0.5 }
            .max { $0.top < $1.top }
    }

    /// A window top close enough to hop up to: a bit above the pet and within reach sideways.
    public static func climbTarget(
        centerX: Double, bottomY: Double, surfaces: [Surface],
        maxRise: Double = 500, maxReach: Double = 450, minWidth: Double = 220, rng: inout any RandomSource
    ) -> Surface? {
        let options = surfaces.filter { s in
            let rise = s.top - bottomY
            let reach = centerX < s.minX ? s.minX - centerX : (centerX > s.maxX ? centerX - s.maxX : 0)
            return s.width >= minWidth && rise >= 24 && rise <= maxRise && reach <= maxReach
        }
        guard !options.isEmpty else { return nil }
        let i = min(Int(rng.next(in: 0...Double(options.count))), options.count - 1)
        return options[i]
    }

    /// Keeps `x` (the pet's centre) inside the surface, `margin` from either end.
    public static func clamp(centerX x: Double, to s: Surface, margin: Double = 20) -> Double {
        min(max(x, s.minX + margin), max(s.maxX - margin, s.minX + margin))
    }
}
