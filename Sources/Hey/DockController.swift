import AppKit
import SwiftUI
import UniformTypeIdentifiers
import HeyDomain

/// A floating glass launcher dock, shown on demand (⌃⌥D, the ring, or hey://dock) and dismissed by clicking elsewhere.
@MainActor
final class DockController {
    private let model: GameModel
    private let service = DockService()
    private var panel: NSPanel?
    private var monitor: Any?
    private var contentSize = CGSize(width: 520, height: 150)

    init(model: GameModel) { self.model = model }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        if panel == nil { build() }
        service.refresh()
        position()
        panel?.orderFrontRegardless()
        if monitor == nil {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let panel = self.panel, !panel.frame.contains(NSEvent.mouseLocation) else { return }
                    self.hide()
                }
            }
        }
    }

    func hide() {
        panel?.orderOut(nil)
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// Dev check: draws the dock's own view to a PNG, so it can be looked at without grabbing the screen.
    func writeSnapshot(to path: String) {
        let probe = DockView(model: model, service: service, onSize: { print("[dock] probe size", $0) }, onAdd: {}, onDropURLs: { _ in }, onRename: { _, _ in })
            .background(Color(red: 0.05, green: 0.2, blue: 0.4))
        let renderer = ImageRenderer(content: probe)
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
        print("[dock] panel frame:", panel?.frame ?? .zero, "content:", contentSize)
    }

    private func build() {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: contentSize),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = DockView(model: model, service: service,
                            onSize: { [weak self] size in self?.fit(size) },
                            onAdd: { [weak self] in self?.pickApps() },
                            onDropURLs: { [weak self] urls in self?.add(urls) },
                            onRename: { [weak self] id, name in self?.rename(id, current: name) },
                            maxWidth: (NSScreen.main?.visibleFrame.width ?? 1200) - 60)
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        panel.contentView = host
        self.panel = panel
    }

    private func fit(_ size: CGSize) {
        guard size.width > 1, size != contentSize else { return }
        contentSize = size
        position()
    }

    /// Centered just above the system Dock.
    private func position() {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.midX - contentSize.width / 2, y: visible.minY + 4)
        panel.setFrame(NSRect(origin: origin, size: contentSize), display: true)
    }

    private func add(_ urls: [URL]) {
        let apps = urls.compactMap(DockService.app(at:))
        guard !apps.isEmpty else { return }
        model.perform { game in game.setDock { layout in apps.forEach { layout.add($0) } }; return [] }
    }

    private func pickApps() {
        let open = NSOpenPanel()
        open.allowedContentTypes = [.application]
        open.allowsMultipleSelection = true
        open.directoryURL = URL(fileURLWithPath: "/Applications")
        open.prompt = "เพิ่มใน Dock"
        NSApp.activate(ignoringOtherApps: true)
        if open.runModal() == .OK { add(open.urls) }
    }

    private func rename(_ id: UUID, current: String) {
        let field = NSTextField(string: current)
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        let alert = NSAlert()
        alert.messageText = "เปลี่ยนชื่อกลุ่ม"
        alert.accessoryView = field
        alert.addButton(withTitle: "ตกลง")
        alert.addButton(withTitle: "ยกเลิก")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let name = field.stringValue
            model.perform { game in game.setDock { $0.rename(id, to: name) }; return [] }
        }
    }
}
