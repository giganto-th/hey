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
                        Text("อีกหนึ่งวันดี ๆ\nไปด้วยกัน").font(.system(size: 28, weight: .medium))
                        Text("งานของคุณอยู่ตรงหน้า\nส่วนเพื่อนตัวป่วนอยู่ข้าง ๆ")
                            .foregroundStyle(.secondary)
                        Button("ดูแล \(game.pet.state.name)", systemImage: "heart") { router.section = .pet }
                            .buttonStyle(PillButtonStyle())
                    }
                    Spacer(minLength: 0)
                    CompanionPreview(stage: game.pet.state.stage, mode: previewMode, settings: game.motion, species: game.species)
                }
                if game.pet.state.stage == .egg {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ค่อย ๆ อุ่น แล้วมารู้จักกัน").font(.headline)
                        ProgressView(value: min(game.pet.state.hatchProgress, game.pet.balance.hatchNeeded), total: game.pet.balance.hatchNeeded)
                        Text("ฟักก่อน แล้ว \(game.pet.state.name) จะจิกคีย์บอร์ดและเต้นเป็นเพื่อนคุณ")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 24) {
                        stat("ความอิ่ม", value: game.pet.state.hunger, symbol: "fork.knife")
                        stat("อารมณ์", value: game.pet.state.mood, symbol: "face.smiling")
                        stat("พลังงาน", value: game.pet.state.energy, symbol: "bolt")
                    }
                }
                Divider()
                featureRow("เวลาให้เรื่องสำคัญ", subtitle: pomodoro.timer.isRunning ? "\(pomodoro.remainingText) · \(pomodoro.timer.phase == .focus ? "โฟกัส" : "พัก")" : "โฟกัสทีละรอบ · \(game.pet.state.name) จะอยู่นิ่ง ๆ", symbol: "timer") {
                    Button(pomodoro.timer.isRunning ? "หยุดชั่วคราว" : "เริ่มโฟกัส") { pomodoro.toggle() }
                }
                Divider()
                featureRow("เพลงของคุณ", subtitle: music.nowPlaying?.title ?? "เลือกเพลงที่อยากฟัง แล้วค่อย ๆ ทำงานไปด้วยกัน", symbol: "music.note") {
                    Button(music.nowPlaying == nil ? "เลือกเพลง" : music.isPlaying ? "หยุดเพลง" : "เล่นต่อ") {
                        if music.nowPlaying == nil { router.section = .music } else { music.toggle() }
                    }
                }
                Divider()
                if let next = game.reminders.filter(\.isActive).min(by: { $0.nextFire < $1.nextFire }) {
                    featureRow("เตือนถัดไป", subtitle: "\(next.nextFire.formatted(date: .abbreviated, time: .shortened)) · \(next.text)", symbol: "bell") {
                        Button("ดูเตือน") { router.section = .reminders }
                    }
                } else {
                    featureRow("เผื่อมีเรื่องต้องจำ", subtitle: "ตั้งเตือนด้วยภาษาไทย หรือเรียกด่วนด้วย ⌃⌥R", symbol: "bell") {
                        Button("ตั้งเตือน") { router.section = .reminders }
                    }
                }
                Divider()
                HStack(spacing: 12) {
                    Button("ฝากไฟล์ \(game.vault.count) ชิ้น", systemImage: "tray") { router.section = .vault }
                    Button("โน้ต \(game.notes.count) ใบ", systemImage: "note.text") { router.section = .notes }
                    Spacer()
                    Button("ปรับการเคลื่อนไหว", systemImage: "slider.horizontal.3") { router.section = .settings }
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
