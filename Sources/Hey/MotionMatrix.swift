import AppKit
import SpriteKit
import HeyDomain

/// Dev tool (`HEY_DEV_MOTION_MATRIX=<dir>`): plays every species × stage × activity through the real sprite pet at the redraw rate the
/// app would use, reads the rendered pixels back and writes how steady each one is (`matrix.csv`), plus how far the picture jumps
/// when one activity hands over to another (`transitions.csv`). The raw clip art is checked separately by docs/art-tools/clip_report.py;
/// this checks what the player does with it.
@MainActor
enum MotionMatrix {
    private static let size = CGSize(width: 300, height: 280)

    private struct Frame { var torso: Double; var bottom: Int; var hash: UInt64; var empty: Bool }

    /// Redraw rates by power tier: (moving, still).
    private static let tiers: [(name: String, moving: Double, still: Double)] = [("full", 24, 6), ("saver", 12, 3)]

    private static let rates: [CompanionActivity: Double] = [
        .idle: 0.4, .walking: 2, .sleeping: 0.3, .dancing: 1.8, .typing: 1.6, .quietTyping: 1, .eating: 2, .pleased: 1.5,
        .startled: 1, .dizzy: 0.9, .carried: 1, .falling: 1, .flapping: 3.5, .flying: 4.5, .focusing: 0.4, .worried: 0.4, .attentive: 1,
    ]
    private static let stillActivities: Set<CompanionActivity> = [.idle, .sleeping, .focusing, .attentive, .egg]

