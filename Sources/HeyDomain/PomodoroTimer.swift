import Foundation

public enum PomodoroPhase: Sendable, Equatable {
    case focus, shortBreak, longBreak

    public var label: String {
        switch self {
        case .focus: tr("โฟกัส")
        case .shortBreak: tr("พักสั้น")
        case .longBreak: tr("พักยาว")
        }
    }
}

public enum PomodoroEvent: Equatable, Sendable {
    case focusFinished(session: Int)
    case breakFinished
}

/// Date-based, so it stays accurate even if ticks are delayed or the Mac sleeps.
public struct PomodoroTimer: Sendable {
    public var focus: TimeInterval = 25 * 60
    public var shortBreak: TimeInterval = 5 * 60
    public var longBreak: TimeInterval = 15 * 60
    public var longBreakEvery = 4

    public private(set) var phase: PomodoroPhase = .focus
    public private(set) var isRunning = false
    public private(set) var completedFocus = 0
    private var frozenRemaining: TimeInterval
    private var endAt: Date?

    public init() { frozenRemaining = 25 * 60 }

    public func duration(of phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .focus: focus
        case .shortBreak: shortBreak
        case .longBreak: longBreak
        }
    }

    public func remaining(at now: Date) -> TimeInterval {
        guard isRunning, let endAt else { return frozenRemaining }
        return max(endAt.timeIntervalSince(now), 0)
    }

    public mutating func start(at now: Date) {
        guard !isRunning else { return }
        isRunning = true
        endAt = now.addingTimeInterval(frozenRemaining)
    }

    public mutating func pause(at now: Date) {
        guard isRunning else { return }
        frozenRemaining = remaining(at: now)
        isRunning = false
        endAt = nil
    }

    public mutating func toggle(at now: Date) {
        isRunning ? pause(at: now) : start(at: now)
    }

    /// Back to a fresh focus round (the session counter is kept).
    public mutating func reset() {
        phase = .focus
        isRunning = false
        endAt = nil
        frozenRemaining = focus
    }

    /// Jump to the next phase without crediting a finished focus session.
    public mutating func skip(at now: Date) {
        let wasRunning = isRunning
        switch phase {
        case .focus: enter(completedFocus % longBreakEvery == longBreakEvery - 1 ? .longBreak : .shortBreak)
        case .shortBreak, .longBreak: enter(.focus)
        }
        if wasRunning { start(at: now) }
    }

    public mutating func tick(at now: Date) -> PomodoroEvent? {
        guard isRunning, let endAt, now >= endAt else { return nil }
        switch phase {
        case .focus:
            completedFocus += 1
            enter(completedFocus % longBreakEvery == 0 ? .longBreak : .shortBreak)
            start(at: now)                               // breaks start by themselves
            return .focusFinished(session: completedFocus)
        case .shortBreak, .longBreak:
            enter(.focus)                                // the next focus round waits for you
            return .breakFinished
        }
    }

    private mutating func enter(_ phase: PomodoroPhase) {
        self.phase = phase
        isRunning = false
        endAt = nil
        frozenRemaining = duration(of: phase)
    }
}
