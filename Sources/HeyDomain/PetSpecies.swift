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
