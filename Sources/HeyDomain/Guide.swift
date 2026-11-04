import Foundation

/// A few one-time tips the pet says itself, so a new player learns the app by using it.
public enum GuideTip: String, CaseIterable, Sendable {
    case warmEgg, openMenu, dropFiles, feedPet

    public var text: String {
        switch self {
        case .warmEgg: tr("คลิกที่ไข่เพื่ออุ่นนะ")
        case .openMenu: tr("คลิกขวาที่ตัวฉันเพื่อเปิดเมนู")
        case .dropFiles: tr("ลากไฟล์เข้ามาหาฉัน ฉันเก็บให้ได้")
        case .feedPet: tr("หิวเมื่อไร คลิกขวาแล้วเลือกอาหารนะ")
        }
    }

    public var symbol: String {
        switch self {
        case .warmEgg: "hand.tap.fill"
        case .openMenu: "contextualmenu.and.cursorarrow"
        case .dropFiles: "tray.and.arrow.down.fill"
        case .feedPet: "fork.knife"
        }
    }

    func applies(to stage: PetStage) -> Bool {
        switch self {
        case .warmEgg: stage == .egg
        case .feedPet: stage != .egg
        case .openMenu, .dropFiles: true
        }
    }
}

public struct GuideState: Codable, Equatable, Sendable {
    public var seen: Set<String> = []
    public init() {}
}

public enum DurationText {
    /// "อีก 8 นาที" style text for a wait.
    public static func wait(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 { return tr("อีก {0} นาที", max(minutes, 1)) }
        let hours = Int((Double(minutes) / 60).rounded(.up))
        return tr("อีก {0} ชั่วโมง", hours)
    }
}
