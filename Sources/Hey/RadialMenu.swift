import AppKit
import Observation
import SwiftUI
import HeyDomain

/// One round button in the fan.
struct RadialItem: Identifiable {
    let id: String
    var icon: RadialIcon
    var title: String
    var badge: String?
    var badgeColor: Color = .orange
    var enabled = true
    /// Menu keeps open (page changes) or closes after the action runs.
    var closes = true
    var action: () -> Void
}

/// A button's picture: an SF Symbol (a plain string literal works), or an image such as a food illustration.
enum RadialIcon: ExpressibleByStringLiteral {
    case symbol(String)
    case image(NSImage)
    init(stringLiteral value: String) { self = .symbol(value) }
}

enum RadialPage { case main, food, more }

@MainActor @Observable
final class RadialModel {
    var page: RadialPage = .main
    /// Flips to true to make the buttons fly out of the pet; false to fold them back in.
    var shown = false
    /// Where everything goes (screen coordinates), and where the window itself sits.
    var layout = RadialLayout(petCenter: .zero, arcs: [], buttonSize: 76, header: .zero, bounds: .zero)
    var origin = CGPoint.zero
    var panelSize = CGSize(width: 400, height: 300)

    /// Screen coordinates (origin bottom-left) to the view's (origin top-left).
    func inView(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - origin.x, y: panelSize.height - (p.y - origin.y)) }
}

/// A circular menu that unfolds around the pet instead of a rectangle of text: live stats on top,
/// big glass buttons on an arc, sub-pages that swap in with a spring.
@MainActor
final class RadialMenuController {
    /// The most buttons any page shows; the layout is planned once for this many.
    static let maxItems = 8
    static let headerSize = CGSize(width: 280, height: 84)

    let model = RadialModel()
    private let panel: RadialPanel
    private var monitors: [Any] = []
    private var idleTimer: Timer?
    private(set) var isOpen = false

    /// What each page contains; evaluated while drawing, so badges and states stay live.
    var items: (RadialPage) -> [RadialItem] = { _ in [] }
    var header: () -> RadialHeaderInfo = { RadialHeaderInfo() }
    var onOpenChanged: ((Bool) -> Void)?

    init() {
        panel = RadialPanel(contentRect: NSRect(origin: .zero, size: CGSize(width: 400, height: 300)),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        let host = NSHostingView(rootView: RadialMenuView(controller: nil))
        host.rootView = RadialMenuView(controller: self)
        panel.contentView = host
        panel.onEscape = { [weak self] in self?.close() }
    }

    // MARK: opening and closing

    /// `petCenter` is the middle of the pet's body in screen coordinates; `petRadius` is roughly how far its body reaches.
    func open(around petCenter: NSPoint, petRadius: CGFloat) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(petCenter) }) ?? NSScreen.main else { return }
        var input = RadialLayoutPlanner.Input(petCenter: petCenter, petRadius: Double(petRadius),
                                              screen: screen.visibleFrame, maxItems: Self.maxItems)
        input.headerSize = Self.headerSize
        let layout = RadialLayoutPlanner.plan(input)

        let frame = layout.bounds.integral
        panel.setFrame(frame, display: false)
        model.layout = layout
        model.origin = frame.origin
        model.panelSize = frame.size
        model.page = .main
        model.shown = false
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        panel.makeKey()                // so Esc reaches it; a non-activating panel leaves the app you're using in front
        isOpen = true
        onOpenChanged?(true)
        installMonitors()
        resetIdleTimer()
        DispatchQueue.main.async { [weak self] in self?.model.shown = true }     // next turn, so the fly-out animates
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        removeMonitors()
        idleTimer?.invalidate()
        model.shown = false
        onOpenChanged?(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            MainActor.assumeIsolated { if self?.isOpen == false { self?.panel.orderOut(nil) } }
        }
    }

    func toggle(around petCenter: NSPoint, petRadius: CGFloat) { isOpen ? close() : open(around: petCenter, petRadius: petRadius) }

    /// Swap to another page: fold the buttons in, change, unfold.
    func go(_ page: RadialPage) {
        resetIdleTimer()
        model.shown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
            MainActor.assumeIsolated {
                self?.model.page = page
                self?.model.shown = true
            }
        }
    }

    // MARK: dismissal

    private func installMonitors() {
        removeMonitors()
        let outside: (NSEvent) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.close() } }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: outside) { monitors.append(g) }
        // clicks in our own other windows (the pet itself, the Hub…)
        let local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            if let self, event.window !== self.panel { MainActor.assumeIsolated { self.close() } }
            return event
        }
        if let local { monitors.append(local) }
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    /// Forgets about itself after a while so it never lingers on the screen.
    func resetIdleTimer() {
        idleTimer?.invalidate()
        let t = Timer(timeInterval: 14, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.close() } }
        RunLoop.main.add(t, forMode: .common)
        idleTimer = t
    }

    // MARK: dev

    func snapshot() -> Data? {
        guard let host = panel.contentView, let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }
}

