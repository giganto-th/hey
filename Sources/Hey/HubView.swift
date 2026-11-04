import QuickLookThumbnailing
import SwiftUI
import Combine
import HeyDomain

enum HubSection: String, CaseIterable, Identifiable {
    case today, pet, quests, shop, achievements, game
    case vault, music, capture, reminders, focus, notes, clipboard
    case gestures, settings

    /// The sidebar's groups, so twelve-plus pages stay easy to scan.
    static let groups: [(title: String, sections: [HubSection])] = [
        ("สัตว์เลี้ยง", [.pet, .quests, .shop, .achievements, .game]),
        ("เครื่องมือ", [.vault, .clipboard, .music, .capture, .reminders, .focus, .notes]),
        ("ตั้งค่า", [.gestures, .settings]),
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "วันนี้"
        case .quests: "ภารกิจ"
        case .shop: "ร้านค้า"
        case .vault: "ฝากไฟล์"
        case .music: "เพลง"
        case .capture: "ถ่าย/อัด"
        case .reminders: "เตือน"
        case .focus: "โฟกัส"
        case .notes: "โน้ต"
        case .clipboard: "คลิปบอร์ด"
        case .game: "มินิเกม"
        case .achievements: "ความสำเร็จ"
        case .gestures: "ท่าทาง"
        case .pet: "ภาพรวม"
        case .settings: "การตั้งค่า"
        }
    }

    var icon: String {
        switch self {
        case .today: "sun.max"
        case .quests: "checklist"
        case .shop: "bag"
        case .vault: "tray.full"
        case .music: "music.note.list"
        case .capture: "camera"
        case .reminders: "bell"
        case .focus: "timer"
        case .notes: "note.text"
        case .clipboard: "doc.on.clipboard"
        case .game: "gamecontroller"
        case .achievements: "trophy"
        case .gestures: "hand.draw"
        case .pet: "pawprint"
        case .settings: "gearshape"
        }
    }
}

enum HubDestination: String, CaseIterable, Identifiable {
    case today, music, files, productivity, pet, settings
    var id: Self { self }
    var sections: [HubSection] {
        switch self {
        case .today: [.today]
        case .music: [.music]
        case .files: [.vault, .clipboard, .notes]
        case .productivity: [.focus, .reminders]
        case .pet: [.pet, .quests, .shop, .achievements, .game]
        case .settings: [.settings, .gestures, .capture]
        }
    }
    var title: String {
        switch self {
        case .today: "วันนี้"
        case .music: "เพลง"
        case .files: "ไฟล์และโน้ต"
        case .productivity: "โฟกัสและเตือน"
        case .pet: "Hei Hei"
        case .settings: "การตั้งค่า"
        }
    }
    var icon: String {
        switch self {
        case .today: "sun.max"
        case .music: "music.note"
        case .files: "square.stack.3d.up"
        case .productivity: "timer"
        case .pet: "bird"
        case .settings: "slider.horizontal.3"
        }
    }
    static func containing(_ section: HubSection) -> Self { allCases.first { $0.sections.contains(section) } ?? .today }
}

/// Which page the Hub shows, so other parts of the app can open it at the right place.
@MainActor @Observable
final class HubRouter {
    var section: HubSection? = .today
}

struct HubView: View {
    let model: GameModel
    let pomodoro: PomodoroModel
    let clipboard: ClipboardService
    let vault: VaultService
    let shelf: ShelfService
    let music: MusicPlayer
    let capture: CaptureService
    let camera: CameraController
    let power: PowerMonitor
    let gestureLog: GestureLog
    let detector: MusicDetector
    @Bindable var router: HubRouter
    @AppStorage("hubOpacity") private var hubOpacity = 0.8

    var body: some View {
        let game = model.game
        let current = HubDestination.containing(router.section ?? .today)
        HStack(spacing: 14) {
            VStack(spacing: 10) {
                ForEach(HubDestination.allCases.filter { $0 != .settings }) { destination in
                    RailButton(symbol: destination.icon,
                               title: destination == .pet ? game.pet.state.name : destination.title,
                               selected: current == destination) { router.section = destination.sections.first }
                }
                Spacer()
                RailButton(symbol: HubDestination.settings.icon, title: HubDestination.settings.title,
                           selected: current == .settings) { router.section = HubDestination.settings.sections.first }
            }
            .padding(.vertical, 14).padding(.horizontal, 10)
            .frame(width: 66)
            .heyPanel(cornerRadius: 33)

            VStack(spacing: 0) {
                header(game)
                let sections = current.sections
                if sections.count > 1 {
                    Picker("หน้า", selection: Binding<HubSection>(get: { router.section ?? .today }, set: { router.section = $0 })) {
                        ForEach(sections) { section in Text(section.title).tag(section) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24).padding(.bottom, 14)
                }
                Group {
                    switch router.section ?? .today {
                    case .today: TodayView(model: model, music: music, pomodoro: pomodoro, router: router)
                    case .quests: QuestsTab(game: game)
                    case .shop: ShopTab(model: model, game: game)
                    case .vault: FilesTab(model: model, game: game, vault: vault, shelf: shelf)
                    case .music: MusicTab(model: model, game: game, player: music)
                    case .capture: GalleryTab(model: model, game: game, capture: capture, camera: camera)
                    case .reminders: RemindersTab(model: model, game: game)
                    case .focus: PomodoroTab(pomodoro: pomodoro)
                    case .notes: NotesTab(model: model, game: game)
                    case .clipboard: ClipboardTab(service: clipboard)
                    case .game: MiniGameTab(model: model, game: game)
                    case .achievements: AchievementsTab(game: game)
                    case .gestures: GesturesTab(model: model, game: game, log: gestureLog)
                    case .pet: PetTab(model: model, game: game, router: router)
                    case .settings: SettingsTab(model: model, game: game, power: power, detector: detector)
                    }
                }
                .scrollContentBackground(.hidden)
                .heyPanel()
            }
        }
        .padding(.top, 38).padding([.horizontal, .bottom], 16)
        .background(HubBackdrop(opacity: hubOpacity))
        .preferredColorScheme(.dark)
        .tint(HeyLook.glow)
        .frame(minWidth: 760, minHeight: 560)
    }

    private func header(_ game: Game) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(HubDestination.containing(router.section ?? .today).title).font(.system(size: 26, weight: .semibold, design: .rounded))
                Text("เพื่อนร่วมโต๊ะตัวป่วน").font(.caption).foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Label("\(game.coins) เหรียญ", systemImage: "circle.hexagongrid.fill").glassPill()
            Label("\(game.streak.current) วัน", systemImage: "flame").glassPill()
        }
        .font(.callout)
        .padding(.horizontal, 8).padding(.bottom, 14).padding(.top, 4)
    }
}

private struct QuestsTab: View {
    let game: Game

