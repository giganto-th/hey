import AppKit
import SwiftUI
import HeyDomain

/// A second menu-bar item that appears while a song is loaded and shows its name as scrolling text.
@MainActor
final class MusicStatusItem: NSObject, NSMenuDelegate {
    static let width: CGFloat = 170

    private let music: MusicPlayer
    private let model: GameModel
    private let detector: MusicDetector
    private var item: NSStatusItem?
    private var marquee: MarqueeView?
    /// Off in the power-saving tiers: the text stays still and is simply cut off.
    private var scrollingAllowed = true
    private var fromSystem = false
    private let popover = NSPopover()
    var onOpenHub: (() -> Void)?
    private(set) lazy var mini = MiniPlayerController(music: music)

    init(music: MusicPlayer, model: GameModel, detector: MusicDetector) {
        self.music = music
        self.model = model
        self.detector = detector
    }

    func setScrollingAllowed(_ allowed: Bool) {
        guard allowed != scrollingAllowed else { return }
        scrollingAllowed = allowed
        sync()
    }

    /// Cheap to call often: it only touches the bar when something actually changed.
    func sync() {
        guard model.game.music.showInMenuBar else { remove(); return }
        // Our own player wins; otherwise show whatever the system says is playing (a browser, another app).
        let line: String, playing: Bool
        if let track = music.nowPlaying {
            line = MarqueeText.display(title: track.title, artist: track.artist); playing = music.isPlaying; fromSystem = false
        } else if let song = detector.systemSong {
            line = MarqueeText.display(title: song.title, artist: song.artist); playing = song.isPlaying; fromSystem = true
        } else {
            remove(); return
        }
        if item == nil { create() }
        marquee?.set(text: line, playing: playing, scrolling: playing && scrollingAllowed)
    }

    private func create() {
        let item = NSStatusBar.system.statusItem(withLength: Self.width)
        item.autosaveName = "HeyMusic"
        item.isVisible = true
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            let view = MarqueeView(frame: button.bounds)
            view.autoresizingMask = [.width, .height]
            button.addSubview(view)
            marquee = view
        }
        self.item = item
    }

    private func remove() {
        popover.performClose(nil)
        mini.hide()
        guard let item else { return }
        NSStatusBar.system.removeStatusItem(item)
        self.item = nil
        marquee = nil
    }

    // MARK: click

    /// Click: the music screen. Right-click (or control-click): the short menu.
    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            let menu = NSMenu()
            menu.delegate = self
            item?.menu = menu
            sender.performClick(nil)
            item?.menu = nil
            return
        }
        if popover.isShown { popover.performClose(nil); return }
        let screen = MusicScreenView(music: music, detector: detector, model: model, mini: mini) { [weak self] in
            self?.popover.performClose(nil)
            self?.onOpenHub?()
        }
        popover.behavior = .transient
        popover.animates = false
        // Give the popover its final size before it opens: if the picture makes it grow afterwards, it slides up under the menu bar.
        let host = NSHostingController(rootView: screen)
        host.view.layoutSubtreeIfNeeded()
        let size = host.view.fittingSize
        host.view.frame = NSRect(origin: .zero, size: size)
        popover.contentSize = size
        popover.contentViewController = host
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        func add(_ title: String, _ action: Selector, enabled: Bool = true) {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
            i.target = self
            i.isEnabled = enabled
            menu.addItem(i)
        }
        func header(_ text: String) {
            let head = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            head.isEnabled = false
            menu.addItem(head)
        }
        if fromSystem, let s = detector.systemSong {
            header(MarqueeText.display(title: s.title, artist: s.artist))
            header("เล่นอยู่ในแอปอื่น")
            menu.addItem(.separator())
            add(s.isPlaying ? "หยุดชั่วคราว" : "เล่นต่อ", #selector(toggleSystem))
            add("หยุดเพลงและปิดแถบเมนู", #selector(stopSystem))
            menu.addItem(.separator())
        } else {
            if let t = music.nowPlaying {
                header(MarqueeText.display(title: t.title, artist: t.artist))
                menu.addItem(.separator())
            }
            add(music.isPlaying ? "หยุดชั่วคราว" : "เล่นต่อ", #selector(toggle))
            add("เพลงก่อนหน้า", #selector(previous))
            add("เพลงถัดไป", #selector(next))
            if music.hasVideo { add(mini.isShown ? "ปิดจอเล็ก" : "เล่นในจอเล็ก", #selector(toggleMini)) }
            add("หยุดเพลง", #selector(stop))
            menu.addItem(.separator())
        }
        add("ซ่อนจากแถบเมนู", #selector(hide))
    }

    @objc private func toggle() { music.toggle() }
    @objc private func previous() { music.previous() }
    @objc private func next() { music.next() }
    @objc private func toggleMini() { if mini.isShown { mini.hide() } else { mini.show() } }
    @objc private func stop() { music.stop() }
    @objc private func toggleSystem() { detector.toggleSystemSong() }
    @objc private func stopSystem() { detector.stopSystemSong() }
    @objc private func hide() { model.perform { $0.setMusic { $0.showInMenuBar = false }; return [] } }

    // MARK: dev

    /// Opens the music screen as a click would, and reports where it ended up.
    func devShowPopover() {
        guard let button = item?.button else { print("[popover] no status item"); return }
        clicked(button)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, let win = self.popover.contentViewController?.view.window else { print("[popover] no window"); return }
            let screen = win.screen?.frame ?? .zero, visible = win.screen?.visibleFrame ?? .zero
            print("[popover] frame:", win.frame, "screen:", screen, "visible:", visible, "inside visible:", visible.contains(win.frame))
        }
    }

    func writeSnapshot(to path: String) {
        if let data = marquee?.snapshot() { try? data.write(to: URL(fileURLWithPath: path)) }
    }

    var itemWidth: CGFloat? { item?.button?.window?.frame.width }
    var isScrolling: Bool { marquee?.isScrolling ?? false }
}
