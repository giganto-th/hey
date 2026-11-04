import AppKit
import SwiftUI
import HeyDomain

/// A small always-on-top card listing reminders that are ringing, until you answer them.
@MainActor
final class ReminderToastController {
    private let model: GameModel
    private var panel: NSPanel?
    private var host: NSHostingView<ToastView>?

    init(model: GameModel) { self.model = model }

    func sync() {
        let ringing = model.game.reminders.contains { $0.ringing && $0.isActive }
        guard ringing else { panel?.orderOut(nil); return }

        if panel == nil {
            let host = NSHostingView(rootView: ToastView(model: model))
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
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
            panel.setFrame(NSRect(x: area.maxX - size.width - 16, y: area.maxY - size.height - 16,
                                  width: size.width, height: size.height), display: true)
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
}

private struct ToastView: View {
    let model: GameModel

    var body: some View {
        let ringing = model.game.reminders.filter { $0.ringing && $0.isActive }
        VStack(alignment: .leading, spacing: 10) {
            ForEach(ringing) { r in
                VStack(alignment: .leading, spacing: 8) {
                    Label(r.text, systemImage: "bell.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    HStack {
                        Button(tr("รับทราบ")) {
                            model.perform { $0.acknowledgeReminder(id: r.id, at: Date()); return [] }
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        Button(tr("เลื่อน 10 นาที")) {
                            model.perform { $0.snoozeReminder(id: r.id, minutes: 10, at: Date()); return [] }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                if r.id != ringing.last?.id { Divider() }
            }
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
        .glassCard(cornerRadius: 22)
    }
}
