import AppKit
import SpriteKit
import HeyDomain

/// Articulated 2D rooster. All joints use one clock; the feet and UI have independent anchors.
/// Canonical art coordinates: feet y=0, top of comb y=174, facing right.
@MainActor
final class HeiHeiRig: SKNode {
    private static let ink = NSColor(hex: 0x3A1D2C)
    private static let gold = NSColor(hex: 0xF6B02A)
    private static let red = NSColor(hex: 0xE8244F)
    private static let brown = NSColor(hex: 0xE8861F)
    private static let teal = NSColor(hex: 0xB8321F)
    private static let beakColor = NSColor(hex: 0xF39A2B)

    private let bodyRoot = SKNode()
    private let tail = SKNode()
    private let neck = SKShapeNode()
    private let head = SKNode()
    private let wing = SKNode()
    private let farWing = SKNode()
    private let comb = SKNode()
    private let wattles = SKNode()
    private let eyes = [SKNode(), SKNode()]
    private let pupils = [SKShapeNode(circleOfRadius: 2.9), SKShapeNode(circleOfRadius: 2.6)]
    private let legs = [SKShapeNode(), SKShapeNode()]
    private let keyboard = SKNode()
    private let food = SKNode()
    private var keys: [SKShapeNode] = []
    private var phase = 0.0
    private var age = 0.0
    private var keyboardOpacity: CGFloat = 0
    private var previous: CompanionActivity = .idle

    // Every moving part chases its target on a spring, so nothing starts or stops abruptly and the loose parts
    // (comb, wattles, tail) lag behind the head and overshoot a little.
    private var headX = Spring(16), headY = Spring(126), headTilt = Spring(0)
    private var wingFlap = Spring(0)
    private var bob = Spring(0), lean = Spring(0), sway = Spring(0)
    private var tailSwing = Spring(0), combFlop = Spring(0), wattleFlop = Spring(0)
    private var idle = IdleVariety()

    /// How a bird of each age is proportioned: young ones have a big head, a short neck and a stub of a tail.
    private struct Look { var head: CGFloat, neckDrop: CGFloat, tail: CGFloat, comb: CGFloat, eyes: CGFloat }
    private static func look(for stage: PetStage) -> Look {
        switch stage {
        case .egg, .hatchling: Look(head: 1.30, neckDrop: -38, tail: 0.40, comb: 0.35, eyes: 1.18)
        case .child: Look(head: 1.15, neckDrop: -24, tail: 0.65, comb: 0.55, eyes: 1.10)
        case .teen: Look(head: 1.04, neckDrop: -7, tail: 0.88, comb: 0.85, eyes: 1.03)
        case .adult: Look(head: 1.0, neckDrop: 0, tail: 1.0, comb: 1.0, eyes: 1.0)
        }
    }

