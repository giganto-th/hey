import SwiftUI
import HeyDomain

struct TodayView: View {
    let model: GameModel
    let music: MusicPlayer
    let pomodoro: PomodoroModel
    let router: HubRouter

    private var game: Game { model.game }
    private var previewMode: CompanionPreviewMode { pomodoro.isFocusing ? .focus : music.isPlaying ? .music : .idle }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tr("อีกหนึ่งวันดี ๆ\nไปด้วยกัน")).font(.system(size: 28, weight: .medium))
                        Text(tr("งานของคุณอยู่ตรงหน้า\nส่วนเพื่อนตัวป่วนอยู่ข้าง ๆ"))
                            .foregroundStyle(.secondary)
                        Button(tr("ดูแล {0}", game.pet.state.name), systemImage: "heart") { router.section = .pet }
                            .buttonStyle(PillButtonStyle())
                    }
                    Spacer(minLength: 0)
                    CompanionPreview(stage: game.pet.state.stage, mode: previewMode, settings: game.motion, species: game.species)
                }
                if game.pet.state.stage == .egg {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tr("ค่อย ๆ อุ่น แล้วมารู้จักกัน")).font(.headline)
                        ProgressView(value: min(game.pet.state.hatchProgress, game.pet.balance.hatchNeeded), total: game.pet.balance.hatchNeeded)
                        Text(tr("ฟักก่อน แล้ว {0} จะจิกคีย์บอร์ดและเต้นเป็นเพื่อนคุณ", game.pet.state.name))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 24) {
                        stat(tr("ความอิ่ม"), value: game.pet.state.hunger, symbol: "fork.knife")
                        stat(tr("อารมณ์"), value: game.pet.state.mood, symbol: "face.smiling")
                        stat(tr("พลังงาน"), value: game.pet.state.energy, symbol: "bolt")
                    }
                }
                Divider()
                featureRow(tr("เวลาให้เรื่องสำคัญ"), subtitle: pomodoro.timer.isRunning ? "\(pomodoro.remainingText) · \(pomodoro.timer.phase == .focus ? tr("โฟกัส") : tr("พัก"))" : tr("โฟกัสทีละรอบ · {0} จะอยู่นิ่ง ๆ", game.pet.state.name), symbol: "timer") {
                    Button(pomodoro.timer.isRunning ? tr("หยุดชั่วคราว") : tr("เริ่มโฟกัส")) { pomodoro.toggle() }
                }
                Divider()
                featureRow(tr("เพลงของคุณ"), subtitle: music.nowPlaying?.title ?? tr("เลือกเพลงที่อยากฟัง แล้วค่อย ๆ ทำงานไปด้วยกัน"), symbol: "music.note") {
                    Button(music.nowPlaying == nil ? tr("เลือกเพลง") : music.isPlaying ? tr("หยุดเพลง") : tr("เล่นต่อ")) {
                        if music.nowPlaying == nil { router.section = .music } else { music.toggle() }
                    }
                }
                Divider()
                if let next = game.reminders.filter(\.isActive).min(by: { $0.nextFire < $1.nextFire }) {
                    featureRow(tr("เตือนถัดไป"), subtitle: "\(next.nextFire.formatted(date: .abbreviated, time: .shortened)) · \(next.text)", symbol: "bell") {
                        Button(tr("ดูเตือน")) { router.section = .reminders }
                    }
                } else {
                    featureRow(tr("เผื่อมีเรื่องต้องจำ"), subtitle: tr("ตั้งเตือนด้วยภาษาไทย หรือเรียกด่วนด้วย ⌃⌥R"), symbol: "bell") {
                        Button(tr("ตั้งเตือน")) { router.section = .reminders }
                    }
                }
                Divider()
                HStack(spacing: 12) {
                    Button(tr("ฝากไฟล์ {0} ชิ้น", game.vault.count), systemImage: "tray") { router.section = .vault }
                    Button(tr("โน้ต {0} ใบ", game.notes.count), systemImage: "note.text") { router.section = .notes }
                    Spacer()
                    Button(tr("ปรับการเคลื่อนไหว"), systemImage: "slider.horizontal.3") { router.section = .settings }
                }.font(.callout)
            }.padding(28)
        }
    }

    private func stat(_ title: String, value: Double, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text("\(Int(value)) / 100").font(.callout.monospacedDigit())
            ProgressView(value: min(max(value, 0), 100), total: 100)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureRow<Actions: View>(_ title: String, subtitle: String, symbol: String, @ViewBuilder actions: () -> Actions) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.tint).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            actions()
        }
    }
}