    var body: some View {
        List {
            Section("ภารกิจวันนี้ (รีเซ็ตตี 4)") {
                if game.quests.isEmpty {
                    Text("ยังไม่มีภารกิจ").foregroundStyle(.secondary)
                }
                ForEach(game.quests) { quest in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: quest.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(quest.done ? .green : .secondary)
                            Text(quest.title).strikethrough(quest.done)
                            Spacer()
                            Text(reward(quest)).font(.caption).foregroundStyle(.secondary)
                        }
                        ProgressView(value: min(quest.progress, quest.target), total: quest.target)
                        Text("\(Int(quest.progress))/\(Int(quest.target))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            Section {
                Label("ทำครบทุกข้อ รับโบนัส \(Game.allDoneBonus) เหรียญ", systemImage: "gift")
                Label("ทำครบต่อเนื่อง \(Game.streakBonusEvery) วัน รับ \(Game.streakBonus) เหรียญ", systemImage: "flame")
                Label("ขาดวัน streak ไม่รีเซ็ต แต่ลดลงครึ่งหนึ่ง", systemImage: "info.circle")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private func reward(_ q: Quest) -> String {
        q.rewardXP > 0 ? "\(q.rewardCoins) เหรียญ · XP \(Int(q.rewardXP))" : "\(q.rewardCoins) เหรียญ"
    }
}

private struct ShopTab: View {
    let model: GameModel
    let game: Game

    var body: some View {
        List {
            Section("อาหาร") {
                ForEach(game.pet.balance.foods) { food in
                    HStack {
                        FoodIconView(food: food, size: 40)
                        VStack(alignment: .leading) {
                            Text(food.name)
                            Text("อิ่ม +\(Int(food.hunger))  อารมณ์ +\(Int(food.mood))  XP +\(Int(food.xp))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if food.price == 0 {
                            Text("ฟรี ไม่จำกัด").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("มี \(game.stock(of: food))").font(.caption).foregroundStyle(.secondary)
                            Button("ซื้อ \(food.price) เหรียญ") {
                                model.perform { $0.buy(food) }
                            }
                            .disabled(game.coins < food.price)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct PetTab: View {
    let model: GameModel
    let game: Game
    let router: HubRouter

    var body: some View {
        let s = game.pet.state
        List {
            Section {
                let installed = SpritePet.installedSpecies()
                if installed.count > 1 {
                    Picker("หน้าตา", selection: Binding(
                        get: { game.species },
                        set: { id in model.perform { $0.setSpecies(id); return [] } })) {
                            ForEach(PetSpecies.all.filter { installed.contains($0.id) }) { Text($0.label).tag($0.id) }
                        }
                        .pickerStyle(.segmented)
                }
                HStack {
                    Spacer()
                    CompanionPreview(stage: s.stage, mode: .idle, settings: game.motion, species: game.species,
                                     size: CGSize(width: 200, height: 175))
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section(s.stage == .egg ? "ไข่" : "\(s.name) — \(s.stage.displayName)") {
                if s.stage == .egg {
                    bar("อุ่นไข่", s.hatchProgress, game.pet.balance.hatchNeeded)
                    Text("คลิก/ลูบไข่ หรือเปิดแอปไว้เพื่ออุ่น ฟักแล้วจึงให้อาหารได้")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    if let need = game.pet.balance.xpToLeave(s.stage) {
                        bar("XP", s.xp, need)
                    } else {
                        Text("XP \(Int(s.xp)) (ขั้นสูงสุด)").font(.callout)
                    }
                    bar("อิ่ม", s.hunger, 100, symbol: "fork.knife")
                    bar("อารมณ์", s.mood, 100, symbol: "face.smiling")
                    bar("พลังงาน", s.energy, 100, symbol: "bolt.fill")
                    Label("ผูกพัน \(Int(s.bond))", systemImage: "heart.fill").font(.callout)
                }
            }
            if s.stage != .egg {
                Section("ให้อาหาร") {
                    ForEach(game.pet.balance.foods) { food in
                        let stock = game.stock(of: food)
                        HStack {
                            HStack(spacing: 8) {
                                FoodIconView(food: food, size: 24)
                                Text("\(food.name)\(food.id == s.favoriteFood ? " · ของโปรด" : "")")
                            }
                            Spacer()
                            if food.price > 0 {
                                Text("มี \(stock)").font(.caption).foregroundStyle(.secondary)
                            }
                            let wait = game.pet.cooldownRemaining(food, at: Date())
                            if stock <= 0 {
                                Button("ซื้อ") { router.section = .shop }
                            } else if wait > 0 {
                                Text("ให้ได้\(DurationText.wait(wait))").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Button("ให้") { model.perform { $0.feed(food, at: Date()) } }
                            }
                        }
                    }
                }
            }
        }
    }

    private func bar(_ title: String, _ value: Double, _ total: Double, symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let symbol { Label(title, systemImage: symbol) } else { Text(title) }
                Spacer()
                Text("\(Int(value))/\(Int(total))").foregroundStyle(.secondary)
            }
            .font(.callout)
            ProgressView(value: min(max(value, 0), total), total: total)
        }
    }
}


// MARK: reminders

private struct RemindersTab: View {
    let model: GameModel
    let game: Game

    @State private var text = ""
    @State private var date = Date().addingTimeInterval(1800)
    @State private var rule = 0
    @State private var hint = ""

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "th_TH")
        f.dateFormat = "E d MMM HH:mm"
        return f
    }()

    var body: some View {
        List {
            Section("ตั้งเตือนใหม่") {
                TextField("เช่น  ประชุม อีก 20 นาที  /  พรุ่งนี้ 9 โมง ส่งงาน  /  กินยา 18:30", text: $text)
                    .onChange(of: text) { _, new in
                        if let p = ReminderParser.parse(new, now: Date()) {
                            date = p.fireAt
                            hint = "เข้าใจว่า: \"\(p.text)\" เวลา \(Self.formatter.string(from: p.fireAt))"
                        } else {
                            hint = new.isEmpty ? "" : "ไม่พบเวลาในข้อความ — เลือกเวลาด้านล่างเอง"
                        }
                    }
                if !hint.isEmpty { Text(hint).font(.caption).foregroundStyle(.secondary) }
                DatePicker("เวลา", selection: $date)
                Picker("ซ้ำ", selection: $rule) {
                    Text("ครั้งเดียว").tag(0)
                    Text("ทุกวัน").tag(1)
                    Text("ทุกสัปดาห์").tag(2)
                    Text("ทุก 30 นาที").tag(3)
                }
                Button("เพิ่มการเตือน") { add() }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section("รายการ") {
                let active = game.reminders.filter(\.isActive).sorted { $0.nextFire < $1.nextFire }
                if active.isEmpty { Text("ยังไม่มีการเตือน").foregroundStyle(.secondary) }
                ForEach(active) { r in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.text)
                            Text("\(Self.formatter.string(from: r.anchor)) · \(r.repeatRule.label)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if r.ringing {
                            Button("รับทราบ") { model.perform { $0.acknowledgeReminder(id: r.id, at: Date()); return [] } }
                        }
                        Button(role: .destructive) {
                            model.perform { $0.removeReminder(id: r.id); return [] }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    private func add() {
        let parsed = ReminderParser.parse(text, now: Date())
        let message = parsed?.text ?? text.trimmingCharacters(in: .whitespaces)
        let fire = parsed?.fireAt ?? date
        let repeatRule: RepeatRule = [.none, .daily, .weekly, .everyMinutes(30)][rule]
        model.perform { $0.addReminder(message, at: fire, repeat: repeatRule, now: Date()) }
        text = ""
        hint = ""
        date = Date().addingTimeInterval(1800)
    }
}

// MARK: pomodoro

private struct PomodoroTab: View {
    let pomodoro: PomodoroModel

    var body: some View {
        let t = pomodoro.timer
        VStack(spacing: 18) {
            Spacer()
            VStack(spacing: 18) {
            Text(t.phase.label)
                .font(.title3)
                .foregroundStyle(t.phase == .focus ? Color.red : Color.green)
            Text(pomodoro.remainingText)
                .font(.system(size: 72, weight: .semibold, design: .rounded))
                .monospacedDigit()
            ProgressView(value: t.duration(of: t.phase) - t.remaining(at: pomodoro.now), total: t.duration(of: t.phase))
                .frame(maxWidth: 260)
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button(t.isRunning ? "หยุดชั่วคราว" : "เริ่ม") { pomodoro.toggle() }
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut(.defaultAction)
                    Button("ข้าม") { pomodoro.skip() }.buttonStyle(.glass)
                    Button("รีเซ็ต") { pomodoro.reset() }.buttonStyle(.glass)
                }
            }
            }
            .padding(32)
            .glassCard(cornerRadius: 32)
            Text("โฟกัสเสร็จแล้ววันนี้ \(t.completedFocus) รอบ · ทำครบรับ XP และนับเป็นภารกิจ")
                .font(.caption).foregroundStyle(.secondary)
            Text("25 นาทีโฟกัส · 5 นาทีพัก · ทุก 4 รอบพัก 15 นาที · สัตว์เลี้ยงจะนั่งเงียบ ๆ ระหว่างโฟกัส")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: notes

private struct ClipboardTab: View {
    let service: ClipboardService
    @State private var query = ""
    @State private var copiedID: UUID?

    private var entries: [ClipEntry] {
        let all = service.history.entries
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? all : all.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("ค้นหา", text: $query).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                Toggle("หยุดบันทึก", isOn: Binding(get: { service.paused }, set: { service.paused = $0 }))
                Spacer()
                Button("ล้าง (เว้นที่ปักหมุด)") { service.clear() }
                    .disabled(service.history.entries.allSatisfy(\.pinned))
            }
            .padding(12)
            Divider()
            List {
                if entries.isEmpty {
                    Text(query.isEmpty ? "ยังไม่มีอะไร คัดลอกข้อความแล้วจะมาอยู่ที่นี่" : "ไม่พบ").foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.isLink ? "link" : "text.alignleft").foregroundStyle(.secondary).frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.preview).lineLimit(2)
                            Text(entry.createdAt, style: .relative).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if copiedID == entry.id { Text("คัดลอกแล้ว").font(.caption).foregroundStyle(.secondary) }
                        Button { service.togglePin(entry.id) } label: { Image(systemName: entry.pinned ? "pin.fill" : "pin") }
                            .buttonStyle(.borderless).help(entry.pinned ? "เลิกปักหมุด" : "ปักหมุด")
                        Button { service.copy(entry); copiedID = entry.id } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.borderless).help("คัดลอกอีกครั้ง")
                        Button { service.remove(entry.id) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless).help("ลบ")
                    }
                    .padding(.vertical, 2)
                }
            }
            Text("เก็บเฉพาะข้อความ ในหน่วยความจำเท่านั้น ปิดแอปแล้วหาย และไม่เก็บสิ่งที่แอปรหัสผ่านระบุว่าเป็นความลับ")
                .font(.caption).foregroundStyle(.secondary).padding(8)
        }
    }
}

private struct NotesTab: View {
    let model: GameModel
    let game: Game

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { model.perform { $0.addNote(now: Date()); return [] } } label: {
                    Label("โน้ตใหม่", systemImage: "plus")
                }
                Spacer()
                Text("ปักหมุดเพื่อให้โน้ตลอยอยู่บนจอ").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            Divider()
            List {
                if game.notes.isEmpty { Text("ยังไม่มีโน้ต").foregroundStyle(.secondary) }
                ForEach(game.notes) { note in
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(stickyColors[note.colorIndex % stickyColors.count])
                            .frame(width: 8)
                        TextField("พิมพ์โน้ต…", text: Binding(
                            get: { note.text },
                            set: { t in model.perform { $0.updateNote(id: note.id, text: t, now: Date()); return [] } }),
                            axis: .vertical)
                            .lineLimit(1...6)
                            .textFieldStyle(.plain)
                        Button {
                            model.perform { $0.setNote(id: note.id, pinned: !note.pinned); return [] }
                        } label: { Image(systemName: note.pinned ? "pin.fill" : "pin") }
                        .buttonStyle(.borderless)
                        Button(role: .destructive) {
                            model.perform { $0.deleteNote(id: note.id); return [] }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }
}

// MARK: vault

private struct VaultTab: View {
    let model: GameModel
    let game: Game
    let vault: VaultService

    @State private var query = ""
    @State private var tag: String?
    @State private var pendingDelete: VaultItem?
    @State private var dropTargeted = false

    var body: some View {
        let items = game.searchVault(query, tag: tag)
        VStack(spacing: 0) {
            controls(game)
            Divider()
            List {
                if items.isEmpty {
                    Text(game.vault.isEmpty ? "ลากไฟล์ โฟลเดอร์ ข้อความ หรือลิงก์มาวางที่สัตว์เลี้ยง (หรือที่หน้าต่างนี้) เพื่อฝากไว้"
                                            : "ไม่พบรายการที่ตรงกัน")
                        .foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    VaultRow(model: model, vault: vault, item: item, onDelete: { pendingDelete = item })
                }
            }
            .overlay { if dropTargeted { RoundedRectangle(cornerRadius: 8).stroke(.blue, lineWidth: 3).padding(4) } }
            .dropDestination(for: URL.self, action: { urls, _ in
                let files = urls.filter(\.isFileURL)
                guard !files.isEmpty else { return false }
                vault.add(.files(files))
                return true
            }, isTargeted: { dropTargeted = $0 })
        }
        .confirmationDialog(
            "ลบ “\(pendingDelete?.name ?? "")” ?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("ลบ", role: .destructive) {
                if let item = pendingDelete { model.perform { $0.removeVaultItem(id: item.id) } }
                pendingDelete = nil
            }
            Button("ยกเลิก", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(pendingDelete?.mode == .copy ? "ไฟล์ที่คัดลอกไว้ใน vault จะถูกลบถาวร" : "ลบเฉพาะรายการ ไฟล์ต้นฉบับไม่ถูกแตะต้อง")
        }
    }

    private func controls(_ game: Game) -> some View {
        VStack(spacing: 8) {
            HStack {
                TextField("ค้นหาชื่อ ข้อความ แท็ก", text: $query)
                    .textFieldStyle(.roundedBorder)
                if !game.vaultTags.isEmpty {
                    Picker("แท็ก", selection: $tag) {
                        Text("ทุกแท็ก").tag(String?.none)
                        ForEach(game.vaultTags, id: \.self) { Text("#\($0)").tag(String?.some($0)) }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
            }
            HStack {
                Picker("เก็บแบบ", selection: Binding(
                    get: { game.vaultSettings.policy },
                    set: { p in model.perform { $0.setVaultPolicy(p); return [] } })) {
                    ForEach(VaultPolicy.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("หมดอายุ", selection: Binding(
                    get: { game.vaultSettings.defaultExpiryDays },
                    set: { d in model.perform { $0.setVaultDefaultExpiry(days: d); return [] } })) {
                    Text("ไม่ลบ").tag(Int?.none)
                    Text("1 วัน").tag(Int?.some(1))
                    Text("7 วัน").tag(Int?.some(7))
                    Text("30 วัน").tag(Int?.some(30))
                }
                .frame(width: 150)
            }
            .font(.caption)
        }
        .padding(12)
    }
}

private struct VaultRow: View {
    let model: GameModel
    let vault: VaultService
    let item: VaultItem
    let onDelete: () -> Void

    @State private var editingTags = false
    @State private var tagText = ""

    private var url: URL? { vault.resolve(item) }
    private var missing: Bool { (item.kind == .file || item.kind == .folder) && url == nil }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                HStack(spacing: 10) {
                    icon.frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            if item.pinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.orange) }
                            Text(item.name).lineLimit(1)
                        }
                        Text(subtitle).font(.caption).foregroundStyle(missing ? .red : .secondary).lineLimit(1)
                        if !item.tags.isEmpty {
                            Text(item.tags.map { "#\($0)" }.joined(separator: " "))
                                .font(.caption2).foregroundStyle(.blue)
                        }
                    }
                    Spacer(minLength: 0)
                }
                // A real drag session, so the item can be dropped on the Finder, the desktop or any other app (as a copy).
                if !missing {
                    DragHandle(writer: { dragWriter() }, image: { dragIcon() }, onFinished: { _ in }, onOpen: { vault.open(item) })
                }
            }
            Button { vault.open(item) } label: { Image(systemName: opensExternally ? "arrow.up.forward.square" : "doc.on.doc") }
                .help(opensExternally ? "เปิด" : "คัดลอกข้อความ")
                .disabled(missing)
            if item.kind == .file || item.kind == .folder {
                Button { vault.reveal(item) } label: { Image(systemName: "magnifyingglass") }
                    .help("แสดงใน Finder").disabled(missing)
            }
            Menu {
                Button(item.pinned ? "เลิกปักหมุด" : "ปักหมุด (ไม่หมดอายุ)") {
                    model.perform { $0.setVaultPinned(id: item.id, !item.pinned); return [] }
                }
                Button("แก้แท็ก…") { tagText = item.tags.joined(separator: ", "); editingTags = true }
                Menu("หมดอายุ") {
                    Button("ไม่หมดอายุ") { setExpiry(nil) }
                    Button("อีก 1 วัน") { setExpiry(1) }
                    Button("อีก 7 วัน") { setExpiry(7) }
                    Button("อีก 30 วัน") { setExpiry(30) }
                }
                Divider()
                Button("ลบ…", role: .destructive, action: onDelete)
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 3)
        .popover(isPresented: $editingTags) {
            VStack(alignment: .leading, spacing: 8) {
                Text("แท็ก (คั่นด้วย ,)").font(.caption)
                TextField("เช่น งาน, ด่วน", text: $tagText)
                    .frame(width: 220)
                    .onSubmit { saveTags() }
                Button("บันทึก") { saveTags() }.keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
    }

    private var opensExternally: Bool { item.kind != .text }

    @ViewBuilder private var icon: some View {
        switch item.kind {
        case .file, .folder:
            if let url { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable() }
            else { Image(systemName: "questionmark.folder").resizable().scaledToFit().foregroundStyle(.red) }
        case .link: Image(systemName: "link").resizable().scaledToFit().foregroundStyle(.blue)
        case .text: Image(systemName: "text.alignleft").resizable().scaledToFit().foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        if missing { return "ไม่พบไฟล์ (ถูกย้ายหรือลบ)" }
        var parts: [String] = []
        switch item.kind {
        case .file, .folder: parts.append(item.mode == .copy ? "คัดลอกไว้" : "อ้างอิง")
        case .link: parts.append(item.text ?? "")
        case .text: parts.append(String((item.text ?? "").prefix(50)).replacingOccurrences(of: "\n", with: " "))
        }
        if let size = item.size, size > 0 { parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "th_TH")
        parts.append(f.localizedString(for: item.addedAt, relativeTo: Date()))
        if let exp = item.expiresAt, !item.pinned { parts.append("หมดอายุ " + f.localizedString(for: exp, relativeTo: Date())) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func dragWriter() -> NSPasteboardWriting? {
        switch item.kind {
        case .file, .folder: return url.map { $0 as NSURL }
        case .link: return item.text.flatMap(URL.init(string:)).map { $0 as NSURL }
        case .text: return (item.text ?? "") as NSString
        }
    }

    private func dragIcon() -> NSImage {
        switch item.kind {
        case .file, .folder:
            if let url { return NSWorkspace.shared.icon(forFile: url.path) }
            return NSImage()
        case .link: return NSImage(systemSymbolName: "link", accessibilityDescription: nil) ?? NSImage()
        case .text: return NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: nil) ?? NSImage()
        }
    }

    private func setExpiry(_ days: Int?) {
        model.perform { $0.setVaultExpiry(id: item.id, days: days, now: Date()); return [] }
    }

    private func saveTags() {
        let tags = tagText.split(separator: ",").map(String.init)
        model.perform { $0.setVaultTags(id: item.id, tags); return [] }
        editingTags = false
    }
}

// MARK: music

private struct MusicTab: View {
    let model: GameModel
    let game: Game
    let player: MusicPlayer

    @State private var link = ""
    @State private var message = ""
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmDelete = false
    @State private var dropTargeted = false

    private var playlist: Playlist? { game.currentPlaylist }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
            PlayerBar(model: model, game: game, player: player)
        }
        .alert("เปลี่ยนชื่อเพลย์ลิสต์", isPresented: $renaming) {
            TextField("ชื่อ", text: $newName)
            Button("ตกลง") { if let p = playlist { model.perform { $0.renamePlaylist(id: p.id, to: newName); return [] } } }
            Button("ยกเลิก", role: .cancel) {}
        }
        .confirmationDialog("ลบเพลย์ลิสต์ “\(playlist?.name ?? "")” ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("ลบ", role: .destructive) { if let p = playlist { model.perform { $0.deletePlaylist(id: p.id); return [] } } }
            Button("ยกเลิก", role: .cancel) {}
        } message: { Text("ลบเฉพาะรายการ ไฟล์เพลงและวิดีโอจริงไม่ถูกลบ") }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                if game.playlists.isEmpty {
                    Text("ยังไม่มีเพลย์ลิสต์").foregroundStyle(.secondary)
                } else {
                    Picker("เพลย์ลิสต์", selection: Binding(
                        get: { playlist?.id },
                        set: { id in model.perform { $0.setMusic { $0.playlistID = id }; return [] } })) {
                        ForEach(game.playlists) { Text("\($0.name) (\($0.tracks.count))").tag(Optional($0.id)) }
                    }
                    .labelsHidden()
                }
                Button { model.perform { $0.createPlaylist(""); return [] } } label: { Image(systemName: "plus") }
                    .help("เพลย์ลิสต์ใหม่")
                if let p = playlist {
                    Button { newName = p.name; renaming = true } label: { Image(systemName: "pencil") }.help("เปลี่ยนชื่อ")
                    Button { confirmDelete = true } label: { Image(systemName: "trash") }.help("ลบเพลย์ลิสต์")
                }
            }
            if let p = playlist {
                HStack {
                    TextField("วางลิงก์ YouTube แล้วกด Enter", text: $link)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addLink(p) }
                    Button("เพิ่ม") { addLink(p) }.disabled(link.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("ไฟล์เพลง…") { pickFiles(p) }
                }
                if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.orange) }
            }
        }
        .padding(12)
    }

    @ViewBuilder private var list: some View {
        if let p = playlist {
            List {
                if p.tracks.isEmpty {
                    Text("ว่างเปล่า — วางลิงก์ YouTube ด้านบน หรือลากลิงก์/ไฟล์เสียงมาวางที่นี่")
                        .foregroundStyle(.secondary)
                }
                ForEach(p.tracks) { track in
                    TrackRow(track: track, playing: player.nowPlaying?.id == track.id,
                             missing: !player.fileExists(track),
                             onPlay: { player.play(track, in: p) },
                             onRemove: { model.perform { $0.removeTrack(id: track.id, from: p.id); return [] } })
                }
                .onMove { offsets, dest in
                    guard let from = offsets.first else { return }
                    model.perform { $0.moveTrack(in: p.id, from: from, to: dest > from ? dest - 1 : dest); return [] }
                }
            }
            .overlay { if dropTargeted { RoundedRectangle(cornerRadius: 8).stroke(.blue, lineWidth: 3).padding(4) } }
            .dropDestination(for: URL.self, action: { urls, _ in
                let files = urls.filter(\.isFileURL)
                if !files.isEmpty { player.addFiles(files, to: p.id) }
                for url in urls where !url.isFileURL {
                    if let m = player.addYouTube(url.absoluteString, to: p.id) { message = m }
                }
                return !urls.isEmpty
            }, isTargeted: { dropTargeted = $0 })
        } else {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "music.note.list").font(.largeTitle).foregroundStyle(.secondary)
                Button("สร้างเพลย์ลิสต์แรก") { model.perform { $0.createPlaylist("เพลงของฉัน"); return [] } }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func addLink(_ p: Playlist) {
        if let m = player.addYouTube(link, to: p.id) { message = m } else { message = ""; link = "" }
    }

    private func pickFiles(_ p: Playlist) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        if panel.runModal() == .OK { player.addFiles(panel.urls, to: p.id) }
    }
}

private struct TrackRow: View {
    let track: Track
    let playing: Bool
    let missing: Bool
    let onPlay: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            thumbnail.frame(width: 56, height: 36).clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if playing { Image(systemName: "speaker.wave.2.fill").font(.caption).foregroundStyle(.green) }
                    Text(track.title).lineLimit(1)
                }
                Text(subtitle).font(.caption).foregroundStyle(missing ? .red : .secondary).lineLimit(1)
            }
            Spacer()
            Button(action: onPlay) { Image(systemName: "play.fill") }.buttonStyle(.borderless).disabled(missing)
            Button(role: .destructive, action: onRemove) { Image(systemName: "xmark") }.buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if !missing { onPlay() } }
    }

    @ViewBuilder private var thumbnail: some View {
        if let s = track.thumbnailURL, let url = URL(string: s) {
            AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.2) }
        } else {
            ZStack { Color.gray.opacity(0.15); Image(systemName: "music.note").foregroundStyle(.secondary) }
        }
    }

    private var subtitle: String {
        if missing { return "ไม่พบไฟล์เพลง (ถูกย้ายหรือลบ)" }
        var parts = [track.isYouTube ? "YouTube" : "ไฟล์"]
        if let a = track.artist { parts.append(a) }
        if let d = track.duration { parts.append(format(d)) }
        return parts.joined(separator: " · ")
    }
}

private func format(_ seconds: Double) -> String {
    let s = Int(seconds.isFinite ? seconds : 0)
    return String(format: "%d:%02d", s / 60, s % 60)
}

private struct PlayerBar: View {
    let model: GameModel
    let game: Game
    let player: MusicPlayer

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(player.nowPlaying?.title ?? "ยังไม่ได้เล่น").lineLimit(1).font(.callout.weight(.medium))
                Spacer()
                if player.isLoading { ProgressView().controlSize(.small) }
            }
            if let e = player.errorText { Text(e).font(.caption).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading) }
            HStack(spacing: 8) {
                Text(format(player.position)).font(.caption).monospacedDigit().frame(width: 40, alignment: .trailing)
                Slider(value: Binding(get: { player.position }, set: { player.seek(to: $0) }),
                       in: 0...max(player.duration, 1))
                    .disabled(player.nowPlaying == nil)
                Text(format(player.duration)).font(.caption).monospacedDigit().frame(width: 40, alignment: .leading)
            }
            HStack(spacing: 16) {
                Button { player.toggleShuffle() } label: { Image(systemName: "shuffle") }
                    .foregroundStyle(game.music.shuffle ? Color.accentColor : .secondary)
                Button { player.previous() } label: { Image(systemName: "backward.fill") }
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 30))
                }
                Button { player.next() } label: { Image(systemName: "forward.fill") }
                Button { player.cycleRepeat() } label: {
                    Image(systemName: game.music.repeatMode == .one ? "repeat.1" : "repeat")
                }
                .foregroundStyle(game.music.repeatMode == .off ? Color.secondary : Color.accentColor)
                Spacer()
                Image(systemName: "speaker.fill").font(.caption).foregroundStyle(.secondary)
                Slider(value: Binding(get: { game.music.volume }, set: { player.setVolume($0) }), in: 0...1)
                    .frame(width: 90)
            }
            .buttonStyle(.borderless)
            Text("เพลงจาก YouTube ใช้แบตมากกว่าไฟล์ในเครื่อง และต้องออนไลน์")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
        .padding(12)
    }
}

