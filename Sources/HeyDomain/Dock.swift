import Foundation

public struct DockApp: Codable, Equatable, Hashable, Sendable {
    public var bundleID: String
    public var name: String
    public var path: String
    public init(bundleID: String, name: String, path: String) {
        self.bundleID = bundleID; self.name = name; self.path = path
    }
}

public struct DockGroup: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var apps: [DockApp]
    public init(id: UUID = UUID(), name: String, apps: [DockApp]) { self.id = id; self.name = name; self.apps = apps }
}

public enum DockEntry: Codable, Equatable, Sendable, Identifiable {
    case app(DockApp)
    case group(DockGroup)

    public var id: String {
        switch self {
        case .app(let a): a.bundleID
        case .group(let g): g.id.uuidString
        }
    }
}

/// The launcher dock's pinned apps and groups. Pure data: the app layer supplies real icons and running state.
public struct DockLayout: Codable, Equatable, Sendable {
    public static let defaultGroupName = "กลุ่มใหม่"
    public static let iconSizeRange: ClosedRange<Double> = 32...96

    public private(set) var entries: [DockEntry] = []
    /// Icon edge in points, like the system Dock's size slider.
    public private(set) var iconSize: Double = 52
    /// Stays on screen instead of closing when you click elsewhere.
    public var alwaysOn = false
    /// Icons grow under the pointer.
    public var magnify = true
    /// Icons of running apps turn slowly.
    public var spinRunning = true

    public init() {}

    public mutating func setIconSize(_ value: Double) {
        iconSize = min(max(value, Self.iconSizeRange.lowerBound), Self.iconSizeRange.upperBound)
    }

    private enum CodingKeys: String, CodingKey { case entries, iconSize, alwaysOn, magnify, spinRunning }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        setIconSize(((try? c.decodeIfPresent(Double.self, forKey: .iconSize)) ?? nil) ?? 52)
        alwaysOn = ((try? c.decodeIfPresent(Bool.self, forKey: .alwaysOn)) ?? nil) ?? false
        magnify = ((try? c.decodeIfPresent(Bool.self, forKey: .magnify)) ?? nil) ?? true
        spinRunning = ((try? c.decodeIfPresent(Bool.self, forKey: .spinRunning)) ?? nil) ?? true
        entries = ((try? c.decodeIfPresent([DockEntry].self, forKey: .entries)) ?? nil) ?? []
        var seen = Set<String>()                       // a hand-edited or damaged file never shows an app twice
        entries = entries.compactMap { entry in
            switch entry {
            case .app(let a): return seen.insert(a.bundleID).inserted ? entry : nil
            case .group(var g):
                g.apps = g.apps.filter { seen.insert($0.bundleID).inserted }
                return g.apps.isEmpty ? nil : .group(g)
            }
        }
    }

    public func contains(_ bundleID: String) -> Bool {
        entries.contains { entry in
            switch entry {
            case .app(let a): a.bundleID == bundleID
            case .group(let g): g.apps.contains { $0.bundleID == bundleID }
            }
        }
    }

    public var allApps: [DockApp] {
        entries.flatMap { entry -> [DockApp] in
            switch entry {
            case .app(let a): [a]
            case .group(let g): g.apps
            }
        }
    }

    @discardableResult
    public mutating func add(_ app: DockApp) -> Bool {
        guard !contains(app.bundleID) else { return false }
        entries.append(.app(app))
        return true
    }

    public mutating func remove(_ bundleID: String) {
        entries = entries.compactMap { entry in
            switch entry {
            case .app(let a): return a.bundleID == bundleID ? nil : entry
            case .group(var g):
                g.apps.removeAll { $0.bundleID == bundleID }
                return g.apps.isEmpty ? nil : .group(g)
            }
        }
    }

    /// Drop one app on another to make a group, or on a group to join it. The dragged app leaves wherever it was.
    public mutating func drop(_ bundleID: String, onto targetID: String) {
        guard bundleID != targetID, let app = allApps.first(where: { $0.bundleID == bundleID }) else { return }
        guard let ti = entries.firstIndex(where: { $0.id == targetID }) else { return }
        let target = entries[ti]
        remove(bundleID)
        guard let index = entries.firstIndex(where: { $0.id == targetID }) else { return }
        switch target {
        case .group(var g):
            g.apps.append(app)
            entries[index] = .group(g)
        case .app(let other):
            entries[index] = .group(DockGroup(name: Self.defaultGroupName, apps: [other, app]))
        }
    }

    public mutating func move(_ bundleID: String, toGroup groupID: UUID) {
        guard let app = allApps.first(where: { $0.bundleID == bundleID }),
              entries.contains(where: { $0.id == groupID.uuidString }) else { return }
        remove(bundleID)
        guard let i = entries.firstIndex(where: { $0.id == groupID.uuidString }), case .group(var g) = entries[i] else { return }
        g.apps.append(app)
        entries[i] = .group(g)
    }

    /// Takes an app out of its group and puts it right after the group.
    public mutating func ungroup(_ bundleID: String) {
        for (i, entry) in entries.enumerated() {
            guard case .group(var g) = entry, let app = g.apps.first(where: { $0.bundleID == bundleID }) else { continue }
            g.apps.removeAll { $0.bundleID == bundleID }
            if g.apps.isEmpty {
                entries[i] = .app(app)
            } else {
                entries[i] = .group(g)
                entries.insert(.app(app), at: i + 1)
            }
            return
        }
    }

    public mutating func dissolve(_ groupID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == groupID.uuidString }), case .group(let g) = entries[i] else { return }
        entries.replaceSubrange(i...i, with: g.apps.map { .app($0) })
    }

    public mutating func rename(_ groupID: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = entries.firstIndex(where: { $0.id == groupID.uuidString }),
              case .group(var g) = entries[i] else { return }
        g.name = String(trimmed.prefix(24))
        entries[i] = .group(g)
    }

    /// Puts an app at a top-level slot (0 = first, `entries.count` = last), taking it out of its group if it was in one.
    public mutating func insert(_ bundleID: String, at index: Int) {
        guard let app = allApps.first(where: { $0.bundleID == bundleID }) else { return }
        var target = index
        if let old = entries.firstIndex(where: { $0.id == bundleID }), old < target { target -= 1 }
        remove(bundleID)
        entries.insert(.app(app), at: min(max(target, 0), entries.count))
    }

    public mutating func move(_ entryID: String, by offset: Int) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let j = i + offset
        guard entries.indices.contains(j) else { return }
        entries.swapAt(i, j)
    }
}
