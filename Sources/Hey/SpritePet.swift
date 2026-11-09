import AppKit
import SpriteKit
import HeyDomain

/// The pet as generated artwork: one picture per pose, brought to life with motion effects (hops, squash and
/// stretch, tilts, springs) and small particle effects (stars, hearts, notes, crumbs, dust).
///
/// Art lives in `Resources/Pets/<species>/<stage>/<pose>.png` (+ `egg.png`); every frame is the same square canvas
/// with the feet on the bottom edge, so swapping frames never makes the bird jump around.
/// Coordinates here are art units: the canvas is `canvas` wide and the idle bird is about 174 tall.
@MainActor
final class SpritePet: SKNode {
    static let canvas: CGFloat = 240
    /// Where the beak and the head are, for effects (art units from the feet / centre line).
    private static let headSpot = CGPoint(x: 28, y: 150)
    private static let beakSpot = CGPoint(x: 62, y: 70)

    enum Pose: String, CaseIterable {
        case idle, walkA = "walk_a", walkB = "walk_b", flapUp = "flap_up", flapDown = "flap_down"
        case peck, eat, sleep, startled, dizzy, happy, carried
    }

    // MARK: art

    private static var cache: [String: [Pose: SKTexture]] = [:]
    private static var eggTextures: [String: SKTexture] = [:]

    private static func roots() -> [URL] {
        let fm = FileManager.default
        var paths: [String] = []
        if let env = ProcessInfo.processInfo.environment["HEY_PETS_DIR"] { paths.append(env) }
        if let res = Bundle.main.resourceURL?.path { paths.append(res + "/Pets") }
        paths.append(fm.currentDirectoryPath + "/Resources/Pets")
        return paths.map { URL(fileURLWithPath: $0) }.filter { fm.fileExists(atPath: $0.path) }
    }

    private static func load(_ relative: String) -> SKTexture? {
        for root in roots() {
            let url = root.appendingPathComponent(relative)
            if FileManager.default.fileExists(atPath: url.path), let image = NSImage(contentsOf: url) { return SKTexture(image: image) }
        }
        return nil
    }

    private static func textures(species: String, stage: PetStage) -> [Pose: SKTexture]? {
        let key = "\(species)/\(stage.rawValue)"
        if let hit = cache[key] { return hit }
        var set: [Pose: SKTexture] = [:]
        for pose in Pose.allCases { if let t = load("\(species)/\(stage.rawValue)/\(pose.rawValue).png") { set[pose] = t } }
        guard set[.idle] != nil else { return nil }
        cache[key] = set
        return set
    }

    /// The species whose adult art is installed, so the picker never offers one that would draw nothing.
    static func installedSpecies() -> [String] {
        PetSpecies.all.map(\.id).filter { textures(species: $0, stage: .adult) != nil }
    }

    /// True when there is art for this species and stage (an egg only needs its one picture).
    static func hasArt(species: String, stage: PetStage) -> Bool {
        if stage == .egg { return egg(species: species) != nil }
        return textures(species: species, stage: stage) != nil
    }

    private static func egg(species: String) -> SKTexture? {
        if let t = eggTextures[species] { return t }
        guard let t = load("\(species)/egg.png") else { return nil }
        eggTextures[species] = t
        return t
    }

    // MARK: frame sequences

    /// A 10-frame animation for one action (`<stage>/anim/<name>_0…9.png`). Stages without them use the single poses.
    enum Clip: String, CaseIterable {
        case idle, walk, type, eat, dance, sleep, flap, fly, startled, dizzy, carried, happy
        /// Plays once from the moment the action starts, instead of looping with the activity's cycle.
        var oneShot: Bool { self == .startled || self == .happy }
    }

    /// Typing clips whose art has no keyboard in it (every other set draws its own), so the code-made one is shown instead.
    private static let typingClipsWithoutKeyboard: Set<String> = ["shishi/child"]

    private static var clips: [String: [SKTexture]] = [:]

    private static func frames(of clip: Clip, species: String, stage: PetStage) -> [SKTexture]? {
        let key = "\(species)/\(stage.rawValue)/\(clip.rawValue)"
        if let hit = clips[key] { return hit.isEmpty ? nil : hit }
        var list: [SKTexture] = []
        for i in 0..<30 {
            guard let t = load("\(species)/\(stage.rawValue)/anim/\(clip.rawValue)_\(i).png") else { break }
            list.append(t)
        }
        clips[key] = list
        return list.isEmpty ? nil : list
    }

