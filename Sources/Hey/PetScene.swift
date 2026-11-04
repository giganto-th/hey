import AppKit
import SpriteKit
import HeyDomain

@MainActor
final class PetScene: SKScene {
    static let windowSize = CGSize(width: 190, height: 250)
    static let baseSprite: CGFloat = 128

    private let flipNode = SKNode()
    /// Between the flip and the sprite: moods (shivering, panting) and keystroke taps move this, never the pose art.
    private let motionNode = SKNode()
    private var focusCalm = false
    private var ambientCalm = false
    private var menuCalm = false
    private var ambient: AmbientMotion = .none
    private var sinceGaze = 0.0
    private let sprite = SKSpriteNode()
    private let rig = HeiHeiRig()
    private let art = SpritePet()
    private var flyClock = 0.0
    private var flyDuration = 1.6
    private var wasFlying = false
    private var musicPlaying = false
    private var dropActive = false
    private var lastKeyAt: TimeInterval?
    private var fastTyping = false
    private var presentation = CompanionMotion.resolve(CompanionSignals(), settings: MotionSettings(), now: 0)
    let bubbleModel = BubbleModel()
    private let library = SpriteLibrary()
    private var fsm = BehaviorFSM()
    private let model: GameModel

    private var shown: (pose: PetPose, stage: PetStage)?
    private var shownScale = 1.0
    private var lastTime: TimeInterval = 0
    private var velocityY: CGFloat = 0
    private var tickCount = 0
    private(set) var tier: PowerTier = .full
    private var lastBeg = Date.distantPast

    weak var window: NSWindow?

    private var stage: PetStage { model.game.pet.state.stage }
    private var queue: [(text: String, symbol: String?)] = []

