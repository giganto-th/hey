import Foundation

public enum VaultKind: String, Codable, Sendable { case file, folder, text, link }

public enum VaultMode: String, Codable, Sendable {
    /// Points at the original file (bookmark + path); nothing is copied.
    case reference
    /// A private copy inside the app's Vault folder.
    case copy
}

public enum VaultPolicy: String, Codable, CaseIterable, Sendable {
    case auto, alwaysCopy, alwaysReference

    public var label: String {
        switch self {
        case .auto: "อัตโนมัติ (คัดลอกไฟล์เล็ก อ้างอิงไฟล์ใหญ่/โฟลเดอร์)"
        case .alwaysCopy: "คัดลอกเสมอ"
        case .alwaysReference: "อ้างอิงไฟล์เดิมเสมอ"
        }
    }

    /// Files up to this size are copied under `.auto`.
    public static let autoCopyLimit: Int64 = 100 * 1024 * 1024

    public func mode(isFolder: Bool, size: Int64) -> VaultMode {
        switch self {
        case .alwaysCopy: .copy
        case .alwaysReference: .reference
        case .auto: (isFolder || size > Self.autoCopyLimit) ? .reference : .copy
        }
    }
}

public struct VaultSettings: Codable, Equatable, Sendable {
    public var policy: VaultPolicy = .auto
    /// New items disappear after this many days (pinned items never do). nil = keep forever.
    public var defaultExpiryDays: Int?
    public init() {}
}

public struct VaultItem: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var kind: VaultKind
    public var mode: VaultMode
    public var name: String
    /// Original location (references) or where the copy came from.
    public var sourcePath: String?
    public var bookmark: Data?
    /// File name of the copy inside `Vault/<id>/`.
    public var storedName: String?
    /// Body for `.text` and `.link` items.
    public var text: String?
    public var size: Int64?
    public var tags: [String] = []
    public var pinned = false
    public var expiresAt: Date?
    public var addedAt: Date

    public init(
        kind: VaultKind, mode: VaultMode, name: String, sourcePath: String? = nil, bookmark: Data? = nil,
        storedName: String? = nil, text: String? = nil, size: Int64? = nil, addedAt: Date
    ) {
        self.kind = kind; self.mode = mode; self.name = name; self.sourcePath = sourcePath
        self.bookmark = bookmark; self.storedName = storedName; self.text = text; self.size = size
        self.addedAt = addedAt
    }

    func matches(_ tokens: [String]) -> Bool {
        let haystack = ([name, text ?? "", sourcePath ?? ""] + tags).joined(separator: "\n")
        return tokens.allSatisfy {
            haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
