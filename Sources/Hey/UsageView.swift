import SwiftUI
import HeyDomain

/// Hub › AI credits: how much of each AI subscription's quota is used, with the time it resets.
struct UsageTab: View {
    let service: AIUsageService

    var body: some View {
        let now = Date()
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("โควตา AI ที่สมัครไว้")).font(.headline)
                        if let last = service.lastRefresh {
                            Text(tr("อัปเดตล่าสุด {0}", last.formatted(date: .omitted, time: .shortened))).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if service.refreshing { ProgressView().controlSize(.small) }
                    Button(tr("รีเฟรช")) { Task { await service.refresh() } }.disabled(service.refreshing)
                }
            }
            Section(AIProvider.claude.label) {
                Toggle(tr("เช็คโควตา Claude"), isOn: Binding(
                    get: { service.isEnabled(.claude) }, set: { service.setEnabled(.claude, $0) }))
                if service.isEnabled(.claude) {
                    if service.claudeRows.isEmpty {
                        Text(service.refreshing ? tr("กำลังอ่านข้อมูล…") : tr("ยังไม่พบบัญชี Claude — เข้าสู่ระบบ Claude Code หรือเชื่อมต่อบัญชีด้านล่าง"))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(service.claudeRows) { row in ClaudeAccountRow(row: row, service: service, now: now) }
                }
                Text(tr("ใช้การเข้าสู่ระบบของ Claude Code ใน Keychain และบัญชีที่คุณเชื่อมต่อเอง แล้วถามโควตาจาก api.anthropic.com โดยตรง (endpoint ที่ไม่เป็นทางการ Anthropic เปลี่ยนได้ทุกเมื่อ) ไม่ส่งไปที่อื่น"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if service.isEnabled(.claude) { ConnectAccountSection(service: service) }
            Section(AIProvider.codex.label) {
                Toggle(tr("เช็คโควตา Codex"), isOn: Binding(
                    get: { service.isEnabled(.codex) }, set: { service.setEnabled(.codex, $0) }))
                if service.isEnabled(.codex) {
                    if let usage = service.codexUsage {
                        ForEach(usage.windows) { window in WindowRow(window: window, now: now).id("codex.\(window.id)") }
                        if let note = usage.creditsNote { Text(note).font(.caption).foregroundStyle(.secondary) }
                        Text(tr("ค่าล่าสุดที่ Codex บันทึกไว้เมื่อ {0}", usage.asOf.formatted(date: .abbreviated, time: .shortened)))
                            .font(.caption2).foregroundStyle(.secondary)
                    } else if let error = service.codexError {
                        Text(error).font(.callout).foregroundStyle(.orange)
                    } else {
                        Text(tr("กำลังอ่านข้อมูล…")).foregroundStyle(.secondary)
                    }
                }
                Text(tr("อ่านจากไฟล์ session ของ Codex ในเครื่อง (~/.codex/sessions) ไม่ใช้อินเทอร์เน็ต ตัวเลขจะเก่าถ้าไม่ได้ใช้ Codex สักพัก"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Section(tr("การเตือน")) {
                Toggle(tr("ให้สัตว์เลี้ยงเตือนเมื่อใช้โควตาไปแล้ว 80% และ 95%"), isOn: Binding(
                    get: { service.alertsEnabled }, set: { service.alertsEnabled = $0 }))
                Text(tr("เตือนครั้งเดียวต่อระดับในแต่ละช่วงโควตา ChatGPT และ Claude แบบแชตบนเว็บไม่มี API จึงดูโควตาแชตไม่ได้ ดูได้เฉพาะโควตาของ Codex และ Claude Code ตามแพ็กเกจเดียวกัน"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .task { await service.refresh() }
    }
}

private struct WindowRow: View {
    let window: UsageWindow
    let now: Date

    var body: some View {
        let used = window.effectivePercent(at: now)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(window.label)
                Spacer()
                Text("\(Int(used.rounded()))%").monospacedDigit().foregroundStyle(color(used)).fontWeight(.semibold)
            }
            ProgressView(value: used, total: 100).tint(color(used))
            if let reset = window.resetsAt {
                Text(window.isExpired(at: now) ? tr("รีเซ็ตแล้ว") : tr("รีเซ็ตในอีก {0}", UsageText.until(reset, now: now)))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func color(_ used: Double) -> Color { used >= 95 ? .red : (used >= 80 ? .orange : .green) }
}

private struct ClaudeAccountRow: View {
    let row: AIUsageService.ClaudeRow
    let service: AIUsageService
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "person.crop.circle").foregroundStyle(.secondary)
                Text(row.name).fontWeight(.semibold)
                if let plan = row.usage?.plan { Text(plan.capitalized).font(.caption).padding(.horizontal, 6).padding(.vertical, 1)
                    .background(.quaternary, in: Capsule()) }
                Spacer()
                if row.removable {
                    Button(role: .destructive) { service.disconnect(row.id) } label: { Image(systemName: "xmark.circle") }
                        .buttonStyle(.borderless).help(tr("ยกเลิกการเชื่อมต่อบัญชีนี้"))
                }
            }
            if let usage = row.usage {
                ForEach(usage.windows) { window in WindowRow(window: window, now: now).id("\(row.id).\(window.id)") }
            } else if let error = row.error {
                Text(error).font(.callout).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Connect a Claude account by hand: the second login on this Mac, or one that is not in Claude Code at all.
private struct ConnectAccountSection: View {
    let service: AIUsageService
    @State private var name = ""
    @State private var token = ""
    @State private var message: String?
    @State private var working = false

    private let command = "CLAUDE_CONFIG_DIR=~/.claude-2 claude"

    var body: some View {
        Section(tr("เชื่อมต่อบัญชี Claude เพิ่ม")) {
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
}
