import Foundation

/// What the pet should do about a target on the floor: it is close enough, or it walks toward it.
public enum Seek: Equatable, Sendable {
    case arrived
    case toward(right: Bool)

    public static func decide(petX: Double, targetX: Double, reach: Double) -> Seek {
        let dx = targetX - petX
        return abs(dx) <= reach ? .arrived : .toward(right: dx > 0)
    }
}

/// One soap bubble drifting across the screen. `x` is a screen coordinate; `height` is how far above the floor it floats.
public struct Bubble: Identifiable, Equatable, Sendable {
    public let id: Int
    public var x: Double
    public var baseHeight: Double
    public var height: Double
    public var vx: Double
    public var radius: Double
    public var phase: Double
    /// Seconds left before it starts to sink toward the floor.
    public var floatTime: Double

    /// Resting on the floor: the only state in which the pet can peck it.
    public var isGrounded: Bool { baseHeight <= radius + 0.5 }
}

/// Bubbles that float around while the pet chases and pops them. Pure movement; drawing is the app's job.
public struct BubbleField: Sendable {
    public private(set) var bubbles: [Bubble] = []
    public private(set) var popped = 0
    private var nextID = 0
    private var rng: any RandomSource

    public static let heightRange: ClosedRange<Double> = 50...170
    public static let maxBubbles = 12

    public init(rng: any RandomSource = SystemRandom()) { self.rng = rng }

    public var isEmpty: Bool { bubbles.isEmpty }

    /// Blow `count` new bubbles somewhere between `minX` and `maxX`.
    public mutating func spawn(_ count: Int, minX: Double, maxX: Double) {
        for _ in 0..<count where bubbles.count < Self.maxBubbles {
            let base = rng.next(in: Self.heightRange)
            let speed = rng.next(in: 14...34)
            bubbles.append(Bubble(
                id: nextID,
                x: rng.next(in: minX...max(minX, maxX)),
                baseHeight: base, height: base,
                vx: rng.next(in: 0...1) < 0.5 ? -speed : speed,
                radius: rng.next(in: 16...30),
                phase: rng.next(in: 0...(2 * Double.pi)),
                floatTime: rng.next(in: 4...12)))
            nextID += 1
        }
    }

    public static let sinkSpeed = 45.0

    /// Drift sideways, bob up and down and bounce off the edges; after a while each bubble sinks to the floor and rolls slowly there.
    public mutating func step(dt: Double, minX: Double, maxX: Double) {
        for i in bubbles.indices {
            var b = bubbles[i]
            let sinking = b.floatTime <= 0
            b.floatTime -= dt
            if sinking { b.baseHeight = max(b.radius, b.baseHeight - Self.sinkSpeed * dt) }
            let speedFactor = b.isGrounded ? 0.25 : 1
            b.x += b.vx * speedFactor * dt
            if b.x < minX { b.x = minX; b.vx = abs(b.vx) }
            if b.x > maxX { b.x = maxX; b.vx = -abs(b.vx) }
            b.phase += dt * 1.6
            let bob = 14 * sin(b.phase) * min(max((b.baseHeight - b.radius) / 40, 0), 1)       // the bob dies away as it lands
            b.height = max(b.radius, b.baseHeight + bob)
            bubbles[i] = b
        }
    }

    /// The bubble closest to `x` along the floor.
    public func nearest(toX x: Double) -> Bubble? {
        bubbles.min { abs($0.x - x) < abs($1.x - x) }
    }

    /// The closest bubble that has landed; one still in the air cannot be pecked.
    public func nearestGrounded(toX x: Double) -> Bubble? {
        bubbles.filter(\.isGrounded).min { abs($0.x - x) < abs($1.x - x) }
    }

    @discardableResult
    public mutating func pop(_ id: Int) -> Bool {
        guard let i = bubbles.firstIndex(where: { $0.id == id }) else { return false }
        bubbles.remove(at: i)
        popped += 1
        return true
    }

    public mutating func clear() { bubbles.removeAll() }
}
