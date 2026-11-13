import SwiftUI
import HeyDomain

struct TodayView: View {
    let model: GameModel
    let music: MusicPlayer
    let pomodoro: PomodoroModel
    let calendar: CalendarService
    let router: HubRouter
    @State private var part = DayPart.now

    private var game: Game { model.game }
    private var previewMode: CompanionPreviewMode { pomodoro.isFocusing ? .focus : music.isPlaying ? .music : .idle }
    private var moodColor: Color {
        switch game.pet.state.mood {
        case ..<25: Color(red: 1.0, green: 0.42, blue: 0.40)
        case ..<55: Color(red: 1.0, green: 0.76, blue: 0.35)
        default: HeyLook.glow
        }
    }

    var body: some View {
        let s = game.pet.state
        ScrollView {
            VStack(spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 14) { hero(s); rings(s).frame(width: 300) }
                    VStack(spacing: 14) { hero(s); rings(s) }
                }

                CalendarTodayCard(calendar: calendar, router: router)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                    HubTile(symbol: "timer", title: tr("โฟกัส"),
                            value: pomodoro.timer.isRunning ? "\(pomodoro.remainingText) · \(pomodoro.timer.phase == .focus ? tr("โฟกัส") : tr("พัก"))" : tr("พร้อมเริ่ม"),
                            tint: .orange, action: { withAnimation(.snappy) { router.section = .focus } }) {
                        roundButton(pomodoro.timer.isRunning ? "pause.fill" : "play.fill", pomodoro.timer.isRunning ? tr("หยุดชั่วคราว") : tr("เริ่มโฟกัส")) { pomodoro.toggle() }
                    }
                    HubTile(symbol: "music.note", title: tr("เพลง"),
                            value: music.nowPlaying?.title ?? tr("ยังไม่เล่น"),
                            tint: .pink, action: { withAnimation(.snappy) { router.section = .music } }) {
                        if music.nowPlaying != nil {
                            roundButton(music.isPlaying ? "pause.fill" : "play.fill", music.isPlaying ? tr("หยุดเพลง") : tr("เล่นต่อ")) { music.toggle() }
                        }
                    }
                    HubTile(symbol: "bell", title: tr("เตือน"), value: nextReminder, tint: .yellow,
                            action: { withAnimation(.snappy) { router.section = .reminders } })
                    HubTile(symbol: "tray.full", title: tr("ฝากไฟล์"), value: tr("ฝากไฟล์ {0} ชิ้น", game.vault.count), tint: .mint,
                            action: { withAnimation(.snappy) { router.section = .vault } })
                    HubTile(symbol: "note.text", title: tr("โน้ต"), value: tr("โน้ต {0} ใบ", game.notes.count), tint: HeyLook.accent,
                            action: { withAnimation(.snappy) { router.section = .notes } })
                    HubTile(symbol: "gauge.with.dots.needle.67percent", title: tr("เครดิต AI"), value: tr("ดูโควตาที่เหลือ"), tint: .cyan,
                            action: { withAnimation(.snappy) { router.section = .usage } })
                }
            }
            .padding(16)
        }
        .onAppear { part = .now }
    }

    private func hero(_ s: PetState) -> some View {
        HubCard(padding: 18) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(part.greeting, systemImage: part.symbol)
                        .font(.callout).foregroundStyle(.white.opacity(0.7))
                    Text(s.name).font(.system(size: 30, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                    Button(tr("ดูแล {0}", s.name), systemImage: "heart") {
                        withAnimation(.snappy) { router.section = .pet }
                    }
                    .buttonStyle(PillButtonStyle())
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().fill(RadialGradient(colors: [moodColor.opacity(0.35), .clear], center: .center, startRadius: 6, endRadius: 90))
                        .frame(width: 180, height: 180)
                    CompanionPreview(stage: s.stage, mode: previewMode, settings: game.motion, species: game.species,
                                     size: CGSize(width: 168, height: 147))
                }
                .frame(width: 180, height: 156)
            }
        }
    }

    private func rings(_ s: PetState) -> some View {
        HubCard {
            HStack(spacing: 4) {
                if s.stage == .egg {
                    StatRing(value: s.hatchProgress / max(game.pet.balance.hatchNeeded, 1) * 100, symbol: "egg", title: tr("อุ่นไข่"), diameter: 72)
                } else {
                    StatRing(value: s.hunger, symbol: "fork.knife", title: tr("ความอิ่ม"), diameter: 72)
                    StatRing(value: s.mood, symbol: "face.smiling", title: tr("อารมณ์"), diameter: 72)
                    StatRing(value: s.energy, symbol: "bolt.fill", title: tr("พลังงาน"), diameter: 72)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var nextReminder: String {
        guard let next = game.reminders.filter(\.isActive).min(by: { $0.nextFire < $1.nextFire }) else { return tr("ไม่มีเตือน") }
        return "\(next.nextFire.formatted(date: .omitted, time: .shortened)) · \(next.text)"
    }

    private func roundButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.14), in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
