import SwiftUI
import HeyDomain

/// Which friend this egg is, and what it will be called. Used wherever a new egg starts: the first launch, after a death, and when
/// the player lets a pet go. The kind is fixed once the egg is started, so the view says so.
struct EggChoiceView: View {
    @Binding var species: String
    @Binding var name: String
    /// Already chosen: shown, but nothing can be changed.
    var locked = false
    var note: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ForEach(PetSpecies.all.filter { SpritePet.installedSpecies().contains($0.id) }) { sp in
                    Button { species = sp.id } label: {
                        VStack(spacing: 6) {
                            if let image = WelcomeWindow.preview(sp.id) { Image(nsImage: image).resizable().scaledToFit().frame(height: 96) }
                            Text(sp.defaultName).font(.headline)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(species == sp.id ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(species == sp.id ? Color.accentColor : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .disabled(locked)
                    .accessibilityLabel(sp.defaultName)
                    .accessibilityAddTraits(species == sp.id ? .isSelected : [])
                }
            }
            TextField(tr("ชื่อของเพื่อนคุณ"), text: $name, prompt: Text(PetSpecies.named(species)?.defaultName ?? "Hei Hei"))
                .textFieldStyle(.roundedBorder)
                .disabled(locked)
                .onChange(of: name) { _, new in if new.count > PetName.maxLength { name = String(new.prefix(PetName.maxLength)) } }
            Text(locked ? tr("เลือกไว้แล้ว เปลี่ยนได้ที่ Hub › สัตว์เลี้ยง ตอนเริ่มไข่ใหม่") : (note ?? tr("เลือกแล้วเปลี่ยนพันธุ์ไม่ได้ จนกว่าจะเริ่มไข่ใหม่ ส่วนชื่อเปลี่ยนทีหลังได้")))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// "Start a new egg": lets the current pet go (it is kept in the memorial list) and starts a fresh egg of the chosen kind.
struct NewEggSheet: View {
    let model: GameModel
    let game: Game
    let close: () -> Void
    @State private var species = ""
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("เริ่มไข่ใหม่")).font(.title2.weight(.bold))
            Text(game.pet.state.stage == .egg
                 ? tr("ไข่ฟองนี้จะถูกแทนที่ด้วยไข่ฟองใหม่")
                 : tr("{0} จะถูกเก็บไว้ในที่ระลึกว่าปล่อยไป ไม่ใช่การจากไป เหรียญ ของในคลัง เควส และความสำเร็จยังอยู่ครบ", game.pet.state.name))
                .font(.callout).foregroundStyle(.secondary)
            EggChoiceView(species: $species, name: $name)
            HStack {
                Spacer()
                Button(tr("ยกเลิก")) { close() }
                Button {
                    let choice = species.isEmpty ? game.species : species
                    model.perform { $0.releasePet(at: Date(), species: choice, name: name); return [] }
                    close()
                } label: { Label(tr("ฟักไข่ใหม่"), systemImage: "egg.fill") }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear { species = game.species }
    }
}
