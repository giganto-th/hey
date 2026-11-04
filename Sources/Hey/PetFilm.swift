import AppKit
import SpriteKit
import HeyDomain

/// Dev tool (`HEY_DEV_PET_FILM=<dir>`): steps the sprite pet through each action at 60 fps and saves frames.
@MainActor
enum PetFilm {
    static func write(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let species = ProcessInfo.processInfo.environment["HEY_DEV_PET_SPECIES"] ?? "heihei"
        let scene = SKScene(size: CGSize(width: 300, height: 280))
        scene.backgroundColor = NSColor(white: 0.93, alpha: 1)
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        view.presentScene(scene)
        view.isPaused = true

        // (name, activity, rate, seconds between captures, how many captures, stage, start offset)
        let shots: [(String, CompanionActivity, Double, Double, Int, PetStage)] = [
            ("walk", .walking, 2, 0.12, 6, .adult), ("dance", .dancing, 1.8, 0.14, 6, .adult),
            ("type", .typing, 1.6, 0.13, 6, .adult), ("eat", .eating, 2, 0.14, 6, .adult),
            ("click", .pleased, 1.5, 0.12, 6, .adult), ("sleep", .sleeping, 0.3, 0.7, 4, .adult),
            ("startle", .startled, 1, 0.1, 6, .adult), ("dizzy", .dizzy, 0.9, 0.2, 6, .adult),
            ("flap", .flapping, 3.5, 0.09, 6, .adult), ("fly", .flying, 4.5, 0.07, 6, .adult),
            ("carried", .carried, 1, 0.12, 6, .adult), ("worried", .worried, 0.4, 0.2, 3, .adult),
            ("idle", .idle, 0.4, 1.3, 8, .adult),
            ("hatchling_walk", .walking, 2, 0.12, 4, .hatchling), ("child_dance", .dancing, 1.8, 0.14, 4, .child),
            ("teen_eat", .eating, 2, 0.14, 4, .teen), ("egg", .egg, 1, 0.25, 6, .egg),
        ]
        for (name, activity, rate, spacing, count, stage) in shots {
            let pet = SpritePet()
            pet.position = CGPoint(x: 150, y: 22)
            scene.addChild(pet)
            let presentation = CompanionPresentation(activity: activity, amplitude: 1, cyclesPerSecond: rate)
            var elapsed = 0.0
            for frame in 0..<count {
                let target = Double(frame) * spacing + 0.05
                while elapsed < target { pet.update(presentation, dt: 1.0 / 60, stage: stage, species: species); elapsed += 1.0 / 60 }
                guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)) else { continue }
                let rep = NSBitmapImageRep(cgImage: texture.cgImage())
                try rep.representation(using: .png, properties: [:])?
                    .write(to: directory.appendingPathComponent("\(name)_\(frame).png"))
            }
            pet.removeFromParent()
        }
        // egg → chick: a few egg frames, then the stage changes and the hatch sequence plays
        let hatching = SpritePet()
        hatching.position = CGPoint(x: 150, y: 22)
        scene.addChild(hatching)
        let idle = CompanionPresentation(activity: .idle, amplitude: 1, cyclesPerSecond: 0.4)
        let eggMode = CompanionPresentation(activity: .egg, amplitude: 1, cyclesPerSecond: 1)
        for _ in 0..<30 { hatching.update(eggMode, dt: 1.0 / 60, stage: .egg, species: species) }
        for frame in 0..<12 {
            for _ in 0..<12 { hatching.update(idle, dt: 1.0 / 60, stage: .hatchling, species: species) }
            guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)) else { continue }
            try NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:])?
                .write(to: directory.appendingPathComponent("hatch_\(frame).png"))
        }
        hatching.removeFromParent()
        print("[film] written to", directory.path)
    }
}
