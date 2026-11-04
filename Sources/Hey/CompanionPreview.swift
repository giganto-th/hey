import AppKit
import SpriteKit
import SwiftUI
import HeyDomain

enum CompanionPreviewMode: String, CaseIterable, Identifiable {
    case idle, music, typing, combined, focus
    var id: Self { self }
    var title: String {
        switch self {
        case .idle: "พัก"
        case .music: "เพลง"
        case .typing: "พิมพ์"
        case .combined: "พิมพ์ + เพลง"
        case .focus: "โฟกัส"
        }
    }
}

/// The Hub previews the same rig and resolver as the desktop, without granting rewards or playing audio.
@MainActor
final class CompanionPreviewScene: SKScene {
    private let rig = HeiHeiRig()
    private let art = SpritePet()
    private let egg = SKShapeNode(ellipseOf: CGSize(width: 55, height: 72))
    var mode: CompanionPreviewMode = .idle
    var settings = MotionSettings()
    var stage: PetStage = .adult
    var species = "heihei"
    private var lastTime: TimeInterval = 0

    override init() {
        super.init(size: CGSize(width: 240, height: 210))
        backgroundColor = .clear; scaleMode = .aspectFit
        rig.position = CGPoint(x: 110, y: 15); rig.setScale(0.98)
        addChild(rig)
        art.position = CGPoint(x: 120, y: 10); art.setScale(1.0)
        addChild(art)
        egg.position = CGPoint(x: 120, y: 60)
        egg.fillColor = NSColor(calibratedRed: 0.94, green: 0.87, blue: 0.70, alpha: 1)
        egg.strokeColor = .brown; egg.lineWidth = 2
        addChild(egg)
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0.05 : min(max(currentTime - lastTime, 0), 0.1)
        lastTime = currentTime
        var signals = CompanionSignals()
        signals.isEgg = stage == .egg
        signals.musicPlaying = mode == .music || mode == .combined
        signals.lastKeyAt = mode == .typing || mode == .combined ? currentTime : nil
        signals.focusing = mode == .focus
        signals.systemReduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let presentation = CompanionMotion.resolve(signals, settings: settings, now: currentTime)
        let hasArt = SpritePet.hasArt(species: species, stage: stage)
        art.isHidden = !hasArt
        rig.isHidden = hasArt || stage == .egg
        egg.isHidden = hasArt || stage != .egg
        if hasArt { art.update(presentation, dt: dt, stage: stage, species: species) }
        else { rig.update(presentation, dt: dt, stage: stage) }
    }

    /// Captures the actual SpriteKit renderer for visual QA; available only via a dev hook.
    static func writeSamples(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for mode in CompanionPreviewMode.allCases {
            let scene = CompanionPreviewScene()
            scene.mode = mode
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 480, height: 420))
            view.allowsTransparency = true
            view.presentScene(scene)
            view.isPaused = true
            for frame in 1...12 { scene.update(Double(frame) / 60) }
            guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)) else { continue }
            let image = NSBitmapImageRep(cgImage: texture.cgImage())
            if let data = image.representation(using: .png, properties: [:]) {
                try data.write(to: directory.appendingPathComponent("rig-\(mode.rawValue).png"))
            }
            view.presentScene(nil)
        }
    }
}

struct CompanionPreview: View {
    var stage: PetStage = .adult
    var mode: CompanionPreviewMode = .idle
    var settings = MotionSettings()
    var species = "heihei"
    var size = CGSize(width: 220, height: 192)
    @State private var scene = CompanionPreviewScene()
    @State private var visible = false

    var body: some View {
        SpriteView(scene: scene, isPaused: !visible, preferredFramesPerSecond: settings.level == .reduced ? 6 : 24, options: [.allowsTransparency])
            .frame(width: size.width, height: size.height)
            .accessibilityLabel(stage == .egg ? "ไข่ของสัตว์เลี้ยง" : "สัตว์เลี้ยง · \(mode.title)")
            .onAppear { configure(); visible = true }
            .onDisappear { visible = false }
            .onChange(of: stage) { configure() }
            .onChange(of: species) { configure() }
            .onChange(of: mode) { configure() }
            .onChange(of: settings) { configure() }
    }

    private func configure() { scene.mode = mode; scene.stage = stage; scene.settings = settings; scene.species = species }
}

struct MotionSettingsControls: View {
    let model: GameModel
    let game: Game
    @State private var preview: CompanionPreviewMode = .idle

    var body: some View {
        Picker("ระดับการเคลื่อนไหว", selection: Binding(
            get: { game.motion.level },
            set: { level in model.perform { $0.setMotion { $0.level = level }; return [] } })) {
                ForEach(MotionLevel.allCases, id: \.self) { Text($0.label).tag($0) }
            }
        Toggle("เต้นขณะเปิดเพลง", isOn: Binding(
            get: { game.motion.dance },
            set: { value in model.perform { $0.setMotion { $0.dance = value }; return [] } }))
        Toggle("เดินสำรวจเมื่อไม่ได้ทำกิจกรรม", isOn: Binding(
            get: { game.motion.roam },
            set: { value in model.perform { $0.setMotion { $0.roam = value }; return [] } }))
        Text("การเต้นใช้จังหวะอัตโนมัติจากสถานะเล่นเพลง ยังไม่ได้ตรวจจับ beat ของเสียง · พิมพ์จะเปลี่ยนเป็นจิกคีย์บอร์ด และโฟกัสจะหยุดเต้น")
            .font(.caption).foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 8) {
            Picker("ลองท่าทาง", selection: $preview) {
                ForEach(CompanionPreviewMode.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            HStack {
                CompanionPreview(stage: .adult, mode: preview, settings: game.motion, species: game.species)
                VStack(alignment: .leading, spacing: 6) {
                    Text("ลองท่าทางของ \(game.pet.state.name)").font(.headline)
                    Text("ใช้ตัววาดเดียวกับบนเดสก์ท็อป ตัวอย่างนี้ไม่มีเสียงและไม่เพิ่มรางวัล")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(.vertical, 8)
    }
}
