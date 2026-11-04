import Foundation

/// Everything the pet's fan menu can hold.
public enum RadialAction: String, CaseIterable, Codable, Sendable {
    case music, files, focus, hub, feed, note, remind, shot, ocr, clip, rec, shelf, bubbles

    public var label: String {
        switch self {
        case .music: tr("เพลง")
        case .files: tr("ฝากไฟล์")
        case .focus: tr("โฟกัส")
        case .hub: "Hub"
        case .feed: tr("ให้อาหาร")
        case .note: tr("โน้ต")
        case .remind: tr("ตั้งเตือน")
        case .shot: tr("แคปจอ")
        case .ocr: tr("อ่านข้อความจากจอ")
        case .clip: tr("ประวัติคลิปบอร์ด")
        case .rec: tr("อัดจอ")
        case .shelf: tr("ถาดไฟล์")
        case .bubbles: tr("ฟองสบู่")
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

/// A folder on the ring: a button that opens a page of its own actions. The built-in ones have a fixed id, a symbol and a default name;
/// a folder the user makes carries its own name.
public struct RadialFolder: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// Nil on a built-in folder that was never renamed: it then shows `defaultName`.
    public var name: String?
    public var symbol: String
    public var actions: [RadialAction]

    public init(id: String, name: String? = nil, symbol: String = "folder", actions: [RadialAction] = []) {
        self.id = id; self.name = name; self.symbol = symbol; self.actions = actions
    }

    /// The built-in folders and what they start with.
    public static let capture = RadialFolder(id: "capture", symbol: "camera.viewfinder", actions: [.shot, .rec, .ocr])
    public static let notes = RadialFolder(id: "notes", symbol: "checklist", actions: [.note, .remind, .clip, .focus])
    public static let other = RadialFolder(id: "other", symbol: "ellipsis", actions: [.shelf, .bubbles])

    public var defaultName: String? {
        switch id {
        case "capture": tr("จับภาพ")
        case "notes": tr("จดและเตือน")
        case "other": tr("อื่น ๆ")
        default: nil
        }
    }

    /// What the button says (the caller localizes it).
    public var displayName: String { name ?? defaultName ?? tr("โฟลเดอร์") }
}

/// One slot on the ring.
public enum RadialEntry: Codable, Equatable, Sendable {
    case action(RadialAction)
    case folder(RadialFolder)

    private enum CodingKeys: String, CodingKey { case action, folder }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let raw = try c.decodeIfPresent(String.self, forKey: .action), let action = RadialAction(rawValue: raw) {
            self = .action(action)
        } else if let folder = try c.decodeIfPresent(RadialFolder.self, forKey: .folder) {
            self = .folder(folder)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .action, in: c, debugDescription: "unknown ring entry")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .action(let a): try c.encode(a.rawValue, forKey: .action)
        case .folder(let f): try c.encode(f, forKey: .folder)
        }
    }
}

/// What the pet's fan menu holds and in what order: a ring of actions and folders, and the actions the user has hidden.
/// Every action is in exactly one place (the ring, one folder, or hidden). Hub always stays on the ring.
public struct RadialMenuSettings: Codable, Equatable, Sendable {
    public static let maxRing = 10
    public static let maxFolderActions = 7

    public enum Place: Equatable, Sendable { case ring, folder(String) }

    public private(set) var ring: [RadialEntry]

    public static let defaultRing: [RadialEntry] = [
        .action(.music), .action(.files), .action(.focus), .action(.feed), .action(.hub),
        .folder(RadialFolder(id: "capture", symbol: "camera.viewfinder", actions: [.shot, .rec, .ocr])),
        .folder(RadialFolder(id: "notes", symbol: "checklist", actions: [.note, .remind, .clip])),
        .folder(RadialFolder(id: "other", symbol: "ellipsis", actions: [.shelf, .bubbles])),
    ]

    public init() { ring = Self.defaultRing }

