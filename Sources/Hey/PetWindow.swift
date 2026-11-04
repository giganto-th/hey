import AppKit
import SpriteKit
import HeyDomain

final class PetWindow: NSPanel {
    init(size: CGSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// SKView that turns raw mouse input into pet events.
@MainActor
final class PetView: SKView {
    var onEvent: ((PetEvent) -> Void)?
    var onDrop: ((DropPayload) -> Void)?
    var onDragEnter: (() -> Void)?
    var menuProvider: (() -> NSMenu)?
    /// Right-click: the fan menu. (⌥ + right-click still gives the classic text menu.)
    var onContext: (() -> Void)?
    var onGesture: ((GestureKind) -> Void)?
    /// Pinch: the factor to multiply the pet's size by, and whether the fingers have lifted.
    var onPinch: ((CGFloat, Bool) -> Void)?

    private var swipe = SwipeDetector()
    private var rotation = RotationDetector()

    private var stroke = StrokeDetector()
    private var grabOffset = CGPoint.zero
    private var pressedAt = CGPoint.zero
    private var dragging = false
    private var lastDragX: CGFloat = 0
    private var dragDirection: CGFloat = 0
    private var reversals: [TimeInterval] = []
    private var shakeSent = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        allowsTransparency = true
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        preferredFramesPerSecond = 30
        registerForDraggedTypes([.fileURL, .URL, .string])
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        pressedAt = mouse
        grabOffset = CGPoint(x: mouse.x - window.frame.origin.x, y: mouse.y - window.frame.origin.y)
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        if !dragging {
            guard hypot(mouse.x - pressedAt.x, mouse.y - pressedAt.y) > 4 else { return }
            dragging = true
            lastDragX = mouse.x; dragDirection = 0; reversals.removeAll(); shakeSent = false
            onEvent?(.grabbed)
        }
        trackShake(x: mouse.x, at: event.timestamp)
        window.setFrameOrigin(CGPoint(x: mouse.x - grabOffset.x, y: mouse.y - grabOffset.y))
    }

    /// Whipping the pet from side to side leaves it dizzy once it is let go.
    private func trackShake(x: CGFloat, at time: TimeInterval) {
        let dx = x - lastDragX
        guard abs(dx) > 14 else { return }
        let direction: CGFloat = dx > 0 ? 1 : -1
        if dragDirection != 0, direction != dragDirection {
            reversals.append(time)
            reversals.removeAll { time - $0 > 1.2 }
            if reversals.count >= 5, !shakeSent { shakeSent = true; onEvent?(.shaken) }
        }
        dragDirection = direction
        lastDragX = x
    }

    override func mouseUp(with event: NSEvent) {
        if !dragging, event.clickCount == 2 { onGesture?(.doubleClick) }
        if dragging { onEvent?(.released) } else { onEvent?(event.clickCount >= 2 ? .doubleClicked : .clicked) }
        dragging = false
        stroke.reset()
    }

    override func mouseMoved(with event: NSEvent) {
        if stroke.move(x: event.locationInWindow.x, at: event.timestamp) {
            onEvent?(.petted)
        }
    }

    override func mouseExited(with event: NSEvent) { stroke.reset() }

    // MARK: trackpad

    /// Fingers' direction, whatever the "natural scrolling" setting is.
    override func scrollWheel(with event: NSEvent) {
        // Momentum after the fingers lift is just the content coasting; the swipe was decided at lift-off.
        guard event.momentumPhase == [] else { return }
        let precise = event.hasPreciseScrollingDeltas
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        let fingersRight = Double(event.scrollingDeltaX * sign)
        let fingersDown = Double(event.scrollingDeltaY * sign)
        let ended = precise && (event.phase == .ended || event.phase == .cancelled)
        if let g = swipe.scroll(dx: fingersRight, dyUp: -fingersDown, precise: precise, ended: ended, at: event.timestamp) {
            onGesture?(g)
        }
    }

    override func magnify(with event: NSEvent) {
        let ended = event.phase == .ended || event.phase == .cancelled
        onPinch?(1 + event.magnification, ended)
    }

    override func rotate(with event: NSEvent) {
        let ended = event.phase == .ended || event.phase == .cancelled
        if let g = rotation.rotate(by: Double(event.rotation), ended: ended) { onGesture?(g) }
    }

    override func rightMouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option), let menu = menuProvider?() {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            onContext?()
        }
    }

    // MARK: drag & drop (vault entry point)

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEnter?()
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let payload = DropPayload(from: sender.draggingPasteboard) else { return false }
        onDrop?(payload)
        return true
    }
}
