import AppKit
import SpriteKit
import SwiftUI
import Carbon.HIToolbox
import HeyDomain

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var window: PetWindow!
    private var food: FoodController!
    private let aiUsage = AIUsageService()
    private var bubbles: BubbleController!
    private let windowSpread = WindowSpreadController()
    private var scene: PetScene!
    private var model: GameModel!
    private var pomodoro = PomodoroModel()
    private var toast: ReminderToastController!
    private var stickies: StickyController!
    private var vault: VaultService!
    private var shelf: ShelfService!
    private let clipboard = ClipboardService()
    private var tray: ShelfTrayController!
    private var dropZones: DropZonesController!
    private var radial: RadialMenuController!
    private var music: MusicPlayer!
    private var detector: MusicDetector!
    private var musicBar: MusicStatusItem!
    private var suggestionToast: SuggestionToastController!
    private var capture: CaptureService!
    private var camera: CameraController!
    private var power: PowerMonitor!
    private var clock: Timer?
    private var termSource: DispatchSourceSignal?
    private let router = HubRouter()
    private var ticksUntilTip = 2
    private var activity: ActivityMonitor!
    private var userHidPet = false
    private let gestureLog = GestureLog()
    private var context = ContextEngine()
    private var appFocus = AppFocusEngine()
    private let calendar = CalendarService()
    private var pendingCorner: Corner?
    private var cornerWork: DispatchWorkItem?
    private var cornerArmed = true
    private var hubWindow: NSWindow?
    private var bubbleHost: PassthroughHostingView<PetBubbleView>?
    private var statusItem: NSStatusItem!
    private var monitors: [Any] = []
    private let devMode = ProcessInfo.processInfo.environment["HEY_DEV"] != nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        handleTerminationSignal()
        installEditMenu()
        NSApp.applicationIconImage = LogoArt.applicationImage()       // for alerts and dialogs
        let size = PetScene.windowSize
        window = PetWindow(size: size)

        model = GameModel()
        let view = PetView(frame: NSRect(origin: .zero, size: size))
        scene = PetScene(size: size, model: model)
        scene.window = window
        food = FoodController(model: model, scene: scene)
        bubbles = BubbleController(scene: scene, model: model)
        aiUsage.onAlert = { [weak self] alert in
            let text = tr("{0} ({1}) ใช้ไปแล้ว {2}% ของโควตา", alert.provider.label, alert.window.label, alert.level)
            self?.scene.announce(text, symbol: "gauge.with.dots.needle.67percent")
            self?.aiUsage.postSystemNotification(text)
        }
        aiUsage.start()
        if WelcomeWindow.shouldShow { DispatchQueue.main.async { [weak self] in if let self { WelcomeWindow.show(model: self.model) } } }
        scene.seekTarget = { [weak self] in self?.food.target() ?? self?.bubbles.target() }
        view.onEvent = { [weak scene] in scene?.send($0) }
        vault = VaultService(model: model)
        music = MusicPlayer(model: model)
        detector = MusicDetector(model: model, player: music)
        detector.isActive = { [weak self] in
            guard let s = self?.power?.signals else { return true }
            return !s.screenAsleep && !s.screenLocked
        }
        suggestionToast = SuggestionToastController(detector: detector)
        detector.onChange = { [weak self] in self?.suggestionToast.sync() }
        detector.onSuggest = { [weak scene] _ in scene?.announce(tr("เจอเพลง YouTube!"), symbol: "music.note") }
        capture = CaptureService(model: model)
        capture.onMessage = { [weak scene] in scene?.announce($0, symbol: $1) }
        capture.onChange = { [weak self] in self?.updateStatusTitle() }
        camera = CameraController(model: model)
        camera.onMessage = { [weak scene] in scene?.announce($0, symbol: $1) }
        music.onMessage = { [weak scene] in scene?.announce($0, symbol: $1) }
        musicBar = MusicStatusItem(music: music, model: model, detector: detector)
        musicBar.onOpenHub = { [weak self] in self?.router.section = .music; self?.openHub() }
        detector.onSystemSongChange = { [weak self] in
            self?.musicBar.sync()
            self?.updateCompanionMusic()
        }
        music.onChange = { [weak self] in
            guard let self else { return }
            self.updateCompanionMusic()
            self.musicBar.sync()
        }
        vault.onMessage = { [weak scene] in scene?.announce($0) }
        view.onDrop = { [weak self] payload in
            guard let self else { return }
            self.route(payload, to: self.model.game.files.dropDefault)      // dropped straight on the pet
        }
        view.onDragEnter = { [weak scene] in scene?.announce(tr("วางเลย!"), symbol: "tray.and.arrow.down.fill") }
        view.onGesture = { [weak self] in self?.gesture($0) }
        view.onPinch = { [weak self] factor, ended in self?.pinch(factor, ended: ended) }
        view.onContext = { [weak self] in self?.openRadial() }
        view.menuProvider = { [weak self] in
            let menu = NSMenu()
            self?.fill(menu)
            return menu
        }
        window.contentView = view
        view.presentScene(scene)
        let bubbleHost = PassthroughHostingView(rootView: PetBubbleView(model: scene.bubbleModel))
        bubbleHost.frame = view.bounds
        bubbleHost.autoresizingMask = [.width, .height]
        view.addSubview(bubbleHost)
        self.bubbleHost = bubbleHost

        if let area = NSScreen.main?.visibleFrame {
            window.setFrameOrigin(CGPoint(x: area.midX - size.width / 2, y: scene.floorY(in: area)))
        }
        window.orderFrontRegardless()

        power = PowerMonitor(model: model)
        power.onChange = { [weak self] in self?.applyPower($0) }
        applyPower(power.decision)
        power.onWake = { [weak self] in self?.scene.yawn() }
        activity = ActivityMonitor(model: model, power: power)
        let logMoods = ProcessInfo.processInfo.environment["HEY_DEV_LOG"] != nil
        activity.onAmbient = { [weak self] in
            if logMoods { print("[mood]", $0) }
            self?.scene.setAmbient($0)
        }
        activity.onReaction = { [weak self] in
            if logMoods { print("[reaction]", $0) }
            self?.scene.react(to: $0)
        }
        activity.onKeys = { [weak self] fast in self?.scene.keyTap(fast: fast) }
        // One slow clock drives stats/reminders/quests, independent of whether the pet is being drawn.
        let t = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scene.tick()
                self?.power.evaluate()
                self?.reactToContext()
                self?.showGuideTip()
                self?.announceCalendar()
            }
        }
        t.tolerance = 3
        RunLoop.main.add(t, forMode: .common)
        clock = t

        radial = RadialMenuController()
        radial.items = { [weak self] page in self?.radialItems(page) ?? [] }
        radial.pages = { [weak self] in [.main, .food] + (self?.model.game.radialMenu.folders.map { RadialPage.folder($0.id) } ?? []) }
        radial.header = { [weak self] in self?.radialHeader() ?? RadialHeaderInfo() }
        radial.onOpenChanged = { [weak self] open in self?.scene.setMenuOpen(open) }

        shelf = ShelfService(model: model)
        clipboard.start()
        tray = ShelfTrayController(model: model, service: shelf)
        shelf.onAdded = { [weak self] in self?.tray.show() }
        dropZones = DropZonesController()
        dropZones.petFrame = { [weak self] in
            guard let self else { return nil }
            var f = self.window.frame
            f.size.height = self.scene.headTop      // the targets go just above the head, not above the empty window
            return f
        }
        dropZones.onDrop = { [weak self] payload, dest in self?.route(payload, to: dest) }
        dropZones.onActiveChanged = { [weak self] active in
            self?.scene.setDropActive(active)
            self?.updateClickThrough()
        }
        dropZones.onDragBegan = { [weak self] in self?.scene.announce(tr("ปล่อยลงช่องไหนดี?"), symbol: "hand.point.up.left.fill") }
        dropZones.startWatching()

        toast = ReminderToastController(model: model)
        stickies = StickyController(model: model)
        model.onChange = { [weak self] in
            self?.scene.refreshMotion()
            self?.toast.sync()
            self?.stickies.sync()
            self?.musicBar.sync()
            self?.tray.sync()
            self?.music.refreshQueueIfNeeded()
        }
        model.observe { [weak self] events in
            for case .vaultRemoved(let items) in events { items.forEach { self?.vault.deleteFiles(of: $0) } }
            if events.contains(where: { if case .reminderDue = $0 { true } else { false } }) {
                NSSound(named: "Glass")?.play()
            }
        }
        toast.sync()
        stickies.sync()

        pomodoro.onEvent = { [weak self] event in self?.pomodoroEvent(event) }
        pomodoro.onChange = { [weak self] in self?.pomodoroChanged() }

        setUpStatusItem()
        setUpClickThrough()
        setUpHotKeys()

        if ProcessInfo.processInfo.environment["HEY_DEV_CALM"] != nil { scene.setCalm(true) }   // measuring: no wandering

        if devMode {   // lets us exercise the vault without dragging by hand
            let env = ProcessInfo.processInfo.environment
            if env["HEY_DEV_ADULT"] != nil {
                model.perform { $0.grantWarmth(10_000) }
                model.perform { $0.grantXP(100_000) }
            }
            if let dir = env["HEY_DEV_PET_FILM"] {
                do { try PetFilm.write(to: URL(fileURLWithPath: dir)) } catch { print("[film] failed:", error) }
            }
            if let dir = env["HEY_DEV_RIG_FILM"] {
                do { try RigFilm.write(to: URL(fileURLWithPath: dir)) } catch { print("[film] failed:", error) }
            }
            if let dir = env["HEY_DEV_RIG_SNAPSHOTS"] {
                do { try CompanionPreviewScene.writeSamples(to: URL(fileURLWithPath: dir)) }
                catch { print("[rig] snapshot failed:", error) }
            }
            if let section = env["HEY_DEV_HUB"].flatMap(HubSection.init(rawValue:)) {
                router.section = section; openHub()
            }
            if let path = env["HEY_DEV_LOCAL_TRACK"] {
                // An isolated silent fixture exercises the real AVPlayer → scene callbacks.
                if model.game.currentPlaylist == nil { model.perform { $0.createPlaylist(tr("ทดสอบเพลง")); return [] } }
                let track = Track(source: .file(path: path, bookmark: nil), title: tr("ทดสอบสถานะเพลง"), addedAt: Date())
                music.setVolume(0)
                if let id = model.game.currentPlaylist?.id {
                    model.perform { $0.addTrack(track, to: id) }
                    if let list = model.game.playlist(id: id) { music.play(track, in: list) }
                }
            }
            if let paths = env["HEY_DEV_DROP"] {
                vault.add(.files(paths.split(separator: ":").map { URL(fileURLWithPath: String($0)) }))
            }
            if let paths = env["HEY_DEV_SHELF"] {
                shelf.add(.files(paths.split(separator: ":").map { URL(fileURLWithPath: String($0)) }))
            }
            if env["HEY_DEV_ZONES"] != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    MainActor.assumeIsolated { self?.dropZones.devShow() }
                }
            }
            if let dir = env["HEY_DEV_HUB_SNAPSHOTS"] {     // render every Hub page to a PNG, to check them without clicking
                Task { @MainActor in
                    self.openHub()
                    for section in HubSection.allCases {
                        self.router.section = section
                        try? await Task.sleep(for: .milliseconds(700))
                        guard let view = self.hubWindow?.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                        view.cacheDisplay(in: view.bounds, to: rep)
                        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(section.rawValue).png"))
                    }
                    print("[hub] all pages rendered")
                }
            }
            if let page = env["HEY_DEV_RADIAL"] {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        if let at = env["HEY_DEV_RADIAL_AT"]?.split(separator: ",").compactMap({ Double($0) }), at.count == 2,
                           let area = NSScreen.main?.visibleFrame {
                            // try the menu with the pet anywhere on the screen (fractions of the visible area)
                            self.radial.open(around: NSPoint(x: area.minX + area.width * at[0], y: area.minY + area.height * at[1]),
                                             petRadius: self.scene.bodyRadius)
                            let l = self.radial.model.layout
                            print("[radial] arcs:", l.arcs.map { "r=\(Int($0.radius)) cap=\($0.capacity) angle=\(Int($0.centerAngle * 180 / .pi))°" },
                                  "window:", self.radial.model.panelSize, "screen:", area.size)
                        } else {
                            self.openRadial()
                        }
                        if page != "main" {
                            self.radial.go(page == "food" ? .food : .folder(page))
                        }
                        if let out = env["HEY_DEV_RADIAL_PNG"] {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                MainActor.assumeIsolated { try? self.radial.snapshot()?.write(to: URL(fileURLWithPath: out)) }
                            }
                        }
                    }
                }
            }
            if let path = env["HEY_DEV_SNAPSHOT"] {   // render the bubble layer to a PNG so it can be checked without a screen grab
                scene.announce(tr("ทดสอบฟองแก้ว ยาวหน่อยให้ขึ้นสองบรรทัด"), symbol: "sparkles")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    MainActor.assumeIsolated {
                        guard let host = self?.bubbleHost, let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
                        host.cacheDisplay(in: host.bounds, to: rep)
                        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                    }
                }
            }
            if let what = env["HEY_DEV_CAPTURE"] {
                Task {
                    if what == "full" { await capture.screenshot(region: false) }
                    if what == "record" { await capture.startRecording(); try? await Task.sleep(for: .seconds(3)); await capture.stopRecording() }
                }
            }
            if env["HEY_DEV_SPREAD"] != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.windowSpread.show() } }
            if env["HEY_DEV_BUBBLES"] != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.bubbles.start() } }
            if let id = env["HEY_DEV_PLACE"], let f = model.game.pet.balance.foods.first(where: { $0.id == id }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.food.begin(f) }
            }
            if let id = env["HEY_DEV_FOOD"], let f = model.game.pet.balance.foods.first(where: { $0.id == id }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.food.dropForDev(f) }
            }
            if let dir = env["HEY_DEV_MENU_PNG"] {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                    MainActor.assumeIsolated { self?.writeMenuPreview(to: dir) }
                }
            }
            if env["HEY_DEV_MENU_OPEN"] != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.statusClicked() }
            }
            if let path = env["HEY_DEV_ABOUT_PNG"] {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    MainActor.assumeIsolated { if let self { writeAboutPreview(model: self.model, to: path) } }
                }
            }
            if let path = env["HEY_DEV_MARQUEE"] {
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                    MainActor.assumeIsolated {
                        self?.musicBar.writeSnapshot(to: path)
                        print("[marquee] item width:", self?.musicBar.itemWidth.map { "\($0)" } ?? "none", "scrolling:", self?.musicBar.isScrolling ?? false)
                    }
                }
            }
            if let id = env["HEY_DEV_PLAY"] {
                if id == "toggle" { music.logStates = true; music.toggle() } else { music.devPlay(videoID: id) }
            }
            if let out = env["HEY_DEV_MINI"] {
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                    self?.musicBar.mini.show()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self?.music.devSnapshot(to: out) }
                }
            }
            if env["HEY_DEV_MUSIC_POPOVER"] != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.musicBar.devShowPopover() }
            }
            if let out = env["HEY_DEV_VIDEO_SNAP"] {    // show the video in a real window, then save what the web view paints
                let w = NSWindow(contentRect: NSRect(x: 200, y: 300, width: 356, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
                let holder = NSView(frame: NSRect(x: 0, y: 0, width: 356, height: 200))
                w.contentView = holder
                w.isReleasedWhenClosed = false
                w.makeKeyAndOrderFront(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                    guard let self else { return }
                    let pop = NSPopover()
                    pop.behavior = .applicationDefined
                    pop.contentViewController = NSHostingController(rootView: MusicScreenView(music: self.music, detector: self.detector, model: self.model, mini: self.musicBar.mini) {})
                    pop.show(relativeTo: holder.bounds, of: holder, preferredEdge: .minY)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { self.music.devSnapshot(to: out) }
                }
            }
            if let text = env["HEY_DEV_DROP_TEXT"], let payload = DropPayload(from: pasteboard(with: text)) {
                vault.add(payload)
            }
        }
    }

    /// The two ways to take something from the user: keep it (vault) or hold it for a moment (shelf).
    private func route(_ payload: DropPayload, to destination: DropDestination) {
        switch destination {
        case .vault: handleDrop(payload)
        case .shelf: shelf.add(payload)
        }
    }

    /// YouTube links go to the music playlist; everything else is kept in the vault.
    private func handleDrop(_ payload: DropPayload) {
        guard case .links(let urls) = payload else { vault.add(payload); return }
        let songs = urls.filter { YouTubeLink.videoID(from: $0.absoluteString) != nil }
        let others = urls.filter { YouTubeLink.videoID(from: $0.absoluteString) == nil }
        if !songs.isEmpty {
            if model.game.currentPlaylist == nil { model.perform { $0.createPlaylist(tr("เพลงของฉัน")); return [] } }
            if let id = model.game.currentPlaylist?.id {
                for url in songs { _ = music.addYouTube(url.absoluteString, to: id) }
            }
        }
        if !others.isEmpty { vault.add(.links(others)) }
    }

    private func pasteboard(with text: String) -> NSPasteboard {
        let pb = NSPasteboard(name: NSPasteboard.Name("hey.dev.drop"))
        pb.clearContents()
        pb.setString(text, forType: .string)
        return pb
    }

    // MARK: first-run guide

    /// One tip about every minute, only while someone is actually at the Mac to read it.
    private func showGuideTip() {
        guard power.decision.tier.rendersPet, power.signals.userIdleSeconds < 60 else { return }
        ticksUntilTip -= 1
        guard ticksUntilTip <= 0 else { return }
        ticksUntilTip = 6
        var tip: GuideTip?
        model.performQuietly { tip = $0.nextGuideTip(); return [] }
        guard let tip else { return }
        model.save()
        scene.announce(tip.text, symbol: tip.symbol)
    }

    /// A menu-bar-less app has no Edit menu, so ⌘C/⌘V/⌘X/⌘A/⌘Z never reach text fields. This restores them.
    private func installEditMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: tr("ซ่อน Hey!"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: tr("ปิดหน้าต่าง"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: tr("แก้ไข")); editItem.submenu = edit
        edit.addItem(withTitle: tr("เลิกทำ"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: tr("ทำซ้ำ"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: tr("ตัด"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: tr("คัดลอก"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: tr("วาง"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: tr("เลือกทั้งหมด"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
    }

    // MARK: context

    private func announceCalendar() {
        guard power.decision.tier.rendersPet else { return }
        for line in calendar.dueLines() { scene.announce(line, symbol: "calendar") }
    }

    private func reactToContext() {
        let now = Date()
        let idle = power.signals.userIdleSeconds
        scene.setSleepy(context.isLateNight(hour: Calendar.current.component(.hour, from: now)))
        for cue in context.tick(now: now, idleSeconds: idle) {
            switch cue {
            case .welcomeBack: scene.announce(tr("กลับมาแล้ว! คิดถึงนะ"), symbol: "hand.wave.fill")
            case .lateNight: scene.announce(tr("ดึกแล้วนะ พักผ่อนบ้างน้า"), symbol: "moon.stars.fill")
            case .takeBreak: scene.announce(tr("นั่งมานานแล้ว พักสายตาหน่อย"), symbol: "eye.fill")
            }
        }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let cue = appFocus.tick(now: now, frontBundleID: front, idleSeconds: idle)
        guard model.game.reactions.enabled, model.game.reactions.appStreaks else { return }
        switch cue {
        case .codingStreak: scene.announce(tr("เขียนโค้ดมานานแล้ว ยืดเส้นหน่อยไหม"), symbol: "chevron.left.forwardslash.chevron.right")
        case .readingStreak: scene.announce(tr("อ่านมาตั้งนาน พักสายตานิดนึงนะ"), symbol: "book.fill")
        case .gamingStreak: scene.announce(tr("เล่นมานานแล้ว ดื่มน้ำก่อนไหม"), symbol: "gamecontroller.fill")
        case nil: break
        }
    }

    // MARK: power

    private func applyPower(_ decision: PowerDecision) {
        scene.setTier(decision.tier)
        musicBar?.setScrollingAllowed(decision.tier.allowsPerching)       // scrolling only in the fuller power tiers
        if decision.hidePet {
            window.orderOut(nil)
        } else if !window.isVisible, !userHidPet {
            window.orderFrontRegardless()
        }
    }

    /// Finish what would otherwise be lost: a recording in progress needs a moment to write its file.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { if let command = HeyURL.parse(url) { run(command) } }
    }

    private func run(_ command: HeyCommand) {
        switch command {
        case .focusStart: if !pomodoro.timer.isRunning { pomodoro.toggle() }
        case .focusStop: if pomodoro.timer.isRunning { pomodoro.toggle() }
        case .note(let text):
            model.perform { game in
                let id = game.addNote(pinned: true, now: Date())
                game.updateNote(id: id, text: text, now: Date())
                return []
            }
            stickies.sync()
            scene.announce(tr("จดโน้ตให้แล้ว"), symbol: "note.text")
        case .copyClip(let n):
            let entries = clipboard.history.entries
            if n < entries.count { clipboard.copy(entries[n]) }
        case .openHub(let page):
            if let section = page.flatMap(HubSection.init(rawValue:)) { router.section = section }
            openHub()
        case .bubbles: bubbles.start()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard capture.isRecording || camera.isRecording else { return .terminateNow }
        Task {
            await capture.stopRecording()
            camera.close()
            try? await Task.sleep(for: .seconds(1))
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.flush()
    }

    /// `kill` and system shutdown scripts should still go through the normal, saving, exit.
    private func handleTerminationSignal() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        termSource = source
    }

    // MARK: pomodoro

    private func pomodoroEvent(_ event: PomodoroEvent) {
        NSSound(named: "Hero")?.play()
        switch event {
        case .focusFinished(let n):
            model.perform { $0.creditPomodoro(session: n) }
            scene.announce(tr("ครบ {0} รอบ พักได้แล้ว", n), symbol: "timer")
            scene.cheer()
        case .breakFinished:
            scene.announce(tr("กลับมาโฟกัสกัน"), symbol: "target")
            scene.cheer()
        }
    }

    private func pomodoroChanged() {
        scene.setCalm(pomodoro.isFocusing)
        updateStatusTitle()
    }

    private func updateCompanionMusic() {
        scene.setMusicPlaying(music.isPlaying || detector.systemSong?.isPlaying == true)
    }

    /// Recording wins the menu-bar item, then the Pomodoro countdown, then the plain logo.
    private func updateStatusTitle() {
        func symbol(_ name: String) -> NSImage? { NSImage(systemSymbolName: name, accessibilityDescription: nil) }
        if capture.isRecording {
            let s = Int(capture.elapsed)
            statusItem.button?.image = symbol("record.circle.fill")
            statusItem.button?.title = String(format: " %d:%02d", s / 60, s % 60)
        } else if pomodoro.timer.isRunning {
            statusItem.button?.image = symbol(pomodoro.timer.phase == .focus ? "timer" : "cup.and.saucer.fill")
            statusItem.button?.title = " \(pomodoro.remainingText)"
        } else {
            statusItem.button?.image = LogoArt.menuBarImage()
            statusItem.button?.title = ""
        }
    }

    // MARK: hotkeys (⌃⌥ + key)

    private func setUpHotKeys() {
        let table: [(Int, String, @MainActor () -> Void)] = [
            (kVK_ANSI_N, "N", { [weak self] in self?.quickNote() }),
            (kVK_ANSI_R, "R", { [weak self] in self?.quickReminder() }),
            (kVK_ANSI_P, "P", { [weak self] in self?.pomodoro.toggle() }),
            (kVK_ANSI_H, "H", { [weak self] in self?.openHub() }),
            (kVK_ANSI_M, "M", { [weak self] in self?.music.toggle() }),
            (kVK_ANSI_S, "S", { [weak self] in self?.captureRegion() }),
            (kVK_ANSI_V, "V", { [weak self] in self?.capture.toggleRecording() }),
            (kVK_ANSI_RightBracket, "]", { [weak self] in self?.music.next() }),
            (kVK_ANSI_LeftBracket, "[", { [weak self] in self?.music.previous() }),
        ]
        for (code, name, action) in table where !HotKeys.register(keyCode: code, action: action) {
            FileHandle.standardError.write(Data("[Hey] ⌃⌥\(name) is taken by another app\n".utf8))
        }
    }

    // MARK: quick actions

    @objc private func quickNote() {
        model.perform { g in g.addNote(pinned: true, now: Date()); return [] }
        if let newest = model.game.notes.first { stickies.focus(newest.id) }
    }

    @objc private func quickReminder() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = tr("ตั้งเตือน")
        alert.informativeText = tr("พิมพ์ข้อความพร้อมเวลา เช่น  “ประชุม อีก 20 นาที”  “พรุ่งนี้ 9 โมง ส่งงาน”  “กินยา 18:30”")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: tr("ตั้งเตือน"))
        alert.addButton(withTitle: tr("ยกเลิก"))
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let input = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return }
        guard let parsed = ReminderParser.parse(input, now: Date()) else {
            let fail = NSAlert()
            fail.messageText = tr("ไม่พบเวลาในข้อความ")
            fail.informativeText = tr("ลองใส่เวลา เช่น “อีก 20 นาที”, “15:30”, “บ่าย 2 โมง”, “พรุ่งนี้ 9 โมง”")
            fail.runModal()
            return
        }
        model.perform { $0.addReminder(parsed.text, at: parsed.fireAt, now: Date()) }
        scene.announce(tr("จดไว้แล้ว"), symbol: "bell.fill")
    }

    // MARK: click-through
    // The window only intercepts the mouse while the pointer is over the pet's body.

    private func setUpClickThrough() {
        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.updateClickThrough() }
        }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) { monitors.append(g) }
        let local = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            handler(event)
            return event
        }
        if let local { monitors.append(local) }
        updateClickThrough()
    }

    private func updateClickThrough() {
        checkHotCorner()
        let mouse = NSEvent.mouseLocation
        let origin = window.frame.origin
        let local = NSPoint(x: mouse.x - origin.x, y: mouse.y - origin.y)
        let overPet = scene.hitRect.contains(local)
        // Keep receiving events while a button is held so drags never get cut off.
        let busy = NSEvent.pressedMouseButtons != 0 || (dropZones?.isActive ?? false)
        window.ignoresMouseEvents = !(overPet || busy)
    }

    // MARK: the fan menu

    private func openRadial() {
        guard let window else { return }
        let c = scene.bodyCenterInWindow
        radial.toggle(around: NSPoint(x: window.frame.minX + c.x, y: window.frame.minY + c.y), petRadius: scene.bodyRadius)
    }

    private func radialHeader() -> RadialHeaderInfo {
        let game = model.game, s = game.pet.state
        var info = RadialHeaderInfo()
        info.title = s.name
        info.subtitle = s.stage.displayName
        info.coins = game.coins
        info.streak = game.streak.current
        if s.stage == .egg {
            info.progress = (tr("อุ่นไข่ {0}/{1}", Int(s.hatchProgress), Int(game.pet.balance.hatchNeeded)), s.hatchProgress / game.pet.balance.hatchNeeded)
        } else {
            info.bars = [("fork.knife", s.hunger / 100, .orange), ("face.smiling", s.mood / 100, .pink), ("bolt.fill", s.energy / 100, .green)]
            if let need = game.pet.balance.xpToLeave(s.stage) { info.progress = ("XP \(Int(s.xp))/\(Int(need))", s.xp / need) }
        }
        return info
    }

    /// One button for each catalogue action; badges and icons reflect the live state.
    private func radialItem(_ action: RadialAction) -> RadialItem {
        let game = model.game
        switch action {
        case .music:
            return RadialItem(id: "music", icon: music.isPlaying ? "pause.fill" : "music.note",
                              title: music.isPlaying ? tr("หยุดเพลง") : tr("เล่นเพลง")) { [weak self] in self?.music.toggle() }
        case .files:
            return RadialItem(id: "files", icon: "tray.fill", title: tr("ฝากไฟล์"),
                              badge: game.vault.isEmpty ? nil : "\(game.vault.count)", badgeColor: .teal) { [weak self] in self?.showHub(section: .vault) }
        case .focus:
            return RadialItem(id: "focus", icon: pomodoro.timer.isRunning ? "pause.circle.fill" : "timer",
                              title: pomodoro.timer.isRunning ? tr("หยุดโฟกัส") : tr("โฟกัส"),
                              badge: pomodoro.timer.isRunning ? pomodoro.remainingText : nil, badgeColor: .red) { [weak self] in self?.pomodoro.toggle() }
        case .usage:
            return RadialItem(id: "usage", icon: "gauge.with.dots.needle.67percent", title: tr("เครดิต AI")) { [weak self] in self?.showAIUsage() }
        case .windows: return RadialItem(id: "windows", icon: "rectangle.stack.fill", title: tr("คลี่หน้าต่าง")) { [weak self] in self?.windowSpread.show() }
        case .bubbles: return RadialItem(id: "bubbles", icon: "bubbles.and.sparkles", title: tr("ฟองสบู่")) { [weak self] in self?.bubbles.start() }
        case .hub:
            let questsLeft = game.quests.filter { !$0.done }.count
            return RadialItem(id: "hub", icon: "square.grid.2x2.fill", title: "Hub",
                              badge: questsLeft > 0 ? "\(questsLeft)" : nil) { [weak self] in self?.openHub() }
        case .feed:
            return RadialItem(id: "feed", icon: "fork.knife", title: tr("ให้อาหาร"), closes: false) { [weak self] in self?.radial.go(.food) }
        case .note: return RadialItem(id: "note", icon: "note.text", title: tr("โน้ต")) { [weak self] in self?.quickNote() }
        case .remind: return RadialItem(id: "remind", icon: "bell.fill", title: tr("ตั้งเตือน")) { [weak self] in self?.quickReminder() }
        case .shot: return RadialItem(id: "shot", icon: "camera.viewfinder", title: tr("แคปจอ")) { [weak self] in self?.captureRegion() }
        case .ocr: return RadialItem(id: "ocr", icon: "text.viewfinder", title: tr("อ่านข้อความ")) { [weak self] in self?.readScreenText() }
        case .clip: return RadialItem(id: "clip", icon: "doc.on.clipboard", title: tr("คลิปบอร์ด")) { [weak self] in self?.router.section = .clipboard; self?.openHub() }
        case .rec:
            return RadialItem(id: "rec", icon: capture.isRecording ? "stop.circle.fill" : "record.circle",
                              title: capture.isRecording ? tr("หยุดอัด") : tr("อัดจอ")) { [weak self] in self?.capture.toggleRecording() }
        case .shelf:
            return RadialItem(id: "shelf", icon: "suitcase.fill", title: tr("ถาดไฟล์"),
                              badge: game.shelf.isEmpty ? nil : "\(game.shelf.count)", badgeColor: .teal) { [weak self] in self?.toggleTray() }
        }
    }

    private func radialItems(_ page: RadialPage) -> [RadialItem] {
        let game = model.game
        func back() -> RadialItem {
            RadialItem(id: "back", icon: "chevron.backward", title: tr("กลับ"), closes: false) { [weak self] in self?.radial.go(.main) }
        }
        switch page {
        case .main:
            return game.radialMenu.ring.compactMap { entry -> RadialItem? in
                switch entry {
                case .action(let action): return radialItem(action)
                case .folder(let folder):
                    return RadialItem(id: "folder-\(folder.id)", icon: .symbol(folder.symbol), title: folder.displayName, closes: false) { [weak self] in
                        self?.radial.go(.folder(folder.id))
                    }
                }
            }
        case .food:
            return [back()] + game.pet.balance.foods.map { food in
                let stock = game.stock(of: food)
                let wait = game.pet.cooldownRemaining(food, at: Date())
                if stock <= 0 {         // nothing to give: the button leads to the shop instead of a dead end
                    return RadialItem(id: food.id, icon: .image(IconLibrary.foodImage(food)), title: food.name, badge: tr("ซื้อ"), badgeColor: .blue) { [weak self] in
                        self?.showHub(section: .shop)
                    }
                }
                return RadialItem(id: food.id, icon: .image(IconLibrary.foodImage(food)), title: food.name,
                                  badge: wait > 0 ? DurationText.wait(wait) : (food.price == 0 ? tr("ฟรี") : "×\(stock)"),
                                  badgeColor: wait > 0 ? .gray : (food.price == 0 ? .green : .orange)) { [weak self] in
                    self?.food.begin(food)
                }
            }
        case .folder(let id):
            return [back()] + (game.radialMenu.folder(id)?.actions ?? []).map(radialItem)
        }
    }

    // MARK: gestures

    private func gesture(_ g: GestureKind) {
        gestureLog.record(g.label)
        run(model.game.gestures.action(for: g))
    }

    private func pinch(_ factor: CGFloat, ended: Bool) {
        let current = model.game.gestures.petScale
        let next = min(max(current * Double(factor), GestureSettings.minScale), GestureSettings.maxScale)
        model.performQuietly { $0.setGestures { $0.petScale = next }; return [] }   // live, without a disk write per frame
        if ended {
            gestureLog.record(tr("ย่อ/ขยายสัตว์เลี้ยง {0}%", Int(next * 100)))
            model.save()
        }
    }

    private func run(_ action: PetAction) {
        if let text = action.feedback { scene.announce(text, symbol: action.feedbackSymbol) }
        switch action {
        case .none: break
        case .musicToggle: music.toggle()
        case .musicNext: music.next()
        case .musicPrevious: music.previous()
        case .volumeUp: music.setVolume(music.volume + 0.1)
        case .volumeDown: music.setVolume(music.volume - 0.1)
        case .openHub: openHub()
        case .quickNote: quickNote()
        case .quickReminder: quickReminder()
        case .pomodoroToggle: pomodoro.toggle()
        case .screenshotRegion: captureRegion()
        case .recordToggle: capture.toggleRecording()
        case .summonPet: summon()
        case .hidePet: toggleVisible()
        case .petMenu: openRadial()
        }
    }

    /// Bring the pet to the pointer, standing on the bottom edge of that screen.
    private func summon() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        if userHidPet { toggleVisible() }
        let size = PetScene.windowSize
        let x = min(max(mouse.x - size.width / 2, screen.visibleFrame.minX), screen.visibleFrame.maxX - size.width)
        window.setFrameOrigin(NSPoint(x: x, y: scene.floorY(in: screen.visibleFrame)))
        window.orderFrontRegardless()
        scene.react()
    }

    /// Fires when the pointer rests in a corner long enough, then waits until it leaves before firing again.
    private func checkHotCorner() {
        let settings = model.game.gestures
        guard settings.hotCornersEnabled else {
            cornerWork?.cancel(); cornerWork = nil; pendingCorner = nil; cornerArmed = true
            return
        }
        let frames = NSScreen.screens.map(\.frame)
        let corner = HotCorner.corner(at: NSEvent.mouseLocation, in: frames)
        guard corner != pendingCorner else { return }
        cornerWork?.cancel()
        cornerWork = nil
        pendingCorner = corner
        guard let corner else { cornerArmed = true; return }
        guard cornerArmed else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, HotCorner.corner(at: NSEvent.mouseLocation, in: NSScreen.screens.map(\.frame)) == corner else { return }
                self.cornerArmed = false
                self.gestureLog.record(corner.label)
                self.run(self.model.game.gestures.action(for: corner))
            }
        }
        cornerWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.cornerDwell, execute: work)
    }

    // MARK: menu (menu bar + right click)

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = LogoArt.menuBarImage()
        statusItem.button?.imagePosition = .imageLeft
        statusItem.button?.title = ""
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusClicked() {
        let event = NSApp.currentEvent
        if event?.modifierFlags.contains(.option) == true {
            if userHidPet { toggleVisible() }          // Option-click keeps the round menu around the pet
            openRadial()
        } else {
            let menu = NSMenu()                         // a click and a right-click both open the same menu
            menu.delegate = self
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) { fill(menu) }

    private func fill(_ menu: NSMenu) {
        menu.removeAllItems()
        let game = model.game
        let s = game.pet.state

        func card<V: View>(_ view: V) {
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(origin: .zero, size: host.fittingSize)
            let item = NSMenuItem()
            item.view = host
            menu.addItem(item)
        }
        func section(_ title: String) {
            menu.addItem(.separator())
            menu.addItem(NSMenuItem.sectionHeader(title: title))
        }
        @discardableResult
        func action(_ title: String, _ symbol: String? = nil, _ sel: Selector, key: String = "", control: Bool = true) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            item.target = self
            if !key.isEmpty { item.keyEquivalentModifierMask = control ? [.control, .option] : [.command] }
            if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
            menu.addItem(item)
            return item
        }

        // 1. the pet at a glance
        let xpNeeded = game.pet.balance.xpToLeave(s.stage)
        card(PetMenuCard(data: PetCardData(
            name: s.name, stage: s.stage.displayName, isEgg: s.stage == .egg,
            hatch: (s.hatchProgress, game.pet.balance.hatchNeeded), xp: (s.xp, xpNeeded),
            hunger: s.hunger, mood: s.mood, energy: s.energy, coins: game.coins, streak: game.streak.current,
            questsDone: game.quests.filter(\.done).count, questsTotal: game.quests.count,
            reminders: game.reminders.filter(\.isActive).count,
            mode: tr("โหมด{0}{1}", power.decision.tier.label, power.decision.reason.isEmpty ? "" : " · \(power.decision.reason)"),
            nowPlaying: music.nowPlaying.map { String($0.title.prefix(40)) })))

        // 2. AI quota, one row per account
        let accounts = AIProvider.allCases.flatMap { aiUsage.rows(for: $0) }.compactMap { row -> AIUsageCardData.Item? in
            guard let usage = row.usage else { return nil }
            let now = Date()
            let windows = usage.windows.prefix(2).map { (label: $0.id.count <= 3 ? $0.id : String($0.id.prefix(10)), percent: $0.effectivePercent(at: now)) }
            return AIUsageCardData.Item(id: row.id, provider: row.provider, name: row.name, windows: Array(windows))
        }
        if !accounts.isEmpty {
            section(tr("เครดิต AI"))
            card(AIUsageMenuCard(data: AIUsageCardData(items: accounts)))
        }

        // 3. the pet
        section(tr("สัตว์เลี้ยง"))
        let feedItem = NSMenuItem(title: tr("ให้อาหาร"), action: nil, keyEquivalent: "")
        feedItem.image = NSImage(systemSymbolName: "fork.knife", accessibilityDescription: nil)
        let feedMenu = NSMenu()
        for food in game.pet.balance.foods {
            let stock = game.stock(of: food)
            let star = food.id == s.favoriteFood ? tr(" · ของโปรด") : ""
            let count = food.price == 0 ? "" : "  ×\(stock)"
            let item = NSMenuItem(title: "\(food.name)\(star)\(count)", action: #selector(feed(_:)), keyEquivalent: "")
            item.image = IconLibrary.foodMenuImage(food)
            item.target = self
            item.representedObject = food.id
            item.isEnabled = s.stage != .egg && stock > 0
            feedMenu.addItem(item)
        }
        feedItem.submenu = feedMenu
        menu.addItem(feedItem)
        action(tr("เป่าฟองสบู่"), "bubbles.and.sparkles", #selector(blowBubbles))
        action(game.shelf.isEmpty ? tr("ถาดพักไฟล์ (ว่าง)") : tr("ถาดพักไฟล์ ({0})", game.shelf.count), "suitcase.fill", #selector(toggleTray))
        action(tr("ซ่อน/แสดงสัตว์เลี้ยง"), "eye.slash", #selector(toggleVisible))

        // 4. tools
        section(tr("เครื่องมือ"))
        action(tr("เปิด Hub…"), "square.grid.2x2.fill", #selector(openHub), key: "h")
        action(tr("เช็คเครดิต AI"), "gauge.with.dots.needle.67percent", #selector(showAIUsage))
        action(tr("คลี่หน้าต่างที่เปิดอยู่"), "rectangle.stack.fill", #selector(spreadWindows))
        action(tr("ตั้งเตือนด่วน…"), "bell.fill", #selector(quickReminder), key: "r")
        action(tr("โน้ตด่วน"), "note.text", #selector(quickNote), key: "n")
        let shoot = NSMenuItem(title: tr("ถ่าย/อัด"), action: nil, keyEquivalent: "")
        shoot.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)
        let shootMenu = NSMenu()
        for (title, sel, key) in [(tr("ภาพทั้งจอ (นับถอยหลัง)"), #selector(captureFull), ""), (tr("เลือกพื้นที่"), #selector(captureRegion), "s"),
                                  (capture.isRecording ? tr("หยุดอัดหน้าจอ") : tr("อัดหน้าจอ"), #selector(toggleRecording), "v"),
                                  (tr("เปิดกล้อง…"), #selector(openCamera), "")] {
            let item = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            item.target = self
            if !key.isEmpty { item.keyEquivalentModifierMask = [.control, .option] }
            shootMenu.addItem(item)
        }
        shoot.submenu = shootMenu
        menu.addItem(shoot)

        // 5. music and focus
        section(tr("เพลงและโฟกัส"))
        action(music.isPlaying ? tr("หยุดเพลง") : tr("เล่นเพลง"), music.isPlaying ? "pause.fill" : "play.fill", #selector(toggleMusic), key: "m")
        action(tr("เพลงถัดไป"), "forward.fill", #selector(nextTrack), key: "]")
        let t = pomodoro.timer
        action(t.isRunning ? tr("หยุด Pomodoro ({0})", pomodoro.remainingText) : tr("เริ่ม Pomodoro"), "timer", #selector(togglePomodoro), key: "p")

        if devMode {
            section("Dev")
            action(tr("Dev: อุ่นไข่ +50"), nil, #selector(devWarm))
            action("Dev: +100 XP", nil, #selector(devXP))
            action(tr("Dev: +100 เหรียญ"), nil, #selector(devCoins))
            action(tr("Dev: เตือนใน 5 วินาที"), nil, #selector(devReminder))
        }

        menu.addItem(.separator())
        action(tr("ออกจาก Hey!"), nil, #selector(quit), key: "q", control: false)
    }

    /// Dev hook: draw the status menu's cards into PNGs (a menu itself cannot be captured by window).
    private func writeMenuPreview(to dir: String) {
        let menu = NSMenu()
        fill(menu)
        for (i, item) in menu.items.enumerated() {
            guard let view = item.view else { continue }
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
            if let rep { view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: dir + "/card\(i).png")) }
        }
        print("[menu] items:", menu.items.map { $0.isSeparatorItem ? "—" : ($0.view != nil ? "<card>" : $0.title) })
    }

    private func showHub(section: HubSection) {
        router.section = section
        openHub()
    }

    @objc private func spreadWindows() { windowSpread.show() }

    @objc private func openHub() {
        if hubWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            w.title = "Hey! Hub"
            w.titlebarAppearsTransparent = true
            w.isOpaque = false                      // the Hub's opacity setting lets the desktop show through
            w.backgroundColor = .clear
            w.titleVisibility = .hidden
            w.minSize = NSSize(width: 780, height: 580)
            if let size = ProcessInfo.processInfo.environment["HEY_DEV_HUB_SIZE"]?.split(separator: "x").compactMap({ Double($0) }),
               size.count == 2, devMode { w.setContentSize(NSSize(width: size[0], height: size[1])) }       // see a long page in one capture
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: HubView(model: model, pomodoro: pomodoro, clipboard: clipboard, vault: vault, shelf: shelf, music: music, capture: capture, camera: camera, power: power, gestureLog: gestureLog, detector: detector, aiUsage: aiUsage, router: router))
            w.center()
            hubWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        hubWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func captureFull() { Task { await capture.screenshot(region: false) } }
    @objc private func captureRegion() { Task { await capture.screenshot(region: true) } }
    private func readScreenText() { Task { await capture.readText() } }
    @objc private func toggleRecording() { capture.toggleRecording() }
    @objc private func openCamera() { Task { await camera.show() } }
    @objc private func toggleTray() {
        if model.game.shelf.isEmpty { scene.announce(tr("ถาดว่างอยู่ ลากไฟล์มาวางที่ฉันได้เลย"), symbol: "suitcase.fill") } else { tray.toggle() }
    }
    @objc private func blowBubbles() { bubbles.start() }

    /// The pet reads out the AI quota; the Hub page has the details.
    @objc private func showAIUsage() {
        Task {
            await aiUsage.refresh()
            let lines = aiUsage.summaryLines()
            if lines.isEmpty { router.section = .usage; openHub() }
            else { lines.forEach { scene.announce($0, symbol: "gauge.with.dots.needle.67percent") } }
        }
    }
    @objc private func toggleMusic() { music.toggle() }
    @objc private func nextTrack() { music.next() }
    @objc private func togglePomodoro() { pomodoro.toggle() }

    @objc private func feed(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let food = model.game.pet.balance.foods.first(where: { $0.id == id }) else { return }
        self.food.begin(food)
    }

    @objc private func devWarm() { model.perform { $0.grantWarmth(50) } }
    @objc private func devXP() { model.perform { $0.grantXP(100) } }
    @objc private func devCoins() { model.perform { $0.grantCoins(100); return [] } }
    @objc private func devReminder() {
        model.perform { $0.addReminder(tr("ทดสอบการเตือน"), at: Date().addingTimeInterval(5), now: Date()) }
    }

    @objc private func toggleVisible() {
        userHidPet.toggle()
        power.setUserHidPet(userHidPet)
        if userHidPet { window.orderOut(nil) } else { window.orderFrontRegardless() }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
