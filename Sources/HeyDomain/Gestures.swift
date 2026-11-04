import CoreGraphics
import Foundation

public enum GestureKind: String, Codable, CaseIterable, Sendable {
    case swipeLeft, swipeRight, swipeUp, swipeDown, rotateLeft, rotateRight, doubleClick

    public var label: String {
        switch self {
        case .swipeLeft: "ปัดซ้าย (2 นิ้ว)"
        case .swipeRight: "ปัดขวา (2 นิ้ว)"
        case .swipeUp: "ปัดขึ้น (2 นิ้ว)"
        case .swipeDown: "ปัดลง (2 นิ้ว)"
        case .rotateLeft: "หมุนทวนเข็ม (2 นิ้ว)"
        case .rotateRight: "หมุนตามเข็ม (2 นิ้ว)"
        case .doubleClick: "ดับเบิลคลิก"
        }
    }
}

public enum Corner: String, Codable, CaseIterable, Sendable {
    case topLeft, topRight, bottomLeft, bottomRight

    public var label: String {
        switch self {
        case .topLeft: "มุมซ้ายบน"
        case .topRight: "มุมขวาบน"
        case .bottomLeft: "มุมซ้ายล่าง"
        case .bottomRight: "มุมขวาล่าง"
        }
    }
}

public enum PetAction: String, Codable, CaseIterable, Sendable {
    case none
    case musicToggle, musicNext, musicPrevious, volumeUp, volumeDown
    case openHub, quickNote, quickReminder, pomodoroToggle
    case screenshotRegion, recordToggle
    case summonPet, hidePet, petMenu

    public var label: String {
        switch self {
        case .none: "ไม่ทำอะไร"
        case .musicToggle: "เล่น/หยุดเพลง"
        case .musicNext: "เพลงถัดไป"
        case .musicPrevious: "เพลงก่อนหน้า"
        case .volumeUp: "เพิ่มเสียง"
        case .volumeDown: "ลดเสียง"
        case .openHub: "เปิด Hub"
        case .quickNote: "โน้ตด่วน"
        case .quickReminder: "ตั้งเตือนด่วน"
        case .pomodoroToggle: "เริ่ม/หยุด Pomodoro"
        case .screenshotRegion: "แคปภาพเลือกพื้นที่"
        case .recordToggle: "เริ่ม/หยุดอัดหน้าจอ"
        case .summonPet: "เรียกสัตว์เลี้ยงมาที่เมาส์"
        case .hidePet: "ซ่อน/แสดงสัตว์เลี้ยง"
        case .petMenu: "เปิดเมนูสัตว์เลี้ยง"
        }
    }

    /// Short text the pet says when it runs the action.
    public var feedback: String? {
        switch self {
        case .musicNext: "ถัดไป"
        case .musicPrevious: "ก่อนหน้า"
        case .volumeUp: "เสียงดังขึ้น"
        case .volumeDown: "เสียงเบาลง"
        case .summonPet: "มาแล้ว!"
        default: nil
        }
    }

    /// An SF Symbol to show beside `feedback`.
    public var feedbackSymbol: String? {
        switch self {
        case .musicNext: "forward.fill"
        case .musicPrevious: "backward.fill"
        case .volumeUp: "speaker.wave.3.fill"
        case .volumeDown: "speaker.wave.1.fill"
        case .summonPet: "pawprint.fill"
        default: nil
        }
    }
}

public struct GestureSettings: Codable, Equatable, Sendable {
    public static let minScale = 0.5
    public static let maxScale = 1.1

    /// Keyed by `GestureKind.rawValue`; a missing key means "use the default".
    public var bindings: [String: PetAction] = [:]
    public var hotCornersEnabled = false
    public var cornerBindings: [String: PetAction] = [:]
    /// How long the pointer must rest in a corner (seconds).
    public var cornerDwell = 0.5
    /// The player's own size preference, multiplied with the growth-stage size.
    public var petScale = 1.0

    public init() {}