    init(size: CGSize, model: GameModel) {
        self.model = model
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        motionNode.addChild(sprite)
        flipNode.addChild(rig)
        flipNode.addChild(art)
        flipNode.addChild(motionNode)
        addChild(flipNode)
        model.observe { [weak self] in self?.handle($0) }
        // Time that passed while the app was closed, then today's check-in.
        model.perform { $0.startSession(at: Date()) }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: input from the view / menus

    /// A real interaction with the pet (counts for stats and quests).
    func send(_ event: PetEvent) {
        if event == .grabbed { perch = nil }             // picked up: no longer standing on anything
        fsm.send(event)
        if event == .clicked || event == .petted || event == .doubleClicked {
            model.perform { $0.pet(at: Date()) }
        }
    }

    /// Show a message above the pet.
    func announce(_ text: String, symbol: String? = nil) { say(text, symbol: symbol) }

    /// Playback state only: automatic dance tempo is not an analysis of the audio.
    func setMusicPlaying(_ on: Bool) {
        musicPlaying = on
        refreshMotion()
    }

    /// Late at night the pet dozes more.
    func setSleepy(_ sleepy: Bool) { fsm.sleepy = sleepy }

    /// A calm pet stays put (used during focus rounds).
    func setCalm(_ calm: Bool) { focusCalm = calm; refreshMotion() }

    /// The pet stands still and pays attention while its menu is open.
    func setMenuOpen(_ open: Bool) {
        menuCalm = open
        refreshMotion()
    }

    func setDropActive(_ active: Bool) { dropActive = active; refreshMotion() }

    private func resolveMotion() -> CompanionPresentation {
        var signals = CompanionSignals()
        signals.pose = fsm.pose; signals.isEgg = stage == .egg; signals.tier = tier
        signals.menuOpen = menuCalm; signals.dropActive = dropActive; signals.focusing = focusCalm
        signals.musicPlaying = musicPlaying
        signals.ambient = model.game.reactions.enabled ? ambient : .none
        signals.lastKeyAt = lastKeyAt; signals.fastTyping = fastTyping
        signals.typingEnabled = model.game.reactions.enabled && model.game.reactions.typing
        signals.systemReduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        return CompanionMotion.resolve(signals, settings: model.game.motion, now: ProcessInfo.processInfo.systemUptime)
    }

    func refreshMotion() {
        let next = resolveMotion()
        if next.activity != presentation.activity, ProcessInfo.processInfo.environment["HEY_DEV_LOG"] != nil {
            print("[motion]", next.activity.rawValue, "keyboard=\(next.showsKeyboard)", "amplitude=\(next.amplitude)")
        }
        presentation = next
        fsm.calm = focusCalm || ambientCalm || menuCalm || dropActive || presentation.holdsPosition
            || !model.game.motion.roam || presentation.amplitude == 0
        if fsm.calm { fsm.settle() }
        applyFrameRate()
    }

    /// The middle of the pet's body, in its window's coordinates.
    /// Height of the top of the pet's head above the bottom of its window.
    var headTop: CGFloat { feetInset + spriteSide * 0.98 }

    /// Roughly how far the pet's body reaches from its centre (so a menu can keep clear of it).
    var bodyRadius: CGFloat { max(spriteSide * 0.40, 36) }

    var bodyCenterInWindow: CGPoint { CGPoint(x: Self.windowSize.width / 2, y: feetInset + spriteSide * 0.42) }

    // MARK: moods from what is happening on the Mac

    /// The pet's lasting mood (shivering when the battery is nearly flat, panting when hot, …).
    func setAmbient(_ mood: AmbientMotion) {
        guard mood != ambient else { return }
        ambient = mood
        ambientCalm = mood.keepsPetStill
        if mood == .dozing { fsm.send(.tired) }
        refreshMotion()
        if stage != .egg { return }

        motionNode.removeAction(forKey: "ambient")
        motionNode.position = .zero
        motionNode.zRotation = 0
        motionNode.yScale = 1
        sprite.removeAction(forKey: "tint")

        func tint(_ color: NSColor, _ amount: CGFloat) {
            sprite.run(.colorize(with: color, colorBlendFactor: amount, duration: 0.6), withKey: "tint")
        }
        switch mood {
        case .none, .typingSlow, .typingFast:
            tint(.white, 0)
        case .dozing:
            tint(.white, 0)
            motionNode.run(.rotate(toAngle: 0.05, duration: 1.5), withKey: "ambient")
        case .lowBattery:
            tint(NSColor(calibratedRed: 0.55, green: 0.62, blue: 0.75, alpha: 1), 0.25)
            let shiver = SKAction.sequence([.moveBy(x: -1.2, y: 0, duration: 0.05), .moveBy(x: 2.4, y: 0, duration: 0.10),
                                            .moveBy(x: -1.2, y: 0, duration: 0.05), .wait(forDuration: 1.4)])
            motionNode.run(.repeatForever(shiver), withKey: "ambient")
        case .criticalBattery:
            let red = NSColor(calibratedRed: 1, green: 0.25, blue: 0.2, alpha: 1)
            sprite.run(.repeatForever(.sequence([
                .colorize(with: red, colorBlendFactor: 0.4, duration: 0.5),
                .colorize(with: red, colorBlendFactor: 0.08, duration: 0.5)])), withKey: "tint")
            let shake = SKAction.sequence([.moveBy(x: -2.5, y: 0, duration: 0.04), .moveBy(x: 5, y: 0, duration: 0.08),
                                           .moveBy(x: -2.5, y: 0, duration: 0.04)])
            motionNode.run(.repeatForever(shake), withKey: "ambient")
        case .hot:
            tint(NSColor(calibratedRed: 1, green: 0.5, blue: 0.3, alpha: 1), 0.28)
            motionNode.run(.repeatForever(.sequence([.scaleY(to: 1.05, duration: 0.18), .scaleY(to: 1.0, duration: 0.18)])),
                           withKey: "ambient")
        }
    }

    /// Receives only timing and speed, never the content of a key.
    func keyTap(fast: Bool) {
        guard tier.rendersPet else { return }
        lastKeyAt = ProcessInfo.processInfo.systemUptime
        fastTyping = fast
        refreshMotion()
    }

    /// One-off events: say something and move.
    func react(to reaction: Reaction) {
        func flash(_ color: NSColor) {
            sprite.run(.sequence([.colorize(with: color, colorBlendFactor: 0.55, duration: 0.12),
                                  .colorize(with: color, colorBlendFactor: 0, duration: 0.5)]), withKey: "flash")
        }
        switch reaction {
        case .lowBattery(let p): say("แบตเหลือ \(p)% แล้วนะ หาที่เสียบปลั๊กหน่อย", symbol: "battery.25percent")
        case .criticalBattery(let p): say("แบตเหลือ \(p)%! เสียบปลั๊กด่วน", symbol: "battery.0percent")
        case .pluggedIn: say("ได้ไฟแล้ว! อิ่มจัง", symbol: "bolt.fill"); fsm.send(.clicked); flash(.systemYellow)
        case .unplugged(let p): if p <= 40 { say("ถอดปลั๊กแล้ว… เหลือ \(p)%") }
        case .fullyCharged: say("แบตเต็มแล้ว ถอดปลั๊กได้นะ", symbol: "battery.100percent"); fsm.send(.clicked); flash(.systemGreen)
        case .overheating: say("ร้อนจังเลย พักเครื่องหน่อยมั้ย", symbol: "thermometer.high")
        case .fastTypist: say("พิมพ์เร็วจัง", symbol: "keyboard"); fsm.send(.clicked)
        case .dozeOff: say("zZz…")
        case .wakeUp: fsm.send(.wake)
        }
    }

    /// Wakes up with a yawn after the Mac comes back from sleep.
    /// A small celebration, e.g. a finished focus round.
    func cheer() { fsm.send(.cheered) }

    func yawn() { fsm.send(.wake); say("ฮ้าว~ ตื่นแล้ว", symbol: "moon.zzz.fill") }

    /// Visual reaction only (e.g. a file was dropped on the pet).
    func react() { fsm.send(.clicked) }

    // MARK: geometry

    private var spriteSide: CGFloat { Self.baseSprite * CGFloat(stage.scale * model.game.gestures.petScale) }

    /// Region (window coordinates) where the pet is solid enough to take mouse input.
    var hitRect: NSRect {
        let w = Self.windowSize.width, s = spriteSide
        return NSRect(x: (w - s * 0.92) / 2, y: feetInset, width: s * 0.92, height: s)
    }

    // MARK: loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(currentTime - lastTime, 0.1)
        lastTime = currentTime

        // The mouse-up can get lost (a dialog opened mid-drag, say); never leave the pet dangling.
        if fsm.pose == .carried, NSEvent.pressedMouseButtons & 1 == 0 { fsm.send(.released) }

        fsm.canFly = stage == .adult && model.game.motion.roam && tier.allowsPerching
        refreshMotion()
        lookAtPointer(dt: dt)
        refreshSurfaces(dt: dt)
        fsm.tick(dt: dt)
        if !presentation.holdsPosition || fsm.pose == .carried || fsm.pose == .falling || fsm.pose == .fly { move(dt: CGFloat(dt)) }
        render(dt: dt)
    }

