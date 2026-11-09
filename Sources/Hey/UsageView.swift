import SwiftUI
import HeyDomain

/// The real logo of each provider: the icon of its installed app (nothing is bundled or downloaded), or a plain symbol if it isn't installed.
@MainActor
enum ProviderLogo {
    private static var cache: [AIProvider: NSImage] = [:]
    private static var menuBarCache: [AIProvider: NSImage] = [:]

    static func fallbackSymbol(_ provider: AIProvider) -> String {
        switch provider {
        case .claude: "asterisk.circle.fill"
        case .codex: "bubble.left.fill"
        case .antigravity: "sparkles"
        }
    }

    static func menuBarImage(_ provider: AIProvider) -> NSImage? {
        if let hit = menuBarCache[provider] { return hit }
        let icon: NSImage?
        if let installed = image(provider) {
            icon = installed.copy() as? NSImage
        } else {
            icon = NSImage(systemSymbolName: fallbackSymbol(provider), accessibilityDescription: provider.label)
        }
        icon?.size = NSSize(width: 16, height: 16)
        menuBarCache[provider] = icon
        return icon
    }

    private static func candidates(_ provider: AIProvider) -> [String] {
        switch provider {
        case .claude: ["/Applications/Claude.app"]
        case .codex: ["/Applications/ChatGPT.app", "/Applications/Codex.app"]
        case .antigravity: ["/Applications/Antigravity.app", "/Applications/Antigravity IDE.app"]
        }
    }

    static func image(_ provider: AIProvider) -> NSImage? {
        if let hit = cache[provider] { return hit }
        for path in candidates(provider) where FileManager.default.fileExists(atPath: path) {
            let icon = NSWorkspace.shared.icon(forFile: path)
            cache[provider] = icon
            return icon
        }
        return nil
    }
}

struct ProviderLogoView: View {
    let provider: AIProvider
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let image = ProviderLogo.image(provider) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: ProviderLogo.fallbackSymbol(provider))
                    .resizable().scaledToFit().foregroundStyle(.secondary).padding(size * 0.15)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Hub › AI credits: every connected AI account in a list, each with its provider's logo, its quota bars and the time they reset.
struct UsageTab: View {
    let service: AIUsageService
    @State private var adding = ProcessInfo.processInfo.environment["HEY_DEV_USAGE_ADD"] != nil      // dev: open the sheet to look at it