    override init() {
        super.init()
        name = "Hei Hei articulated rig"
        addChild(bodyRoot)
        buildBody()
        buildHead()
        buildProps()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func shape(_ path: CGPath, color: NSColor, in parent: SKNode, width: CGFloat = 1.8) -> SKShapeNode {
        let node = SKShapeNode(path: path)
        node.fillColor = color
        node.strokeColor = Self.ink
        node.lineWidth = width
        node.lineJoin = .round
        node.isAntialiased = true
        parent.addChild(node)
        return node
    }

    private func ellipse(_ rect: CGRect, color: NSColor, in parent: SKNode, width: CGFloat = 1.8) {
        _ = shape(CGPath(ellipseIn: rect, transform: nil), color: color, in: parent, width: width)
    }

    private func path(_ draw: (CGMutablePath) -> Void) -> CGPath {
        let p = CGMutablePath(); draw(p); return p
    }

    private func buildBody() {
        bodyRoot.addChild(tail)
        tail.position = CGPoint(x: -30, y: 61)
        for (i, color) in [Self.teal, NSColor(hex: 0xE8861F), NSColor(hex: 0xF6B02A)].enumerated() {
            let shift = CGFloat(i) * 7
            _ = shape(path { p in
                p.move(to: .zero)
                p.addCurve(to: CGPoint(x: -43 + shift, y: 65 - shift), control1: CGPoint(x: -7, y: 31), control2: CGPoint(x: -13 + shift, y: 89 - shift))
                p.addCurve(to: CGPoint(x: -66 + shift, y: 28 - shift), control1: CGPoint(x: -75 + shift, y: 82 - shift), control2: CGPoint(x: -82 + shift, y: 42 - shift))
                p.addCurve(to: CGPoint(x: -39 + shift, y: 48 - shift), control1: CGPoint(x: -62 + shift, y: 53 - shift), control2: CGPoint(x: -48 + shift, y: 63 - shift))
                p.addCurve(to: CGPoint(x: -12, y: 4), control1: CGPoint(x: -20 + shift, y: 40 - shift), control2: CGPoint(x: -25, y: 16))
                p.addCurve(to: .zero, control1: CGPoint(x: -4, y: -10), control2: CGPoint(x: 8, y: -2)); p.closeSubpath()
            }, color: color, in: tail)
        }
        bodyRoot.addChild(farWing)
        farWing.position = CGPoint(x: 16, y: 68)
        buildWing(in: farWing, color: NSColor(hex: 0xC8681A))
        for leg in legs {
            leg.strokeColor = Self.beakColor; leg.lineWidth = 5; leg.lineCap = .round; leg.lineJoin = .round
            bodyRoot.addChild(leg)
        }
        _ = shape(path { p in
            p.move(to: CGPoint(x: -35, y: 68))
            p.addCurve(to: CGPoint(x: -26, y: 28), control1: CGPoint(x: -47, y: 49), control2: CGPoint(x: -41, y: 31))
            p.addLine(to: CGPoint(x: -20, y: 33)); p.addLine(to: CGPoint(x: -15, y: 26)); p.addLine(to: CGPoint(x: -8, y: 32))
            p.addCurve(to: CGPoint(x: 23, y: 67), control1: CGPoint(x: 25, y: 19), control2: CGPoint(x: 37, y: 52))
            p.addCurve(to: CGPoint(x: -35, y: 68), control1: CGPoint(x: 13, y: 87), control2: CGPoint(x: -22, y: 89)); p.closeSubpath()
        }, color: Self.brown, in: bodyRoot)
        ellipse(CGRect(x: -16, y: 34, width: 36, height: 40), color: NSColor(hex: 0xFAD24B), in: bodyRoot, width: 0)
        ellipse(CGRect(x: -30, y: 38, width: 30, height: 24), color: NSColor(hex: 0xC8681A), in: bodyRoot, width: 0)
        neck.fillColor = Self.gold; neck.strokeColor = Self.ink; neck.lineWidth = 2.2; neck.lineJoin = .round
        bodyRoot.addChild(neck)
        bodyRoot.addChild(wing)
        wing.position = CGPoint(x: -16, y: 67)
        buildWing(in: wing, color: NSColor(hex: 0xE2781C))
        bodyRoot.addChild(head)
    }

    private func buildWing(in parent: SKNode, color: NSColor) {
        _ = shape(path { p in
            p.move(to: CGPoint(x: 2, y: 2))
            p.addCurve(to: CGPoint(x: -17, y: -24), control1: CGPoint(x: -24, y: 11), control2: CGPoint(x: -37, y: -4))
            p.addLine(to: CGPoint(x: -14, y: -17)); p.addLine(to: CGPoint(x: -7, y: -25)); p.addLine(to: CGPoint(x: -3, y: -17))
            p.addCurve(to: CGPoint(x: 2, y: 2), control1: CGPoint(x: 10, y: -22), control2: CGPoint(x: 13, y: -5)); p.closeSubpath()
        }, color: color, in: parent)
    }

    private func buildHead() {
        head.addChild(wattles)
        ellipse(CGRect(x: 10, y: -31, width: 15, height: 29), color: Self.red, in: wattles)
        ellipse(CGRect(x: 24, y: -28, width: 12, height: 23), color: Self.red, in: wattles)
        _ = shape(path { p in
            p.move(to: CGPoint(x: -13, y: 8)); p.addLine(to: CGPoint(x: -18, y: -7)); p.addLine(to: CGPoint(x: -9, y: -4))
            p.addLine(to: CGPoint(x: -13, y: -16)); p.addLine(to: CGPoint(x: 0, y: -12))
            p.addCurve(to: CGPoint(x: 29, y: 5), control1: CGPoint(x: 32, y: -25), control2: CGPoint(x: 43, y: -4))
            p.addCurve(to: CGPoint(x: -13, y: 8), control1: CGPoint(x: 31, y: 30), control2: CGPoint(x: -4, y: 28)); p.closeSubpath()
        }, color: Self.gold, in: head)
        head.addChild(comb)
        _ = shape(path { p in
            p.move(to: CGPoint(x: -10, y: 18))
            p.addCurve(to: CGPoint(x: -17, y: 42), control1: CGPoint(x: -34, y: 39), control2: CGPoint(x: -32, y: 53))
            p.addCurve(to: CGPoint(x: 1, y: 32), control1: CGPoint(x: -4, y: 51), control2: CGPoint(x: 2, y: 42))
            p.addCurve(to: CGPoint(x: 9, y: 44), control1: CGPoint(x: -4, y: 66), control2: CGPoint(x: 21, y: 58))
            p.addCurve(to: CGPoint(x: 18, y: 28), control1: CGPoint(x: 18, y: 37), control2: CGPoint(x: 20, y: 33))
            p.addCurve(to: CGPoint(x: 27, y: 40), control1: CGPoint(x: 33, y: 32), control2: CGPoint(x: 33, y: 52))
            p.addCurve(to: CGPoint(x: 21, y: 13), control1: CGPoint(x: 47, y: 45), control2: CGPoint(x: 40, y: 19))
            p.addLine(to: CGPoint(x: -10, y: 18)); p.closeSubpath()
        }, color: Self.red, in: comb)
        for (x, y, w, h, r) in [(-24.0, 44.0, 9.0, 5.0, 0.9), (4.0, 51.0, 10.0, 5.0, -0.2), (30.0, 42.0, 9.0, 5.0, -0.8)] {
            let tip = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
            tip.fillColor = NSColor(hex: 0xF77A94); tip.strokeColor = .clear
            tip.position = CGPoint(x: x, y: y); tip.zRotation = r
            comb.addChild(tip)
        }
        // Far eye first, then beak, then the larger near eye: readable at 80 pt.
        for i in [1, 0] {
            let eye = eyes[i]
            eye.position = i == 0 ? CGPoint(x: 1, y: 8) : CGPoint(x: 24, y: 14)
            head.addChild(eye)
            ellipse(CGRect(x: -15, y: -18, width: 30, height: 36), color: NSColor(hex: 0xB04A86), in: eye, width: 0.8)
            ellipse(CGRect(x: -13, y: -16, width: 26, height: 32), color: NSColor(hex: 0xF3EEF3), in: eye, width: 1.4)
            pupils[i].fillColor = NSColor(hex: 0x15101A); pupils[i].strokeColor = .clear
            eye.addChild(pupils[i])
        }
        let beak = shape(path { p in
            p.move(to: CGPoint(x: 20, y: -4))
            p.addCurve(to: CGPoint(x: 55, y: -9), control1: CGPoint(x: 34, y: 9), control2: CGPoint(x: 47, y: 2))
            p.addCurve(to: CGPoint(x: 25, y: -15), control1: CGPoint(x: 44, y: -5), control2: CGPoint(x: 40, y: -16))
            p.closeSubpath()
        }, color: Self.beakColor, in: head)
        beak.zPosition = 1
    }

    private func buildProps() {
        addChild(keyboard)
        keyboard.position = CGPoint(x: 48, y: 1)
        let base = CGPath(roundedRect: CGRect(x: -22, y: -1, width: 45, height: 12), cornerWidth: 3, cornerHeight: 3, transform: nil)
        _ = shape(base, color: NSColor(hex: 0xB2BDB6), in: keyboard, width: 1.3)
        for row in 0..<2 {
            for column in 0..<5 {
                let key = shape(CGPath(roundedRect: CGRect(x: -18 + column * 8, y: row * 4 + 2, width: 6, height: 3), cornerWidth: 1, cornerHeight: 1, transform: nil), color: NSColor(hex: 0xF4F0E1), in: keyboard, width: 0.6)
                keys.append(key)
            }
        }
        addChild(food)
        food.position = CGPoint(x: 48, y: 3)
        for i in 0..<3 { ellipse(CGRect(x: i * 5 - 5, y: i % 2, width: 5, height: 3), color: Self.beakColor, in: food, width: 0.7) }
        keyboard.alpha = 0; food.isHidden = true
    }

    func update(_ presentation: CompanionPresentation, dt: Double, stage: PetStage, curious: Bool = true) {
        let activity = presentation.activity
        let a = CGFloat(presentation.amplitude)
        let reduced = !presentation.animates
        let dt = max(dt, 0)
        age += dt
        // Keep the phase continuous when typing speed changes, but start a new activity from the beginning of its cycle.
        if activity != previous { phase = 0; previous = activity }
        phase += dt * presentation.cyclesPerSecond * 2 * .pi
        let wave = reduced ? 0 : CGFloat(sin(phase))
        let peck = reduced ? CGFloat(0.5) : pow(max(0, wave), 2)
        let look = Self.look(for: stage)

        idle.update(dt: dt, calm: activity == .idle && !reduced)
        let bell = CGFloat(sin(idle.progress * .pi))                     // 0 → 1 → 0 across an idle move

        // ---- targets for this frame ----
        var target = CGPoint(x: 16, y: 126)
        var tilt: CGFloat = 0, flap: CGFloat = 0, step: CGFloat = 0
        var bobTarget: CGFloat = 0, leanTarget: CGFloat = 0, body: CGFloat = 1
        var pupilDrift = CGPoint.zero
        var pecking = false
        switch activity {
        case .typing, .quietTyping, .eating:
            pecking = true
            target = CGPoint(x: 22 + 10 * peck, y: 101 - 42 * peck)
            tilt = -0.2 - peck * 0.9
            flap = 0.08 * wave * a
            leanTarget = 0.05 + 0.06 * peck
        case .dancing:
            target = CGPoint(x: 16 + 7 * wave * a, y: 126 + 5 * abs(wave) * a)
            tilt = 0.18 * wave * a
            flap = -0.5 * abs(wave) * a
            step = wave * a
            bobTarget = 5 * abs(wave) * a
            leanTarget = 0.07 * wave * a
        case .walking:
            step = wave * a
            bobTarget = 3 * abs(wave) * a
            target.y += 3 * wave * a
            target.x += 3 * a
            leanTarget = 0.05 * a
        case .pleased:
            flap = -0.75 * a
            bobTarget = 9 * abs(wave) * a
            tilt = 0.12 * wave * a
            body = 1 + 0.05 * (1 - abs(wave))
        case .sleeping:
            // tucked in: sunk down onto its belly, head turned back into the shoulder, slow breathing
            target = CGPoint(x: 2, y: 80); tilt = -0.6
            bobTarget = -21
            body = 1 + (reduced ? 0 : 0.03 * CGFloat(sin(age * 1.5)))
        case .focusing:
            target = CGPoint(x: 9, y: 118); tilt = -0.08
            leanTarget = 0.03
        case .carried, .falling:
            flap = -0.95 * a; target.y += 10 * a; tilt = 0.1 * wave * a
            bobTarget = 4 * abs(wave) * a
        case .worried:
            target.y = 113; tilt = -0.12; flap = 0.1
            leanTarget = 0.02 * CGFloat(sin(age * 38))                   // a tremble
        case .idle:
            target.y += wave * a
            tilt = 0.035 * CGFloat(sin(age * 0.8)) * a
            body = 1 + (reduced ? 0 : 0.012 * CGFloat(sin(age * 1.7)))   // breathing
            switch idle.move {
            case .lookLeft, .lookRight:
                let d: CGFloat = idle.move == .lookLeft ? -1 : 1
                target.x += 6 * d * bell; tilt += 0.28 * d * bell
                pupilDrift = CGPoint(x: 5 * d * bell, y: 0)
            case .preen:
                target = CGPoint(x: 4 * bell + 16 * (1 - bell), y: 126 - 30 * bell)
                tilt = -0.85 * bell; flap = -0.45 * bell
            case .stretch:
                target.y += 15 * bell; tilt = 0.4 * bell; flap = -1.0 * bell
                body = 1 + 0.07 * bell
            case .shake:
                leanTarget = 0.1 * CGFloat(sin(idle.progress * 42)) * (1 - CGFloat(idle.progress))
                tilt = -0.2 * leanTarget * 8
            case .peckGround:
                let p = pow(max(0, CGFloat(sin(idle.progress * .pi * 3))), 2)
                target = CGPoint(x: 20 + 8 * p, y: 108 - 36 * p); tilt = -0.2 - 0.8 * p
                pecking = true
            case .none: break
            }
        case .attentive, .egg, .dormant, .startled, .dizzy, .flapping, .flying: break
        }
        // young birds hold the head lower on a shorter neck
        target.y += look.neckDrop * (pecking ? 0.45 : 1)

        // ---- springs ----
        func chase(_ s: inout Spring, _ t: Double, _ frequency: Double, _ damping: Double) {
            if reduced { s.snap(to: t) } else { s.update(toward: t, dt: dt, frequency: frequency, damping: damping) }
        }
        chase(&headX, Double(target.x), pecking ? 11 : 5, pecking ? 0.8 : 0.68)
        chase(&headY, Double(target.y), pecking ? 11 : 5, pecking ? 0.8 : 0.68)
        chase(&headTilt, Double(tilt), pecking ? 11 : 5, 0.7)
        chase(&wingFlap, Double(flap), 9, 0.5)
        chase(&bob, Double(bobTarget), 8, activity == .sleeping ? 0.95 : 0.6)
        chase(&lean, Double(leanTarget), 6, 0.7)
        // loose parts swing against the head's acceleration, then settle
        let kick = reduced ? 0 : -headX.velocity * 0.0045 - headTilt.velocity * 0.05
        chase(&combFlop, Double(max(-0.55, min(0.55, kick))), 7, 0.32)
        chase(&wattleFlop, Double(max(-0.6, min(0.6, kick * 1.2))), 6, 0.28)
        let tailBase = reduced ? 0 : -0.06 * sin(phase - 0.35) * Double(a) - 0.02 * sin(age * 1.1)
        chase(&tailSwing, tailBase + max(-0.2, min(0.2, -bob.velocity * 0.0015)) - lean.value * 0.6, 6, 0.5)

        let hx = CGFloat(headX.value), hy = CGFloat(headY.value)
        head.position = CGPoint(x: hx, y: hy); head.zRotation = CGFloat(headTilt.value)
        head.setScale(look.head)
        wing.zRotation = CGFloat(wingFlap.value); farWing.zRotation = -CGFloat(wingFlap.value) * 0.8
        comb.zRotation = CGFloat(combFlop.value); comb.setScale(look.comb * 1.3)
        wattles.zRotation = CGFloat(wattleFlop.value)
        tail.zRotation = CGFloat(tailSwing.value); tail.setScale(look.tail)

        // squash and stretch from the vertical speed, so hops have weight
        let vy = CGFloat(bob.velocity)
        let stretch = max(-0.09, min(0.09, vy * 0.0016))
        bodyRoot.position = CGPoint(x: -step * 1.6, y: CGFloat(bob.value))
        bodyRoot.yScale = body * (1 + stretch)
        bodyRoot.xScale = body * (1 - stretch * 0.7)
        bodyRoot.zRotation = -CGFloat(lean.value)

        neck.path = path { p in
            p.move(to: CGPoint(x: -5, y: 70))
            p.addCurve(to: CGPoint(x: hx - 6, y: hy + 5), control1: CGPoint(x: -8, y: 105), control2: CGPoint(x: hx - 21, y: hy - 12))
            p.addLine(to: CGPoint(x: hx + 13, y: hy - 8))
            p.addCurve(to: CGPoint(x: 18, y: 63), control1: CGPoint(x: hx - 2, y: hy - 25), control2: CGPoint(x: 18, y: 80))
            p.addLine(to: CGPoint(x: 12, y: 58)); p.addLine(to: CGPoint(x: 7, y: 65)); p.addLine(to: CGPoint(x: 2, y: 59)); p.closeSubpath()
        }

        // legs: a proper stride (swing forward and back, lift the moving foot), folded away when asleep
        let sleeping = activity == .sleeping
        let dangling: CGFloat = activity == .carried || activity == .falling ? 7 : 0
        for i in 0..<2 {
            let x: CGFloat = i == 0 ? -12 : 8
            let phaseSign: CGFloat = i == 0 ? 1 : -1
            let swing = step * phaseSign * 6
            let lift = max(0, step * phaseSign) * 9
            legs[i].isHidden = sleeping
            legs[i].path = path { p in
                p.move(to: CGPoint(x: x - 2, y: 37))
                p.addLine(to: CGPoint(x: x - 4 + swing * 0.5, y: 18 + lift))
                p.addLine(to: CGPoint(x: x + swing, y: lift - dangling))
                p.addLine(to: CGPoint(x: x + 12 + swing, y: lift - dangling))
                p.move(to: CGPoint(x: x + swing, y: lift - dangling)); p.addLine(to: CGPoint(x: x - 7 + swing, y: lift - 2 - dangling))
            }
        }

        // eyes: blink, close when asleep, and wander on their own so they never look quite together
        let blink = !reduced && age.truncatingRemainder(dividingBy: 5.7) > 5.54
        for i in 0..<2 {
            eyes[i].yScale = (sleeping ? 0.2 : blink ? 0.12 : 1) * look.eyes
            eyes[i].xScale = look.eyes
            var pos = CGPoint(x: i == 0 ? 6 : -3, y: sleeping ? 0 : (i == 0 ? -2 : 4))
            if curious && !reduced && !sleeping {
                let amount: CGFloat = activity == .idle ? 2 : 0.8
                pos.x += amount * CGFloat(sin(age * (i == 0 ? 0.4 : 0.31) + Double(i) * 2))
                pos.y += amount * 0.5 * CGFloat(sin(age * (i == 0 ? 0.23 : 0.29) + 1))
            }
            pos.x += pupilDrift.x; pos.y += pupilDrift.y
            if pecking { pos.y = -5 }
            pupils[i].position = pos
        }

        let desired: CGFloat = presentation.showsKeyboard ? 1 : 0
        // No prop left behind when a higher-priority interaction interrupts typing.
        if [.carried, .falling, .attentive, .dormant].contains(activity) || reduced { keyboardOpacity = desired }
        else { keyboardOpacity += (desired - keyboardOpacity) * min(1, CGFloat(dt) * 12) }
        keyboard.alpha = keyboardOpacity
        keyboard.position.x = 48
        keyboard.yScale = 1 - (presentation.showsKeyboard ? peck * 0.05 * a : 0)
        for (i, key) in keys.enumerated() { key.position.y = presentation.showsKeyboard && i == 7 ? -peck * 1.3 * a : 0 }
        food.isHidden = activity != .eating
        isHidden = activity == .dormant || stage == .egg
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(calibratedRed: CGFloat((hex >> 16) & 255) / 255,
                  green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}