    /// Curious: when the pointer is near and the pet is just standing there, it turns to look.
    private func lookAtPointer(dt: Double) {
        sinceGaze += dt
        guard sinceGaze >= 0.25 else { return }
        sinceGaze = 0
        guard presentation.activity == .idle, model.game.reactions.enabled, model.game.reactions.curious,
              tier.allowsPerching, let window else { return }
        let mouse = NSEvent.mouseLocation
        let c = NSPoint(x: window.frame.midX, y: window.frame.midY)
        if let right = Gaze.facingRight(pointerX: mouse.x, petCenterX: c.x, pointerDistance: hypot(mouse.x - c.x, mouse.y - c.y)) {
            fsm.face(right: right)
        }
    }

    /// Called by the app's slow clock (every ~10 s) whether or not the pet is being drawn,
    /// so stats, reminders and quests keep moving while rendering is paused.
    func tick() {
        tickCount += 1
        if tickCount % 6 == 0 { model.save() }
        let now = Date()
        let sleeping = fsm.pose == .sleep || presentation.activity == .sleeping
        model.performQuietly { g in
            var events = g.advance(to: now, sleeping: sleeping)
            events += g.dueReminders(at: now)
            return events
        }
        let pet = model.game.pet.state
        if pet.stage != .egg {
            if pet.energy < 15 || ambient == .dozing { fsm.send(.tired) }
            if pet.hunger < 25, now.timeIntervalSince(lastBeg) > 120, bubbleModel.text == nil, queue.isEmpty {
                lastBeg = now
                say("หิวจัง…", symbol: "fork.knife")
            }
        }
    }