    /// The one-time egg → chick sequence (`<species>/hatchling/anim/hatch_0…9.png`), played when the stage changes from egg.
    private static var hatchClip: [String: [SKTexture]] = [:]
    static let hatchDuration = 2.4

    private static func hatchFrames(_ species: String) -> [SKTexture]? {
        if let hit = hatchClip[species] { return hit.isEmpty ? nil : hit }
        var list: [SKTexture] = []
        for i in 0..<30 {
            guard let t = load("\(species)/hatchling/anim/hatch_\(i).png") else { break }
            list.append(t)
        }
        hatchClip[species] = list
        return list.isEmpty ? nil : list
    }

    // MARK: parts

    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 96, height: 14))
    private let lift = SKNode()               // hops and flight height
    private let squash = SKNode()             // squash, stretch and tilt about the feet (or the grip when carried)
    private let body = SKSpriteNode()

    /// A pet lying down is drawn wider than a standing one, and at the same scale it reads as bigger. These shrink the sleeping pose
    /// so it is at most about 15% wider than standing (docs/art-tools/sleep_scale.py makes the table from the art).
    private static let sleepScale: [String: CGFloat] = [
        "fluff/hatchling": 0.90, "fluff/child": 1.00, "fluff/teen": 0.86, "fluff/adult": 0.90,
        "heihei/hatchling": 0.79, "heihei/child": 0.88, "heihei/teen": 0.74, "heihei/adult": 0.85,
        "shishi/hatchling": 1.00, "shishi/child": 0.99, "shishi/teen": 0.98, "shishi/adult": 0.95,
    ]
    private func setBodyScale(sleeping: Bool) {
        let factor = sleeping ? (Self.sleepScale["\(species)/\(stage.rawValue)"] ?? 1) : 1
        if body.xScale != factor { body.setScale(factor) }
    }
    private let fx = SKNode()                 // particles, drawn over the bird
    private let keyboard = SKNode()
    private var keys: [SKShapeNode] = []

    // MARK: motion state

    private var age = 0.0
    private var phase = 0.0
    private var previous: CompanionActivity = .idle
    private var species = "heihei"
    private var tilt = Spring(0), sx = Spring(1), sy = Spring(1), shiftX = Spring(0)
    private var height = 0.0, heightV = 0.0          // hop physics, art units
    private var bobY = 0.0                           // walking bounce, set directly each frame
    private var lastWave = 0.0
    private var idle = IdleVariety()
    private var spawnClock = 0.0
    private var keyboardOpacity: CGFloat = 0
    private var shownFrame: Pose?
    private var shownClip: (clip: Clip, index: Int)?
    private var enteredAt = 0.0
    private var stage: PetStage = .adult
    private var hatchStart: Double?
    private var particles: [Particle] = []
    private var exclaim: SKNode?
    private var exclaimBorn = 0.0
    private var stars: [SKNode] = []
    private var sweat: SKNode?

    private struct Particle {
        let node: SKNode
        var velocity: CGVector
        var age = 0.0
        let life: Double
        let gravity: CGFloat
        let spin: CGFloat
        let grow: CGFloat
    }

    override init() {
        super.init()
        name = "Pet sprite"
        shadow.fillColor = NSColor(white: 0, alpha: 0.16); shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 4, y: 3)
        addChild(shadow)
        addChild(lift)
        lift.addChild(squash)
        body.anchorPoint = CGPoint(x: 0.5, y: 0)
        body.size = CGSize(width: Self.canvas, height: Self.canvas)
        squash.addChild(body)
        lift.addChild(fx)
        fx.zPosition = 5
        buildKeyboard()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildKeyboard() {
        lift.addChild(keyboard)
        keyboard.position = CGPoint(x: 66, y: 1)
        keyboard.zPosition = 2
        let base = CGPath(roundedRect: CGRect(x: -26, y: -1, width: 54, height: 14), cornerWidth: 3, cornerHeight: 3, transform: nil)
        let plate = SKShapeNode(path: base)
        plate.fillColor = NSColor(hex: 0xB2BDB6); plate.strokeColor = NSColor(hex: 0x3A1D2C); plate.lineWidth = 1.4
        keyboard.addChild(plate)
        for row in 0..<2 {
            for column in 0..<6 {
                let kx: CGFloat = -22 + CGFloat(column) * 8
                let ky: CGFloat = CGFloat(row) * 5 + 2
                let rect = CGRect(x: kx, y: ky, width: 6, height: 3.4)
                let key = SKShapeNode(path: CGPath(roundedRect: rect, cornerWidth: 1, cornerHeight: 1, transform: nil))
                key.fillColor = NSColor(hex: 0xF4F0E1); key.strokeColor = NSColor(hex: 0x3A1D2C); key.lineWidth = 0.6
                keyboard.addChild(key); keys.append(key)
            }
        }
        keyboard.alpha = 0
    }

    // MARK: one frame

    /// What one frame wants: which picture, and where the springs should head.
    private struct Target {
        var frame = Pose.idle
        var tilt = 0.0, shift = 0.0, sx = 1.0, sy = 1.0
        var hopCycle = false
        var grip = false
        var clip: Clip?
    }

    private struct Beat {
        var phase: Double
        var wave: Double
        var count: Int
        var cycleStart: Bool
        var amplitude: Double
        var reduced: Bool
    }

    /// An idle move (a shake, a preen) is code-driven motion that needs the faster redraw rate to read as smooth.
    var isMidIdleMove: Bool { idle.move != .none }

    func update(_ presentation: CompanionPresentation, dt: Double, stage: PetStage, species: String) {
        self.species = species
        let wasEgg = self.stage == .egg
        self.stage = stage
        let activity = presentation.activity
        let reduced = !presentation.animates
        let dt = max(dt, 0)
        age += dt
        if wasEgg, stage != .egg, presentation.animates, Self.hatchFrames(species) != nil { hatchStart = age }
        let changed = activity != previous
        if changed { phase = 0; enteredAt = age; enter(activity, from: previous, stage: stage, reduced: reduced); previous = activity }
        let step: Double = dt * presentation.cyclesPerSecond * 2 * Double.pi
        let before: Double = phase
        phase += step
        let cycleNow = Int(floor(phase / (2 * Double.pi)))
        let cycleBefore = Int(floor(before / (2 * Double.pi)))
        let beat = Beat(phase: phase, wave: reduced ? 0 : sin(phase), count: cycleNow,
                        cycleStart: cycleNow != cycleBefore && !changed, amplitude: presentation.amplitude, reduced: reduced)

        isHidden = activity == .dormant
        guard !isHidden else { return }
        if stage == .egg { updateEgg(reduced: reduced, dt: dt); return }
        if let start = hatchStart {
            let fraction = (age - start) / Self.hatchDuration
            if fraction < 1, presentation.animates, let list = Self.hatchFrames(species) {
                body.texture = list[min(list.count - 1, Int(fraction * Double(list.count)))]
                setBodyScale(sleeping: false)
                shownFrame = nil; shownClip = nil
                tilt.snap(to: 0); shiftX.snap(to: 0); sx.snap(to: 1); sy.snap(to: 1); height = 0; heightV = 0
                squash.zRotation = 0; squash.position = .zero; squash.xScale = 1; squash.yScale = 1
                lift.position = .zero; keyboard.alpha = 0; shadow.isHidden = false
                removeAllParticles()
                return
            }
            hatchStart = nil
        }
        guard let set = Self.textures(species: species, stage: stage) else { return }

        idle.update(dt: dt, calm: activity == .idle && !reduced)
        bobY = 0
        var t = target(for: activity, beat: beat, dt: dt)

        // A drawn sequence replaces the single pose and the code-made hops/tilts: the motion is in the frames.
        var playing = false
        if !reduced, let clip = clip(for: activity, idleMove: idle.move), let list = Self.frames(of: clip, species: species, stage: stage) {
            let fraction: Double
            if clip.oneShot { fraction = min((age - enteredAt) / (activity == .startled ? 1.2 : 1.4), 0.999) }
            else { fraction = (beat.phase / (2 * Double.pi)).truncatingRemainder(dividingBy: 1) }
            let index = max(0, min(list.count - 1, Int(fraction * Double(list.count))))
            if shownClip?.clip != clip || shownClip?.index != index { body.texture = list[index]; shownClip = (clip, index); shownFrame = nil }
            setBodyScale(sleeping: clip == .sleep)
            t.hopCycle = false
            t.sx = 1; t.shift = 0
            if ![.carried, .worried, .attentive, .focusing].contains(activity) { t.tilt = 0; t.sy = 1 }
            playing = true
        }
        if !playing {
            shownClip = nil
            if t.hopCycle, !reduced, beat.cycleStart || changed, height <= 0.1 { jump(speed: activity == .dancing ? 215 : 190) }
            if reduced { t.frame = reducedFrame(for: activity) }
            showFrame(t.frame, set: set)
        }
        applyMotion(t, reduced: reduced, dt: dt)
        updateProps(activity: activity, presentation: presentation, frame: t.frame, reduced: reduced, dt: dt)
        updateParticles(dt: dt, reduced: reduced)
    }

    private func applyMotion(_ t: Target, reduced: Bool, dt: Double) {
        if reduced {
            tilt.snap(to: 0); shiftX.snap(to: 0); sx.snap(to: 1); sy.snap(to: 1); height = 0; heightV = 0
        } else {
            tilt.update(toward: t.tilt, dt: dt, frequency: 7, damping: 0.55)
            shiftX.update(toward: t.shift, dt: dt, frequency: 5, damping: 0.7)
            sx.update(toward: t.sx, dt: dt, frequency: 9, damping: 0.45)
            sy.update(toward: t.sy, dt: dt, frequency: 9, damping: 0.45)
            stepHeight(dt: dt)
        }
        // squash on the ground, stretch in the air
        let stretch: CGFloat = CGFloat(max(-0.1, min(0.1, heightV * 0.0003)))
        squash.xScale = CGFloat(sx.value) * (1 - stretch * 0.7)
        squash.yScale = CGFloat(sy.value) * (1 + stretch)
        squash.zRotation = -CGFloat(tilt.value)
        if t.grip {
            let g: CGFloat = 168
            let th = squash.zRotation
            squash.position = CGPoint(x: g * sin(th), y: g - g * cos(th))
        } else {
            squash.position = CGPoint(x: CGFloat(shiftX.value), y: 0)
        }
        lift.position = CGPoint(x: 0, y: CGFloat(max(height, 0) + bobY))
        let airborne: CGFloat = CGFloat(min(max(height, 0) / 120, 1))
        shadow.xScale = 1 - 0.45 * airborne
        shadow.alpha = 1 - 0.5 * airborne
        shadow.isHidden = previous == .flying || previous == .carried || previous == .falling
    }

    private func target(for activity: CompanionActivity, beat b: Beat, dt: Double) -> Target {
        var t = Target()
        let a: Double = b.amplitude
        let wave = b.wave
        let reduced = b.reduced
        let bell = Double(sin(idle.progress * Double.pi))
        switch activity {
        case .idle:
            t.sy = 1 + (reduced ? 0 : 0.012 * sin(age * 1.7))
            t.tilt = reduced ? 0 : 0.02 * sin(age * 0.8)
            switch idle.move {
            case .lookLeft, .lookRight:
                let d: Double = idle.move == .lookLeft ? -1 : 1
                t.tilt += 0.07 * d * bell
                t.shift = 5 * d * bell
            case .preen:
                t.tilt = -0.16 * bell
                t.sy = 1 - 0.04 * bell
                t.frame = bell > 0.35 ? .peck : .idle
            case .stretch:
                t.sy = 1 + 0.07 * bell
                t.sx = 1 - 0.035 * bell
                t.tilt = 0.05 * bell
            case .shake:
                t.tilt = 0.1 * sin(idle.progress * 40) * (1 - idle.progress)
            case .peckGround:
                t.frame = sin(idle.progress * Double.pi * 3) > 0.35 ? .peck : .idle
                t.tilt = t.frame == .peck ? 0.05 : 0
            case .none: break
            }
        case .walking:
            t.frame = sin(b.phase) >= 0 ? .walkA : .walkB
            t.tilt = 0.035 * a
            bobY = abs(wave) * 3.2 * a
            t.sy = 1 + 0.025 * abs(wave) * a
        case .dancing:
            let frames: [Pose] = [.happy, .walkA, .happy, .walkB]
            t.frame = frames[b.count & 3]
            t.tilt = (b.count & 1 == 0 ? 0.13 : -0.13) * a
            t.hopCycle = true
            if b.cycleStart, !reduced { emit(.note, count: 1) }
        case .typing, .quietTyping:
            t.frame = max(0, wave) > 0.45 ? .peck : .idle
            t.tilt = t.frame == .peck ? 0.06 * a : 0
            t.sy = t.frame == .peck ? 0.985 : 1
        case .eating:
            t.frame = wave > 0 ? .eat : .peck
            t.tilt = (wave > 0 ? 0.04 : 0.08) * a
            if b.cycleStart, !reduced { emit(.crumb, count: 3) }
        case .sleeping:
            t.frame = .sleep
            let breath: Double = reduced ? 0 : sin(age * 1.5)
            t.sy = 1 + 0.03 * breath
            t.sx = 1 - 0.012 * breath
            if !reduced, spawnClock(0, every: 1.6, dt: dt) { emit(.zzz, count: 1) }
        case .startled:
            t.frame = .startled
            t.sy = 1 + 0.04 * a
            t.tilt = height < 1 ? 0.035 * sin(age * 55) * a : 0
        case .dizzy:
            t.frame = .dizzy
            t.tilt = 0.13 * sin(age * 2.4) * a
            t.shift = 5 * cos(age * 2.4) * a
            t.sy = 1 + 0.015 * sin(age * 4.8)
        case .flapping:
            t.frame = wave > 0 ? .flapUp : .flapDown
            t.tilt = (wave > 0 ? -0.02 : 0.03) * a
            t.sy = wave > 0 ? 1.025 : 0.975
            if b.cycleStart, !reduced { emit(.dust, count: 2) }
            if !reduced, height <= 0.1, wave < -0.3, !hasClip(.flap) { jump(speed: 90 * a) }
        case .flying:
            t.frame = wave > 0 ? .flapUp : .flapDown
            t.tilt = -0.12 * a
            t.sy = wave > 0 ? 1.03 : 0.97
            if !reduced, spawnClock(1, every: 0.12, dt: dt) { emit(.wind, count: 1) }
        case .pleased:
            t.frame = .happy
            t.hopCycle = true
            t.tilt = 0.08 * sin(b.phase) * a
            if b.cycleStart, !reduced { emit(.heart, count: 2) }
        case .carried:
            t.frame = .carried
            t.grip = true
            t.tilt = reduced ? 0 : 0.17 * sin(age * 5.2) * a
            t.sy = 1 + 0.02 * sin(age * 10.4)
        case .falling:
            t.frame = sin(age * 18) > 0 ? .flapUp : .flapDown
            t.tilt = 0.05 * sin(age * 9) * a
            t.sy = 1.04
        case .worried:
            t.tilt = 0.02 * sin(age * 38)
            t.shift = 1.2 * sin(age * 41)
            if !reduced, spawnClock(2, every: 1.1, dt: dt) { emit(.sweat, count: 1) }
        case .focusing:
            t.tilt = -0.02
            t.sy = 1 + 0.008 * sin(age * 1.1)
        case .attentive: break               // standing still while its menu is open: no sway
        case .egg, .dormant: break
        }
        return t
    }

    private func hasClip(_ clip: Clip) -> Bool { Self.frames(of: clip, species: species, stage: stage) != nil }

    private func clip(for activity: CompanionActivity, idleMove: IdleVariety.Move) -> Clip? {
        switch activity {
        case .walking: .walk
        case .dancing: .dance
        case .typing, .quietTyping: .type
        case .eating: .eat
        case .sleeping: .sleep
        case .startled: .startled
        case .dizzy: .dizzy
        case .flapping: .flap
        case .flying: .fly
        case .carried, .falling: .carried        // arms out and legs kicking works for a fall too
        case .pleased: .happy
        case .idle, .focusing, .worried: .idle
        default: nil          // attentive holds a still pose: its clip would run at 1 cycle/s but is drawn at the low still rate (6 fps), which stutters
        }
    }

    // MARK: frames

    private func showFrame(_ frame: Pose, set: [Pose: SKTexture]) {
        guard frame != shownFrame || body.texture == nil else { return }
        body.texture = set[frame] ?? set[.idle]
        shownFrame = frame
        setBodyScale(sleeping: frame == .sleep)
    }

    /// With reduced motion there is no flapping or swapping: a still, readable pose for each state.
    private func reducedFrame(for activity: CompanionActivity) -> Pose {
        switch activity {
        case .sleeping: .sleep
        case .eating: .eat
        case .typing, .quietTyping: .idle
        case .pleased, .dancing: .happy
        case .startled: .startled
        case .dizzy: .dizzy
        case .carried, .falling: .carried
        case .flapping, .flying: .flapUp
        default: .idle
        }
    }

    // MARK: hops

    private func jump(speed: Double) { heightV = speed }

    private func stepHeight(dt: Double) {
        guard height > 0 || heightV != 0 else { return }
        heightV -= 1500 * dt
        height += heightV * dt
        if height <= 0 {
            if heightV < -140 {                              // landed: squash, and a puff of dust for a big one
                sy.value = max(0.84, 1 + heightV * 0.0004); sx.value = 1 + (1 - sy.value) * 0.8
                if heightV < -260 { emit(.dust, count: 2) }
            }
            height = 0; heightV = 0
        }
    }

    /// A one-off reaction when the activity changes.
    private func enter(_ activity: CompanionActivity, from old: CompanionActivity, stage: PetStage, reduced: Bool) {
        guard !reduced else { return }
        switch activity {
        case .startled:
            if !hasClip(.startled) { jump(speed: 330); sy.value = 1.1; sx.value = 0.93 }
            showExclaim()
        case .pleased:
            if !hasClip(.happy) { sy.value = 0.9; sx.value = 1.06 }
            emit(.heart, count: 3)
        case .flapping:
            if !hasClip(.flap) { sy.value = 0.92; sx.value = 1.04 }
        case .flying:
            if !hasClip(.fly) { jump(speed: 180); sy.value = 0.9 }
        case .dizzy:
            tilt.value = 0.2; startStars()
        case .eating, .typing, .quietTyping:
            break
        case .carried:
            sy.value = 1.06; sx.value = 0.95
        default: break
        }
        if old == .dizzy { clearStars() }
    }

    // MARK: egg

    private func updateEgg(reduced: Bool, dt: Double) {
        if let t = Self.egg(species: species), body.texture !== t { body.texture = t; shownFrame = nil }
        setBodyScale(sleeping: false)
        // a gentle wobble now and then, as if something is stirring inside
        let cycle = age.truncatingRemainder(dividingBy: 5)
        let wobble = reduced || cycle > 1.2 ? 0 : sin(cycle * 22) * 0.11 * (1 - cycle / 1.2)
        tilt.update(toward: wobble, dt: dt, frequency: 12, damping: 0.4)
        squash.zRotation = -CGFloat(tilt.value); squash.position = .zero
        squash.xScale = 1; squash.yScale = 1
        lift.position = .zero
        keyboard.alpha = 0
        shadow.isHidden = false
        removeAllParticles()
    }

    // MARK: props

    private func updateProps(activity: CompanionActivity, presentation: CompanionPresentation, frame: Pose, reduced: Bool, dt: Double) {
        // the drawn typing frames already include their keyboard
        let drawnKeyboard = shownClip?.clip == .type && !Self.typingClipsWithoutKeyboard.contains("\(species)/\(stage.rawValue)")
        let desired: CGFloat = presentation.showsKeyboard && !drawnKeyboard ? 1 : 0
        if [.carried, .falling, .attentive, .dormant].contains(activity) || reduced { keyboardOpacity = desired }
        else { keyboardOpacity += (desired - keyboardOpacity) * min(1, CGFloat(dt) * 12) }
        keyboard.alpha = keyboardOpacity
        keyboard.yScale = 1 - (presentation.showsKeyboard && frame == .peck ? 0.06 : 0)
        for (i, key) in keys.enumerated() { key.position.y = presentation.showsKeyboard && frame == .peck && i == 8 ? -1.4 : 0 }

        if let mark = exclaim {                              // the "!" pops in, holds, then leaves
            let t = CGFloat(age - exclaimBorn)
            mark.setScale(t < 0.12 ? 0.4 + t / 0.12 * 0.8 : 1.2 - min(0.2, (t - 0.12) * 0.5))
            mark.alpha = t > 1.0 ? max(0, 1 - (t - 1.0) / 0.25) : 1
            if t > 1.25 { mark.removeFromParent(); exclaim = nil }
        }
        if activity != .startled, let mark = exclaim { mark.removeFromParent(); exclaim = nil }

        if activity == .dizzy {
            for (i, star) in stars.enumerated() {
                let a = age * 3.2 + Double(i) * 2 * .pi / Double(max(stars.count, 1))
                star.position = CGPoint(x: Self.headSpot.x + 6 + 36 * CGFloat(cos(a)), y: Self.headSpot.y + 28 + 9 * CGFloat(sin(a)))
                star.zPosition = sin(a) > 0 ? -1 : 1
                star.zRotation = CGFloat(age * 4)
            }
        } else if !stars.isEmpty { clearStars() }

        if activity != .worried, let drop = sweat { drop.removeFromParent(); sweat = nil }
    }

    private func spawnClock(_ slot: Double, every interval: Double, dt: Double) -> Bool {
        let key = Int(slot)
        while clocks.count <= key { clocks.append(0) }
        clocks[key] += dt
        if clocks[key] >= interval { clocks[key] = 0; return true }
        return false
    }
    private var clocks: [Double] = []

    // MARK: particles

    private enum Kind { case note, heart, crumb, dust, zzz, wind, sweat }

    private func emit(_ kind: Kind, count: Int) {
        guard particles.count < 40 else { return }
        for i in 0..<count {
            let jitter = CGFloat.random(in: -1...1)
            switch kind {
            case .note:
                add(note(), at: CGPoint(x: -20 + 70 * CGFloat.random(in: 0...1), y: 196), v: CGVector(dx: 14 * jitter, dy: 46), life: 1.4, gravity: 0, spin: 0.4 * jitter, grow: 0.1)
            case .heart:
                add(heart(), at: CGPoint(x: Self.headSpot.x - 10 + 26 * CGFloat(i), y: Self.headSpot.y + 34), v: CGVector(dx: 22 * jitter, dy: 52), life: 1.1, gravity: 0, spin: 0.5 * jitter, grow: 0.2)
            case .crumb:
                add(crumb(), at: Self.beakSpot, v: CGVector(dx: 34 + 30 * jitter, dy: 55 + 25 * CGFloat.random(in: 0...1)), life: 0.5, gravity: 420, spin: 6 * jitter, grow: -0.6)
            case .dust:
                add(puff(), at: CGPoint(x: -10 + 30 * CGFloat(i) , y: 4), v: CGVector(dx: (i == 0 ? -1 : 1) * 36, dy: 14), life: 0.5, gravity: 0, spin: 0, grow: 1.4)
            case .zzz:
                add(letter("Z"), at: CGPoint(x: Self.headSpot.x + 16, y: 92), v: CGVector(dx: 16, dy: 26), life: 2.2, gravity: 0, spin: 0.15, grow: 0.25)
            case .wind:
                add(streak(), at: CGPoint(x: -70, y: 30 + 100 * CGFloat.random(in: 0...1)), v: CGVector(dx: -150, dy: 0), life: 0.3, gravity: 0, spin: 0, grow: 0)
            case .sweat:
                if sweat == nil {
                    let drop = sweatDrop(); drop.position = CGPoint(x: Self.headSpot.x - 22, y: Self.headSpot.y + 32); fx.addChild(drop); sweat = drop
                    drop.run(.repeatForever(.sequence([.moveBy(x: 0, y: -5, duration: 0.45), .moveBy(x: 0, y: 5, duration: 0.0)])))
                }
            }
        }
    }

    private func add(_ node: SKNode, at point: CGPoint, v: CGVector, life: Double, gravity: CGFloat, spin: CGFloat, grow: CGFloat) {
        node.position = point
        fx.addChild(node)
        particles.append(Particle(node: node, velocity: v, life: life, gravity: gravity, spin: spin, grow: grow))
    }

    private func updateParticles(dt: Double, reduced: Bool) {
        if reduced { removeAllParticles(); return }
        var alive: [Particle] = []
        for var p in particles {
            p.age += dt
            if p.age >= p.life { p.node.removeFromParent(); continue }
            p.velocity.dy -= p.gravity * CGFloat(dt)
            p.node.position.x += p.velocity.dx * CGFloat(dt)
            p.node.position.y += p.velocity.dy * CGFloat(dt)
            p.node.zRotation += p.spin * CGFloat(dt)
            let t = CGFloat(p.age / p.life)
            p.node.setScale(max(0.05, 1 + p.grow * t))
            p.node.alpha = t < 0.7 ? 1 : max(0, 1 - (t - 0.7) / 0.3)
            alive.append(p)
        }
        particles = alive
    }

    private func removeAllParticles() {
        for p in particles { p.node.removeFromParent() }
        particles.removeAll()
        exclaim?.removeFromParent(); exclaim = nil
        sweat?.removeFromParent(); sweat = nil
        clearStars()
    }

    // MARK: effect shapes (drawn, so there is no emoji anywhere)

    private func shape(_ path: CGPath, fill: NSColor, stroke: NSColor = NSColor(hex: 0x3A1D2C), width: CGFloat = 1.2) -> SKShapeNode {
        let n = SKShapeNode(path: path)
        n.fillColor = fill; n.strokeColor = stroke; n.lineWidth = width; n.lineJoin = .round
        return n
    }

    private func star(radius: CGFloat) -> SKShapeNode {
        let p = CGMutablePath()
        for i in 0..<10 {
            let r = i % 2 == 0 ? radius : radius * 0.45
            let a = CGFloat(i) * .pi / 5 + .pi / 2
            let pt = CGPoint(x: r * cos(a), y: r * sin(a))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return shape(p, fill: NSColor(hex: 0xFFD84A))
    }

    private func heart() -> SKShapeNode {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: -7))
        p.addCurve(to: CGPoint(x: -8, y: 3), control1: CGPoint(x: -4, y: -4), control2: CGPoint(x: -8, y: -1))
        p.addCurve(to: CGPoint(x: 0, y: 4), control1: CGPoint(x: -8, y: 8), control2: CGPoint(x: -2, y: 8))
        p.addCurve(to: CGPoint(x: 8, y: 3), control1: CGPoint(x: 2, y: 8), control2: CGPoint(x: 8, y: 8))
        p.addCurve(to: CGPoint(x: 0, y: -7), control1: CGPoint(x: 8, y: -1), control2: CGPoint(x: 4, y: -4))
        return shape(p, fill: NSColor(hex: 0xF0426B))
    }

    private func note() -> SKShapeNode {
        let p = CGMutablePath()
        p.addEllipse(in: CGRect(x: -6, y: -5, width: 9, height: 7))
        p.move(to: CGPoint(x: 2.5, y: -1.5)); p.addLine(to: CGPoint(x: 2.5, y: 13))
        p.addCurve(to: CGPoint(x: 9, y: 6), control1: CGPoint(x: 4, y: 11), control2: CGPoint(x: 9, y: 11))
        let n = shape(p, fill: NSColor(hex: 0x6C4BD8), stroke: NSColor(hex: 0x6C4BD8), width: 1.6)
        return n
    }

    private func crumb() -> SKShapeNode {
        let n = SKShapeNode(ellipseOf: CGSize(width: 4.5, height: 3))
        n.fillColor = NSColor(hex: 0xF3C247); n.strokeColor = NSColor(hex: 0x3A1D2C); n.lineWidth = 0.6
        return n
    }

    private func puff() -> SKShapeNode {
        let n = SKShapeNode(circleOfRadius: 6)
        n.fillColor = NSColor(white: 1, alpha: 0.75); n.strokeColor = NSColor(white: 0.6, alpha: 0.5); n.lineWidth = 0.8
        return n
    }

    private func streak() -> SKShapeNode {
        let p = CGMutablePath(); p.move(to: .zero); p.addLine(to: CGPoint(x: 26, y: 0))
        let n = SKShapeNode(path: p)
        n.strokeColor = NSColor(white: 1, alpha: 0.85); n.lineWidth = 2.2; n.lineCap = .round
        return n
    }

    private func letter(_ text: String) -> SKNode {
        let l = SKLabelNode(text: text)
        l.fontName = "ArialRoundedMTBold"; l.fontSize = 22; l.fontColor = NSColor(hex: 0x4B6FD8)
        l.verticalAlignmentMode = .center
        return l
    }

    private func sweatDrop() -> SKShapeNode {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: 9))
        p.addCurve(to: CGPoint(x: 0, y: -6), control1: CGPoint(x: 8, y: -1), control2: CGPoint(x: 6, y: -6))
        p.addCurve(to: CGPoint(x: 0, y: 9), control1: CGPoint(x: -6, y: -6), control2: CGPoint(x: -8, y: -1))
        return shape(p, fill: NSColor(hex: 0x8FD3F4))
    }

    private func showExclaim() {
        exclaim?.removeFromParent()
        let node = SKNode()
        let bar = CGMutablePath(); bar.addRoundedRect(in: CGRect(x: -4, y: 2, width: 8, height: 22), cornerWidth: 4, cornerHeight: 4)
        node.addChild(shape(bar, fill: NSColor(hex: 0xFF3B3B), width: 1.4))
        node.addChild(shape(CGPath(ellipseIn: CGRect(x: -4.5, y: -9, width: 9, height: 9), transform: nil), fill: NSColor(hex: 0xFF3B3B), width: 1.4))
        node.position = CGPoint(x: Self.headSpot.x + 8, y: Self.headSpot.y + 40)
        exclaimBorn = age
        fx.addChild(node)
        exclaim = node
    }

    private func startStars() {
        clearStars()
        for _ in 0..<3 { let s = star(radius: 7); fx.addChild(s); stars.append(s) }
    }

    private func clearStars() {
        for s in stars { s.removeFromParent() }
        stars.removeAll()
    }
}
