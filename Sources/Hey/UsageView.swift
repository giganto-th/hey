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
            ForEach(AIProvider.allCases) { provider in
                Section(provider.label) {
                    Toggle(provider == .claude ? tr("เช็คโควตา Claude") : tr("เช็คโควตา Codex"), isOn: Binding(
                        get: { service.isEnabled(provider) }, set: { service.setEnabled(provider, $0) }))
                    if service.isEnabled(provider) {
                        if let usage = service.usages[provider] {
                            if let plan = usage.plan { LabeledContent(tr("แพ็กเกจ")) { Text(plan.capitalized).foregroundStyle(.secondary) } }
                            ForEach(usage.windows) { window in WindowRow(window: window, now: now).id("\(provider.rawValue).\(window.id)") }
                            if let note = usage.creditsNote { Text(note).font(.caption).foregroundStyle(.secondary) }
                            if provider == .codex {
                                Text(tr("ค่าล่าสุดที่ Codex บันทึกไว้เมื่อ {0}", usage.asOf.formatted(date: .abbreviated, time: .shortened)))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        } else if let error = service.errors[provider] {
                            Text(error).font(.callout).foregroundStyle(.orange)
                        } else {
                            Text(tr("กำลังอ่านข้อมูล…")).foregroundStyle(.secondary)
                        }
                    }
                    Text(note(for: provider)).font(.caption2).foregroundStyle(.secondary)
                }
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

    private func note(for provider: AIProvider) -> String {
        switch provider {
        case .codex: tr("อ่านจากไฟล์ session ของ Codex ในเครื่อง (~/.codex/sessions) ไม่ใช้อินเทอร์เน็ต ตัวเลขจะเก่าถ้าไม่ได้ใช้ Codex สักพัก")
        case .claude: tr("ใช้การเข้าสู่ระบบของ Claude Code ที่อยู่ใน Keychain แล้วถามโควตาจาก api.anthropic.com โดยตรง (endpoint ที่ไม่เป็นทางการ Anthropic เปลี่ยนได้ทุกเมื่อ) ไม่ส่งไปที่อื่น")
        }
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