    private static func activities(for stage: PetStage) -> [CompanionActivity] {
        if stage == .egg { return [.egg] }
        var list = Array(rates.keys)
        if stage != .adult { list.removeAll { $0 == .flapping || $0 == .flying } }
        return list.sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: rendering

    private static func render(_ view: SKView, _ scene: SKScene) -> (alpha: [UInt8], w: Int, h: Int)? {
        guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)) else { return nil }
        let image = texture.cgImage()
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let context = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var alpha = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) { alpha[i] = pixels[i * 4 + 3] }
        return (alpha, w, h)
    }

    /// Torso x (mean x of the opaque pixels in a band relative to the lowest opaque row), lowest row, and a hash of the silhouette.
    private static func measure(_ shot: (alpha: [UInt8], w: Int, h: Int), band: (Int, Int)?) -> Frame {
        let (alpha, w, h) = shot
        var bottom = -1, top = h
        for y in 0..<h {
            var any = false
            for x in stride(from: 0, to: w, by: 1) where alpha[y * w + x] > 200 { any = true; break }
            if any { top = min(top, y); bottom = y }
        }
        guard bottom >= 0 else { return Frame(torso: .nan, bottom: -1, hash: 0, empty: true) }
        var hash: UInt64 = 1469598103934665603
        for y in stride(from: 0, to: h, by: 3) { for x in stride(from: 0, to: w, by: 3) {
            hash = (hash ^ UInt64(alpha[y * w + x] > 128 ? 1 : 0)) &* 1099511628211
        } }
        let lo: Int, hi: Int
        if let band { lo = band.0; hi = band.1 } else { lo = top + Int(0.45 * Double(bottom - top)); hi = top + Int(0.8 * Double(bottom - top)) }
        var sum = 0.0, count = 0.0
        for y in max(0, lo)..<min(h, max(hi, lo + 1)) { for x in 0..<w where alpha[y * w + x] > 200 { sum += Double(x); count += 1 } }
        return Frame(torso: count > 0 ? sum / count : .nan, bottom: bottom, hash: hash, empty: false)
    }

    private static func run(_ pet: SpritePet, _ view: SKView, _ scene: SKScene, activity: CompanionActivity, species: String, stage: PetStage,
                            seconds: Double, tier: (name: String, moving: Double, still: Double), band: (Int, Int)?, idleBottom: Int?) -> [Frame] {
        var frames: [Frame] = []
        var t = 0.0
        while t < seconds {
            let midMove = activity == .idle && pet.isMidIdleMove
            let fps = (stillActivities.contains(activity) && !midMove) ? tier.still : tier.moving
            let rate = ClipRate.limited(rates[activity] ?? 1, fps: Int(fps))
            let p = CompanionPresentation(activity: activity, amplitude: 1, cyclesPerSecond: activity == .egg ? 1 : rate)
            pet.update(p, dt: 1 / fps, stage: stage, species: species)
            t += 1 / fps
            guard let shot = render(view, scene) else { continue }
            var b = band
            if let b0 = band, let idleBottom {            // let the band follow the feet in a hop, as the registration tool does
                let m = measure(shot, band: nil)
                if m.bottom >= 0 { b = (b0.0 + (m.bottom - idleBottom), b0.1 + (m.bottom - idleBottom)) }
            }
            frames.append(measure(shot, band: b))
        }
        return frames
    }

    private static func range(_ v: [Double]) -> Double { let f = v.filter { !$0.isNaN }; return (f.max() ?? 0) - (f.min() ?? 0) }
    private static func median(_ v: [Double]) -> Double { let f = v.filter { !$0.isNaN }.sorted(); return f.isEmpty ? .nan : f[f.count / 2] }

    // MARK: entry

    static func write(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scene = SKScene(size: size)
        scene.backgroundColor = .clear
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.allowsTransparency = true
        view.presentScene(scene)
        view.isPaused = true
        let only = ProcessInfo.processInfo.environment["HEY_DEV_MATRIX_SPECIES"]
        var matrix = "species,stage,activity,tier,fps,torso_range_px,torso_offset_from_idle_px,bottom_range_px,changes_per_s,max_step_px,frames\n"
        var transitions = "species,stage,from,to,tier,jump_px\n"

        for species in PetSpecies.all.map(\.id) where only == nil || only == species {
            for stage in PetStage.allCases {
                // reference: the idle clip's resting torso position and the band of rows the torso lives in
                let ref = SpritePet()
                ref.position = CGPoint(x: 150, y: 22); scene.addChild(ref)
                let idleFrames = stage == .egg ? [] : run(ref, view, scene, activity: .idle, species: species, stage: stage, seconds: 2.5, tier: tiers[0], band: nil, idleBottom: nil)
                ref.removeFromParent()
                guard stage == .egg || idleFrames.contains(where: { !$0.empty }) else { continue }
                let idleBottom = idleFrames.map(\.bottom).filter { $0 >= 0 }.sorted().last ?? 0
                let idleTop = idleBottom - 150
                let band = (idleTop + Int(0.45 * 150), idleTop + Int(0.8 * 150))
                // the real silhouette height decides the band; recompute from the first idle frame
                let idleMedian = median(idleFrames.map(\.torso))

                for activity in activities(for: stage) {
                    for tier in tiers {
                        let pet = SpritePet()
                        pet.position = CGPoint(x: 150, y: 22); scene.addChild(pet)
                        let frames = run(pet, view, scene, activity: activity, species: species, stage: stage, seconds: 3, tier: tier,
                                         band: stage == .egg ? nil : band, idleBottom: stage == .egg ? nil : idleBottom)
                        pet.removeFromParent()
                        let steady = Array(frames.dropFirst(max(1, Int(0.5 * (stillActivities.contains(activity) ? tier.still : tier.moving)))))
                        guard !steady.isEmpty else { continue }
                        let fps = stillActivities.contains(activity) ? tier.still : tier.moving
                        let torso = steady.map(\.torso)
                        var steps = 0.0, maxStep = 0.0, changes = 0
                        for i in 1..<max(steady.count, 1) where i < steady.count {
                            if steady[i].hash != steady[i - 1].hash { changes += 1 }
                            let d = abs(steady[i].torso - steady[i - 1].torso)
                            if !d.isNaN { steps += d; maxStep = max(maxStep, d) }
                        }
                        let perSecond = Double(changes) / (Double(steady.count) / fps)
                        let offset = median(torso) - idleMedian
                        matrix += "\(species),\(stage.rawValue),\(activity.rawValue),\(tier.name),\(Int(fps)),"
                        matrix += String(format: "%.1f,%.1f,%.1f,%.1f,%.1f,%d\n", range(torso), offset.isNaN ? 0 : offset,
                                         Double(steady.map(\.bottom).max()! - steady.map(\.bottom).min()!), perSecond, maxStep, steady.count)
                    }
                }

                // hand-overs: idle → X → idle on one pet, how far the torso jumps at each switch (full tier)
                if stage != .egg {
                    let tier = tiers[0]
                    for activity in activities(for: stage) where activity != .idle {
                        let pet = SpritePet()
                        pet.position = CGPoint(x: 150, y: 22); scene.addChild(pet)
                        let a = run(pet, view, scene, activity: .idle, species: species, stage: stage, seconds: 1.5, tier: tier, band: band, idleBottom: idleBottom)
                        let b = run(pet, view, scene, activity: activity, species: species, stage: stage, seconds: 1.5, tier: tier, band: band, idleBottom: idleBottom)
                        let c = run(pet, view, scene, activity: .idle, species: species, stage: stage, seconds: 1.5, tier: tier, band: band, idleBottom: idleBottom)
                        pet.removeFromParent()
                        if let la = a.last?.torso, let fb = b.first?.torso, !la.isNaN, !fb.isNaN {
                            transitions += "\(species),\(stage.rawValue),idle,\(activity.rawValue),full,\(String(format: "%.1f", abs(fb - la)))\n"
                        }
                        if let lb = b.last?.torso, let fc = c.first?.torso, !lb.isNaN, !fc.isNaN {
                            transitions += "\(species),\(stage.rawValue),\(activity.rawValue),idle,full,\(String(format: "%.1f", abs(fc - lb)))\n"
                        }
                    }
                }
            }
        }
        try matrix.write(to: directory.appendingPathComponent("matrix.csv"), atomically: true, encoding: .utf8)
        try transitions.write(to: directory.appendingPathComponent("transitions.csv"), atomically: true, encoding: .utf8)
        print("[matrix] written to", directory.path)
    }
}
