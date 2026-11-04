import AppKit
import SpriteKit
import HeyDomain

/// Finds the right picture for (species, growth stage, pose).
///
/// Art lives in `Resources/Sprites/<species>/<stage>_<pose>.png`. Anything missing falls back, in order, to:
/// the same stage's idle picture → the same pose at a younger stage → the old placeholder blob → a drawn blob,
/// so a half-finished art set still runs.
@MainActor
final class SpriteLibrary {
    static let frameSize: CGFloat = 256

    private let roots: [URL]
    private var cache: [String: SKTexture] = [:]
    private lazy var drawn: SKTexture = Self.fallbackTexture()

    init() {
        let fm = FileManager.default
        var paths: [String] = []
        if let env = ProcessInfo.processInfo.environment["HEY_SPRITES_DIR"] { paths.append(env) }
        if let res = Bundle.main.resourceURL?.path { paths.append(res + "/Sprites") }   // when running as Hey.app
        paths.append(fm.currentDirectoryPath + "/Resources/Sprites")
        roots = paths.map { URL(fileURLWithPath: $0) }.filter { fm.fileExists(atPath: $0.path) }
        if roots.isEmpty { FileHandle.standardError.write(Data("[Hey] sprites folder not found, using drawn art\n".utf8)) }
    }

    func texture(for pose: PetPose, stage: PetStage, species: String) -> SKTexture {
        let key = "\(species)/\(stage.rawValue)/\(Self.poseName(pose))"
        if let hit = cache[key] { return hit }
        let texture = resolve(pose: Self.poseName(pose), stage: stage, species: species)
        if ProcessInfo.processInfo.environment["HEY_DEV_LOG"] != nil {
            print("[sprites]", key, texture == nil ? "-> DRAWN FALLBACK" : "ok")
        }
        let final = texture ?? drawn
        cache[key] = final
        return final
    }

    /// Poses without their own picture borrow the closest one.
    private static func poseName(_ pose: PetPose) -> String {
        switch pose {
        case .idle: "idle"
        case .walk: "walk"
        case .eat: "eat"
        case .happy, .carried, .falling, .startled, .flap, .fly: "happy"
        case .dizzy: "idle"      // arms/wings up reads well while dangling or dropping
        case .sleep: "sleep"
        }
    }

    private func resolve(pose: String, stage: PetStage, species: String) -> SKTexture? {
        // 1–3: this species, this stage then younger stages
        var current: PetStage? = stage
        while let s = current {
            for name in [pose, "idle"] {
                if let t = load("\(species)/\(s.rawValue)_\(name).png") {
                    if ProcessInfo.processInfo.environment["HEY_DEV_LOG"] != nil, s != stage || name != pose { print("[sprites] borrowed \(species)/\(s.rawValue)_\(name) for \(stage.rawValue)_\(pose)") }
                    return t
                }
            }
            current = Self.younger(than: s)
        }
        // 4: the old placeholder blob
        if stage == .egg, let t = load("_gen/egg_idle.png") { return t }
        for name in [pose, "idle"] {
            if let t = load("_gen/hatchling_\(name).png") { return t }
        }
        return nil
    }

    private static func younger(than stage: PetStage) -> PetStage? {
        switch stage {
        case .adult: .teen
        case .teen: .child
        case .child: .hatchling
        case .hatchling: nil          // an egg never borrows a chick's picture
        case .egg: nil
        }
    }

    private func load(_ relative: String) -> SKTexture? {
        for root in roots {
            let url = root.appendingPathComponent(relative)
            if let image = Self.loadScaled(url) { return SKTexture(image: image) }
        }
        return nil
    }

    /// Downscales big source art so we don't keep multi-megabyte bitmaps resident.
    private static func loadScaled(_ url: URL) -> NSImage? {
        guard FileManager.default.fileExists(atPath: url.path), let src = NSImage(contentsOf: url) else { return nil }
        let size = NSSize(width: frameSize, height: frameSize)
        let out = NSImage(size: size)
        out.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        src.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1)
        out.unlockFocus()
        return out
    }

    private static func fallbackTexture() -> SKTexture {
        let size = NSSize(width: frameSize, height: frameSize)
        let image = NSImage(size: size, flipped: false) { rect in
            let body = NSBezierPath(ovalIn: rect.insetBy(dx: 30, dy: 30).offsetBy(dx: 0, dy: -10))
            NSColor(calibratedRed: 0.62, green: 0.90, blue: 0.80, alpha: 1).setFill()
            body.fill()
            NSColor(calibratedWhite: 0.2, alpha: 1).setStroke()
            body.lineWidth = 6
            body.stroke()
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 90, y: 120, width: 20, height: 28)).fill()
            NSBezierPath(ovalIn: NSRect(x: 150, y: 120, width: 20, height: 28)).fill()
            return true
        }
        return SKTexture(image: image)
    }
}
