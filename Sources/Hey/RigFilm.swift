import AppKit
import SpriteKit
import HeyDomain

/// Dev tool (`HEY_DEV_RIG_FILM=<dir>`): steps the real rig through each action at 60 fps and saves frames,
/// so motion can be checked as contact sheets without watching the screen.
@MainActor
enum RigFilm {
    static func write(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scene = SKScene(size: CGSize(width: 250, height: 230))
        scene.backgroundColor = .clear
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        view.allowsTransparency = true
        view.presentScene(scene)
        view.isPaused = true

        // (name, activity, rate, seconds between captures, how many captures, stage)
        let shots: [(String, CompanionActivity, Double, Double, Int, PetStage)] = [
            ("walk", .walking, 1.6, 0.16, 5, .adult), ("dance", .dancing, 1.8, 0.14, 5, .adult),
            ("peck", .typing, 3.0, 0.11, 5, .adult), ("eat", .eating, 2.2, 0.14, 5, .adult),
            ("happy", .pleased, 1.8, 0.14, 5, .adult), ("sleep", .sleeping, 0.4, 0.8, 3, .adult),
            ("carried", .carried, 2.0, 0.15, 3, .adult), ("worried", .worried, 1.0, 0.1, 3, .adult),
            ("idle", .idle, 1.0, 1.4, 12, .adult),
            ("stage_hatchling", .idle, 1.0, 0.5, 1, .hatchling), ("stage_child", .idle, 1.0, 0.5, 1, .child),
            ("stage_teen", .idle, 1.0, 0.5, 1, .teen), ("stage_adult", .idle, 1.0, 0.5, 1, .adult),
            ("walk_hatchling", .walking, 1.6, 0.16, 3, .hatchling), ("sleep_child", .sleeping, 0.4, 0.5, 1, .child),
        ]
        for (name, activity, rate, spacing, count, stage) in shots {
            let rig = HeiHeiRig()
            rig.position = CGPoint(x: 120, y: 30)
            scene.addChild(rig)
            let presentation = CompanionPresentation(activity: activity, amplitude: 1, cyclesPerSecond: rate)
            var elapsed = 0.0
            for frame in 0..<count {
                let target = Double(frame + 1) * spacing + (activity == .idle ? 3 : 0.5)
                while elapsed < target { rig.update(presentation, dt: 1.0 / 60, stage: stage); elapsed += 1.0 / 60 }
                guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)) else { continue }
                let rep = NSBitmapImageRep(cgImage: texture.cgImage())
                try rep.representation(using: .png, properties: [:])?
                    .write(to: directory.appendingPathComponent("\(name)_\(frame).png"))
            }
            rig.removeFromParent()
        }
        print("[film] written to", directory.path)
    }
}
