import AppKit
import QuartzCore
import HeyDomain

// Things the pet walks to on its own: food you put down anywhere on the screen, and soap bubbles it chases and pecks.

// MARK: food

/// A full-screen sheet that catches one click: where it lands is where the food goes. Esc or a right click cancels.
private final class PlacementPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class PlacementView: NSView {
    let image: NSImage
    let hint: String
    var mouse: NSPoint?
    var onPlace: (NSPoint) -> Void = { _ in }
    var onCancel: () -> Void = {}

    init(frame: NSRect, image: NSImage, hint: String) {
        self.image = image
        self.hint = hint
        super.init(frame: frame)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseMoved(with event: NSEvent) { mouse = convert(event.locationInWindow, from: nil); needsDisplay = true }
    override func mouseDown(with event: NSEvent) { onPlace(convert(event.locationInWindow, from: nil)) }
    override func rightMouseDown(with event: NSEvent) { onCancel() }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { onCancel() } }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.04).setFill()          // nearly invisible, but enough for the window to take the click
        bounds.fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold), .foregroundColor: NSColor.white]
        let text = NSAttributedString(string: hint, attributes: attrs)
        let size = text.size()
        let pill = NSRect(x: bounds.midX - size.width / 2 - 16, y: bounds.maxY - 90, width: size.width + 32, height: size.height + 14)
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
        text.draw(at: NSPoint(x: pill.minX + 16, y: pill.minY + 7))
        if let mouse {
            image.draw(in: NSRect(x: mouse.x - 32, y: mouse.y - 32, width: 64, height: 64))
        }
    }
}

@MainActor
final class FoodController {
    private struct Piece {
        let food: Food
        let panel: NSPanel
        var x: CGFloat
        var y: CGFloat
        var velocity: CGFloat = 0
        let floorY: CGFloat
        var landed = false
        let placedAt = Date()
    }

    private static let size: CGFloat = 64
    private let model: GameModel
    private weak var scene: PetScene?
    private var overlays: [PlacementPanel] = []
    private var piece: Piece?
    private var fallTimer: Timer?

    init(model: GameModel, scene: PetScene) {
        self.model = model
        self.scene = scene
    }