// MARK: gallery

private struct GalleryTab: View {
    let model: GameModel
    let game: Game
    let capture: CaptureService
    let camera: CameraController

    @State private var filter: MediaKind?
    @State private var pendingDelete: MediaItem?

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 180), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            let items = game.media.filter { filter == nil || $0.kind == filter }
            ScrollView {
                if items.isEmpty {
                    Text(game.media.isEmpty ? "ยังไม่มีรูปหรือวิดีโอ — ลองกดปุ่มด้านบน หรือ ⌃⌥S / ⌃⌥V" : "ไม่มีรายการในหมวดนี้")
                        .foregroundStyle(.secondary).padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(items) { item in
                            MediaCell(item: item)
                                .contextMenu {
                                    Button("เปิด") { NSWorkspace.shared.open(URL(fileURLWithPath: item.path)) }
                                    Button("แสดงใน Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                                    }
                                    if !item.kind.isVideo {
                                        Button("คัดลอกภาพ") {
                                            if let image = NSImage(contentsOfFile: item.path) {
                                                NSPasteboard.general.clearContents()
                                                NSPasteboard.general.writeObjects([image])
                                            }
                                        }
                                    }
                                    Divider()
                                    Button("ย้ายไปถังขยะ…", role: .destructive) { pendingDelete = item }
                                }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .confirmationDialog("ย้าย “\(URL(fileURLWithPath: pendingDelete?.path ?? "").lastPathComponent)” ไปถังขยะ?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("ย้ายไปถังขยะ", role: .destructive) {
                if let item = pendingDelete {
                    try? FileManager.default.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
                    model.perform { $0.removeMedia(id: item.id) }
                }
                pendingDelete = nil
            }
            Button("ยกเลิก", role: .cancel) { pendingDelete = nil }
        } message: { Text("กู้คืนได้จากถังขยะ") }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Button("ภาพทั้งจอ") { Task { await capture.screenshot(region: false) } }
                Button("เลือกพื้นที่  ⌃⌥S") { Task { await capture.screenshot(region: true) } }
                Button(capture.isRecording ? "หยุดอัด (\(Int(capture.elapsed))s)" : "อัดหน้าจอ  ⌃⌥V") { capture.toggleRecording() }
                    .tint(capture.isRecording ? .red : nil)
                Button("กล้อง…") { Task { await camera.show() } }
                Spacer()
            }
            HStack(spacing: 16) {
                Stepper("นับถอยหลัง \(game.capture.countdown) วิ", value: Binding(
                    get: { game.capture.countdown },
                    set: { n in model.perform { $0.setCapture { $0.countdown = n }; return [] } }), in: 0...10)
                Toggle("เสียงระบบ", isOn: Binding(
                    get: { game.capture.recordSystemAudio },
                    set: { v in model.perform { $0.setCapture { $0.recordSystemAudio = v }; return [] } }))
                Toggle("ไมค์", isOn: Binding(
                    get: { game.capture.recordMicrophone },
                    set: { v in model.perform { $0.setCapture { $0.recordMicrophone = v }; return [] } }))
                Spacer()
                Picker("แสดง", selection: $filter) {
                    Text("ทั้งหมด").tag(MediaKind?.none)
                    ForEach(MediaKind.allCases, id: \.self) { Text($0.label).tag(MediaKind?.some($0)) }
                }
                .frame(width: 190)
            }
            .font(.caption)
            Text("ภาพเก็บที่ ~/Pictures/Hey · วิดีโอที่ ~/Movies/Hey · หน้าต่างของ Hey! (สัตว์เลี้ยง ฯลฯ) จะไม่ติดในภาพ")
                .font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }
}

