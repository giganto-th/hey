import AppKit
import SwiftUI
import HeyDomain

let stickyColors: [Color] = [
    Color(red: 1.00, green: 0.95, blue: 0.62), Color(red: 1.00, green: 0.80, blue: 0.85),
    Color(red: 0.78, green: 0.94, blue: 0.80), Color(red: 0.76, green: 0.88, blue: 1.00),
]

/// Floating sticky windows for every pinned note.
@MainActor
final class StickyController: NSObject, NSWindowDelegate {
    private let model: GameModel
    private var panels: [UUID: NSPanel] = [:]
    private var closing: Set<UUID> = []
    private var moveWork: [UUID: DispatchWorkItem] = [:]

    init(model: GameModel) { self.model = model }

    func sync() {
        let pinned = model.game.notes.filter(\.pinned)
        let ids = Set(pinned.map(\.id))
        for (id, panel) in panels where !ids.contains(id) {
            closing.insert(id)
            panel.close()
            panels[id] = nil
        }
        for (index, note) in pinned.enumerated() where panels[note.id] == nil {
            panels[note.id] = makePanel(for: note, index: index)
        }
    }

    func focus(_ id: UUID) {
        guard let panel = panels[id] else { return }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func makePanel(for note: Note, index: Int) -> NSPanel {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 240, height: 200),
                        styleMask: [.titled, .closable, .resizable, .utilityWindow],
                        backing: .buffered, defer: false)
        p.title = "โน้ต"
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = NSHostingView(rootView: StickyView(model: model, id: note.id))
        p.delegate = self
        p.identifier = NSUserInterfaceItemIdentifier(note.id.uuidString)
        if let x = note.x, let y = note.y {
            p.setFrameOrigin(NSPoint(x: x, y: y))
        } else if let area = NSScreen.main?.visibleFrame {
            let step = CGFloat(index % 6) * 28
            p.setFrameOrigin(NSPoint(x: area.maxX - 280 - step, y: area.maxY - 260 - step))
        }
        p.orderFrontRegardless()
        return p
    }

    private func id(of window: NSWindow?) -> UUID? {
        window?.identifier.flatMap { UUID(uuidString: $0.rawValue) }
    }

    func windowWillClose(_ notification: Notification) {
        guard let id = id(of: notification.object as? NSWindow) else { return }
        if closing.remove(id) != nil { return }          // closed by us
        panels[id] = nil
        model.perform { $0.setNote(id: id, pinned: false); return [] }   // user clicked the close button
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let id = id(of: window) else { return }
        moveWork[id]?.cancel()
        let work = DispatchWorkItem { [weak self, weak window] in
            MainActor.assumeIsolated {
                guard let self, let window else { return }
                self.model.perform { $0.moveNote(id: id, x: window.frame.origin.x, y: window.frame.origin.y); return [] }
            }
        }
        moveWork[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}

struct StickyView: View {
    let model: GameModel
    let id: UUID

    var body: some View {
        let note = model.game.notes.first { $0.id == id }
        TextEditor(text: Binding(
            get: { note?.text ?? "" },
            set: { text in model.perform { $0.updateNote(id: id, text: text, now: Date()); return [] } }))
            .font(.system(size: 14))
            .scrollContentBackground(.hidden)
            .padding(8)
            .foregroundStyle(.black.opacity(0.85))
            .background(stickyColors[(note?.colorIndex ?? 0) % stickyColors.count])
    }
}
