import Foundation

/// The two ways to handle a file you give the pet:
/// - the **vault** keeps it for good (copy or reference, tags, search);
/// - the **shelf** just holds it for a moment so you can drag it somewhere else.
public enum DropDestination: String, Codable, CaseIterable, Sendable {
    case vault, shelf

    public var label: String {
        switch self {
        case .vault: "ฝากเก็บ"
        case .shelf: "พักไว้ลากต่อ"
        }
    }
}

public enum ShelfKind: String, Codable, Sendable { case file, folder, text, link }

public struct ShelfItem: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var kind: ShelfKind
    public var name: String
    /// Where the file or folder is (the shelf never copies anything).
    public var path: String?
    /// The body of a text or link.
    public var text: String?
    public var addedAt: Date

    public init(kind: ShelfKind, name: String, path: String? = nil, text: String? = nil, addedAt: Date) {
        self.kind = kind; self.name = name; self.path = path; self.text = text; self.addedAt = addedAt
    }
}

public struct FileSettings: Codable, Equatable, Sendable {
    /// What happens when something is dropped straight on the pet (the two drop targets always choose explicitly).
    public var dropDefault: DropDestination = .vault
    /// Take an item off the shelf once it has been dragged out to its destination.
    public var removeAfterDragOut = true
    /// Items left on the shelf this long disappear (0 = never).
    public var shelfExpireHours = 24
    public init() {}

    private enum CodingKeys: String, CodingKey { case dropDefault, removeAfterDragOut, shelfExpireHours }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dropDefault = try c.decodeIfPresent(DropDestination.self, forKey: .dropDefault) ?? .vault
        removeAfterDragOut = try c.decodeIfPresent(Bool.self, forKey: .removeAfterDragOut) ?? true
        shelfExpireHours = try c.decodeIfPresent(Int.self, forKey: .shelfExpireHours) ?? 24
    }
}
