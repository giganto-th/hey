import AppKit
import SwiftUI
import HeyDomain

/// Shown once on the first launch: language, which friend to start with, and what to expect.
struct WelcomeView: View {
    let model: GameModel
    let finish: () -> Void

    @State private var step = 0
    @State private var language = AppLanguage.choice
    @State private var species: String
    @State private var petName = ""

    init(model: GameModel, finish: @escaping () -> Void) {
        self.model = model
        self.finish = finish
        _species = State(initialValue: model.game.species)
    }

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.14, blue: 0.32).ignoresSafeArea()
            VStack(spacing: 18) {
                Group {
                    switch step {
                    case 0: languageStep
                    case 1: petStep
                    default: tipsStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    HStack(spacing: 6) { ForEach(0..<3) { i in Circle().fill(i == step ? Color.white : Color.white.opacity(0.3)).frame(width: 8, height: 8) } }
                    Spacer()
                    if step > 0 { Button(tr("ย้อนกลับ")) { step -= 1 } }
                    if step < 2 {
                        Button(tr("ถัดไป")) {
                            if step == 1 { model.perform { $0.chooseEgg(species: species, name: petName); return [] } }      // the choice is made once, here
                            step += 1
                        }.buttonStyle(PillButtonStyle()).keyboardShortcut(.defaultAction)
                    } else {
                        Button(tr("เริ่มเลย")) { finish() }.buttonStyle(PillButtonStyle()).keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(32)
        }
        .frame(width: 640, height: 520)
        .preferredColorScheme(.dark)
        .tint(HeyLook.glow)
    }

    private var languageStep: some View {
        VStack(spacing: 18) {
            Text("Hey!").font(.system(size: 64, weight: .heavy, design: .rounded))
            Text(tr("ยินดีต้อนรับ เพื่อนตัวน้อยบนเดสก์ท็อปของคุณ")).font(.title3).foregroundStyle(.secondary)
            Picker(tr("ภาษาของแอป"), selection: $language) {
                Text(tr("ตามระบบ")).tag(LanguageChoice.system)
                Text("ไทย").tag(LanguageChoice.thai)
                Text("English").tag(LanguageChoice.english)
            }
            .pickerStyle(.segmented).frame(width: 360)
            .onChange(of: language) { _, new in AppLanguage.choice = new }
            if AppLanguage.needsRestart {
                Button(tr("เปิดแอปใหม่ตอนนี้")) { UserDefaults.standard.set(true, forKey: WelcomeWindow.shownKey); AppLanguage.relaunch() }
                Text(tr("ภาษาใหม่จะใช้เมื่อเปิดแอปใหม่")).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private var petStep: some View {
        VStack(spacing: 16) {
            Text(tr("เลือกเพื่อนของคุณ")).font(.title.weight(.bold))
            Text(tr("ตั้งชื่อให้เพื่อนด้วย เลือกแล้วเปลี่ยนพันธุ์ไม่ได้ จนกว่าจะเริ่มไข่ใหม่")).font(.callout).foregroundStyle(.secondary)
            EggChoiceView(species: $species, name: $petName, locked: model.game.speciesLocked)
        }
    }

    private var tipsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("เริ่มต้นใช้งาน")).font(.title.weight(.bold))
            tip("hand.tap.fill", tr("คลิกที่ไข่เพื่ออุ่น พอฟักแล้วให้อาหารและเลี้ยงให้โต"))
            tip("contextualmenu.and.cursorarrow", tr("คลิกขวาที่ตัวสัตว์เพื่อเปิดเมนูรอบตัว หรือคลิกไอคอน Hey! บนแถบเมนู"))
            tip("tray.and.arrow.down.fill", tr("ลากไฟล์ ข้อความ หรือลิงก์มาวางที่สัตว์เลี้ยงเพื่อเก็บไว้"))
            tip("keyboard", tr("คีย์ลัด: ⌃⌥H เปิด Hub · ⌃⌥R ตั้งเตือน · ⌃⌥N โน้ต · ⌃⌥P โฟกัส · ⌃⌥S แคปจอ"))
            Divider()
            Text(tr("สิทธิ์ที่แอปอาจขอ (ขอเมื่อคุณใช้ฟีเจอร์นั้นครั้งแรกเท่านั้น)")).font(.headline)
            tip("camera.viewfinder", tr("บันทึกหน้าจอ: แคปภาพ อัดจอ อ่านข้อความจากจอ"))
            tip("calendar", tr("ปฏิทิน: เตือนก่อนนัดหมาย (เปิดเองใน ตั้งค่า)"))
            tip("video", tr("กล้องและไมค์: ถ่ายรูป อัดวิดีโอ"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).frame(width: 26).foregroundStyle(HeyLook.glow)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

@MainActor
enum WelcomeWindow {
    static let shownKey = "welcomeShown"
    private static var window: NSWindow?

    static var shouldShow: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["HEY_DEV_WELCOME"] != nil { return true }
        return !UserDefaults.standard.bool(forKey: shownKey) && env["HEY_DEV"] == nil
    }

    static func show(model: GameModel) {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 520), styleMask: [.titled, .closable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: WelcomeView(model: model) { close() })
        w.center()
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        window = w
    }

    static func close() {
        UserDefaults.standard.set(true, forKey: shownKey)
        window?.close()
        window = nil
    }

    /// The adult idle picture of a species, for the picker.
    static func preview(_ species: String) -> NSImage? {
        let roots = [Bundle.main.resourcePath.map { $0 + "/Pets" }, FileManager.default.currentDirectoryPath + "/Resources/Pets"].compactMap { $0 }
        for root in roots {
            if let image = NSImage(contentsOfFile: "\(root)/\(species)/adult/idle.png") { return image }
        }
        return nil
    }
}