private struct MediaCell: View {
    let item: MediaItem
    @State private var image: NSImage?
    @State private var missing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image { Image(nsImage: image).resizable().scaledToFill() }
                    else { Color.gray.opacity(0.15).overlay(Image(systemName: missing ? "questionmark.square.dashed" : "photo").foregroundStyle(.secondary)) }
                }
                .frame(height: 90).clipped().clipShape(RoundedRectangle(cornerRadius: 6))
                if item.kind.isVideo {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                        if let d = item.duration { Text(String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)).monospacedDigit() }
                    }
                    .font(.caption2).padding(4).background(.black.opacity(0.6), in: Capsule()).foregroundStyle(.white).padding(4)
                }
            }
            Text(item.kind.label).font(.caption)
            Text(item.createdAt, format: .dateTime.day().month().hour().minute())
                .font(.caption2).foregroundStyle(.secondary)
        }
        .overlay {
            if !missing {
                DragHandle(writer: { URL(fileURLWithPath: item.path) as NSURL },
                           image: { image ?? NSWorkspace.shared.icon(forFile: item.path) },
                           onFinished: { _ in },
                           onOpen: { NSWorkspace.shared.open(URL(fileURLWithPath: item.path)) })
            }
        }
        .task(id: item.path) {
            let url = URL(fileURLWithPath: item.path)
            guard FileManager.default.fileExists(atPath: item.path) else { missing = true; return }
            let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 260, height: 180),
                                                       scale: 2, representationTypes: .thumbnail)
            if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                image = rep.nsImage
            }
        }
    }
}


