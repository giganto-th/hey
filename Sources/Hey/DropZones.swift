import AppKit
import Observation
import SwiftUI
import HeyDomain

/// While anything is being dragged, two big glass targets appear beside the pet: keep it, or park it on the shelf.
/// No setup, no menus: drag a file toward the pet and choose.
@MainActor
final class DropZonesController {
    @MainActor @Observable final class ZoneModel { var hovering: DropDestination? }

    private let panel: NSPanel
    private let zones = ZoneModel()
    private var pollTimer: Timer?
    private var countAtMouseDown = 0
    private var monitors: [Any] = []
    private(set) var isActive = false

    /// Where the pet is, so the targets can sit just above its head.
    var petFrame: () -> NSRect? = { nil }
    var onDrop: ((DropPayload, DropDestination) -> Void)?
    var onActiveChanged: ((Bool) -> Void)?
    var onDragBegan: (() -> Void)?

    static let size = CGSize(width: 330, height: 112)

    init() {
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.alphaValue = 0

        let root = NSView(frame: NSRect(origin: .zero, size: Self.size))
        let visuals = PassthroughHostingView(rootView: ZonesView(model: zones))
        visuals.frame = root.bounds
        visuals.autoresizingMask = [.width, .height]
        root.addSubview(visuals)
        let half = (Self.size.width - 10) / 2
        for (i, dest) in DropDestination.allCases.enumerated() {
            let z = DropZoneView(destination: dest)
            z.frame = NSRect(x: CGFloat(i) * (half + 10), y: 0, width: half, height: Self.size.height)
            z.onHover = { [weak self] in self?.zones.hovering = $0 }
            z.onDrop = { [weak self] payload, dest in self?.dropped(payload, dest) }
            root.addSubview(z)
        }
        panel.contentView = root
    }

    // MARK: noticing a drag

    /// A drag session isn't visible to us as events, but it always leaves new content on the system's drag
    /// pasteboard. So: when the mouse goes down, remember that pasteboard's change count and, while the button
    /// stays down, look for it to change.
    func startWatching() {
        let down: (NSEvent) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.mouseWentDown() } }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: down) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { down($0); return $0 }) { monitors.append(l) }
    }

    private func mouseWentDown() {
        countAtMouseDown = NSPasteboard(name: .drag).changeCount
        pollTimer?.invalidate()
        let t = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func poll() {
        guard NSEvent.pressedMouseButtons & 1 != 0 else { end(); return }          // button released
        guard !isActive else { return }
        let pb = NSPasteboard(name: .drag)
        guard pb.changeCount != countAtMouseDown, DropPayload(from: pb) != nil else { return }
        begin()
    }

    /// For trying the targets without a real drag (`HEY_DEV_ZONES=1`).
    func devShow() { begin() }

    private func begin() {
        isActive = true
        zones.hovering = nil
        place()
        panel.orderFrontRegardless()
        panel.animator().alphaValue = 1
        onActiveChanged?(true)
        onDragBegan?()
    }

    private func end() {
        pollTimer?.invalidate()
        pollTimer = nil
        guard isActive else { return }
        isActive = false
        // give a drop that is just landing a moment to finish before the targets vanish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isActive else { return }
                self.panel.animator().alphaValue = 0
                self.zones.hovering = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { MainActor.assumeIsolated { if !self.isActive { self.panel.orderOut(nil) } } }
                self.onActiveChanged?(false)
            }
        }
    }

    private func dropped(_ payload: DropPayload, _ destination: DropDestination) {
        zones.hovering = nil
        onDrop?(payload, destination)
    }

    /// Centred just above the pet's head, kept on screen.
    private func place() {
        guard let pet = petFrame(), let screen = NSScreen.screens.first(where: { $0.frame.intersects(pet) }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        var x = pet.midX - Self.size.width / 2
        var y = pet.maxY + 4
        x = min(max(x, area.minX + 8), area.maxX - Self.size.width - 8)
        if y + Self.size.height > area.maxY - 8 { y = pet.minY - Self.size.height - 4 }       // no room above: go below
        panel.setFrameOrigin(NSPoint(x: x, y: max(y, area.minY + 8)))
    }
}

/// A target that accepts whatever is dragged onto it.
final class DropZoneView: NSView {
    let destination: DropDestination
    var onHover: ((DropDestination?) -> Void)?
    var onDrop: ((DropPayload, DropDestination) -> Void)?

    init(destination: DropDestination) {
        self.destination = destination
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { onHover?(destination); return .copy }
    override func draggingExited(_ sender: NSDraggingInfo?) { onHover?(nil) }
    override func draggingEnded(_ sender: NSDraggingInfo) { onHover?(nil) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let payload = DropPayload(from: sender.draggingPasteboard) else { return false }
        onDrop?(payload, destination)
        return true
    }
}

private struct ZonesView: View {
    let model: DropZonesController.ZoneModel

    var body: some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(DropDestination.allCases, id: \.self) { dest in zone(dest) }
            }
        }
    }

    private func zone(_ dest: DropDestination) -> some View {
        let hot = model.hovering == dest
        return VStack(spacing: 6) {
            Image(systemName: dest == .vault ? "tray.and.arrow.down.fill" : "suitcase.fill")
                .font(.system(size: 30, weight: .semibold))
            Text(dest.label).font(.headline)
            Text(dest == .vault ? tr("เก็บไว้ดูทีหลัง") : tr("แล้วลากไปวางที่อื่น"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .heyGlass(.rect(cornerRadius: 24), tint: hot ? (dest == .vault ? .teal.opacity(0.55) : .orange.opacity(0.55)) : nil)
        .scaleEffect(hot ? 1.05 : 1)
        .animation(.spring(duration: 0.25), value: hot)
    }
}
