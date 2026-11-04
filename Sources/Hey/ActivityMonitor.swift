import AppKit
import HeyDomain

/// Watches how the Mac is being used and tells the pet. It only ever counts key presses (the system keeps
/// that counter for everyone, no permission needed) — it never sees which keys, and nothing is stored.
@MainActor
final class ActivityMonitor {
    var onReaction: ((Reaction) -> Void)?
    var onAmbient: ((AmbientMotion) -> Void)?
    var onKeys: ((_ fast: Bool) -> Void)?

    private let model: GameModel
    private let power: PowerMonitor
    private var reactor = ActivityReactor()
    private var timer: Timer?
    private var lastKeyCount = CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
    private var shownAmbient: AmbientMotion = .none
    private var localKeyMonitor: Any?
    private var localKeyTimes: [TimeInterval] = []
    private var lastLocalKeyAt: TimeInterval?
    private static let fake: [String: String] = {
        guard let raw = ProcessInfo.processInfo.environment["HEY_DEV_FAKE"] else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.split(separator: ",").compactMap { pair in
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            return kv.count == 2 ? (kv[0], kv[1]) : nil
        })
    }()

    init(model: GameModel, power: PowerMonitor) {
        self.model = model
        self.power = power
        // Local events give immediate feedback inside our Hub, including input posted directly
        // to this process. Read no characters/key codes; the global counter still covers other apps.
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, self.model.game.reactions.enabled, self.model.game.reactions.typing,
                      !self.power.signals.screenLocked else { return }
                let now = ProcessInfo.processInfo.systemUptime
                self.lastLocalKeyAt = now
                self.localKeyTimes = self.localKeyTimes.filter { now - $0 < 1 }
                self.localKeyTimes.append(now)
                self.onKeys?(self.localKeyTimes.count >= 4)
                self.schedule(after: 0.2)
            }
            return event
        }
        schedule(after: 1)
    }

    private func schedule(after seconds: TimeInterval) {
        timer?.invalidate()
        let t = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = seconds * 0.25
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let settings = model.game.reactions
        let signals = power.signals
        let keys = CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
        let systemIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        let localIdle = lastLocalKeyAt.map { ProcessInfo.processInfo.systemUptime - $0 } ?? .infinity
        let idle = min(systemIdle, localIdle)

        // HEY_DEV_FAKE="battery=15,ac=0" / "thermal=3" / "idle=200" lets every mood be tried without a real emergency.
        let fake = Self.fake
        let sample = ActivitySample(
            time: Date(), keyCount: keys, idleSeconds: fake["idle"].flatMap { Double($0) } ?? idle,
            batteryPercent: fake["battery"].flatMap { Int($0) } ?? signals.batteryPercent,
            onAC: fake["ac"].map { $0 != "0" } ?? signals.onAC, charging: signals.isCharging,
            thermal: fake["thermal"].flatMap { Int($0) }.flatMap { ThermalLevel(rawValue: $0) } ?? signals.thermal,
            screenLocked: signals.screenLocked || signals.screenAsleep)
        let reactions = reactor.update(sample, settings: settings)

        if reactor.ambient != shownAmbient {
            shownAmbient = reactor.ambient
            onAmbient?(shownAmbient)
        }
        reactions.forEach { onReaction?($0) }

        // a hop for each burst of typing
        if settings.enabled, settings.typing, !sample.screenLocked, keys != lastKeyCount, sample.idleSeconds < 2 {
            onKeys?(reactor.keyRate >= reactor.fastTypingKeysPerSecond)
        }
        lastKeyCount = keys

        // Sample quickly only while someone is typing; otherwise a relaxed once-a-second (or slower when nothing is drawn).
        let typing = settings.typing && (reactor.keyRate >= reactor.slowTypingKeysPerSecond || localIdle < 2.5) && sample.idleSeconds < 2.5
        let interval: TimeInterval = !settings.enabled ? 5 : typing ? 0.2 : (power.decision.tier.rendersPet ? 1 : 3)
        schedule(after: interval)
    }
}