    /// Pick the food up: the next click puts it down anywhere on the pet's screen, and the pet walks over to eat it.
    func begin(_ food: Food) {
        guard let scene, let screen = scene.window?.screen ?? NSScreen.main else { return }
        if let why = model.game.feedRefusal(food, at: Date()) {
            scene.announce(Self.message(for: why), symbol: "fork.knife")
            return
        }
        if piece != nil { scene.announce(tr("มีอาหารวางอยู่แล้ว รอให้กินก่อนนะ"), symbol: "fork.knife"); return }
        cancelPlacing()
        let image = IconLibrary.foodImage(food)
        let panel = PlacementPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = PlacementView(frame: NSRect(origin: .zero, size: screen.frame.size), image: image,
                                 hint: tr("คลิกเพื่อวาง {0} · Esc ยกเลิก", food.name))
        view.onPlace = { [weak self, weak panel] point in
            guard let self, let panel else { return }
            self.place(food, atScreenPoint: NSPoint(x: panel.frame.minX + point.x, y: panel.frame.minY + point.y), on: screen)
        }
        view.onCancel = { [weak self] in self?.cancelPlacing() }
        panel.contentView = view
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(view)
        overlays = [panel]
        NSCursor.crosshair.push()
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self, weak panel] in      // forgotten: put the food back
            if let panel, self?.overlays.contains(where: { $0 === panel }) == true { self?.cancelPlacing() }
        }
    }

    /// Dev hook: drop food from the top of the screen, a quarter of the way across.
    func dropForDev(_ food: Food) {
        guard let screen = scene?.window?.screen ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        place(food, atScreenPoint: NSPoint(x: area.minX + area.width * 0.25, y: area.maxY - 120), on: screen)
    }

    private func cancelPlacing() {
        if !overlays.isEmpty { NSCursor.pop() }
        overlays.forEach { $0.orderOut(nil) }
        overlays = []
    }

    private func place(_ food: Food, atScreenPoint p: NSPoint, on screen: NSScreen) {
        cancelPlacing()
        guard let scene else { return }
        let area = screen.visibleFrame
        let half = Self.size / 2
        let x = min(max(p.x, area.minX + half), area.maxX - half)
        let floorY = area.minY + 2
        let panel = NSPanel(contentRect: NSRect(x: x - half, y: max(p.y - half, floorY), width: Self.size, height: Self.size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let image = NSImageView(frame: NSRect(origin: .zero, size: panel.frame.size))
        image.image = IconLibrary.foodImage(food)
        image.imageScaling = .scaleProportionallyUpOrDown
        panel.contentView = image
        panel.orderFrontRegardless()
        piece = Piece(food: food, panel: panel, x: x, y: max(p.y - half, floorY), floorY: floorY)
        scene.announce(tr("มาแล้ว!"), symbol: "fork.knife")
        fallTimer?.invalidate()
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.fall() } }
        RunLoop.main.add(timer, forMode: .common)
        fallTimer = timer
    }

    private func fall() {
        guard var p = piece else { fallTimer?.invalidate(); return }
        p.velocity -= 2200 / 60
        p.y += p.velocity / 60
        if p.y <= p.floorY {
            p.y = p.floorY
            if p.velocity < -500 { p.velocity = -p.velocity * 0.3 } else { p.velocity = 0; p.landed = true }
        }
        p.panel.setFrameOrigin(NSPoint(x: p.x - Self.size / 2, y: p.y))
        piece = p
        if p.landed { fallTimer?.invalidate(); fallTimer = nil }
    }

    /// What the pet should walk to, if food is waiting.
    func target() -> PetScene.SeekTarget? {
        guard let p = piece else { return nil }
        if Date().timeIntervalSince(p.placedAt) > 300 { remove(); return nil }          // nobody came for it
        return PetScene.SeekTarget(x: p.x, reach: 24, ready: p.landed) { [weak self] in self?.eaten() }
    }

    private func eaten() {
        guard let p = piece else { return }
        remove()
        model.perform { $0.feed(p.food, at: Date()) }
    }

    private func remove() {
        fallTimer?.invalidate(); fallTimer = nil
        piece?.panel.orderOut(nil)
        piece = nil
    }

    private static func message(for event: GameEvent) -> String {
        switch event {
        case .noStock: return tr("ไม่มีอาหารนี้แล้ว ไปซื้อที่ร้านค้านะ")
        case .pet(.refusedEgg): return tr("ไข่ยังกินไม่ได้นะ")
        case .pet(.refusedFull): return tr("อิ่มแล้ว~")
        case .pet(.refusedCooldown(let remaining)): return tr("ยังไม่หิวนะ ให้ได้{0}", DurationText.wait(remaining))
        default: return tr("ให้อาหารไม่ได้ตอนนี้")
        }
    }
}

// MARK: bubbles

@MainActor
final class BubbleController {
    private static let lifetime: TimeInterval = 150
    private var field = BubbleField()
    private weak var scene: PetScene?
    private let model: GameModel
    private var panel: NSPanel?
    private var root: NSView?
    private var layers: [Int: CALayer] = [:]
    private var timer: Timer?
    private var startedAt = Date()
    private var last = Date()
    private var area = NSRect.zero
    private var frame = NSRect.zero
    private var popped = 0
    private static let image: CGImage? = makeImage()

    init(scene: PetScene, model: GameModel) { self.scene = scene; self.model = model }

    var isActive: Bool { !field.isEmpty }

    /// Bubbles stay where the pet can stand over them: its window never gets closer to a screen edge than half its width,
    /// so a bubble in the last few dozen points (the right corner, say) could never be pecked.
    private var bounds: ClosedRange<Double> {
        let margin = Double(PetScene.windowSize.width / 2)
        return (area.minX + margin)...(area.maxX - margin)
    }

