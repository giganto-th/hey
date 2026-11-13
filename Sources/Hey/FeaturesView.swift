import SwiftUI
import HeyDomain

/// The home of "Features": everything that is not about the pet, as tiles you tap to open.
struct FeaturesHome: View {
    let model: GameModel
    let music: MusicPlayer
    let pomodoro: PomodoroModel
    let router: HubRouter

    private var game: Game { model.game }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                group(tr("งานและความจำ"), symbol: "checklist") {
                    tile(.calendar, "calendar", tr("ปฏิทิน"), tr("ตารางนัดรายสัปดาห์และรายเดือน"), HeyLook.glow)
                    tile(.focus, "timer", tr("โฟกัส"), pomodoro.timer.isRunning ? "\(pomodoro.remainingText) · \(pomodoro.timer.phase == .focus ? tr("โฟกัส") : tr("พัก"))" : tr("พร้อมเริ่ม"), HeyLook.glow)
                    tile(.reminders, "bell", tr("เตือน"), nextReminder, HeyLook.glow)
                    tile(.notes, "note.text", tr("โน้ต"), tr("โน้ต {0} ใบ", game.notes.count), HeyLook.glow)
                }
                group(tr("ไฟล์และภาพ"), symbol: "tray.full") {
                    tile(.vault, "tray.full", tr("ฝากไฟล์"), tr("ฝากไฟล์ {0} ชิ้น", game.vault.count), HeyLook.glow)
                    tile(.clipboard, "doc.on.clipboard", tr("คลิปบอร์ด"), tr("ประวัติที่คัดลอก"), HeyLook.glow)
                    tile(.capture, "camera", tr("ถ่าย/อัด"), tr("ภาพหน้าจอและอัดจอ"), HeyLook.glow)
                }
                group(tr("เพลงและเครื่อง"), symbol: "music.note") {
                    tile(.music, "music.note", tr("เพลง"), music.nowPlaying?.title ?? tr("ยังไม่เล่น"), HeyLook.glow)
                    tile(.usage, "gauge.with.dots.needle.67percent", tr("เครดิต AI"), tr("ดูโควตาที่เหลือ"), HeyLook.glow)
                    tile(.system, "cpu", tr("เครื่องของฉัน"), tr("CPU หน่วยความจำ ดิสก์"), HeyLook.glow)
                }
            }
            .padding(16)
        }
    }

    private var nextReminder: String {
        guard let next = game.reminders.filter(\.isActive).min(by: { $0.nextFire < $1.nextFire }) else { return tr("ไม่มีเตือน") }
        return "\(next.nextFire.formatted(date: .omitted, time: .shortened)) · \(next.text)"
    }

    private func group<Content: View>(_ title: String, symbol: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
        HubCard(title: title, symbol: symbol) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) { content() }
        }
    }

    private func tile(_ section: HubSection, _ symbol: String, _ title: String, _ value: String, _ tint: Color) -> some View {
        HubTile(symbol: symbol, title: title, value: value, tint: tint) {
            withAnimation(.snappy) { router.section = section }
        }
    }
}

/// The Hub's sidebar, one glass column like Finder's: a greeting, the menu, the features, and settings at the bottom.
struct HubSidebar: View {
    let router: HubRouter
    let petName: String
    let greeting: String
    @Environment(\.hubOpacity) private var glass

    private let features: [HubSection] = HubDestination.features.sections

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 18)).foregroundStyle(.white)
                    .frame(width: 40, height: 40).background(HeyLook.accent, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(greeting).font(.caption).foregroundStyle(.secondary)
                    Text(petName).font(.system(size: 17, weight: .bold, design: .rounded)).lineLimit(1)
                }
            }
            .padding(.horizontal, 16).padding(.top, 52).padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    label(tr("เมนู"))
                    row(.today, "sun.max", tr("วันนี้"), selected: router.section == .today)
                    row(.pet, "bird", petName, selected: HubDestination.containing(router.section ?? .today) == .pet)
                    label(tr("ฟีเจอร์")).padding(.top, 14)
                    ForEach(features) { section in
                        row(section, section.icon, section == .features ? tr("ทั้งหมด") : section.title, selected: router.section == section)
                    }
                }
                .padding(.horizontal, 10)
            }
            .scrollIndicators(.never)

            row(.settings, "slider.horizontal.3", tr("ตั้งค่า"), selected: HubDestination.containing(router.section ?? .today) == .settings)
                .padding(.horizontal, 10).padding(.vertical, 12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(HeyLook.surface.opacity(0.03 + 0.15 * glass))
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.vertical, 6)
    }

    private func row(_ section: HubSection, _ symbol: String, _ title: String, selected: Bool) -> some View {
        Button { withAnimation(.snappy(duration: 0.25)) { router.section = section } } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 15, weight: .medium)).frame(width: 22)
                    .foregroundStyle(selected ? HeyLook.accent : Color.primary.opacity(0.55))
                Text(title).font(.system(size: 14, weight: selected ? .semibold : .regular)).lineLimit(1)
                    .foregroundStyle(selected ? HeyLook.accent : Color.primary.opacity(0.85))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 14).fill(HeyLook.surface.opacity(0.75))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HeyLook.edge, lineWidth: 1))
                        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
