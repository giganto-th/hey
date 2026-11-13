import AppKit
import SpriteKit

/// A short fireworks show above the pet: a few rockets go up from its head and burst. The window exists only while the show runs
/// (a few seconds), lets every click through, and is gone afterwards, so it costs nothing the rest of the time.
@MainActor
enum Fireworks {
    private static var panel: NSPanel?
    static let size = CGSize(width: 440, height: 560)

    /// `from` is the screen point the rockets start at (the pet's head). `shells` is how many go up.
    static func launch(from start: NSPoint, shells: Int) {
        guard panel == nil else { return }                                    // one show at a time
        let screen = NSScreen.screens.first { $0.frame.contains(start) } ?? NSScreen.main
        var origin = NSPoint(x: start.x - size.width / 2, y: start.y - 20)
        if let frame = screen?.visibleFrame {                                  // keep the whole show on screen
            origin.x = min(max(origin.x, frame.minX), frame.maxX - size.width)
            origin.y = min(max(origin.y, frame.minY), frame.maxY - size.height)
        }
        let p = NSPanel(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let view = SKView(frame: NSRect(origin: .zero, size: size))
        view.allowsTransparency = true
        view.preferredFramesPerSecond = 60
        let scene = FireworksScene(size: size, launchX: start.x - origin.x, launchY: start.y - origin.y, shells: max(1, shells))
        view.presentScene(scene)
        p.contentView = view
        p.orderFrontRegardless()
        panel = p
        DispatchQueue.main.asyncAfter(deadline: .now() + scene.duration) {
            MainActor.assumeIsolated {
                (panel?.contentView as? SKView)?.presentScene(nil)
                panel?.orderOut(nil)
                panel = nil
            }
        }
    }
}

private final class FireworksScene: SKScene {
    private let launchX: CGFloat, launchY: CGFloat, shells: Int
    private static let dot: SKTexture = {
        let side = 16
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let g = NSGradient(colors: [.white, NSColor.white.withAlphaComponent(0)])
            g?.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
            return true
        }
        return SKTexture(image: image)
    }()
    private static let palettes: [[NSColor]] = [
        [.systemPink, .systemYellow], [.systemTeal, .white], [.systemOrange, .systemRed],
        [.systemPurple, .systemPink], [.systemGreen, .systemYellow], [NSColor(red: 0.3, green: 0.6, blue: 1, alpha: 1), .white]]

    /// How long the whole show lasts, to take the window down after.
    var duration: Double { Double(shells - 1) * 0.55 + 3.2 }

    init(size: CGSize, launchX: CGFloat, launchY: CGFloat, shells: Int) {
        self.launchX = launchX; self.launchY = launchY; self.shells = shells
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        let palettes = Self.palettes.shuffled()
        for i in 0..<shells {
            let apex = CGPoint(x: launchX + CGFloat.random(in: -130...130) * (shells > 1 ? 1 : 0.4),
                               y: min(size.height - 70, launchY + CGFloat.random(in: 280...400)))
            run(.sequence([.wait(forDuration: Double(i) * 0.55), .run { [weak self] in
                self?.rocket(to: apex, colors: palettes[i % palettes.count])
            }]))
        }
    }

    private func rocket(to apex: CGPoint, colors: [NSColor]) {
        let rocket = SKSpriteNode(texture: Self.dot, size: CGSize(width: 9, height: 9))
        rocket.color = colors[0]; rocket.colorBlendFactor = 0.3
        rocket.position = CGPoint(x: launchX, y: launchY)
        let trail = SKEmitterNode()
        trail.particleTexture = Self.dot
        trail.particleBirthRate = 90
        trail.particleLifetime = 0.35
        trail.particleSpeed = 20; trail.emissionAngle = -.pi / 2; trail.emissionAngleRange = 0.5
        trail.particleScale = 0.35; trail.particleScaleSpeed = -0.8
        trail.particleAlphaSpeed = -2.6
        trail.particleColor = NSColor.systemYellow; trail.particleColorBlendFactor = 1
        trail.particleBlendMode = .add
        trail.targetNode = self
        rocket.addChild(trail)
        addChild(rocket)

        let rise = SKAction.move(to: apex, duration: 0.9)
        rise.timingMode = .easeOut
        rocket.run(.sequence([rise, .run { [weak self] in self?.burst(at: apex, colors: colors) }, .removeFromParent()]))
    }

    private func burst(at point: CGPoint, colors: [NSColor]) {
        // a flash, then a ring of sparks that fall and fade, then a crackle of small glints
        let flash = SKSpriteNode(texture: Self.dot, size: CGSize(width: 110, height: 110))
        flash.position = point; flash.blendMode = .add; flash.color = colors[1]; flash.colorBlendFactor = 0.5
        addChild(flash)
        flash.run(.sequence([.group([.scale(to: 1.6, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))

        let sparks = SKEmitterNode()
        sparks.particleTexture = Self.dot
        sparks.position = point
        sparks.numParticlesToEmit = 260
        sparks.particleBirthRate = 4000
        sparks.particleLifetime = 1.7; sparks.particleLifetimeRange = 0.5
        sparks.particleSpeed = 175; sparks.particleSpeedRange = 120            // a filled sphere, not just a ring
        sparks.emissionAngleRange = .pi * 2
        sparks.xAcceleration = 0; sparks.yAcceleration = -90
        sparks.particleScale = 0.8; sparks.particleScaleRange = 0.25; sparks.particleScaleSpeed = -0.35
        sparks.particleAlphaSpeed = -0.55
        sparks.particleBlendMode = .add
        sparks.particleColorBlendFactor = 1
        let seq = SKKeyframeSequence(keyframeValues: [NSColor.white, colors[1], colors[0], colors[0]], times: [0, 0.08, 0.35, 1])   // a white-hot start
        sparks.particleColorSequence = seq
        sparks.targetNode = self
        addChild(sparks)

        let glints = SKEmitterNode()
        glints.particleTexture = Self.dot
        glints.position = point
        glints.numParticlesToEmit = 70
        glints.particleBirthRate = 60
        glints.particleLifetime = 0.5
        glints.particlePositionRange = CGVector(dx: 170, dy: 170)
        glints.particleScale = 0.45
        glints.particleAlpha = 0; glints.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 0], times: [0, 0.3, 1])
        glints.particleColor = .white; glints.particleColorBlendFactor = 1
        glints.particleBlendMode = .add
        glints.targetNode = self
        run(.sequence([.wait(forDuration: 0.5), .run { [weak self] in self?.addChild(glints) }]))

        run(.sequence([.wait(forDuration: 2.4), .run { sparks.removeFromParent(); glints.removeFromParent() }]))
    }
}