/// Takes keyboard focus without activating the app, only to hear Esc.
private final class RadialPanel: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 { onEscape?() } else { super.sendEvent(event) }
    }
}

struct RadialHeaderInfo {
    var title = ""
    var subtitle = ""
    var bars: [(symbol: String, value: Double, color: Color)] = []
    var progress: (label: String, value: Double)?
    var coins = 0
    var streak = 0
}

// MARK: - view

struct RadialMenuView: View {
    let controller: RadialMenuController?

    var body: some View {
        if let controller {
            let model = controller.model
            let items = controller.items(model.page)
            let centers = model.layout.centers(count: items.count)
            let start = model.inView(model.layout.petCenter)
            ZStack {
                // anywhere outside the buttons: close
                Color.clear.contentShape(Rectangle()).onTapGesture { controller.close() }

                header(controller.header(), model: model, controller: controller)

                GlassEffectContainer(spacing: 6) {
                    ZStack {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            let target = index < centers.count ? model.inView(centers[index]) : start
                            button(item, size: model.layout.buttonSize, controller: controller)
                                .position(model.shown ? target : start)
                                .scaleEffect(model.shown ? 1 : 0.25)
                                .opacity(model.shown ? 1 : 0)
                                .animation(.spring(response: 0.46, dampingFraction: 0.66).delay(Double(index) * 0.04), value: model.shown)
                        }
                    }
                    .id(model.page)
                }
            }
            .frame(width: model.panelSize.width, height: model.panelSize.height)
        }
    }

    private func button(_ item: RadialItem, size: Double, controller: RadialMenuController) -> some View {
        Button {
            guard item.enabled else { return }
            item.action()
            if item.closes { controller.close() }
        } label: {
            VStack(spacing: 1) {
                switch item.icon {
                case .symbol(let name): Image(systemName: name).font(.system(size: 17, weight: .medium)).frame(height: 20)
                case .image(let image): Image(nsImage: image).resizable().scaledToFit().frame(width: 24, height: 22)
                }
                Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .opacity(item.enabled ? 1 : 0.4)
        .overlay(alignment: .topTrailing) {
            if let badge = item.badge {
                Text(badge)
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(item.badgeColor, in: Capsule())
                    .offset(x: 6, y: -3)
            }
        }
    }

    private func header(_ info: RadialHeaderInfo, model: RadialModel, controller: RadialMenuController) -> some View {
        let rect = model.layout.header
        let centre = model.inView(CGPoint(x: rect.midX, y: rect.midY))
        return VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(info.title).font(.system(size: 14, weight: .bold, design: .rounded))
                Text(info.subtitle).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Label("\(info.coins)", systemImage: "circle.hexagongrid.fill").foregroundStyle(.orange).font(.caption.weight(.semibold))
            }
            if let p = info.progress {
                HStack(spacing: 8) {
                    Text(p.label).font(.caption2).foregroundStyle(.secondary)
                    MiniBar(value: p.value, color: .yellow).frame(height: 5)
                }
            }
            HStack(spacing: 14) {
                ForEach(Array(info.bars.enumerated()), id: \.offset) { _, bar in
                    HStack(spacing: 5) {
                        Image(systemName: bar.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(bar.color)
                        MiniBar(value: bar.value, color: bar.color).frame(height: 6)
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .frame(width: rect.width, height: rect.height)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .scaleEffect(model.shown ? 1 : 0.85)
        .opacity(model.shown ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.shown)
        .position(centre)
    }
}

private struct MiniBar: View {
    let value: Double
    let color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.12))
                Capsule().fill(color.gradient).frame(width: max(geo.size.width * min(max(value, 0), 1), 4))
            }
        }
    }
}