    public static func defaultAction(for gesture: GestureKind) -> PetAction {
        switch gesture {
        case .swipeLeft: .musicNext
        case .swipeRight: .musicPrevious
        case .swipeUp: .volumeUp
        case .swipeDown: .volumeDown
        case .rotateLeft, .rotateRight, .doubleClick: .none
        }
    }

    public static func defaultAction(for corner: Corner) -> PetAction {
        switch corner {
        case .topLeft: .summonPet
        case .topRight: .openHub
        case .bottomLeft: .none
        case .bottomRight: .quickNote
        }
    }

    public func action(for gesture: GestureKind) -> PetAction {
        bindings[gesture.rawValue] ?? Self.defaultAction(for: gesture)
    }

    public func action(for corner: Corner) -> PetAction {
        cornerBindings[corner.rawValue] ?? Self.defaultAction(for: corner)
    }

    public mutating func bind(_ gesture: GestureKind, to action: PetAction) { bindings[gesture.rawValue] = action }
    public mutating func bind(_ corner: Corner, to action: PetAction) { cornerBindings[corner.rawValue] = action }

    public mutating func resetBindings() {
        bindings = [:]
        cornerBindings = [:]
    }

    public mutating func clamp() {
        petScale = min(max(petScale, Self.minScale), Self.maxScale)
        cornerDwell = min(max(cornerDwell, 0.2), 3)
    }
}

/// Turns the stream of scroll events into one swipe. Directions are where the *fingers* moved:
/// `dx` > 0 is right, `dyUp` > 0 is up.
public struct SwipeDetector: Sendable {
    public var trackpadThreshold = 80.0
    public var wheelThreshold = 1.0
    public var dominance = 1.5          // the main axis must beat the other one by this factor
    public var cooldown = 0.6

    private var sumX = 0.0
    private var sumY = 0.0
    private var lastFired = -Double.infinity

    public init() {}

    public mutating func reset() { sumX = 0; sumY = 0 }

    /// Trackpad: call with `ended: false` while fingers are down and once with `ended: true` when they lift.
    /// Mouse wheel (`precise: false`): every event stands alone.
    public mutating func scroll(dx: Double, dyUp: Double, precise: Bool, ended: Bool, at time: Double) -> GestureKind? {
        sumX += dx
        sumY += dyUp
        guard !precise || ended else { return nil }
        defer { reset() }
        let limit = precise ? trackpadThreshold : wheelThreshold
        let ax = abs(sumX), ay = abs(sumY)
        guard max(ax, ay) >= limit, time - lastFired >= cooldown else { return nil }
        let result: GestureKind
        if ax >= ay * dominance { result = sumX > 0 ? .swipeRight : .swipeLeft }
        else if ay >= ax * dominance { result = sumY > 0 ? .swipeUp : .swipeDown }
        else { return nil }                                  // diagonal: ambiguous, ignore
        lastFired = time
        return result
    }
}

/// Two-finger rotation, reported in degrees (positive = counter-clockwise, like NSEvent.rotation).
public struct RotationDetector: Sendable {
    public var thresholdDegrees = 25.0
    private var total = 0.0

    public init() {}

    public mutating func rotate(by degrees: Double, ended: Bool) -> GestureKind? {
        total += degrees
        guard ended else { return nil }
        defer { total = 0 }
        guard abs(total) >= thresholdDegrees else { return nil }
        return total > 0 ? .rotateLeft : .rotateRight
    }
}

public enum HotCorner {
    /// Which corner of any screen the point sits in. Coordinates: bottom-left origin, like NSScreen.frame.
    public static func corner(at p: CGPoint, in screens: [CGRect], margin: Double = 2) -> Corner? {
        for f in screens where f.insetBy(dx: -1, dy: -1).contains(p) {
            let left = p.x <= f.minX + margin, right = p.x >= f.maxX - margin
            let bottom = p.y <= f.minY + margin, top = p.y >= f.maxY - margin
            switch (left, right, top, bottom) {
            case (true, _, true, _): return .topLeft
            case (_, true, true, _): return .topRight
            case (true, _, _, true): return .bottomLeft
            case (_, true, _, true): return .bottomRight
            default: continue          // on this screen but not in a corner; the point may also sit on a neighbour's edge
            }
        }
        return nil
    }
}