    /// Blow a handful of bubbles across the pet's screen.
    func start() {
        guard let scene, let screen = scene.window?.screen ?? NSScreen.main else { return }
        area = screen.visibleFrame
        frame = screen.frame
        if panel == nil {
            let p = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = .floating
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let v = NSView(frame: NSRect(origin: .zero, size: frame.size))
            v.wantsLayer = true
            p.contentView = v
            p.orderFrontRegardless()
            panel = p
            root = v
        }
        if field.isEmpty { popped = 0; startedAt = Date() }
        field.spawn(8, minX: bounds.lowerBound, maxX: bounds.upperBound)
        scene.announce(tr("ฟองสบู่! รอมันลงถึงพื้นแล้วจิ๊กเลย"), symbol: "bubbles.and.sparkles")
        last = Date()
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate(); timer = nil
        field.clear()
        layers.removeAll()
        panel?.orderOut(nil)
        panel = nil; root = nil
    }

    func target() -> PetScene.SeekTarget? {
        guard let x = scene?.petCenterX, let b = field.nearestGrounded(toX: Double(x)) else { return nil }
        let id = b.id
        return PetScene.SeekTarget(x: CGFloat(b.x), reach: 26) { [weak self] in self?.pop(id) }
    }

    private func pop(_ id: Int) {
        guard field.pop(id) else { return }
        popped += 1
        model.perform { $0.recordBubbles(1); return [] }
        scene?.peck()
        if let layer = layers.removeValue(forKey: id) {
            let grow = CABasicAnimation(keyPath: "transform.scale"); grow.toValue = 1.5
            let fade = CABasicAnimation(keyPath: "opacity"); fade.toValue = 0
            let group = CAAnimationGroup(); group.animations = [grow, fade]; group.duration = 0.22
            group.fillMode = .forwards; group.isRemovedOnCompletion = false
            layer.add(group, forKey: "pop")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { layer.removeFromSuperlayer() }
        }
        if field.isEmpty { finish(message: tr("จิ๊กครบแล้ว {0} ลูก!", popped)) }
    }

    private func finish(message: String?) {
        scene?.cheer()
        if let message { scene?.announce(message, symbol: "bubbles.and.sparkles") }
        timer?.invalidate(); timer = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.field.isEmpty else { return }
            self.panel?.orderOut(nil); self.panel = nil; self.root = nil; self.layers.removeAll()
        }
    }

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(last), 0.1)
        last = now
        if now.timeIntervalSince(startedAt) > Self.lifetime { field.clear(); layers.values.forEach { $0.removeFromSuperlayer() }; layers.removeAll(); finish(message: nil); return }
        field.step(dt: dt, minX: bounds.lowerBound, maxX: bounds.upperBound)
        guard let host = root?.layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for b in field.bubbles {
            let layer: CALayer
            if let l = layers[b.id] { layer = l } else {
                layer = CALayer()
                layer.contents = Self.image
                layer.bounds = CGRect(x: 0, y: 0, width: b.radius * 2, height: b.radius * 2)
                host.addSublayer(layer)
                layers[b.id] = layer
            }
            layer.position = CGPoint(x: b.x - frame.minX, y: area.minY + b.height - frame.minY)
        }
        CATransaction.commit()
    }

    /// A soap bubble: clear in the middle, a pale rim and a bright highlight.
    private static func makeImage() -> CGImage? {
        let side: CGFloat = 128
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3))
            NSGradient(colors: [NSColor.white.withAlphaComponent(0.02), NSColor(calibratedRed: 0.6, green: 0.8, blue: 1, alpha: 0.18),
                                NSColor(calibratedRed: 0.9, green: 0.7, blue: 1, alpha: 0.45)],
                       atLocations: [0, 0.75, 1], colorSpace: .sRGB)?
                .draw(in: circle, relativeCenterPosition: .zero)
            NSColor.white.withAlphaComponent(0.7).setStroke()
            circle.lineWidth = 2
            circle.stroke()
            let shine = NSBezierPath(ovalIn: NSRect(x: side * 0.24, y: side * 0.58, width: side * 0.22, height: side * 0.14))
            var t = AffineTransform(); t.translate(x: side * 0.35, y: side * 0.65); t.rotate(byDegrees: 35); t.translate(x: -side * 0.35, y: -side * 0.65)
            shine.transform(using: t)
            NSColor.white.withAlphaComponent(0.85).setFill()
            shine.fill()
            return true
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