    var body: some View {
        let now = Date()
        let all = AIProvider.allCases.flatMap { service.rows(for: $0) }
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("บัญชี AI ของคุณ")).font(.headline)
                        if let last = service.lastRefresh {
                            Text(tr("อัปเดตล่าสุด {0}", last.formatted(date: .omitted, time: .shortened))).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if service.refreshing { ProgressView().controlSize(.small) }
                    Button(tr("รีเฟรช")) { Task { await service.refresh() } }.disabled(service.refreshing)
                    Button { adding = true } label: { Label(tr("เพิ่มบัญชี AI"), systemImage: "plus.circle.fill") }
                        .buttonStyle(.borderedProminent)
                }
            }
            UsageMenuBarSection(service: service, accounts: all)
            Section {
                if all.isEmpty {
                    Text(service.refreshing ? tr("กำลังอ่านข้อมูล…") : tr("ยังไม่มีบัญชี — กด เพิ่มบัญชี AI เพื่อเริ่ม"))
                        .foregroundStyle(.secondary)
                }
                ForEach(all) { row in AccountCard(row: row, service: service, now: now) }
                if !service.hiddenAccountIDs.isEmpty {
                    Button(tr("แสดงบัญชีที่ซ่อนอีกครั้ง")) { service.restoreHiddenAccounts() }
                }
            }
            Section(tr("ผู้ให้บริการที่เช็ค")) {
                ForEach(AIProvider.allCases) { provider in
                    HStack(spacing: 10) {
                        ProviderLogoView(provider: provider, size: 24)
                        Toggle(provider.label, isOn: Binding(
                            get: { service.isEnabled(provider) }, set: { service.setEnabled(provider, $0) }))
                    }
                }
                Text(tr("ChatGPT และ Claude แบบแชตบนเว็บไม่มี API จึงดูโควตาแชตไม่ได้ ดูได้เฉพาะโควตาของ Codex และ Claude Code ตามแพ็กเกจเดียวกัน และโควตาของ Antigravity"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Section(tr("การเตือน")) {
                Toggle(tr("ให้สัตว์เลี้ยงเตือนเมื่อใช้โควตาไปแล้ว 80% และ 95%"), isOn: Binding(
                    get: { service.alertsEnabled }, set: { service.alertsEnabled = $0 }))
                Stepper(tr("เตือนครั้งแรกเมื่อใช้ไป {0}%", service.warnAt), value: Binding(
                    get: { service.warnAt }, set: { service.warnAt = $0 }), in: 50...95, step: 5)
                Stepper(tr("เตือนอีกครั้งเมื่อใช้ไป {0}%", service.criticalAt), value: Binding(
                    get: { service.criticalAt }, set: { service.criticalAt = $0 }), in: 60...100, step: 5)
                Toggle(tr("แจ้งเตือนผ่านศูนย์การแจ้งเตือนของ macOS ด้วย"), isOn: Binding(
                    get: { service.systemNotify }, set: { service.systemNotify = $0 }))
                Text(tr("เตือนครั้งเดียวต่อระดับในแต่ละช่วงโควตาของแต่ละบัญชี"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .task { await service.refresh() }
        .sheet(isPresented: $adding) { AddAccountSheet(service: service) { adding = false } }
    }
}

/// Compact menu-bar preferences live beside the accounts they describe.
private struct UsageMenuBarSection: View {
    @Bindable var service: AIUsageService
    let accounts: [AIUsageService.AccountRow]

    private var selectedUsages: [ProviderUsage] {
        service.menuBarSettings.usages(from: accounts.compactMap(\.usage))
    }

    private var windows: [UsageWindow] {
        var seen = Set<String>()
        let candidates = accounts.filter { service.menuBarSettings.accountIDs.isEmpty || service.menuBarSettings.accountIDs.contains($0.id) }
            .compactMap(\.usage).flatMap(\.windows)
        let available = candidates.filter { seen.insert($0.id).inserted }
        if available.contains(where: { $0.id == service.menuBarSettings.windowID }) { return available }
        return [UsageWindow(id: service.menuBarSettings.windowID, usedPercent: 0, resetsAt: nil)] + available
    }

    var body: some View {
        Section(tr("แถบเมนู")) {
            Toggle(tr("แสดงโควตา AI บนแถบเมนู"), isOn: $service.menuBarSettings.enabled)
            Group {
                Text(tr("เลือกบัญชีที่แสดง (เลือกได้หลายบัญชี)")).font(.subheadline)
                ForEach(accounts.indices, id: \.self) { index in
                    let row = accounts[index]
                    Toggle(isOn: Binding(
                        get: { service.menuBarSettings.accountIDs.contains(row.id) },
                        set: { selected in
                            if selected { service.menuBarSettings.accountIDs.append(row.id) }
                            else { service.menuBarSettings.accountIDs.removeAll { $0 == row.id } }
                        })) {
                            HStack(spacing: 6) {
                                ProviderLogoView(provider: row.provider, size: 18)
                                Text("\(row.provider.label) · \(row.name)")
                            }
                        }
                        .id("menuBarSelection.\(row.id)")
                }
                ForEach(service.menuBarSettings.accountIDs.filter { id in !accounts.contains { $0.id == id } }, id: \.self) { id in
                    HStack {
                        Text(tr("บัญชีที่เลือกไม่พร้อมใช้งาน")).foregroundStyle(.secondary)
                        Spacer()
                        Button(tr("เอาบัญชีนี้ออกจากรายการ")) { service.menuBarSettings.accountIDs.removeAll { $0 == id } }
                    }
                }
                if service.menuBarSettings.accountIDs.isEmpty {
                    Text(tr("อัตโนมัติ (บัญชีแรกที่มีช่วงโควตานี้)")).font(.caption).foregroundStyle(.secondary)
                }
                Picker(tr("ช่วงโควตา"), selection: $service.menuBarSettings.windowID) {
                    ForEach(windows) { window in Text(window.label).tag(window.id) }
                }
                Picker(tr("เปอร์เซ็นต์ที่แสดง"), selection: $service.menuBarSettings.percentMode) {
                    ForEach(UsageMenuBarSettings.PercentMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                Toggle(tr("แสดงเวลานับถอยหลังจนรีเซ็ต"), isOn: $service.menuBarSettings.showReset)
            }
            .disabled(!service.menuBarSettings.enabled)
            if service.menuBarSettings.enabled {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    if !selectedUsages.isEmpty {
                        Text(tr("ตัวอย่าง")).font(.subheadline)
                        ForEach(selectedUsages, id: \.accountID) { usage in
                            if let window = usage.windows.first(where: { $0.id == service.menuBarSettings.windowID }) {
                                HStack(spacing: 5) {
                                    if let icon = ProviderLogo.menuBarImage(usage.provider) {
                                        Image(nsImage: icon).accessibilityLabel(usage.provider.label)
                                    }
                                    Text(service.menuBarSettings.text(for: window, now: context.date)).monospacedDigit()
                                    Spacer()
                                    Text(accounts.first { $0.id == usage.accountID }?.name ?? usage.title)
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                .accessibilityLabel("\(usage.title) · \(service.menuBarSettings.percentMode.label) \(service.menuBarSettings.text(for: window, now: context.date))")
                                if service.menuBarSettings.showReset && window.resetsAt == nil {
                                    Text(tr("ไม่มีเวลารีเซ็ตสำหรับช่วงโควตานี้")).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        if !Set(service.menuBarSettings.accountIDs).isSubset(of: Set(selectedUsages.map(\.accountID))) {
                            Text(tr("บางบัญชีไม่มีข้อมูลของช่วงโควตาที่เลือก จะแสดงเฉพาะบัญชีที่มีข้อมูล"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(service.refreshing ? tr("กำลังอ่านข้อมูล…") : tr("ยังไม่มีข้อมูลของบัญชีหรือช่วงโควตาที่เลือก — เลือกบัญชีอื่นหรือกดรีเฟรช"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text(tr("แสดงพร้อมไอคอนผู้ให้บริการ โดยสถานะอัดหน้าจอและ Pomodoro จะแสดงก่อน · ↻ คือเวลาที่เหลือจนรีเซ็ตของช่วงที่เลือก"))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// One account: logo, name, plan and its quota windows.
private struct AccountCard: View {
    let row: AIUsageService.AccountRow
    let service: AIUsageService
    let now: Date
    @State private var confirmingRemoval = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProviderLogoView(provider: row.provider, size: 40)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(row.name).fontWeight(.semibold).lineLimit(1)
                    Text(row.provider.label).font(.caption).padding(.horizontal, 7).padding(.vertical, 2).background(.quaternary, in: Capsule())
                    if let plan = row.usage?.plan {
                        Text(plan.capitalized).font(.caption.weight(.medium)).padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.25), in: Capsule())
                    }
                    Spacer()
                    Button { confirmingRemoval = true } label: { Image(systemName: "xmark.circle") }
                        .buttonStyle(.borderless)
                        .help(tr("เอาบัญชีนี้ออกจากรายการ"))
                        .accessibilityLabel(tr("เอาบัญชีนี้ออกจากรายการ"))
                }
                if let usage = row.usage {
                    ForEach(usage.windows) { window in WindowRow(window: window, now: now).id("\(row.id).\(window.id)") }
                    if let note = usage.creditsNote { Text(note).font(.caption).foregroundStyle(.secondary) }
                    if row.stale || row.provider == .codex {
                        Text(row.stale ? tr("ค่าล่าสุดเมื่อ {0} (ไม่ได้เปิดอยู่)", usage.asOf.formatted(date: .abbreviated, time: .shortened))
                                       : tr("ค่าล่าสุดที่ Codex บันทึกไว้เมื่อ {0}", usage.asOf.formatted(date: .abbreviated, time: .shortened)))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                } else if let error = row.error {
                    Text(error).font(.callout).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog(tr("เอาบัญชีนี้ออกจากรายการ"), isPresented: $confirmingRemoval, titleVisibility: .visible) {
            Button(tr("เอาบัญชีนี้ออกจากรายการ"), role: .destructive, action: remove)
            Button(tr("ยกเลิก"), role: .cancel) { }
        } message: {
            Text(row.removable
                 ? tr("เอา {0} ออกจาก Hey เท่านั้น ไม่ลบบัญชีหรือออกจากระบบในแอปต้นทาง", row.name)
                 : tr("ซ่อน {0} จาก Hey และหยุดการเตือน นำกลับได้ด้วย แสดงบัญชีที่ซ่อนอีกครั้ง โดยไม่ลบข้อมูลเข้าสู่ระบบ", row.name))
        }
    }

    private func remove() {
        guard row.removable else { service.hideAccount(row.id); return }
        switch row.provider {
        case .claude: service.disconnect(row.id)
        case .codex: service.removeCodexHome(row.id)
        case .antigravity: service.forgetAntigravity(row.id)
        }
    }
}

/// Pick a provider (by its logo) and see how to add one more of its accounts.
private struct AddAccountSheet: View {
    let service: AIUsageService
    let done: () -> Void
    @State private var provider: AIProvider = .claude

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("เพิ่มบัญชี AI")).font(.title2.weight(.bold))
            HStack(spacing: 12) {
                ForEach(AIProvider.allCases) { p in
                    Button { provider = p } label: {
                        VStack(spacing: 8) {
                            ProviderLogoView(provider: p, size: 56)
                            Text(p.label).font(.callout.weight(.medium)).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(provider == p ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(provider == p ? Color.accentColor : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    switch provider {
                    case .claude: ClaudeConnect(service: service)
                    case .codex: CodexConnect(service: service)
                    case .antigravity:
                        Text(tr("เปิด Antigravity (หรือ Antigravity IDE) ด้วยบัญชีที่ต้องการ Hey! จะเห็นและจำค่าไว้เอง เปิดสองตัวพร้อมกันด้วยสองบัญชีก็ได้ ถ้าสลับบัญชีในตัวเดียวกัน ค่าของบัญชีที่ปิดไปจะค้างเป็นค่าล่าสุดจนกว่าจะเปิดอีก"))
                            .font(.callout).foregroundStyle(.secondary)
                        Text(tr("ถามโควตาจากเซิร์ฟเวอร์ในเครื่องของ Antigravity ที่กำลังเปิดอยู่ (ไม่ใช้อินเทอร์เน็ต) แต่ละตัวที่เปิดอยู่คือหนึ่งบัญชี"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button(tr("เสร็จ")) { service.setEnabled(provider, true); Task { await service.refresh() }; done() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 560, height: 520)
    }
}

private struct WindowRow: View {
    let window: UsageWindow
    let now: Date

    var body: some View {
        let used = window.effectivePercent(at: now)
        HStack(spacing: 10) {
            Text(window.label).lineLimit(1).truncationMode(.tail).help(window.label)
                .frame(width: 170, alignment: .leading)
            ProgressView(value: used, total: 100).tint(color(used))
            Text("\(Int(used.rounded()))%").monospacedDigit().fontWeight(.semibold).foregroundStyle(color(used))
                .frame(width: 44, alignment: .trailing)
            Text(resetText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                .frame(width: 140, alignment: .trailing)
        }
    }

    private var resetText: String {
        guard let reset = window.resetsAt else { return "" }
        return window.isExpired(at: now) ? tr("รีเซ็ตแล้ว") : tr("รีเซ็ตในอีก {0}", UsageText.until(reset, now: now))
    }

    private func color(_ used: Double) -> Color { used >= 95 ? .red : (used >= 80 ? .orange : .green) }
}

private struct CodexConnect: View {
    let service: AIUsageService
    private let command = "CODEX_HOME=~/.codex-2 codex login"

    var body: some View {
        Text(tr("อ่านจากไฟล์ session ของ Codex ในเครื่อง (~/.codex/sessions) ไม่ใช้อินเทอร์เน็ต ตัวเลขจะเก่าถ้าไม่ได้ใช้ Codex สักพัก"))
            .font(.caption2).foregroundStyle(.secondary)
        Text(tr("บัญชี Codex อื่น: เปิด Terminal รันคำสั่งนี้เพื่อเข้าสู่ระบบด้วยบัญชีที่สอง (โฟลเดอร์ ~/.codex-2 จะถูกพบเอง) แล้วใช้ Codex ด้วย CODEX_HOME เดียวกัน หรือเพิ่มโฟลเดอร์ Codex ที่อยู่ที่อื่นเอง"))
            .font(.caption).foregroundStyle(.secondary)
        HStack {
            Text(command).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
            Spacer()
            Button(tr("คัดลอกคำสั่ง")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(command, forType: .string) }
        }
        Button(tr("เพิ่มโฟลเดอร์ Codex…")) {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.message = tr("เลือกโฟลเดอร์ที่ Codex ใช้เก็บข้อมูล (มี sessions และ auth.json)")
            if panel.runModal() == .OK, let url = panel.url { service.addCodexHome(url) }
        }
    }
}

/// Connect a Claude account by hand: the second login on this Mac, or one that is not in Claude Code at all.
private struct ClaudeConnect: View {
    let service: AIUsageService
    @State private var name = ""
    @State private var token = ""
    @State private var message: String?
    @State private var working = false

    private let command = "CLAUDE_CONFIG_DIR=~/.claude-2 claude"

    var body: some View {
        Text(tr("ใช้การเข้าสู่ระบบของ Claude Code ใน Keychain และบัญชีที่คุณเชื่อมต่อเอง แล้วถามโควตาจาก api.anthropic.com โดยตรง (endpoint ที่ไม่เป็นทางการ Anthropic เปลี่ยนได้ทุกเมื่อ) ไม่ส่งไปที่อื่น"))
            .font(.caption2).foregroundStyle(.secondary)
        Text(tr("วิธีที่ 1 — ให้ Hey! หาเอง: เปิด Terminal รันคำสั่งนี้ แล้วพิมพ์ /login เข้าด้วยบัญชีที่สอง จากนั้นกดรีเฟรช บัญชีจะโผล่ขึ้นเอง (ถ้าโทเคนหมดอายุ ให้เปิดคำสั่งเดิมอีกครั้งเพื่อต่ออายุ)"))
            .font(.caption).foregroundStyle(.secondary)
        HStack {
            Text(command).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
            Spacer()
            Button(tr("คัดลอกคำสั่ง")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(command, forType: .string) }
        }
        Text(tr("วิธีที่ 2 — วางโทเคนเอง: รัน claude setup-token ด้วยบัญชีนั้น แล้ววางโทเคนที่ได้ด้านล่าง โทเคนเก็บใน Keychain ของเครื่องนี้เท่านั้น (ถ้า Anthropic ไม่ให้โทเคนแบบนี้อ่านโควตา จะขึ้นข้อความแจ้ง)"))
            .font(.caption).foregroundStyle(.secondary)
        TextField(tr("ชื่อบัญชี (เช่น งาน)"), text: $name)
        SecureField(tr("โทเคน"), text: $token)
        HStack {
            Button(tr("เชื่อมต่อ")) {
                working = true
                Task {
                    message = await service.connect(name: name, token: token)
                    if message == nil { name = ""; token = "" }
                    working = false
                }
            }
            .disabled(token.isEmpty || working)
            if working { ProgressView().controlSize(.small) }
            if let message { Text(message).font(.caption).foregroundStyle(.orange) }
        }
    }
}
