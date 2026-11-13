import AppKit
import SwiftUI
import HeyDomain

private func timeText(_ d: Date) -> String { d.formatted(date: .omitted, time: .shortened) }
private func rangeText(_ e: CalendarEventInfo) -> String { "\(timeText(e.start))–\(timeText(e.end))" }

// MARK: Hub › Today

/// Hub › Today: the next appointment with a countdown and a join button, then the rest of today.
struct CalendarTodayCard: View {
    let calendar: CalendarService
    let router: HubRouter

    var body: some View {
        HubCard(title: tr("ปฏิทินวันนี้"), symbol: "calendar", tint: HeyLook.glow) {
            switch calendar.access {
            case .off:
                prompt(tr("เปิดเพื่อดูนัดของวันนี้และเข้าห้องประชุมได้ในคลิกเดียว"), button: tr("เปิดใช้ปฏิทิน")) {
                    Task { await calendar.setEnabled(true) }
                }
            case .notAllowed:
                prompt(tr("Hey! ยังไม่ได้รับสิทธิ์อ่านปฏิทิน เปิดได้ที่ การตั้งค่าระบบ › ความเป็นส่วนตัว › ปฏิทิน"),
                       button: tr("เปิดการตั้งค่า")) { calendar.openPrivacySettings() }
            case .ready:
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    content(calendar.agenda(now: context.date), now: context.date)
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ agenda: CalendarAgenda, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !agenda.allDay.isEmpty {
                FlowChips(items: agenda.allDay.map(\.displayTitle))
            }
            if let next = agenda.next {
                nextRow(next, joinable: agenda.joinable(now: now)?.id == next.id, now: now)
                let rest = agenda.upcoming.dropFirst()
                if !rest.isEmpty {
                    Divider().overlay(.primary.opacity(0.1))
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(rest.prefix(4))) { e in laterRow(e) }
                        if rest.count > 4 {
                            Text(tr("และอีก {0} นัด", rest.count - 4)).font(.caption).foregroundStyle(.primary.opacity(0.55))
                        }
                    }
                }
            } else {
                Label(tr("ไม่มีนัดที่เหลือแล้ววันนี้"), systemImage: "checkmark.circle")
                    .font(.callout).foregroundStyle(.primary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nextRow(_ e: CalendarEventInfo, joinable: Bool, now: Date) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(CalendarAgenda.countdown(e, now: now))
                    .font(.caption.weight(.semibold)).foregroundStyle(e.isOngoing(at: now) ? .green : .orange)
                Text(e.displayTitle).font(.headline).lineLimit(2)
                Text(rangeText(e)).font(.footnote).monospacedDigit().foregroundStyle(.primary.opacity(0.6))
            }
            Spacer(minLength: 8)
            if e.meetingURL != nil {
                if joinable {
                    Button(tr("เข้าประชุม"), systemImage: "video.fill") { calendar.join(e) }
                        .buttonStyle(.borderedProminent).tint(.green)
                } else {
                    Button(tr("เปิดลิงก์"), systemImage: "video") { calendar.join(e) }
                        .buttonStyle(.bordered)
                        .help(tr("ปุ่มเข้าประชุมจะเด่นขึ้นเมื่อใกล้ถึงเวลา 15 นาที"))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func laterRow(_ e: CalendarEventInfo) -> some View {
        HStack(spacing: 10) {
            Text(timeText(e.start)).font(.footnote.weight(.medium)).monospacedDigit().foregroundStyle(.primary.opacity(0.6))
                .frame(minWidth: 48, alignment: .leading)
            Text(e.displayTitle).font(.callout).lineLimit(1)
            Spacer(minLength: 4)
            if e.meetingURL != nil {
                Button { calendar.join(e) } label: { Image(systemName: "video") }
                    .buttonStyle(.borderless)
                    .help(tr("เปิดลิงก์ประชุม"))
                    .accessibilityLabel(tr("เปิดลิงก์ประชุม {0}", e.displayTitle))
            }
        }
    }

    private func prompt(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text).font(.callout).foregroundStyle(.primary.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button(button, action: action).buttonStyle(PillButtonStyle())
                Button(tr("ตั้งค่าปฏิทิน")) { withAnimation(.snappy) { router.section = .settings } }
                    .buttonStyle(.borderless)
            }
        }
    }
}

/// All-day items as small capsules that wrap onto new lines.
private struct FlowChips: View {
    let items: [String]
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
    }
    private var chips: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, title in
            Label(title, systemImage: "sun.max").font(.caption).lineLimit(1)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.primary.opacity(0.07), in: Capsule())
        }
    }
}

// MARK: Hub › Settings

struct CalendarSettingsSection: View {
    let calendar: CalendarService

