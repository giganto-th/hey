import Foundation

public enum PetStage: String, Codable, CaseIterable, Sendable {
    case egg, hatchling, child, teen, adult

    public var next: PetStage? {
        switch self {
        case .egg: .hatchling
        case .hatchling: .child
        case .child: .teen
        case .teen: .adult
        case .adult: nil
        }
    }

    /// Sprite scale relative to the base frame.
    public var scale: Double {
        switch self {
        case .egg: 0.6
        case .hatchling: 0.6
        case .child: 0.75
        case .teen: 0.9
        case .adult: 1.1
        }
    }

    public var displayName: String {
        switch self {
        case .egg: tr("ไข่")
        case .hatchling: tr("ลูกน้อย")
        case .child: tr("เด็ก")
        case .teen: tr("วัยรุ่น")
        case .adult: tr("โตเต็มวัย")
        }
    }
}

public struct Food: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// Name of the picture (`Resources/Icons/food_<icon>.png`).
    public var icon: String
    public var hunger: Double
    public var mood: Double
    public var xp: Double
    public var cooldown: TimeInterval
    /// 0 = free and unlimited; otherwise one unit must be bought and is used up.
    public var price: Int
}

public struct Balance: Sendable {
    public var hungerDecayPerHour = 4.0
    public var moodDecayPerHour = 2.0
    public var hungryExtraMoodDecay = 2.0
    public var energyDecayPerHour = 3.0
    public var energyRestPerHour = 10.0
    public var offlineCapHours = 8.0
    /// A gap longer than this between ticks means the app was not running.
    public var offlineGap: TimeInterval = 600

    public var hatchNeeded = 100.0
    public var warmPerMinute = 1.0
    public var warmDailyCap = 60.0
    public var clickWarm = 2.0
    public var clickWarmDailyCap = 10.0

    public var dailyCheckInXP = 5.0

    // Neglect: time spent with a stat at zero. It builds up, eases off twice as fast once everything is above zero again,
    // and the pet dies when it reaches `deathAfterNeglectHours`. Closed-app gaps count for at most `offlineCapHours`.
    public var warnAfterNeglectHours = 3.0
    public var dangerAfterNeglectHours = 8.0
    public var deathAfterNeglectHours = 12.0
    public var neglectRecoveryFactor = 2.0
    public var petBondDailyCap = 20.0

    /// XP needed to leave a stage.
    public func xpToLeave(_ stage: PetStage) -> Double? {
        switch stage {
        case .egg: nil
        case .hatchling: 150
        case .child: 400
        case .teen: 1000
        case .adult: nil
        }
    }

    public var foods: [Food] = [
        Food(id: "rice", name: tr("ข้าวปั้น"), icon: "rice", hunger: 20, mood: 0, xp: 2, cooldown: 600, price: 0),
        Food(id: "cookie", name: tr("คุกกี้"), icon: "cookie", hunger: 10, mood: 15, xp: 3, cooldown: 1200, price: 8),
        Food(id: "fruit", name: tr("ผลไม้"), icon: "fruit", hunger: 30, mood: 20, xp: 8, cooldown: 1800, price: 15),
        Food(id: "honey", name: tr("น้ำผึ้งทอง"), icon: "honey", hunger: 40, mood: 30, xp: 15, cooldown: 3600, price: 40),
    ]

    public static let standard = Balance()
}

/// The three needs that can run out.
public enum PetNeed: String, Codable, CaseIterable, Sendable {
    case hunger, mood, energy

    public var label: String {
        switch self {
        case .hunger: tr("หิว")
        case .mood: tr("เศร้า")
        case .energy: tr("หมดแรง")
        }
    }
}

/// A pet that has died, kept so the player can look back.
public struct PetMemorial: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var name: String
    public var species: String
    public var stage: PetStage
    public var bornAt: Date
    public var diedAt: Date
    public var cause: PetNeed?
    public var xp: Double
    /// Set when the player let this pet go and started a new egg (it did not die).
    public var released: Bool?

    public var wasReleased: Bool { released == true }

    public var daysLived: Int { max(Int(diedAt.timeIntervalSince(bornAt) / 86_400), 0) }
}

public struct PetState: Codable, Equatable, Sendable {
    public var name = "Hei Hei"
    public var stage: PetStage = .egg
    public var xp = 0.0
    public var hatchProgress = 0.0
    public var hunger = 80.0
    public var mood = 80.0
    public var energy = 100.0
    public var bond = 0.0
    public var favoriteFood: String?
    public var bornAt: Date
    public var lastTickAt: Date

    // daily counters (reset when `dayStart` changes)
    public var dayStart: Date
    public var warmedToday = 0.0
    public var clickWarmedToday = 0.0
    public var bondFromPettingToday = 0.0
    public var lastCheckIn: Date?

    public var lastFed: [String: Date] = [:]

    // Written only after a stat has hit zero; optional so a save from an older build still loads.
    /// Seconds spent with a stat at zero that have not been made up yet.
    public var neglectSeconds: Double?
    /// Set when the pet has died; nil while it lives.
    public var diedAt: Date?
    public var deathCause: PetNeed?

    public var isDead: Bool { diedAt != nil }

    public init(now: Date = Date(), calendar: Calendar = .current) {
        bornAt = now
        lastTickAt = now
        dayStart = calendar.startOfDay(for: now)
    }
}