    private enum CodingKeys: String, CodingKey { case ring, pinned }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let entries = try? c.decodeIfPresent([RadialEntry].self, forKey: .ring) {
            ring = entries
        } else if let names = (try? c.decodeIfPresent([String].self, forKey: .pinned)) ?? nil {
            // an older save: the pinned actions went on the ring and the rest sat in the built-in folders
            let pinned = names.compactMap(RadialAction.init(rawValue:))
            ring = pinned.map(RadialEntry.action)
            for var folder in [RadialFolder.capture, .notes, .other] {
                folder.actions.removeAll { pinned.contains($0) }
                if !folder.actions.isEmpty { ring.append(.folder(folder)) }
            }
        } else {
            ring = Self.defaultRing
        }
        normalize()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ring, forKey: .ring)
    }

    // MARK: reading

    public var folders: [RadialFolder] { ring.compactMap { if case .folder(let f) = $0 { f } else { nil } } }

    public func folder(_ id: String) -> RadialFolder? { folders.first { $0.id == id } }

    /// The actions that sit directly on the ring, in order.
    public var ringActions: [RadialAction] { ring.compactMap { if case .action(let a) = $0 { a } else { nil } } }

    private var placed: Set<RadialAction> { Set(ringActions).union(folders.flatMap(\.actions)) }

    /// Actions that are on neither the ring nor a folder.
    public var hidden: [RadialAction] { RadialAction.allCases.filter { !placed.contains($0) } }

    public func place(of action: RadialAction) -> Place? {
        if ringActions.contains(action) { return .ring }
        return folders.first { $0.actions.contains(action) }.map { .folder($0.id) }
    }

    // MARK: editing

    private mutating func removeEverywhere(_ action: RadialAction) {
        ring.removeAll { if case .action(let a) = $0 { a == action } else { false } }
        for i in ring.indices {
            if case .folder(var f) = ring[i] { f.actions.removeAll { $0 == action }; ring[i] = .folder(f) }
        }
    }

    /// Put an action on the ring or into a folder, moving it from wherever it was. Refuses when the place is full,
    /// and Hub only goes on the ring.
    @discardableResult
    public mutating func place(_ action: RadialAction, in destination: Place) -> Bool {
        switch destination {
        case .ring:
            if place(of: action) == .ring { return true }
            guard ring.count < Self.maxRing else { return false }
            removeEverywhere(action)
            ring.append(.action(action))
        case .folder(let id):
            guard action != .hub, let target = folder(id) else { return false }
            if target.actions.contains(action) { return true }
            guard target.actions.count < Self.maxFolderActions else { return false }
            removeEverywhere(action)
            guard let i = ring.firstIndex(where: { if case .folder(let f) = $0 { f.id == id } else { false } }),
                  case .folder(var updated) = ring[i] else { return false }
            updated.actions.append(action)
            ring[i] = .folder(updated)
        }
        return true
    }

    /// Take an action off the menu (Hub stays).
    @discardableResult
    public mutating func hide(_ action: RadialAction) -> Bool {
        guard action != .hub, place(of: action) != nil else { return false }
        removeEverywhere(action)
        return true
    }

    /// Reorder the ring (the offsets and destination follow SwiftUI's `onMove`).
    public mutating func moveEntries(from source: IndexSet, to destination: Int) {
        ring = Self.moved(ring, from: source, to: destination)
    }

    /// Reorder the actions inside a folder.
    public mutating func moveActions(in id: String, from source: IndexSet, to destination: Int) {
        guard let i = ring.firstIndex(where: { if case .folder(let f) = $0 { f.id == id } else { false } }),
              case .folder(var f) = ring[i] else { return }
        f.actions = Self.moved(f.actions, from: source, to: destination)
        ring[i] = .folder(f)
    }

    /// A new, empty folder at the end of the ring. Nil when the ring is full.
    @discardableResult
    public mutating func addFolder(named name: String) -> String? {
        guard ring.count < Self.maxRing else { return nil }
        var n = 1
        while folder("folder-\(n)") != nil { n += 1 }
        let id = "folder-\(n)"
        ring.append(.folder(RadialFolder(id: id, name: Self.clean(name), symbol: "folder")))
        return id
    }

    public mutating func renameFolder(_ id: String, to name: String) {
        guard let i = ring.firstIndex(where: { if case .folder(let f) = $0 { f.id == id } else { false } }),
              case .folder(var f) = ring[i] else { return }
        let cleaned = Self.clean(name)
        f.name = cleaned.isEmpty ? nil : cleaned
        ring[i] = .folder(f)
    }

    /// Remove a folder; the actions inside become hidden (put them back from the hidden list).
    public mutating func deleteFolder(_ id: String) {
        ring.removeAll { if case .folder(let f) = $0 { f.id == id } else { false } }
    }

    public mutating func reset() { ring = Self.defaultRing }

    // MARK: internals

    private static func clean(_ name: String) -> String {
        String(name.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces).prefix(20))
    }

    private static func moved<T>(_ items: [T], from source: IndexSet, to destination: Int) -> [T] {
        let moving = source.sorted().map { items[$0] }
        var rest = items.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let removedBefore = source.filter { $0 < destination }.count
        let at = min(max(destination - removedBefore, 0), rest.count)
        rest.insert(contentsOf: moving, at: at)
        return rest
    }

    /// Every action at most once, Hub always on the ring, no unknown or empty built-in leftovers, within the size limits.
    private mutating func normalize() {
        var seen = Set<RadialAction>()
        var folderIDs = Set<String>()
        var cleaned: [RadialEntry] = []
        for entry in ring {
            switch entry {
            case .action(let a):
                if seen.insert(a).inserted { cleaned.append(entry) }
            case .folder(var f):
                guard folderIDs.insert(f.id).inserted else { continue }
                f.actions = f.actions.filter { $0 != .hub && seen.insert($0).inserted }
                if f.actions.count > Self.maxFolderActions { f.actions = Array(f.actions.prefix(Self.maxFolderActions)) }
                f.name = f.name.map(Self.clean).flatMap { $0.isEmpty ? nil : $0 }
                cleaned.append(.folder(f))
            }
        }
        if !seen.contains(.hub) { cleaned.insert(.action(.hub), at: min(4, cleaned.count)) }
        if cleaned.count > Self.maxRing { cleaned = Array(cleaned.prefix(Self.maxRing)) }
        if !cleaned.contains(.action(.hub)) { cleaned[cleaned.count - 1] = .action(.hub) }
        ring = cleaned
    }
}