    private func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .pet(let e): handle(pet: e)
            case .questCompleted(let q):
                say("\(q.title) +\(q.rewardCoins) เหรียญ", symbol: "checkmark.circle.fill")
            case .allQuestsDone(let bonus):
                say("ภารกิจครบ! +\(bonus) เหรียญ", symbol: "party.popper.fill"); fsm.send(.clicked)
            case .streak(let days, let bonus):
                say(bonus > 0 ? "ต่อเนื่อง \(days) วัน +\(bonus) เหรียญ" : "ต่อเนื่อง \(days) วัน", symbol: "flame.fill")
            case .noStock:
                say("หมดแล้ว ไปซื้อที่ร้านนะ")
            case .reminderDue(let r):
                say(r.text, symbol: "bell.fill"); fsm.send(.clicked)
            case .pomodoroCredited:
                break
            case .vaultAdded(let item):
                say("เก็บแล้ว: \(item.name.prefix(14))", symbol: "tray.and.arrow.down.fill"); fsm.send(.clicked)
            case .vaultDuplicate:
                say("มีไฟล์นี้อยู่แล้ว")
            case .vaultRemoved:
                break
            case .trackAdded:
                say("เพิ่มเพลงแล้ว", symbol: "music.note"); fsm.send(.clicked)
            case .trackDuplicate:
                say("มีเพลงนี้อยู่แล้ว")
            case .mediaAdded(let m):
                say(m.kind.isVideo ? "บันทึกวิดีโอแล้ว" : "บันทึกภาพแล้ว", symbol: m.kind.isVideo ? "video.fill" : "camera.fill"); fsm.send(.clicked)
            case .mediaRemoved:
                break
            case .achievementUnlocked(let a):
                say("\(a.title) +\(a.reward) เหรียญ", symbol: "trophy.fill"); fsm.send(.clicked)
            case .miniGameFinished:
                break   // the game screen shows its own result
            case .shelfAdded(let item):
                say("พักไว้ในถาด: \(item.name.prefix(14))", symbol: "suitcase.fill"); fsm.send(.clicked)
            case .bought, .insufficientCoins:
                break   // the Hub shows these itself
            }
        }
    }

    private func handle(pet event: PetEngineEvent) {
        switch event {
        case .hatched: say("ฟักแล้ว!", symbol: "sparkles"); fsm.send(.clicked)
        case .evolved(let stage): say("โตขึ้นแล้ว: \(stage.displayName)", symbol: "sparkles"); fsm.send(.clicked)
        case .fed: say("อร่อย!", symbol: "fork.knife"); fsm.send(.fed)
        case .refusedEgg: say("ไข่ยังกินไม่ได้นะ")
        case .refusedFull: say("อิ่มแล้ว~")
        case .refusedCooldown(let remaining): say("ยังไม่หิวนะ ให้ได้\(DurationText.wait(remaining))", symbol: "clock")
        case .eggWarmed(let progress, let needed):
            let text = "อุ่นแล้ว \(Int(progress))/\(Int(needed))"
            if bubbleModel.text != nil, queue.isEmpty { bubbleModel.symbol = "flame.fill"; bubbleModel.text = text } else { say(text, symbol: "flame.fill") }
        case .eggWarmEnoughToday: say("วันนี้อุ่นด้วยมือครบแล้ว เปิดแอปไว้ก็อุ่นต่อเองนะ", symbol: "flame.fill")
        case .dailyCheckIn:
            let greeting = Greeting.line(hour: Calendar.current.component(.hour, from: Date()))
            say(greeting.text, symbol: greeting.symbol)
        }
    }

    // MARK: movement

    // MARK: window tops

    private var perch: Surface?
    private var surfaces: [Surface] = []
    private var sinceSurfaces = 0.0
    private var rng: any RandomSource = SystemRandom()

    private var canUseWindows: Bool { model.game.power.walkOnWindows && tier.allowsPerching }
    private var canClimb: Bool { canUseWindows && (stage == .teen || stage == .adult) }
    /// The art has a little empty space under the feet; this keeps the feet on the edge, not floating above it.
    private var feetInset: CGFloat { spriteSide * Self.emptyBelowFeet }

    /// The sprite art puts the feet at 861/1024 of the frame height, so 15.9% of it is empty below the feet.
    static let emptyBelowFeet: CGFloat = 1 - 861.0 / 1024.0

    /// Window origin y that puts the feet right on the bottom edge of the usable screen (just above the Dock).
    func floorY(in area: NSRect) -> CGFloat { area.minY - feetInset }

    private func refreshSurfaces(dt: Double) {
        guard canUseWindows else {
            if perch != nil { perch = nil; forceFall() }
            surfaces = []
            return
        }
        // The window list is only needed by a pet that can climb, or one falling (it may land on a window).
        guard canClimb || perch != nil || fsm.pose == .falling else { surfaces = []; return }
        sinceSurfaces += dt
        guard sinceSurfaces >= 0.5 || surfaces.isEmpty else { return }
        sinceSurfaces = 0
        surfaces = WindowSurfaces.current()
        guard let p = perch, let window else { return }
        // The window may have moved (follow it), shrunk away from under the pet, or closed (fall).
        if let now = surfaces.first(where: { $0.id == p.id }), now.contains(x: window.frame.midX) { perch = now }
        else { perch = nil; forceFall() }
    }

    private func forceFall() {
        velocityY = 0
        fsm.send(.grabbed)
        fsm.send(.released)
    }

    /// Called when the pet starts walking: maybe hop up onto a window, or down from one.
    private func considerPerchChange() {
        guard let window else { return }
        if perch != nil {
            if rng.next(in: 0...1) < 0.3 { perch = nil; forceFall() }
        } else if canClimb, rng.next(in: 0...1) < 0.4,
                  let target = Perches.climbTarget(centerX: window.frame.midX, bottomY: window.frame.minY + feetInset,
                                                   surfaces: surfaces, rng: &rng) {
            perch = target
            var origin = window.frame.origin
            origin.x = Perches.clamp(centerX: window.frame.midX, to: target) - Self.windowSize.width / 2
            origin.y = target.top - feetInset
            window.setFrameOrigin(origin)
            say("ฮึบ!", symbol: "arrow.up.circle.fill")
        }
    }

    // MARK: movement

    private func move(dt: CGFloat) {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        var origin = window.frame.origin
        let half = Self.windowSize.width / 2

        // Dropped past the edge, or its display was unplugged: bring it back.
        if fsm.pose != .carried, perch == nil {
            let x = min(max(origin.x, area.minX), area.maxX - Self.windowSize.width)
            if x != origin.x { origin.x = x; window.setFrameOrigin(origin) }
        }

        switch fsm.pose {
        case .walk where stage != .egg:
            origin.x += 40 * dt * (fsm.facingRight ? 1 : -1)
            if let perch {
                let center = origin.x + half
                let limited = Perches.clamp(centerX: center, to: perch)
                if limited != center { origin.x = limited - half; fsm.turnAround() }     // walked to the edge: turn back
                origin.y = perch.top - feetInset
            } else {
                origin.y = floorY(in: area)
                // turn back at the screen edge, with the whole pet (and its speech bubble) still visible
                let minX = area.minX, maxX = area.maxX - Self.windowSize.width
                if origin.x < minX { origin.x = minX; fsm.turnAround() }
                if origin.x > maxX { origin.x = maxX; fsm.turnAround() }
            }
            window.setFrameOrigin(origin)
        case .falling, .startled, .dizzy, .flap, .fly:
            velocityY -= 1800 * dt
            let feetBefore = origin.y + feetInset
            origin.y += velocityY * dt
            if canUseWindows, let s = Perches.landing(fromY: feetBefore, toY: origin.y + feetInset,
                                                      centerX: origin.x + half, surfaces: surfaces) {
                perch = s
                origin.y = s.top - feetInset
                velocityY = 0
                fsm.send(.landed)
            } else if origin.y <= floorY(in: area) {
                origin.y = floorY(in: area)
                if velocityY < -1000 { fsm.send(.shaken) }           // a long drop leaves it dazed
                if abs(velocityY) > 400 {
                    velocityY = -velocityY * 0.35
                } else {
                    velocityY = 0
                    fsm.send(.landed)
                }
            }
            window.setFrameOrigin(origin)
        default:
            velocityY = 0
            wasFlying = false
            // standing still: stay on the window we're on (it may be dragged around), or on the floor
            let y = perch.map { $0.top - feetInset } ?? floorY(in: area)
            if fsm.pose != .carried, abs(origin.y - y) > 0.5 { origin.y = y; window.setFrameOrigin(origin) }
        }
    }

    // MARK: power

    func setTier(_ tier: PowerTier) {
        self.tier = tier
        if !tier.rendersPet { lastKeyAt = nil; rig.isHidden = true; art.isHidden = true }
        lastTime = 0
        refreshMotion()
        applyFrameRate()
    }

    /// Moving poses get the tier's "active" rate; sitting or sleeping poses only need the low one.
    private func applyFrameRate() {
        guard let view else { return }
        let moving: Bool
        moving = presentation.animates && ![.idle, .sleeping, .focusing, .attentive, .egg].contains(presentation.activity)
        let rates = tier.fps
        let override = ProcessInfo.processInfo.environment["HEY_DEV_FPS"].flatMap(Int.init)   // for measuring
        let fps = max(override ?? (moving ? rates.active : rates.still), 1)
        if view.preferredFramesPerSecond != fps { view.preferredFramesPerSecond = fps }
        if view.isPaused == tier.rendersPet { view.isPaused = !tier.rendersPet }
    }

    // MARK: drawing

    private func render(dt: Double) {
        flipNode.xScale = fsm.facingRight ? 1 : -1
        let stage = self.stage
        let hasArt = SpritePet.hasArt(species: model.game.species, stage: stage)
        let articulated = !hasArt && stage != .egg && model.game.species == "heihei"
        art.isHidden = !hasArt
        rig.isHidden = !articulated
        sprite.isHidden = articulated || hasArt
        if hasArt {
            if sprite.hasActions() { sprite.removeAllActions() }
            if motionNode.hasActions() { motionNode.removeAllActions() }
            let wasWalking = shown?.pose == .walk
            shown = (fsm.pose, stage)
            if fsm.pose == .walk, !wasWalking { considerPerchChange() }
            art.position = CGPoint(x: 0, y: feetInset)
            art.setScale(spriteSide / 174)
            art.update(presentation, dt: dt, stage: stage, species: model.game.species)
            return
        }
        if articulated {
            if sprite.hasActions() { sprite.removeAllActions() }
            if motionNode.hasActions() { motionNode.removeAllActions() }
            let wasWalking = shown?.pose == .walk
            shown = (fsm.pose, stage)
            if fsm.pose == .walk, !wasWalking { considerPerchChange() }
            rig.position = CGPoint(x: 0, y: feetInset)
            rig.setScale(spriteSide / 180)
            rig.update(presentation, dt: dt, stage: stage, curious: model.game.reactions.enabled && model.game.reactions.curious)
            return
        }
        // An egg can't walk or sleep; it just sits there.
        let pose: PetPose = (stage == .egg && (fsm.pose == .walk || fsm.pose == .sleep)) ? .idle : fsm.pose
        let scale = model.game.gestures.petScale
        guard shown?.pose != pose || shown?.stage != stage || shownScale != scale else { return }
        shown = (pose, stage)
        shownScale = scale
        if pose == .walk, stage != .egg { considerPerchChange() }
        applyFrameRate()

        sprite.size = CGSize(width: spriteSide, height: spriteSide)
        sprite.texture = library.texture(for: pose, stage: stage, species: model.game.species)
        sprite.removeAllActions()
        sprite.yScale = 1
        sprite.position = .zero
        sprite.zRotation = 0

        let loop: SKAction
        switch pose {
        case .idle:
            loop = .repeatForever(.sequence([
                .scaleY(to: 1.04, duration: 0.9), .scaleY(to: 1.0, duration: 0.9)]))
        case .sleep:
            loop = .repeatForever(.sequence([
                .scaleY(to: 1.06, duration: 1.8), .scaleY(to: 1.0, duration: 1.8)]))
        case .walk:
            loop = .repeatForever(.sequence([
                .moveBy(x: 0, y: 6, duration: 0.18), .moveBy(x: 0, y: -6, duration: 0.18)]))
        case .happy:
            let hop = SKAction.sequence([
                .moveBy(x: 0, y: 22, duration: 0.2), .moveBy(x: 0, y: -22, duration: 0.2)])
            loop = .repeat(hop, count: 3)
        case .carried:
            loop = .repeatForever(.sequence([
                .rotate(toAngle: 0.15, duration: 0.15), .rotate(toAngle: -0.15, duration: 0.15)]))
        case .eat:
            // peck, peck, peck
            let peck = SKAction.sequence([.rotate(toAngle: -0.12, duration: 0.12), .rotate(toAngle: 0.04, duration: 0.12)])
            loop = .repeat(peck, count: 6)
        case .falling, .startled, .dizzy, .flap, .fly:
            loop = .rotate(toAngle: 0, duration: 0)
        }
        if presentation.amplitude > 0 { sprite.run(loop) }
    }

    /// Bubbles are shown one after another so simultaneous events don't overwrite each other.
    private func say(_ text: String, symbol: String? = nil) {
        guard !queue.contains(where: { $0.text == text }), queue.count < 4 else { return }
        queue.append((text, symbol))
        showNextBubble()
    }

    private func showNextBubble() {
        guard bubbleModel.text == nil, !queue.isEmpty else { return }
        bubbleModel.spriteTop = headTop
        let next = queue.removeFirst()
        bubbleModel.symbol = next.symbol
        bubbleModel.text = next.text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            MainActor.assumeIsolated {
                self?.bubbleModel.text = nil
                // let the old one fade out before the next appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    MainActor.assumeIsolated { self?.showNextBubble() }
                }
            }
        }
    }
}
