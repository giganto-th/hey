import Foundation

public enum MotionLevel: String, Codable, CaseIterable, Sendable {
    case system, full, gentle, reduced

    public var label: String {
        switch self {
        case .system: tr("ตามการตั้งค่าระบบ")
        case .full: tr("เต็มรูปแบบ")
        case .gentle: tr("นุ่มนวล")
        case .reduced: tr("ลดการเคลื่อนไหว")
        }
    }
}

public struct MotionSettings: Codable, Equatable, Sendable {
    public var level: MotionLevel = .system
    public var dance = true
    public var roam = true
    public init() {}

    private enum CodingKeys: String, CodingKey { case level, dance, roam }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = try c.decodeIfPresent(MotionLevel.self, forKey: .level) ?? .system
        dance = try c.decodeIfPresent(Bool.self, forKey: .dance) ?? true
        roam = try c.decodeIfPresent(Bool.self, forKey: .roam) ?? true
    }
}

public enum CompanionActivity: String, Sendable {
    case dormant, egg, idle, walking, sleeping, carried, falling
    case attentive, eating, pleased, typing, quietTyping, focusing, dancing, worried
    case startled, dizzy, flapping, flying

    public var label: String {
        switch self {
        case .dormant: tr("พักการเคลื่อนไหว")
        case .egg: tr("กำลังอุ่นไข่")
        case .idle: tr("กำลังมองไปรอบ ๆ")
        case .walking: tr("เดินสำรวจ")
        case .sleeping: tr("งีบสักหน่อย")
        case .carried: tr("กำลังถูกอุ้ม")
        case .falling: tr("กำลังลงพื้น")
        case .attentive: tr("รอคำสั่งจากคุณ")
        case .eating: tr("กำลังกินอาหาร")
        case .pleased: tr("ดีใจที่ได้เจอคุณ")
        case .typing: tr("จิกคีย์บอร์ดตามคุณ")
        case .quietTyping: tr("จิกเบา ๆ ระหว่างโฟกัส")
        case .focusing: tr("เฝ้าคุณทำงานเงียบ ๆ")
        case .dancing: tr("เต้นขณะเล่นเพลง")
        case .worried: tr("พักแรงสักหน่อย")
        case .startled: tr("ตกใจ")
        case .dizzy: tr("มึนหัว")
        case .flapping: tr("ฝึกกระพือปีก")
        case .flying: tr("บินระยะสั้น")
        }
    }
}

/// Ephemeral signals only: never saved, and no keyboard text or audio samples.
public struct CompanionSignals: Sendable {
    public var pose: PetPose = .idle
    public var isEgg = false
    public var tier: PowerTier = .full
    public var menuOpen = false
    public var dropActive = false
    public var focusing = false
    public var musicPlaying = false
    public var ambient: AmbientMotion = .none
    public var lastKeyAt: TimeInterval?
    public var fastTyping = false
    public var typingEnabled = true
    public var systemReduceMotion = false
    public init() {}
}

public struct CompanionPresentation: Equatable, Sendable {
    public var activity: CompanionActivity
    public var amplitude: Double
    public var cyclesPerSecond: Double
    public init(activity: CompanionActivity, amplitude: Double = 1, cyclesPerSecond: Double = 1) {
        self.activity = activity; self.amplitude = amplitude; self.cyclesPerSecond = cyclesPerSecond
    }

    public var showsKeyboard: Bool { activity == .typing || activity == .quietTyping }
    public var holdsPosition: Bool {
        switch activity {
        case .idle, .walking, .sleeping, .egg, .flying: false
        default: true
        }
    }
    public var animates: Bool { amplitude > 0 && activity != .dormant }
}

/// One decision per frame prevents music, typing, menus and physics fighting over transforms.
public enum CompanionMotion {
    public static let typingHold: TimeInterval = 2.5

    public static func resolve(_ s: CompanionSignals, settings: MotionSettings, now: TimeInterval) -> CompanionPresentation {
        let reduced = settings.level == .reduced || (settings.level == .system && s.systemReduceMotion)
        var strength = reduced ? 0.0 : settings.level == .gentle ? 0.35 : 1.0
        if s.tier <= .saver { strength = min(strength, 0.3) }
        if s.ambient == .lowBattery { strength = min(strength, 0.45) }
        func result(_ activity: CompanionActivity, rate: Double = 1) -> CompanionPresentation {
            .init(activity: activity, amplitude: strength, cyclesPerSecond: rate)
        }
        if !s.tier.rendersPet { return .init(activity: .dormant, amplitude: 0, cyclesPerSecond: 0) }
        if s.pose == .carried { return result(.carried) }
        if s.pose == .falling { return result(.falling) }
        if s.isEgg { return result(.egg) }
        if s.pose == .startled { return result(.startled, rate: 1) }
        if s.pose == .dizzy { return result(.dizzy, rate: 0.9) }
        if s.menuOpen || s.dropActive { return result(.attentive) }
        if s.ambient == .criticalBattery || s.ambient == .hot { return result(.worried, rate: 0.4) }
        if s.pose == .eat { return result(.eating, rate: 2) }
        if s.pose == .flap { return result(.flapping, rate: 3.5) }
        if s.pose == .fly { return result(.flying, rate: 4.5) }
        if s.pose == .happy { return result(.pleased, rate: 1.5) }
        let typing = s.typingEnabled && s.lastKeyAt.map { now >= $0 && now - $0 <= typingHold } == true
        if typing { return result(s.focusing ? .quietTyping : .typing, rate: s.focusing ? 1 : s.fastTyping ? 2.8 : 1.6) }
        if s.focusing { return result(.focusing, rate: 0.4) }
        if s.ambient == .dozing { return result(.sleeping, rate: 0.3) }
        // Playback state is deliberately not represented as an audio beat estimate.
        if s.musicPlaying && settings.dance { return result(.dancing, rate: 1.8) }
        if s.pose == .sleep { return result(.sleeping, rate: 0.3) }
        if s.pose == .walk && settings.roam && !reduced { return result(.walking, rate: 2) }
        return result(.idle, rate: 0.4)
    }
}
