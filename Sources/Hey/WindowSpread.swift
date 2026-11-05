import AppKit
import Observation
import SwiftUI
import HeyDomain

/// One app with windows open on screen.
struct SpreadApp: Identifiable {
    let id: pid_t
    let name: String
    let icon: NSImage
    let windowCount: Int
    /// Title of its frontmost window; only readable when Screen Recording is granted.
    let title: String?
    let canQuit: Bool
    let app: NSRunningApplication
}

enum SpreadApps {
    /// Apps that own a visible window, frontmost first.
    @MainActor static func current() -> [SpreadApp] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        var order: [pid_t] = []
        var counts: [pid_t: Int] = [:]
        var titles: [pid_t: String] = [:]
        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  let pid = w[kCGWindowOwnerPID as String] as? pid_t, pid != me,
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.05,
                  let dict = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: dict), r.width >= 80, r.height >= 50 else { continue }
            if counts[pid] == nil { order.append(pid) }
            counts[pid, default: 0] += 1
            if titles[pid] == nil, let t = w[kCGWindowName as String] as? String, !t.isEmpty { titles[pid] = t }
        }
        return order.compactMap { pid in
            guard let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular else { return nil }
            let name = app.localizedName ?? app.bundleIdentifier ?? "App"
            let icon = app.icon ?? NSWorkspace.shared.icon(for: .application)
            return SpreadApp(id: pid, name: name, icon: icon, windowCount: counts[pid] ?? 1, title: titles[pid],
                             canQuit: app.bundleIdentifier != "com.apple.finder", app: app)
        }
    }
}

@MainActor @Observable
final class SpreadModel {
    var apps: [SpreadApp] = []
    var open = false
    /// The sheet last dragged out, drawn above the rest.
    var raised: pid_t?
    var onDismiss: () -> Void = {}
}

private final class SpreadPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// "Spread out": every app with an open window laid out as overlapping sheets, newest on top.
/// Click a sheet to jump to that app; its close button quits the app.
@MainActor
final class WindowSpreadController {
    private let model = SpreadModel()
    private var panel: NSPanel?
    private var keyMonitor: Any?
    private var backdrop: NSVisualEffectView?
    var isShown: Bool { panel != nil }

    func toggle() { isShown ? dismiss() : show() }

    func show() {
        guard panel == nil else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        model.apps = SpreadApps.current()
        model.onDismiss = { [weak self] in self?.dismiss() }
        let p = SpreadPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .popUpMenu
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: screen.frame.size))
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.alphaValue = 0
        let host = NSHostingView(rootView: SpreadView(model: model, refresh: { [weak self] in self?.refreshSoon() }))
        host.frame = blur.bounds
        host.autoresizingMask = [.width, .height]
        blur.addSubview(host)
        p.contentView = blur
        backdrop = blur
        p.makeKeyAndOrderFront(nil)
        panel = p
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53 { self?.dismiss(); return nil }          // Escape
            return e
        }
        model.open = false
        NSAnimationContext.runAnimationGroup { $0.duration = 0.25; blur.animator().alphaValue = 1 }
        DispatchQueue.main.async { [model] in withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { model.open = true } }
    }

    func dismiss() {
        guard let p = panel else { return }
        panel = nil
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        withAnimation(.easeIn(duration: 0.18)) { model.open = false }
        NSAnimationContext.runAnimationGroup { $0.duration = 0.18; backdrop?.animator().alphaValue = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { p.orderOut(nil) }
    }

    /// An app that was asked to quit takes a moment (or asks to save first), so look again shortly after.
    private func refreshSoon() {
        for delay in [0.6, 1.5, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.panel != nil else { return }
                let now = SpreadApps.current()
                if now.map(\.id) != self.model.apps.map(\.id) { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { self.model.apps = now } }
            }
        }
    }
}

private struct SpreadView: View {
    var model: SpreadModel
    var refresh: () -> Void

    static let card = CGSize(width: 250, height: 160)

    var body: some View {
        GeometryReader { geo in
            let apps = Array(model.apps.reversed())            // frontmost app drawn last, so it sits on top
            let layout = SpreadLayout.slots(count: apps.count, width: min(geo.size.width - 120, 1300),
                                            cardWidth: Self.card.width, cardHeight: Self.card.height)
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { model.onDismiss() }

                if apps.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.stack").font(.system(size: 44, weight: .light))
                        Text(tr("ไม่มีหน้าต่างที่เปิดอยู่")).font(.title3)
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let originX = (geo.size.width - layout.width) / 2
                    let originY = max(80, (geo.size.height - layout.height) / 2)
                    ForEach(Array(apps.enumerated()), id: \.element.id) { i, app in
                        let slot = layout.slots[i]
                        SpreadCard(app: app, isFront: i == apps.count - 1, onOpen: {
                            app.app.activate()
                            model.onDismiss()
                        }, onQuit: {
                            app.app.terminate()
                            refresh()
                        }, onRaise: { model.raised = app.id })
                        .frame(width: Self.card.width, height: Self.card.height)
                        .rotationEffect(.degrees(model.open ? slot.angle : 0))
                        .offset(x: model.open ? originX + slot.x : geo.size.width / 2 - Self.card.width / 2,
                                y: model.open ? originY + slot.y : geo.size.height / 2 - Self.card.height / 2)
                        .opacity(model.open ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(Double(apps.count - 1 - i) * 0.02), value: model.open)
                        .zIndex(model.raised == app.id ? 1000 : Double(i))
                    }
                }

                VStack {
                    Spacer()
                    Text(tr("คลิกที่แอปเพื่อไปที่แอปนั้น · กดปุ่มปิดเพื่อออกจากแอป · Esc เพื่อกลับ"))
                        .font(.callout).foregroundStyle(.secondary).glassPill()
                        .padding(.bottom, 36)
                        .opacity(model.open ? 1 : 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .ignoresSafeArea()
    }
}

private struct SpreadCard: View {
    let app: SpreadApp
    let isFront: Bool
    let onOpen: () -> Void
    let onQuit: () -> Void
    var onRaise: () -> Void = {}
    @State private var hover = false
    @State private var drag = CGSize.zero
    @State private var base = CGSize.zero
    @State private var dragging = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(nsImage: app.icon).resizable().frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                        Text(app.windowCount > 1 ? tr("{0} หน้าต่าง", app.windowCount) : tr("1 หน้าต่าง"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let title = app.title {
                    Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            .shadow(color: .black.opacity(hover || dragging ? 0.35 : 0.18), radius: hover || dragging ? 18 : 8, y: hover || dragging ? 10 : 4)

            // The close button sits on the left strip, which is never covered by the sheet on top.
            if app.canQuit {
                Button(action: onQuit) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 22, height: 22).background(Circle().fill(Color.red.opacity(0.92)))
                }
                .buttonStyle(.plain)
                .help(tr("ปิดแอป"))
                .opacity(hover || dragging ? 1 : 0.55)
                .offset(x: -6, y: -6)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onHover { hover = $0 }
        .gesture(DragGesture(minimumDistance: 6)
            .onChanged { if !dragging { onRaise() }; drag = CGSize(width: base.width + $0.translation.width, height: base.height + $0.translation.height); dragging = true }
            .onEnded { _ in dragging = false; base = drag })                   // stays where it was dropped
        .simultaneousGesture(TapGesture().onEnded(onOpen))
        .scaleEffect(hover || dragging ? 1.04 : 1)
        .offset(x: drag.width, y: drag.height + (hover && !dragging ? -10 : 0))
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: hover)
    }
}
