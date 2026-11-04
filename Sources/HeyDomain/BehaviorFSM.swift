import Foundation

public enum PetPose: Equatable, Sendable {
    case idle, walk, sleep, happy, eat, carried, falling
    /// Shock after a sudden wake-up, wing practice and a short flight (adults), and the daze after a hard landing.
    case startled, dizzy, flap, fly
}

public enum PetEvent: Sendable {
    case clicked, doubleClicked, cheered, petted, grabbed, released, landed, tired, fed, wake
    /// One quick peck at something (a bubble), shorter than a meal.
    case pecked
    /// Shaken hard or dropped from a height while in the air: it will be dazed when it lands.
    case shaken
}

public protocol RandomSource: Sendable {
    mutating func next(in range: ClosedRange<Double>) -> Double
}

public struct SystemRandom: RandomSource {
    public init() {}
    public mutating func next(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range)
    }
}

/// Decides what the pet is doing. Pure logic: time and randomness are injected,
/// the UI layer only reads `pose` / `facingRight` and reports events.
public struct BehaviorFSM: Sendable {
    public private(set) var pose: PetPose = .idle
    public private(set) var facingRight = true
    /// While true the pet stays put (e.g. during a focus round) instead of wandering.
    public var calm = false
    /// Late at night the pet dozes off more and wanders less.
    public var sleepy = false
    /// Grown birds practise flapping and fly short hops.
    public var canFly = false
    private var dazed = false

    private var elapsed = 0.0
    private var duration = 3.0
    private var rng: any RandomSource

    public init(rng: any RandomSource = SystemRandom()) {
        self.rng = rng
    }

    /// Look toward `right`. Only while standing still, so it never interrupts a walk.
    public mutating func face(right: Bool) {
        if pose == .idle { facingRight = right }
    }

    public mutating func turnAround() {
        facingRight.toggle()
    }

    /// Stop autonomous movement immediately when a task needs planted feet.
    /// Never interrupt an explicit interaction or the carried/falling physics cycle.
    public mutating func settle() {
        if pose == .walk || pose == .sleep || pose == .fly || pose == .flap { enter(.idle, for: 2) }
    }

    /// Head for something to the left or right: keeps walking (the duration is refreshed every call) until `settle()`.
    /// A sleeper is woken first. Never interrupts being carried, falling, a daze or a meal.
    public mutating func seek(right: Bool) {
        guard interruptible, pose != .dizzy, pose != .eat else { return }
        facingRight = right
        enter(.walk, for: 3600)
    }

    /// True while the pet is on its way to something.
    public var isSeeking: Bool { pose == .walk && duration >= 3600 }

    private var interruptible: Bool { pose != .carried && pose != .falling }

    public mutating func send(_ event: PetEvent) {
        switch event {
        case .grabbed:
            dazed = false
            enter(.carried, for: .infinity)
        case .released:
            if pose == .carried { enter(.falling, for: .infinity) }
        case .shaken:
            if pose == .carried || pose == .falling { dazed = true }
        case .landed:
            if pose == .falling {
                if dazed { dazed = false; enter(.dizzy, for: 2.6) } else { enter(.idle, for: 1.0) }
            }
        case .fed:
            if interruptible { enter(.eat, for: 2.0) }
        case .pecked:
            if interruptible, pose != .dizzy { enter(.eat, for: 0.7) }
        case .wake:
            if pose == .sleep { enter(.idle, for: 1.5) }
        case .tired:
            if pose == .idle || pose == .walk { enter(.sleep, for: rng.next(in: 10...14)) }
        case .clicked, .petted:
            guard interruptible else { break }
            // poking a sleeper is a shock; a dizzy bird ignores gentle pets
            if pose == .sleep { enter(.startled, for: 1.3) }
            else if pose != .dizzy && pose != .fly { enter(.happy, for: 1.5) }
        case .cheered:
            // A celebration (finished focus round): a grown bird flaps, others hop happily; a sleeper stays asleep.
            guard interruptible, pose != .dizzy, pose != .sleep else { break }
            enter(canFly ? .flap : .happy, for: canFly ? 2.4 : 1.8)
        case .doubleClicked:
            guard interruptible, pose != .dizzy else { break }
            enter(canFly ? .flap : .happy, for: canFly ? 2.0 : 1.5)
        }
    }

    public mutating func tick(dt: Double) {
        guard pose != .carried, pose != .falling else { return }
        elapsed += dt
        if elapsed >= duration { pickNext() }
    }

    private mutating func pickNext() {
        switch pose {
        case .idle:
            let r = rng.next(in: 0...1)
            let walkCut = sleepy ? 0.30 : 0.55
            let sleepCut = sleepy ? 0.75 : 0.70
            if canFly && !calm && !sleepy && r < 0.12 {
                enter(.flap, for: rng.next(in: 2...3))
            } else if r < walkCut {
                if calm {
                    enter(.idle, for: rng.next(in: 2...5))
                } else {
                    facingRight = rng.next(in: 0...1) < 0.5
                    enter(.walk, for: rng.next(in: 3...6))
                }
            } else if r < sleepCut {
                enter(.sleep, for: rng.next(in: 8...15))
            } else {
                enter(.idle, for: rng.next(in: 2...5))
            }
        case .flap where canFly && rng.next(in: 0...1) < 0.5:
            enter(.fly, for: 1.6)
        case .walk, .sleep, .happy, .eat, .startled, .dizzy, .flap, .fly:
            enter(.idle, for: rng.next(in: 2...5))
        case .carried, .falling:
            break
        }
    }

    private mutating func enter(_ pose: PetPose, for duration: Double) {
        self.pose = pose
        self.duration = duration
        self.elapsed = 0
    }
}
