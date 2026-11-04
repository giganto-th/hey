import Foundation
import Observation
import HeyDomain

@MainActor
@Observable
final class PomodoroModel {
    private(set) var timer = PomodoroTimer()
    /// Refreshed once a second while running so views showing the countdown redraw.
    private(set) var now = Date()

    @ObservationIgnored var onEvent: ((PomodoroEvent) -> Void)?
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var ticker: Timer?

    var remainingText: String {
        let s = Int(timer.remaining(at: now).rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    var isFocusing: Bool { timer.isRunning && timer.phase == .focus }

    func toggle() { timer.toggle(at: Date()); changed() }
    func skip() { timer.skip(at: Date()); changed() }
    func reset() { timer.reset(); changed() }

    private func changed() {
        now = Date()
        if timer.isRunning { startTicker() } else { stopTicker() }
        onChange?()
    }

    private func startTicker() {
        guard ticker == nil else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.3
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        now = Date()
        if let event = timer.tick(at: now) { onEvent?(event) }
        if !timer.isRunning { stopTicker() }
        onChange?()
    }
}
