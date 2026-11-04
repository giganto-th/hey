import SwiftUI
import HeyDomain

/// What the menu-bar menu's pet card shows (a plain snapshot, so the card needs no model).
struct PetCardData {
    var name: String
    var stage: String
    var isEgg: Bool
    var hatch: (value: Double, needed: Double)
    var xp: (value: Double, needed: Double?)
    var hunger: Double
    var mood: Double
    var energy: Double
    var coins: Int
    var streak: Int
    var questsDone: Int
    var questsTotal: Int
    var reminders: Int
    var mode: String
    var nowPlaying: String?
}

struct AIUsageCardData {
    struct Item: Identifiable {
        let id: String
        let provider: AIProvider
        let name: String
        let windows: [(label: String, percent: Double)]
    }
    var items: [Item]
}

/// A thin rounded bar.
private struct MiniBar: View {
    let value: Double          // 0...100
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.12))
                Capsule().fill(color.gradient).frame(width: max(geo.size.width * min(max(value, 0), 100) / 100, value > 0 ? height : 0))
            }
        }
        .frame(height: height)
    }
}

/// The top of the menu: who the pet is and how it is doing, in one glance.
struct PetMenuCard: View {
    let data: PetCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(data.name).font(.system(size: 17, weight: .bold, design: .rounded))
                Text(data.stage).font(.caption.weight(.medium)).padding(.horizontal, 8).padding(.vertical, 2)
                    .background(.primary.opacity(0.10), in: Capsule())
                Spacer()
                Label("\(data.coins)", systemImage: "circle.hexagongrid.fill").foregroundStyle(.orange).font(.callout.weight(.semibold))
            }
            if data.isEgg {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("ไข่ — อุ่นแล้ว {0}/{1}", Int(data.hatch.value), Int(data.hatch.needed))).font(.caption).foregroundStyle(.secondary)
                    MiniBar(value: data.hatch.value / max(data.hatch.needed, 1) * 100, color: .yellow)
                }
                Text(tr("คลิกไข่หรือเปิดแอปทิ้งไว้เพื่ออุ่น")).font(.caption2).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(data.xp.needed.map { "XP \(Int(data.xp.value))/\(Int($0))" } ?? "XP \(Int(data.xp.value))")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Label(tr("{0} วัน", data.streak), systemImage: "flame.fill").font(.caption).foregroundStyle(.secondary)
                    }
                    MiniBar(value: data.xp.needed.map { data.xp.value / max($0, 1) * 100 } ?? 100, color: .yellow, height: 7)
                }
                HStack(spacing: 14) {
                    stat(tr("ความอิ่ม"), data.hunger, "fork.knife", .orange)
                    stat(tr("อารมณ์"), data.mood, "face.smiling", .pink)
                    stat(tr("พลังงาน"), data.energy, "bolt.fill", .green)
                }
            }
            HStack(spacing: 6) {
                if data.questsTotal > 0 {
                    chip(tr("ภารกิจ {0}/{1}", data.questsDone, data.questsTotal), "checklist", data.questsDone == data.questsTotal ? .green : .secondary)
                }
                if data.reminders > 0 { chip(tr("เตือน {0}", data.reminders), "bell.fill", .secondary) }
                chip(data.mode, "leaf.fill", .secondary)
            }
            if let playing = data.nowPlaying {
                Label(playing, systemImage: "music.note").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(width: 360, alignment: .leading)
    }

    private func stat(_ title: String, _ value: Double, _ symbol: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.caption2).foregroundStyle(color)
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(Int(value))").font(.caption2.weight(.semibold)).monospacedDigit()
            }
            MiniBar(value: value, color: color)
        }
        .frame(maxWidth: .infinity)
    }

    private func chip(_ text: String, _ symbol: String, _ color: Color) -> some View {
        Label(text, systemImage: symbol).font(.caption2).foregroundStyle(color).lineLimit(1)
            .padding(.horizontal, 7).padding(.vertical, 3).background(.primary.opacity(0.08), in: Capsule())
    }
}

/// The AI accounts in the menu: logo, who, and a small bar per quota window.
struct AIUsageMenuCard: View {
    let data: AIUsageCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(data.items) { item in
                HStack(spacing: 10) {
                    ProviderLogoView(provider: item.provider, size: 22)
                    Text(item.name).font(.callout).lineLimit(1).truncationMode(.middle).frame(width: 150, alignment: .leading)
                    ForEach(Array(item.windows.enumerated()), id: \.offset) { _, window in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(window.label).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                                Spacer(minLength: 2)
                                Text("\(Int(window.percent.rounded()))%").font(.system(size: 10, weight: .semibold)).monospacedDigit()
                                    .foregroundStyle(color(window.percent))
                            }
                            MiniBar(value: window.percent, color: color(window.percent), height: 5)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(width: 360, alignment: .leading)
    }

    private func color(_ used: Double) -> Color { used >= 95 ? .red : (used >= 80 ? .orange : .green) }
}
