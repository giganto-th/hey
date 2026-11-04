import AppKit
import Observation
import SwiftUI
import HeyDomain

/// The picture in a small window that floats above everything: drag it anywhere, resize it, close it; the music keeps playing.
@MainActor
@Observable
final class MiniPlayerController: NSObject, NSWindowDelegate {
    private(set) var isShown = false
    @ObservationIgnored private let music: MusicPlayer
    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored var onClosed: (() -> Void)?

    init(music: MusicPlayer) { self.music = music }

    func show() {
        guard music.hasVideo else { return }
        if panel == nil {
            let p = MiniPanel(contentRect: NSRect(x: 0, y: 0, width: 356, height: 200),
                              styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.level = .floating
            p.isMovableByWindowBackground = true
            p.hidesOnDeactivate = false
            p.isReleasedWhenClosed = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.contentAspectRatio = NSSize(width: 16, height: 9)
            p.contentMinSize = NSSize(width: 356, height: 200)       // the player will not run in anything smaller
            p.delegate = self
            let host = NSHostingView(rootView: MiniPlayerView(music: music, controller: self))
            p.contentView = host
            if !p.setFrameUsingName("HeyMiniPlayer") {
                if let area = NSScreen.main?.visibleFrame { p.setFrameOrigin(NSPoint(x: area.maxX - 380, y: area.minY + 24)) }
            }
            p.setFrameAutosaveName("HeyMiniPlayer")
            panel = p
        }
        isShown = true
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel?.contentView = nil           // lets the picture go back behind the scenes
        panel = nil
        isShown = false
        onClosed?()
    }

    func windowWillClose(_ notification: Notification) { if isShown { hide() } }
}

private final class MiniPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct MiniPlayerView: View {
    let music: MusicPlayer
    let controller: MiniPlayerController
    @State private var hovering = false

    var body: some View {
        ZStack {
            VideoSurface(music: music, draggable: true)
            VStack {
                HStack {
                    Spacer()
                    pill("xmark", tr("ปิดจอเล็ก")) { controller.hide() }
                }
                Spacer()
                HStack(spacing: 18) {
                    pill("backward.fill", tr("เพลงก่อนหน้า")) { music.previous() }
                    pill(music.isPlaying ? "pause.fill" : "play.fill", music.isPlaying ? tr("หยุดชั่วคราว") : tr("เล่นต่อ")) { music.toggle() }
                    pill("forward.fill", tr("เพลงถัดไป")) { music.next() }
                }
            }
            .padding(10)
            .opacity(hovering ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: hovering)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))        // a layer mask on the window itself turns the video black
        .onHover { hovering = $0 }
        .onChange(of: music.hasVideo) { if !music.hasVideo { controller.hide() } }       // song changed to a file, or stopped
    }

    private func pill(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 30, height: 30).background(.black.opacity(0.55), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
