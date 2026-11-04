import AppKit
import SwiftUI

/// Big "3… 2… 1…" in the middle of the screen. It belongs to this app, so captures leave it out.
@MainActor
enum CountdownOverlay {
    static func run(seconds: Int) async {
        guard seconds > 0, let screen = NSScreen.main else { return }
        let model = CountdownModel()
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 220, height: 220),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.contentView = NSHostingView(rootView: CountdownView(model: model))
        panel.setFrameOrigin(NSPoint(x: screen.frame.midX - 110, y: screen.frame.midY - 110))
        panel.orderFrontRegardless()
        for n in stride(from: seconds, through: 1, by: -1) {
            model.value = n
            NSSound(named: "Tink")?.play()
            try? await Task.sleep(for: .seconds(1))
        }
        panel.orderOut(nil)
        try? await Task.sleep(for: .milliseconds(150))      // let the panel disappear before the shot
    }
}

@MainActor @Observable
private final class CountdownModel { var value = 0 }

private struct CountdownView: View {
    let model: CountdownModel
    var body: some View {
        Text("\(model.value)")
            .font(.system(size: 120, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: 200, height: 200)
            .glassEffect(.regular, in: .rect(cornerRadius: 44))
            .contentTransition(.numericText())
            .animation(.spring, value: model.value)
    }
}

/// Dim the screen and let the user drag out a rectangle. Esc cancels.
@MainActor
final class RegionSelector {
    struct Selection: @unchecked Sendable { let screen: NSScreen; let rect: CGRect }   // rect: points, origin bottom-left of the screen

    static func select() async -> Selection? {
        await withCheckedContinuation { continuation in
            let mouse = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else {
                continuation.resume(returning: nil); return
            }
            let window = SelectorWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.setFrame(screen.frame, display: true)
            let view = SelectorView(frame: NSRect(origin: .zero, size: screen.frame.size))
            var finished = false
            let finish: (CGRect?) -> Void = { rect in
                guard !finished else { return }
                finished = true
                window.orderOut(nil)
                NSCursor.arrow.set()
                continuation.resume(returning: rect.map { Selection(screen: screen, rect: $0) })
            }
            view.onDone = finish
            window.onCancel = { finish(nil) }
            window.contentView = view
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            NSCursor.crosshair.set()
        }
    }
}

private final class SelectorWindow: NSWindow {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }   // Esc
    }
}

private final class SelectorView: NSView {
    var onDone: ((CGRect?) -> Void)?
    private var start: CGPoint?
    private var current: CGPoint?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    private var selection: CGRect? {
        guard let s = start, let c = current else { return nil }
        return CGRect(x: min(s.x, c.x), y: min(s.y, c.y), width: abs(s.x - c.x), height: abs(s.y - c.y))
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        if let r = selection, r.width >= 8, r.height >= 8 { onDone?(r) } else { onDone?(nil) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()
        guard let r = selection else { return }
        NSColor.clear.setFill()
        r.fill(using: .copy)
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: r)
        path.lineWidth = 1.5
        path.stroke()
        let label = "\(Int(r.width)) × \(Int(r.height))" as NSString
        label.draw(at: NSPoint(x: r.minX + 4, y: max(r.minY - 18, 2)),
                   withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)])
    }
}