    var body: some View {
        Section(tr("ปฏิทิน")) {
            Toggle(tr("ใช้ปฏิทินของ Mac"), isOn: Binding(
                get: { calendar.isEnabled },
                set: { v in Task { await calendar.setEnabled(v) } }))
            Text(tr("อ่านอย่างเดียว ไม่เก็บและไม่ส่งข้อมูลไปไหน ใช้ Google หรือ Outlook ได้โดยเพิ่มบัญชีใน การตั้งค่าระบบ › บัญชีอินเทอร์เน็ต"))
                .font(.caption).foregroundStyle(.secondary)

            switch calendar.access {
            case .off:
                EmptyView()
            case .notAllowed:
                LabeledContent {
                    Button(tr("เปิดการตั้งค่า")) { calendar.openPrivacySettings() }
                } label: {
                    Label(tr("ยังไม่ได้รับสิทธิ์อ่านปฏิทิน"), systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            case .ready:
                Picker(tr("เตือนก่อนนัด"), selection: Binding(get: { calendar.leadMinutes }, set: { calendar.setLead(minutes: $0) })) {
                    ForEach(CalendarHeadsUp.leadChoices, id: \.self) { Text(tr("{0} นาที", $0)).tag($0) }
                }
                Toggle(tr("ไม่เตือนนัดที่ตอบปฏิเสธแล้ว"), isOn: Binding(get: { calendar.skipDeclined }, set: { calendar.setSkipDeclined($0) }))
                if calendar.calendars.isEmpty {
                    Text(tr("ไม่พบปฏิทินบนเครื่องนี้")).foregroundStyle(.secondary)
                } else {
                    DisclosureGroup(tr("ปฏิทินที่แสดง ({0}/{1})",
                                       calendar.calendars.filter { !calendar.hidden.contains($0.id) }.count, calendar.calendars.count)) {
                        ForEach(calendar.calendars) { c in
                            Toggle(isOn: Binding(get: { !calendar.hidden.contains(c.id) }, set: { calendar.setShown($0, calendarID: c.id) })) {
                                HStack(spacing: 8) {
                                    Circle().fill(Color(nsColor: c.color)).frame(width: 9, height: 9).accessibilityHidden(true)
                                    Text(c.title)
                                    if !c.source.isEmpty { Text(c.source).font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: menu bar

/// The menu-bar menu's calendar line: the next appointment and how soon it is.
struct CalendarMenuCard: View {
    let next: CalendarEventInfo
    let laterCount: Int
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar").font(.system(size: 16)).foregroundStyle(.red).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(next.displayTitle).font(.callout.weight(.medium)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(CalendarAgenda.countdown(next, now: now)).foregroundStyle(next.isOngoing(at: now) ? .green : .orange)
                    Text("· \(rangeText(next))").monospacedDigit().foregroundStyle(.secondary)
                    if laterCount > 0 { Text(tr("· อีก {0} นัดวันนี้", laterCount)).foregroundStyle(.secondary) }
                }
                .font(.caption).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .frame(width: 360, alignment: .leading)
    }
}

// MARK: join toast

/// A small card in the top-right corner when a meeting with a video link is about to start: join or dismiss.
/// It goes away by itself 10 minutes after the start.
@MainActor
final class MeetingToastController {
    private let calendar: CalendarService
    private var panel: NSPanel?
    private var host: NSHostingView<MeetingToastView>?
    private var hideWork: DispatchWorkItem?

    init(calendar: CalendarService) { self.calendar = calendar }

    func show(_ event: CalendarEventInfo) {
        guard event.meetingURL != nil else { return }
        let view = MeetingToastView(event: event,
                                    join: { [weak self] in self?.calendar.join(event); self?.hide() },
                                    dismiss: { [weak self] in self?.hide() })
        if let host { host.rootView = view } else {
            let host = NSHostingView(rootView: view)
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 110),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.hidesOnDeactivate = false
            p.contentView = host
            self.host = host
            panel = p
        }
        guard let panel, let host else { return }
        let size = host.fittingSize
        if let area = NSScreen.main?.visibleFrame {
            panel.setFrame(NSRect(x: area.maxX - size.width - 16, y: area.maxY - size.height - 16, width: size.width, height: size.height),
                           display: true)
        }
        panel.orderFrontRegardless()

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.hide() } }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(60, event.start.timeIntervalSinceNow + 10 * 60), execute: work)
    }

    func hide() {
        hideWork?.cancel()
        panel?.orderOut(nil)
    }
}

struct MeetingToastView: View {
    let event: CalendarEventInfo
    let join: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(tr("ประชุมเวลา {0}", timeText(event.start)), systemImage: "video.fill")
                .font(.caption).foregroundStyle(.secondary)
            Text(event.displayTitle).font(.headline).lineLimit(2)
            HStack {
                Button(tr("เข้าประชุม"), action: join)
                    .buttonStyle(.borderedProminent).tint(.green)
                    .keyboardShortcut(.defaultAction)
                Spacer()
                Button(tr("ปิด"), action: dismiss).buttonStyle(.borderless)
            }
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
        .glassCard(cornerRadius: 22)
    }
}