// MARK: gestures

private struct GesturesTab: View {
    let model: GameModel
    let game: Game
    let log: GestureLog

    var body: some View {
        let g = game.gestures
        List {
            Section("ท่าบนตัวสัตว์เลี้ยง (ต้องใช้ทัชแพด และวางเมาส์บนตัว)") {
                ForEach(GestureKind.allCases, id: \.self) { kind in
                    Picker(kind.label, selection: Binding(
                        get: { g.action(for: kind) },
                        set: { a in model.perform { $0.setGestures { $0.bind(kind, to: a) }; return [] } })) {
                        ForEach(PetAction.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }
                LabeledContent("ท่าล่าสุดที่รู้จัก") {
                    Text(log.last).foregroundStyle(.secondary)
                }
                Text("ลองปัด/หมุนสองนิ้วบนตัวสัตว์ ถ้าทิศกลับด้านกับที่คาดไว้ ให้สลับคำสั่งของท่านั้น หรือบอกผมเพื่อแก้ให้")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("มุมจอ") {
                Toggle("เปิดมุมจอ", isOn: Binding(
                    get: { g.hotCornersEnabled },
                    set: { v in model.perform { $0.setGestures { $0.hotCornersEnabled = v }; return [] } }))
                if g.hotCornersEnabled {
                    Picker("ค้างเมาส์ไว้", selection: Binding(
                        get: { g.cornerDwell },
                        set: { v in model.perform { $0.setGestures { $0.cornerDwell = v }; return [] } })) {
                        Text("0.3 วินาที").tag(0.3)
                        Text("0.5 วินาที").tag(0.5)
                        Text("1 วินาที").tag(1.0)
                    }
                    ForEach(Corner.allCases, id: \.self) { corner in
                        Picker(corner.label, selection: Binding(
                            get: { g.action(for: corner) },
                            set: { a in model.perform { $0.setGestures { $0.bind(corner, to: a) }; return [] } })) {
                            ForEach(PetAction.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                    Text("ถ้าใช้ Hot Corners ของ macOS อยู่ ให้เลือกมุมที่ไม่ชนกัน")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("ขนาดสัตว์เลี้ยง") {
                HStack {
                    Slider(value: Binding(
                        get: { g.petScale },
                        set: { v in model.performQuietly { $0.setGestures { $0.petScale = v }; return [] } }),
                        in: GestureSettings.minScale...GestureSettings.maxScale) { editing in
                        if !editing { model.save() }
                    }
                    Text("\(Int(g.petScale * 100))%").monospacedDigit().frame(width: 48, alignment: .trailing)
                }
                Text("หรือ pinch สองนิ้วบนตัวสัตว์")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Button("คืนค่าเริ่มต้นของท่าและมุมจอ") {
                    model.perform { $0.setGestures { $0.resetBindings() }; return [] }
                }
            }
        }
    }
}


// MARK: achievements

private struct AchievementsTab: View {
    let game: Game

    var body: some View {
        let done = game.achievements.count
        List {
            Section("ปลดล็อกแล้ว \(done)/\(Achievement.all.count)") {
                ForEach(Achievement.all) { a in
                    let unlockedAt = game.achievements[a.id]
                    let value = min(a.progress(game), a.goal)
                    HStack(spacing: 12) {
                        Image(systemName: unlockedAt == nil ? "lock.fill" : "trophy.fill")
                            .foregroundStyle(unlockedAt == nil ? Color.secondary : Color.yellow)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(a.title).fontWeight(.medium)
                                Spacer()
                                Text("\(a.reward) เหรียญ").font(.caption).foregroundStyle(.secondary)
                            }
                            Text(a.detail).font(.caption).foregroundStyle(.secondary)
                            if let unlockedAt {
                                Text("ได้เมื่อ " + unlockedAt.formatted(.dateTime.day().month().year()))
                                    .font(.caption2).foregroundStyle(.green)
                            } else {
                                ProgressView(value: value, total: a.goal)
                                Text("\(Int(value))/\(Int(a.goal))").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }
}

// MARK: mini-game

@MainActor @Observable
private final class MiniGameState {
    enum Kind { case food(Food), hazard }

    struct Item: Identifiable {
        let id = UUID()
        let kind: Kind
        let points: Int
        let x: Double          // 0...1 across the play area
        let spawnedAt: Date
        let speed: Double      // seconds to fall the whole height
    }

    var items: [Item] = []
    var score = 0
    var timeLeft = MiniGame.seconds
    var running = false
    var finished = false
    var lastReward = 0
    private var started = Date()
    private var nextSpawn = Date()

    func start() {
        items = []; score = 0; timeLeft = MiniGame.seconds
        running = true; finished = false
        started = Date(); nextSpawn = started
    }

    /// Called ~20 times a second while the game is running; returns true on the tick the game ends.
    func tick(now: Date) -> Bool {
        guard running else { return false }
        timeLeft = max(MiniGame.seconds - now.timeIntervalSince(started), 0)
        items.removeAll { now.timeIntervalSince($0.spawnedAt) > $0.speed }
        if now >= nextSpawn, timeLeft > 1 {
            let roll = Double.random(in: 0...1)
            let foods = Balance.standard.foods
            let kind: Kind, pts: Int
            if roll < 0.18 { kind = .hazard; pts = -2 }
            else if roll < 0.28, let honey = foods.first(where: { $0.id == "honey" }) { kind = .food(honey); pts = 3 }
            else { kind = .food(foods.filter { $0.id != "honey" }.randomElement() ?? foods[0]); pts = 1 }
            items.append(Item(kind: kind, points: pts, x: Double.random(in: 0.06...0.94),
                              spawnedAt: now, speed: Double.random(in: 2.2...3.4)))
            nextSpawn = now.addingTimeInterval(Double.random(in: 0.35...0.7))
        }
        if timeLeft <= 0 { running = false; finished = true; items = []; return true }
        return false
    }

    func catchItem(_ item: Item) {
        guard running, items.contains(where: { $0.id == item.id }) else { return }
        items.removeAll { $0.id == item.id }
        score = max(score + item.points, 0)
    }
}

private struct MiniGameTab: View {
    let model: GameModel
    let game: Game
    @State private var state = MiniGameState()
    @State private var ticker = Timer.publish(every: 1.0 / 20, on: .main, in: .common).autoconnect()

    @ViewBuilder private func fallingItem(_ item: MiniGameState.Item) -> some View {
        switch item.kind {
        case .food(let food): FoodIconView(food: food, size: 44)
        case .hazard:
            Image(systemName: "flame.fill").font(.system(size: 34)).foregroundStyle(.red)
                .frame(width: 44, height: 44)
        }
    }

    var body: some View {
        let left = game.miniGamePlaysLeft(at: Date())
        VStack(spacing: 12) {
            HStack {
                Text("แต้ม \(state.score)").font(.title2.weight(.semibold)).monospacedDigit()
                Spacer()
                Text(String(format: "เหลือ %.0f วิ", state.timeLeft)).monospacedDigit().foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20).padding(.top, 12)

            GeometryReader { geo in
                ZStack {
                    Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
                    TimelineView(.animation) { timeline in
                        ZStack {
                            ForEach(state.items) { item in
                                let progress = timeline.date.timeIntervalSince(item.spawnedAt) / item.speed
                                fallingItem(item)
                                    .position(x: item.x * geo.size.width, y: progress * (geo.size.height + 40) - 20)
                                    .onTapGesture { state.catchItem(item) }
                            }
                        }
                    }
                    if !state.running {
                        VStack(spacing: 8) {
                            if state.finished {
                                Text("จบเกม! ได้ \(state.score) แต้ม").font(.title3.weight(.semibold))
                                Text(state.lastReward > 0 ? "ได้รับ \(state.lastReward) เหรียญ" : "วันนี้รับเหรียญครบแล้ว (เล่นเพื่อความสนุกได้)")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("จับอาหารที่ร่วงลงมา").font(.title3.weight(.semibold))
                                Text("อาหารทั่วไป +1 · น้ำผึ้ง +3 · ของอันตราย −2").foregroundStyle(.secondary)
                            }
                            Button(state.finished ? "เล่นอีกครั้ง" : "เริ่ม") { state.start() }
                                .buttonStyle(.glassProminent)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            Text(left > 0 ? "รับเหรียญได้อีก \(left) รอบวันนี้ · ได้เหรียญ = แต้ม ÷ 2 (สูงสุด \(MiniGame.maxRewardPerPlay))"
                          : "รอบที่ได้เหรียญของวันนี้หมดแล้ว · สถิติสูงสุด \(game.stats.miniGameBest) แต้ม")
                .font(.caption).foregroundStyle(.secondary).padding(.bottom, 12)
        }
        .onReceive(ticker) { now in
            if state.tick(now: now) {
                let score = state.score
                let events = model.perform { $0.finishMiniGame(score: score, at: Date()) }
                for case .miniGameFinished(_, let reward) in events { state.lastReward = reward }
            }
        }
    }
}


// MARK: files: the vault (keep) and the shelf (carry)

private struct FilesTab: View {
    let model: GameModel
    let game: Game
    let vault: VaultService
    let shelf: ShelfService
    @State private var page = 0     // 0 = vault, 1 = shelf

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Picker("", selection: $page) {
                    Text("ฝากเก็บ (\(game.vault.count))").tag(0)
                    Text("ถาดพักไฟล์ (\(game.shelf.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(page == 0 ? "เก็บไว้ถาวร ค้นหา ติดแท็ก ปักหมุด — ลากไฟล์เข้าหาสัตว์เลี้ยงแล้วเลือกช่อง “ฝากเก็บ”"
                               : "ที่พักชั่วคราวระหว่างทาง — ลากไฟล์เข้าหาสัตว์เลี้ยงแล้วเลือกช่อง “พักไว้ลากต่อ” จากนั้นลากออกไปวางที่ไหนก็ได้")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            Divider()
            if page == 0 { VaultTab(model: model, game: game, vault: vault) }
            else { ShelfList(model: model, game: game, vault: vault, shelf: shelf) }
            Divider()
            settings
        }
    }

    private var settings: some View {
        HStack(spacing: 16) {
            Picker("ปล่อยลงตัวสัตว์ตรงๆ", selection: Binding(
                get: { game.files.dropDefault },
                set: { d in model.perform { $0.setFiles { $0.dropDefault = d }; return [] } })) {
                ForEach(DropDestination.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .frame(width: 230)
            Toggle("เอาออกจากถาดเมื่อลากออกแล้ว", isOn: Binding(
                get: { game.files.removeAfterDragOut },
                set: { v in model.perform { $0.setFiles { $0.removeAfterDragOut = v }; return [] } }))
            Picker("ถาดล้างเอง", selection: Binding(
                get: { game.files.shelfExpireHours },
                set: { v in model.perform { $0.setFiles { $0.shelfExpireHours = v }; return [] } })) {
                Text("ไม่ล้าง").tag(0)
                Text("6 ชม.").tag(6)
                Text("24 ชม.").tag(24)
                Text("3 วัน").tag(72)
            }
            .frame(width: 150)
        }
        .font(.caption)
        .padding(10)
    }
}

private struct ShelfList: View {
    let model: GameModel
    let game: Game
    let vault: VaultService
    let shelf: ShelfService

    var body: some View {
        List {
            if game.shelf.isEmpty {
                Text("ถาดว่างอยู่ — ลากอะไรก็ได้เข้าหาสัตว์เลี้ยง แล้วปล่อยลงช่อง “พักไว้ลากต่อ”")
                    .foregroundStyle(.secondary)
            }
            ForEach(game.shelf) { item in
                let present = shelf.exists(item)
                HStack(spacing: 10) {
                    Image(nsImage: shelf.icon(for: item)).resizable().frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).lineLimit(1)
                        Text(present ? item.kind == .text ? String((item.text ?? "").prefix(60)) : (item.path ?? item.text ?? "")
                                     : "ไม่พบแล้ว (ถูกย้ายหรือลบ)")
                            .font(.caption).foregroundStyle(present ? Color.secondary : Color.red).lineLimit(1)
                    }
                    Spacer()
                    Button("ฝากเก็บถาวร") { keep(item) }.disabled(!present)
                    Button(role: .destructive) { shelf.remove(item) } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                }
                .padding(.vertical, 2)
                .onDrag { provider(item) }
                .onTapGesture(count: 2) { if present { shelf.open(item) } }
            }
            if !game.shelf.isEmpty {
                Button("ล้างถาดทั้งหมด", role: .destructive) { shelf.clear() }
            }
        }
    }

    private func provider(_ item: ShelfItem) -> NSItemProvider {
        switch item.kind {
        case .file, .folder:
            if let p = item.path, let provider = NSItemProvider(contentsOf: URL(fileURLWithPath: p)) { return provider }
            return NSItemProvider()
        case .link:
            if let t = item.text, let u = URL(string: t) { return NSItemProvider(object: u as NSURL) }
            return NSItemProvider()
        case .text:
            return NSItemProvider(object: (item.text ?? "") as NSString)
        }
    }

    /// Move from the shelf into the vault.
    private func keep(_ item: ShelfItem) {
        switch item.kind {
        case .file, .folder: if let p = item.path { vault.add(.files([URL(fileURLWithPath: p)])) }
        case .link: if let t = item.text, let u = URL(string: t) { vault.add(.links([u])) }
        case .text: if let t = item.text { vault.add(.text(t)) }
        }
        shelf.remove(item)
    }
}

// MARK: settings

private struct SettingsTab: View {
    let model: GameModel
    let game: Game
    let power: PowerMonitor
    let detector: MusicDetector
    @State private var loginMessage = ""
    @State private var loginOn = LoginItem.isEnabled
    @State private var calendarOn = CalendarService.isEnabled
    @AppStorage("hubOpacity") private var hubOpacity = 0.8

    var body: some View {
        List {
            Section("การเคลื่อนไหวของ \(game.pet.state.name)") {
                MotionSettingsControls(model: model, game: game)
            }
            Section("เมนูรอบสัตว์เลี้ยง") {
                RadialMenuEditor(model: model, game: game)
            }
            Section("ปฏิกิริยาต่อสิ่งที่เกิดบนเครื่อง") {
                let r = game.reactions
                Toggle("เปิดปฏิกิริยา", isOn: Binding(
                    get: { r.enabled },
                    set: { v in model.perform { $0.setReactions { $0.enabled = v }; return [] } }))
                Group {
                    Toggle("จิกคีย์บอร์ดจิ๋วเมื่อกำลังพิมพ์", isOn: Binding(
                        get: { r.typing },
                        set: { v in model.perform { $0.setReactions { $0.typing = v }; return [] } }))
                    Toggle("แบตใกล้หมด / เสียบปลั๊ก / แบตเต็ม / เครื่องร้อน", isOn: Binding(
                        get: { r.battery },
                        set: { v in model.perform { $0.setReactions { $0.battery = v }; return [] } }))
                    Toggle("หันมองเมาส์ที่เข้ามาใกล้", isOn: Binding(
                        get: { r.curious },
                        set: { v in model.perform { $0.setReactions { $0.curious = v }; return [] } }))
                    Toggle("เตือนเมื่ออยู่ในแอปเดิมนาน (เขียนโค้ด อ่าน เล่นเกม)", isOn: Binding(
                        get: { r.appStreaks },
                        set: { v in model.perform { $0.setReactions { $0.appStreaks = v }; return [] } }))
                }
                .disabled(!r.enabled)
                Text("นับแค่จำนวนครั้งที่กดแป้น ไม่เห็นว่ากดแป้นอะไร ไม่เก็บข้อมูล และไม่ต้องขอสิทธิ์ใดๆ · หลับเองเมื่อไม่ได้ใช้เครื่อง 3 นาที · ง่วงตอนดึก · ตื่นพร้อมหาวหลังเครื่องหลับ")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Section("หน้าตา Hub") {
                LabeledContent("ความทึบของพื้นหลัง") {
                    HStack {
                        Slider(value: $hubOpacity, in: 0.2...1)
                        Text("\(Int(hubOpacity * 100))%").monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    }.frame(maxWidth: 260)
                }
                Text("ลดลงเพื่อให้เห็นเดสก์ท็อปทะลุหน้าต่าง กระจกของแต่ละการ์ดยังคงอยู่")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Section("ปฏิทิน") {
                Toggle("เตือนก่อนนัดหมายถึง 10 นาที", isOn: Binding(
                    get: { calendarOn },
                    set: { v in
                        calendarOn = v
                        UserDefaults.standard.set(v, forKey: CalendarService.enabledKey)
                        if v { Task { if await !CalendarService.requestAccess() {
                            calendarOn = false
                            UserDefaults.standard.set(false, forKey: CalendarService.enabledKey)
                        } } }
                    }))
                Text("อ่านเฉพาะชื่อและเวลานัดหมายใน 30 นาทีข้างหน้า ไม่แก้ไขปฏิทิน ไม่เก็บข้อมูล และจะขอสิทธิ์ปฏิทินเมื่อเปิดสวิตช์นี้ครั้งแรก")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Section("ประหยัดพลังงาน") {
                let d = power.decision
                LabeledContent("ตอนนี้") {
                    Text("\(d.tier.label)\(d.reason.isEmpty ? "" : " · \(d.reason)")").foregroundStyle(.secondary)
                }
                Toggle("ซ่อนสัตว์เลี้ยงเมื่อมีแอปเต็มจอ", isOn: Binding(
                    get: { game.power.hideDuringFullscreen },
                    set: { v in model.perform { $0.setPower { $0.hideDuringFullscreen = v }; return [] }; power.evaluate() }))
                Picker("พักเมื่อไม่ได้ใช้เครื่อง", selection: Binding(
                    get: { game.power.dormantAfterIdleMinutes },
                    set: { v in model.perform { $0.setPower { $0.dormantAfterIdleMinutes = v }; return [] }; power.evaluate() })) {
                    Text("ไม่พัก").tag(0)
                    Text("5 นาที").tag(5)
                    Text("10 นาที").tag(10)
                    Text("30 นาที").tag(30)
                }
                Toggle("ให้สัตว์เลี้ยงโตแล้วเดิน/ยืนบนหน้าต่างอื่น", isOn: Binding(
                    get: { game.power.walkOnWindows },
                    set: { v in model.perform { $0.setPower { $0.walkOnWindows = v }; return [] } }))
                Toggle("เปิด Hey! อัตโนมัติเมื่อเข้าสู่ระบบ", isOn: Binding(
                    get: { loginOn },
                    set: { v in
                        if let message = LoginItem.set(v) { loginMessage = message }
                        else { loginMessage = "" }
                        loginOn = LoginItem.isEnabled
                    }))
                    .disabled(!LoginItem.isAvailable)
                if !loginMessage.isEmpty { Text(loginMessage).font(.caption).foregroundStyle(.orange) }
                if !LoginItem.isAvailable { Text("ตัวเลือกนี้ใช้ได้เมื่อรันจาก Hey.app").font(.caption).foregroundStyle(.secondary) }
                Text("ใช้แบตต่ำ/Low Power/เครื่องร้อน จะลดเฟรมเรตลงอัตโนมัติ · หน้าจอดับหรือล็อกจะหยุดวาดสัตว์ แต่เตือนและภารกิจยังทำงานต่อ")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Section("เพลง") {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("แสดงชื่อเพลงวิ่งบนแถบเมนูขณะเล่น", isOn: Binding(
                    get: { game.music.showInMenuBar },
                    set: { v in model.perform { $0.setMusic { $0.showInMenuBar = v }; return [] } }))
                Toggle("เสนอให้เพิ่มเมื่อคัดลอกลิงก์ YouTube", isOn: Binding(
                    get: { game.music.detectClipboard },
                    set: { v in model.perform { $0.setMusic { $0.detectClipboard = v }; return [] } }))
                Toggle("เสนอให้เพิ่มวิดีโอ YouTube ที่เปิดอยู่ในแท็บหน้าสุดของเบราว์เซอร์", isOn: Binding(
                    get: { game.music.detectBrowser },
                    set: { v in model.perform { $0.setMusic { $0.detectBrowser = v }; return [] } }))
                Toggle("(ทดลอง) อ่านเพลงที่กำลังเล่นจากระบบ — เสนอเพิ่มเข้าเพลย์ลิสต์ และโชว์ชื่อเพลงวิ่งบนแถบเมนูแม้เล่นในเบราว์เซอร์", isOn: Binding(
                    get: { game.music.detectNowPlaying },
                    set: { v in model.perform { $0.setMusic { $0.detectNowPlaying = v }; return [] } }))
                if game.music.detectNowPlaying {
                    Text(NowPlayingReader.libraryURL == nil
                         ? "ไม่พบไฟล์ libheynp.dylib จึงใช้ไม่ได้"
                         : "ใช้ API ส่วนตัวของ macOS (Apple ปิดได้เมื่อไรก็ได้) · รู้ว่ากำลังเล่นอะไรแล้วหาแท็บ YouTube ที่ตรงกันเพื่อเอาลิงก์ จึงต้องอนุญาตระบบอัตโนมัติ · ไม่เก็บ ไม่ส่งออกไปไหน")
                        .font(.caption2).foregroundStyle(NowPlayingReader.libraryURL == nil ? Color.orange : Color.secondary)
                }
                if game.music.detectBrowser {
                    Text(detector.browserNote ?? "รองรับ Safari, Chrome, Arc, Brave, Edge · macOS จะถามสิทธิ์ควบคุมเบราว์เซอร์ครั้งแรก · อ่านเฉพาะ URL ของแท็บหน้าสุด และใช้เฉพาะเมื่อเป็นหน้า YouTube")
                        .font(.caption2).foregroundStyle(detector.browserNote == nil ? Color.secondary : Color.orange)
                }
            }
            }
            Section("เกี่ยวกับ") {
                AboutSection(model: model)
            }
        }
    }
}

/// Version, links, where the data lives and the credits.
private struct AboutSection: View {
    let model: GameModel

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        guard let short else { return "รันจากซอร์สโค้ด (ไม่ใช่ Hey.app)" }
        return build.map { "\(short) (\($0))" } ?? short
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable().frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hey!").font(.title3.weight(.bold))
                Text("เพื่อนตัวน้อยบนเดสก์ท็อป Mac").font(.callout).foregroundStyle(.secondary)
                Text("เวอร์ชัน \(version) · ต้องใช้ macOS 26 ขึ้นไป").font(.caption).foregroundStyle(.secondary)
            }
        }
        HStack(spacing: 10) {
            if let site = URL(string: "https://giganto-th.github.io/hey/") { Link("เว็บไซต์", destination: site) }
            if let repo = URL(string: "https://github.com/giganto-th/hey") { Link("GitHub", destination: repo) }
            if let release = URL(string: "https://github.com/giganto-th/hey/releases/latest") { Link("ดาวน์โหลดเวอร์ชันล่าสุด", destination: release) }
            if let video = URL(string: "https://www.youtube.com/watch?v=JBi-y-_I9jk") { Link("วิดีโอแนะนำ", destination: video) }
        }
        LabeledContent("โฟลเดอร์ข้อมูล") {
            Button("แสดงใน Finder") { NSWorkspace.shared.activateFileViewerSelecting([model.directory]) }
        }
        Text(model.directory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
            .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
        Text("ข้อมูลทั้งหมด (สัตว์เลี้ยง โน้ต ไฟล์ที่ฝาก) เก็บในเครื่องนี้เท่านั้น ไม่ส่งออกไปไหน ตัวละคร Hei Hei เป็นแฟนอาร์ตจากภาพยนตร์ Moana ของ Disney ทำไว้ใช้ส่วนตัว")
            .font(.caption2).foregroundStyle(.secondary)
    }
}

/// Pick which commands sit on the ring around the pet and in what order; the rest wait in the group folders.
private struct RadialMenuEditor: View {
    let model: GameModel
    let game: Game

    var body: some View {
        let menu = game.radialMenu
        Text("เลือก \(RadialMenuSettings.minPinned)–\(RadialMenuSettings.maxPinned) คำสั่งที่อยากให้อยู่บนวงแรก ที่เหลือจะรวมอยู่ในโฟลเดอร์ จับภาพ / จดและเตือน / อื่น ๆ")
            .font(.caption).foregroundStyle(.secondary)
        ForEach(menu.pinned, id: \.self) { action in
            HStack {
                Image(systemName: action.symbol).frame(width: 22).foregroundStyle(.tint)
                Text(action.label)
                Spacer()
                Button { change { $0.move(action, by: -1) } } label: { Image(systemName: "chevron.up") }
                    .disabled(menu.pinned.first == action)
                Button { change { $0.move(action, by: 1) } } label: { Image(systemName: "chevron.down") }
                    .disabled(menu.pinned.last == action)
                Button { change { $0.setPinned(action, false) } } label: { Image(systemName: "minus.circle") }
                    .disabled(action == .hub || menu.pinned.count <= RadialMenuSettings.minPinned)
                    .help("ย้ายเข้าโฟลเดอร์")
            }
            .buttonStyle(.borderless)
        }
        if !menu.rest.isEmpty {
            Text("อยู่ในโฟลเดอร์").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
            ForEach(menu.rest, id: \.self) { action in
                HStack {
                    Image(systemName: action.symbol).frame(width: 22).foregroundStyle(.secondary)
                    Text(action.label)
                    Spacer()
                    Button { change { $0.setPinned(action, true) } } label: { Image(systemName: "plus.circle") }
                        .disabled(menu.pinned.count >= RadialMenuSettings.maxPinned)
                        .help("ย้ายขึ้นวงแรก")
                }
                .buttonStyle(.borderless)
            }
        }
        Button("คืนค่าเริ่มต้น") { change { $0.reset() } }
    }

    private func change(_ edit: @escaping (inout RadialMenuSettings) -> Void) {
        model.perform { $0.setRadialMenu { edit(&$0) }; return [] }
    }
}
