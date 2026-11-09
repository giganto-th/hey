import Foundation

/// The art sets the pet can wear (`Resources/Pets/<id>/`). Growth, food and quests are the same for all of them.
public struct PetSpecies: Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let defaultName: String

    public static let all = [
        PetSpecies(id: "heihei", label: tr("Hei Hei (ไก่ตัวผู้)"), defaultName: "Hei Hei"),
        PetSpecies(id: "fluff", label: tr("Shams (ลูกเจี๊ยบขนฟู)"), defaultName: "Shams"),
        PetSpecies(id: "shishi", label: tr("Shi Shi (ลูกเจี๊ยบทรงผมบ็อบ)"), defaultName: "Shi Shi"),
    ]

    public static func named(_ id: String) -> PetSpecies? { all.first { $0.id == id } }
}


/// What a pet may be called: trimmed, single-spaced, 1 to 20 characters, nothing that is not printable.
public enum PetName {
    public static let maxLength = 20

    /// The cleaned name, or nil when nothing usable is left.
    public static func clean(_ raw: String) -> String? {
        let printable = raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) && $0 != "\u{200B}" }
        let text = String(String.UnicodeScalarView(printable))
        let collapsed = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maxLength))
    }
}
