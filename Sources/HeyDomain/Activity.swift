import CoreGraphics
import Foundation

/// What the Mac looked like at one moment. Only counts and levels: never which keys were pressed.
public struct ActivitySample: Sendable {
    public var time: Date
    /// Total key-down events so far in this login session (a counter that only goes up).
    public var keyCount: UInt32
    public var idleSeconds: Double
    public var batteryPercent: Int?
    public var onAC: Bool
    public var charging: Bool
    public var thermal: ThermalLevel
    public var screenLocked: Bool

    public init(time: Date, keyCount: UInt32 = 0, idleSeconds: Double = 0, batteryPercent: Int? = nil,
                onAC: Bool = true, charging: Bool = false, thermal: ThermalLevel = .nominal, screenLocked: Bool = false) {
        self.time = time; self.keyCount = keyCount; self.idleSeconds = idleSeconds
        self.batteryPercent = batteryPercent; self.onAC = onAC; self.charging = charging
        self.thermal = thermal; self.screenLocked = screenLocked
    }
}

/// A mood the pet keeps showing for as long as it lasts.
public enum AmbientMotion: Equatable, Sendable {
    case none, typingSlow, typingFast, lowBattery, criticalBattery, hot, dozing

    /// The pet stays put instead of wandering off while you type or while it's worried.
    public var keepsPetStill: Bool {
        switch self {
        case .typingSlow, .typingFast, .criticalBattery, .dozing: true
        case .none, .lowBattery, .hot: false
        }
    }
}

/// A one-off event worth a reaction and a line of speech.
public enum Reaction: Equatable, Sendable {
    case lowBattery(percent: Int)
    case criticalBattery(percent: Int)
    case pluggedIn
    case unplugged(percent: Int)
    case fullyCharged
    case overheating
    case fastTypist
    case dozeOff
    case wakeUp
}

public struct ReactionSettings: Codable, Equatable, Sendable {
    public var enabled = true
    public var typing = true
    public var battery = true
    public var curious = true
    public init() {}

    private enum CodingKeys: String, CodingKey { case enabled, typing, battery, curious }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        typing = try c.decodeIfPresent(Bool.self, forKey: .typing) ?? true
        battery = try c.decodeIfPresent(Bool.self, forKey: .battery) ?? true
        curious = try c.decodeIfPresent(Bool.self, forKey: .curious) ?? true
    }
}

/// Turns a stream of `ActivitySample`s into a current mood plus one-off reactions, with hysteresis
/// so a battery hovering around 20% or a pause between words doesn't make the pet flicker.
public struct ActivityReactor: Sendable {
    public var lowBatteryAt = 20
    public var criticalBatteryAt = 10
    public var slowTypingKeysPerSecond = 0.7
    public var fastTypingKeysPerSecond = 4.0
    /// How long after the last key the pet still counts you as "typing".
    public var typingHold: TimeInterval = 2.5
    public var dozeAfter: TimeInterval = 180
    public var fastTypistSustained: TimeInterval = 12
    public var fastTypistCooldown: TimeInterval = 30 * 60
    public var overheatCooldown: TimeInterval = 10 * 60

    private var last: ActivitySample?
    private var lastTyping: Date?
    private var typingFast = false
    private var fastSince: Date?
    private var lastFastTypistCue: Date?
    private var lastOverheatCue: Date?
    private var warnedLow = false
    private var warnedCritical = false
    private var announcedFull = false
    private var dozing = false

    public private(set) var ambient: AmbientMotion = .none
    /// Keys per second seen over the most recent step.
    public private(set) var keyRate = 0.0

    public init() {}

    public mutating func update(_ s: ActivitySample, settings: ReactionSettings = ReactionSettings()) -> [Reaction] {
        defer { last = s }
        guard settings.enabled, !s.screenLocked else { ambient = .none; return [] }
        var reactions: [Reaction] = []

        // typing: keys per second from the counter. UInt32 wraps around, so subtract with wrapping.
        if let prev = last {
            let dt = s.time.timeIntervalSince(prev.time)
            if dt > 0 {
                let delta = Double(s.keyCount &- prev.keyCount)
                keyRate = delta > 100_000 ? 0 : delta / dt          // a huge jump means the counter reset
                if keyRate >= slowTypingKeysPerSecond { lastTyping = s.time }
                typingFast = keyRate >= fastTypingKeysPerSecond
            }
        }
        let typing = settings.typing && (lastTyping.map { s.time.timeIntervalSince($0) <= typingHold } ?? false)

        if settings.typing, typing, typingFast {
            if fastSince == nil { fastSince = s.time }
            if let since = fastSince, s.time.timeIntervalSince(since) >= fastTypistSustained,
               lastFastTypistCue.map({ s.time.timeIntervalSince($0) >= fastTypistCooldown }) ?? true {
                lastFastTypistCue = s.time
                reactions.append(.fastTypist)
            }
        } else if !typing {
            fastSince = nil
        }

        // dozing: no input for a while, then back
        if s.idleSeconds >= dozeAfter, !dozing {
            dozing = true
            reactions.append(.dozeOff)
        } else if dozing, s.idleSeconds < 5 {
            dozing = false
            reactions.append(.wakeUp)
        }

        // battery
        if settings.battery, let pct = s.batteryPercent, let prev = last {
            if s.onAC {
                if !prev.onAC { reactions.append(.pluggedIn); announcedFull = false }
                warnedLow = false; warnedCritical = false
                if pct >= 100, !announcedFull {
                    announcedFull = true
                    // only when it *reaches* full; an app launched at 100% shouldn't announce it every time
                    if (prev.batteryPercent ?? 100) < 100 { reactions.append(.fullyCharged) }
                }
            } else {
                announcedFull = false
                if prev.onAC { reactions.append(.unplugged(percent: pct)) }
                if pct <= criticalBatteryAt, !warnedCritical {
                    warnedCritical = true; warnedLow = true
                    reactions.append(.criticalBattery(percent: pct))
                } else if pct <= lowBatteryAt, !warnedLow {
                    warnedLow = true
                    reactions.append(.lowBattery(percent: pct))
                }
                // charge level recovered (e.g. plugged then unplugged); allow a fresh warning
                if pct > lowBatteryAt + 5 { warnedLow = false; warnedCritical = false }
            }
        }

        // heat
        if s.thermal >= .serious,
           lastOverheatCue.map({ s.time.timeIntervalSince($0) >= overheatCooldown }) ?? true {
            lastOverheatCue = s.time
            reactions.append(.overheating)
        }

        // mood to show, most pressing first
        if settings.battery, !s.onAC, let pct = s.batteryPercent, pct <= criticalBatteryAt {
            ambient = .criticalBattery
        } else if s.thermal >= .serious {
            ambient = .hot
        } else if settings.battery, !s.onAC, let pct = s.batteryPercent, pct <= lowBatteryAt {
            ambient = .lowBattery
        } else if typing {
            ambient = typingFast ? .typingFast : .typingSlow
        } else if dozing {
            ambient = .dozing
        } else {
            ambient = .none
        }
        return reactions
    }
}

public enum Gaze {
    /// Which way the pet should face to look at the pointer, or nil when it is too far (or right above) to bother.
    public static func facingRight(pointerX: Double, petCenterX: Double, pointerDistance: Double, near: Double = 280) -> Bool? {
        guard pointerDistance <= near, abs(pointerX - petCenterX) >= 24 else { return nil }
        return pointerX > petCenterX
    }
}
