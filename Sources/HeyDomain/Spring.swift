import Foundation

/// A damped spring: a value that chases its target with weight and a little overshoot, instead of jumping.
/// Used for the pet's head, wings and tail so every move starts and ends softly and parts follow one another.
public struct Spring: Sendable {
    public var value: Double
    public var velocity = 0.0

    public init(_ value: Double = 0) { self.value = value }

    /// `frequency` is how fast it responds (Hz); `damping` 1 = no overshoot, below 1 = bouncy.
    /// Time is cut into small steps so a long frame (or a pause in the app) can never make it explode.
    public mutating func update(toward target: Double, dt: Double, frequency: Double = 6, damping: Double = 0.75) {
        guard dt > 0 else { return }
        let omega = 2 * Double.pi * max(frequency, 0.01)
        let maxStep = min(1.0 / 240, 0.5 / omega)
        var remaining = min(dt, 0.25)
        while remaining > 0 {
            let h = min(remaining, maxStep)
            // semi-implicit Euler: stable for the stiff springs used here
            let acceleration = omega * omega * (target - value) - 2 * damping * omega * velocity
            velocity += acceleration * h
            value += velocity * h
            remaining -= h
        }
    }

    public mutating func snap(to v: Double) { value = v; velocity = 0 }
}

/// Picks short "idle behaviours" (look around, preen, stretch, shake) at calm, uneven intervals so a pet that is
/// just standing there still feels alive. Time and randomness come in as arguments, so it is fully testable.
public struct IdleVariety: Sendable {
    public enum Move: Equatable, Sendable { case none, lookLeft, lookRight, preen, stretch, shake, peckGround }

    public private(set) var move: Move = .none
    /// 0…1 progress through the current move.
    public private(set) var progress = 0.0
    private var elapsed = 0.0
    private var nextAt: Double
    private var duration = 1.0
    private var rng: any RandomSource

    public init(rng: any RandomSource = SystemRandom(), firstAfter: Double? = nil) {
        self.rng = rng
        nextAt = firstAfter ?? 4
    }

    /// Call every frame while the pet is idle; `calm` false (busy with something else) cancels the current move.
    public mutating func update(dt: Double, calm: Bool) {
        guard calm else { move = .none; progress = 0; elapsed = 0; nextAt = max(nextAt, 3); return }
        elapsed += dt
        if move == .none {
            guard elapsed >= nextAt else { return }
            let r = rng.next(in: 0...1)
            switch r {
            case ..<0.22: move = .lookLeft; duration = 1.6
            case ..<0.44: move = .lookRight; duration = 1.6
            case ..<0.62: move = .preen; duration = 1.9
            case ..<0.78: move = .stretch; duration = 1.8
            case ..<0.90: move = .shake; duration = 0.9
            default: move = .peckGround; duration = 1.4
            }
            elapsed = 0
            progress = 0
        } else {
            progress = min(elapsed / duration, 1)
            if progress >= 1 {
                move = .none
                progress = 0
                elapsed = 0
                nextAt = rng.next(in: 4...9)
            }
        }
    }
}
