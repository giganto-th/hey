import Foundation

/// Everything the pet's fan menu can hold.
public enum RadialAction: String, CaseIterable, Codable, Sendable {
    case music, files, focus, hub, feed, note, remind, shot, ocr, clip, rec, shelf, bubbles

    public var label: String {
        switch self {
        case .music: "เพลง"
        case .files: "ฝากไฟล์"
        case .focus: "โฟกัส"
        case .hub: "Hub"
        case .feed: "ให้อาหาร"
        case .note: "โน้ต"
        case .remind: "ตั้งเตือน"
        case .shot: "แคปจอ"
        case .ocr: "อ่านข้อความจากจอ"
        case .clip: "ประวัติคลิปบอร์ด"
        case .rec: "อัดจอ"
        case .shelf: "ถาดไฟล์"
        case .bubbles: "ฟองสบู่"
        }
    }

    public var symbol: String {
        switch self {
        case .music: "music.note"
        case .files: "tray.fill"
        case .focus: "timer"
        case .hub: "square.grid.2x2.fill"
        case .feed: "fork.knife"
        case .note: "note.text"
        case .remind: "bell.fill"
        case .shot: "camera.viewfinder"
        case .ocr: "text.viewfinder"
        case .clip: "doc.on.clipboard"
        case .rec: "record.circle"
        case .shelf: "suitcase.fill"
        case .bubbles: "bubbles.and.sparkles"
        }
    }
}

/// The folders on the first ring. Every action that is not pinned lives in exactly one of them, so no page is crowded.
public enum RadialGroup: String, CaseIterable, Hashable, Sendable {
    case capture, notes, other

    public var label: String {
        switch self {
        case .capture: "จับภาพ"
        case .notes: "จดและเตือน"
        case .other: "อื่น ๆ"
        }
    }

    public var symbol: String {
        switch self {
        case .capture: "camera.viewfinder"
        case .notes: "checklist"
        case .other: "ellipsis"
        }
    }

    /// Every action in the group, in the order it is shown.
    public var members: [RadialAction] {
        switch self {
        case .capture: [.shot, .rec, .ocr]
        case .notes: [.note, .remind, .clip, .focus]
        case .other: [.music, .files, .feed, .shelf, .bubbles, .hub]
        }
    }
}

extension RadialAction {
    public var group: RadialGroup { RadialGroup.allCases.first { $0.members.contains(self) } ?? .other }
}

/// Which actions sit on the first ring around the pet, in order; everything else folds into "เพิ่มเติม".
public struct RadialMenuSettings: Codable, Equatable, Sendable {
    public static let minPinned = 4
    public static let maxPinned = 6
    public static let defaultPinned: [RadialAction] = [.music, .files, .focus, .feed, .hub]

    public private(set) var pinned: [RadialAction]

    public init() { pinned = Self.defaultPinned }

    private enum CodingKeys: String, CodingKey { case pinned }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let names = (try? c.decodeIfPresent([String].self, forKey: .pinned)) ?? nil
        pinned = names?.compactMap(RadialAction.init(rawValue:)) ?? Self.defaultPinned
        normalize()
    }

    /// Everything not pinned, in catalogue order.
    public var rest: [RadialAction] { RadialAction.allCases.filter { !pinned.contains($0) } }

    /// What is left in a group once the pinned actions have moved out to the ring.
    public func members(of group: RadialGroup) -> [RadialAction] { group.members.filter { !pinned.contains($0) } }

    /// The folders that still hold something, in order.
    public var groups: [RadialGroup] { RadialGroup.allCases.filter { !members(of: $0).isEmpty } }

    public func isPinned(_ action: RadialAction) -> Bool { pinned.contains(action) }

    /// Pin or unpin; refuses when the ring would drop below the minimum or exceed the maximum. Hub always stays.
    @discardableResult
    public mutating func setPinned(_ action: RadialAction, _ on: Bool) -> Bool {
        if on {
            guard !pinned.contains(action), pinned.count < Self.maxPinned else { return false }
            pinned.append(action)
        } else {
            guard action != .hub, pinned.contains(action), pinned.count > Self.minPinned else { return false }
            pinned.removeAll { $0 == action }
        }
        return true
    }

    /// Shift a pinned action earlier (-1) or later (+1).
    public mutating func move(_ action: RadialAction, by offset: Int) {
        guard let i = pinned.firstIndex(of: action) else { return }
        let j = i + offset
        guard pinned.indices.contains(j) else { return }
        pinned.swapAt(i, j)
    }

    public mutating func reset() { pinned = Self.defaultPinned }

    private mutating func normalize() {
        var seen = Set<RadialAction>()
        pinned = pinned.filter { seen.insert($0).inserted }
        if pinned.count > Self.maxPinned { pinned = Array(pinned.prefix(Self.maxPinned)) }
        if !pinned.contains(.hub) { pinned = Array(pinned.prefix(Self.maxPinned - 1)) + [.hub] }
        for action in Self.defaultPinned where pinned.count < Self.minPinned && !pinned.contains(action) { pinned.append(action) }
    }
}
