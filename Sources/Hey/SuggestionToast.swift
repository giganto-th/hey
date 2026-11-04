import AppKit
import SwiftUI

/// A small card in the bottom-right corner: "Found a song — add it?"
@MainActor
final class SuggestionToastController {
    private let detector: MusicDetector
    private var panel: NSPanel?
    private var host: NSHostingView<SuggestionView>?

    init(detector: MusicDetector) { self.detector = detector }

    func sync() {
        guard detector.suggestion != nil else { panel?.orderOut(nil); return }
        if panel == nil {
            let host = NSHostingView(rootView: SuggestionView(detector: detector))
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 110),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.hidesOnDeactivate = false
            p.contentView = host
            self.host = host
            panel = p
        }
        guard let panel, let host else { return }
        let size = host.fittingSize
        if let area = NSScreen.main?.visibleFrame {
            panel.setFrame(NSRect(x: area.maxX - size.width - 16, y: area.minY + 16, width: size.width, height: size.height),
                           display: true)
        }
        panel.orderFrontRegardless()
    }
}

private struct SuggestionView: View {
    let detector: MusicDetector

    var body: some View {
        if let s = detector.suggestion {
            VStack(alignment: .leading, spacing: 10) {
                Label("เจอเพลง YouTube (\(s.source.rawValue))", systemImage: "music.note")
                    .font(.caption).foregroundStyle(.secondary)
                Text(s.title).font(.headline).lineLimit(2)
                HStack {
                    Button("เพิ่มเข้าเพลย์ลิสต์") { detector.accept(play: false) }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    Button("เพิ่มและเล่น") { detector.accept(play: true) }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("ไม่เอา") { detector.dismiss() }.buttonStyle(.borderless)
                }
            }
            .padding(16)
            .frame(width: 320, alignment: .leading)
            .glassCard(cornerRadius: 22)
        }
    }
}
