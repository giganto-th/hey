import SwiftUI
import HeyDomain

/// The small music screen that opens from the menu-bar song title: what is playing, transport, stop, and import.
struct MusicScreenView: View {
    let music: MusicPlayer
    let detector: MusicDetector
    let model: GameModel
    let mini: MiniPlayerController
    let openHub: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let track = music.nowPlaying {
                ownPlayer(track)
            } else if let song = detector.systemSong {
                systemPlayer(song)
            } else {
                Label(tr("ไม่มีเพลงที่เล่นอยู่"), systemImage: "music.note").foregroundStyle(.secondary)
            }
            Divider()
            Toggle(tr("แจ้งเตือนเมื่อพบเพลง YouTube"), isOn: Binding(
                get: { model.game.music.detectNowPlaying && model.game.music.detectBrowser },
                set: { on in model.perform { $0.setMusic { $0.detectNowPlaying = on; $0.detectBrowser = on }; return [] } }))
                .font(.callout)
            HStack {
                if music.hasVideo, !mini.isShown {
                    Button { mini.show() } label: { Label(tr("เล่นในจอเล็ก"), systemImage: "pip.enter") }
                        .buttonStyle(.borderless)
                }
                Spacer()
                Button(tr("เปิดใน Hub"), action: openHub).buttonStyle(.borderless)
            }
        }
        .padding(16)
        .frame(width: 388)
    }

    // MARK: our own player

    @ViewBuilder
    private func ownPlayer(_ track: Track) -> some View {
        if music.hasVideo {
            if mini.isShown {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.on.rectangle").font(.title)
                    Text(tr("กำลังเล่นในจอเล็ก")).font(.callout)
                    Button(tr("ปิดจอเล็ก")) { mini.hide() }
                }
                .frame(width: 356, height: 200)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            } else {
                VideoSurface(music: music)
                    .frame(width: 356, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        header(title: track.title, artist: track.artist, symbol: music.isPlaying ? "music.note" : "pause.fill")
        if music.duration > 0 {
            VStack(spacing: 2) {
                Slider(value: Binding(get: { min(music.position, music.duration) }, set: { music.seek(to: $0) }), in: 0...music.duration)
                HStack {
                    Text(Self.clock(music.position)); Spacer(); Text(Self.clock(music.duration))
                }.font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        HStack(spacing: 22) {
            Spacer()
            button("backward.fill", tr("เพลงก่อนหน้า")) { music.previous() }
            button(music.isPlaying ? "pause.fill" : "play.fill", music.isPlaying ? tr("หยุดชั่วคราว") : tr("เล่นต่อ"), big: true) { music.toggle() }
            button("forward.fill", tr("เพลงถัดไป")) { music.next() }
            button("stop.fill", tr("หยุดเพลง")) { music.stop() }
            Spacer()
        }
    }

    // MARK: something another app plays

    @ViewBuilder
    private func systemPlayer(_ song: NowPlayingInfo) -> some View {
        header(title: song.title, artist: song.artist, symbol: song.isPlaying ? "music.note" : "pause.fill")
        if let elapsed = song.elapsed, let duration = song.duration, duration > 0 {
            VStack(spacing: 2) {
                ProgressView(value: min(elapsed, duration), total: duration)
                HStack { Text(Self.clock(elapsed)); Spacer(); Text(Self.clock(duration)) }
                    .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        HStack(spacing: 22) {
            Spacer()
            button(song.isPlaying ? "pause.fill" : "play.fill", song.isPlaying ? tr("หยุดชั่วคราว") : tr("เล่นต่อ"), big: true) { detector.toggleSystemSong() }
            button("stop.fill", tr("หยุดเพลงและปิดแถบเมนู")) { detector.stopSystemSong() }
            Spacer()
        }
        if detector.canImportSystemSong {
            Button { detector.importSystemSong() } label: {
                Label(tr("เพิ่มเข้าเพลย์ลิสต์"), systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Text(tr("เล่นอยู่ในแอปอื่น")).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: pieces

    private func header(title: String, artist: String?, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title2).frame(width: 34, height: 34)
                .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).lineLimit(2)
                if let artist, !artist.isEmpty { Text(artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
            }
        }
    }

    private func button(_ symbol: String, _ help: String, big: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(big ? .title : .title3).frame(width: big ? 40 : 28, height: 36)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private static func clock(_ seconds: Double) -> String {
        let s = Int(max(seconds, 0))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Hosts the player's web view (the picture). The picture never takes mouse events: in the small window a drag moves the window.
struct VideoSurface: NSViewRepresentable {
    let music: MusicPlayer
    var draggable = false

    func makeCoordinator() -> Coordinator { Coordinator(music: music) }

    func makeNSView(context: Context) -> NSView {
        let container = VideoContainer(frame: NSRect(x: 0, y: 0, width: 356, height: 200))
        container.draggable = draggable
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        music.attachVideo(to: container)
        return container
    }

    func updateNSView(_ view: NSView, context: Context) {
        // A newly created surface owns the picture. The outgoing popover can still update
        // during the handoff to PiP; it must not steal the web view back before dismantling.
        (view as? VideoContainer)?.draggable = draggable
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.music.detachVideo(from: view) }

    final class Coordinator {
        let music: MusicPlayer
        init(music: MusicPlayer) { self.music = music }
    }

    final class VideoContainer: NSView {
        var draggable = false
        override var mouseDownCanMoveWindow: Bool { draggable }
        override func hitTest(_ point: NSPoint) -> NSView? { bounds.contains(convert(point, from: superview)) ? self : nil }
    }
}
