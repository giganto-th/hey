import Foundation

/// The art sets the pet can wear (`Resources/Pets/<id>/`). Growth, food and quests are the same for all of them.
public struct PetSpecies: Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let defaultName: String

    public static let all = [
        PetSpecies(id: "heihei", label: "Hei Hei (ไก่ตัวผู้)", defaultName: "Hei Hei"),
        PetSpecies(id: "fluff", label: "Foo (ลูกเจี๊ยบขนฟู)", defaultName: "Foo"),
    ]

    public static func named(_ id: String) -> PetSpecies? { all.first { $0.id == id } }
}
