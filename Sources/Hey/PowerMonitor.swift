import AppKit
import IOKit.ps
import Observation
import HeyDomain

/// Reads the Mac's power state and turns it into a `PowerTier` using the pure `PowerPolicy`.
@MainActor
@Observable
final class PowerMonitor {
    private(set) var decision = PowerDecision(tier: .full, reason: "", hidePet: false)
    private(set) var signals = PowerSignals()

    @ObservationIgnored var onChange: ((PowerDecision) -> Void)?
    @ObservationIgnored var onWake: (() -> Void)?
    @ObservationIgnored private var powerSource: CFRunLoopSource?
    @ObservationIgnored private let model: GameModel
    @ObservationIgnored private var asleep = false
    @ObservationIgnored private var locked = false
    @ObservationIgnored private var userHidPet = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    /// Dev override (`HEY_DEV_TIER=saver`) so each tier can be measured on any machine.
    @ObservationIgnored private let forcedTier: PowerTier? = {
        switch ProcessInfo.processInfo.environment["HEY_DEV_TIER"] {
        case "full": .full
        case "balanced": .balanced
        case "saver": .saver
        case "dormant": .dormant
        default: nil
        }
    }()

    init(model: GameModel) {
        self.model = model
        let ws = NSWorkspace.shared.notificationCenter
        let dc = DistributedNotificationCenter.default()
        func watch(_ center: NotificationCenter, _ name: Notification.Name, _ update: @escaping @MainActor (PowerMonitor) -> Void) {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { if let self { update(self); self.evaluate() } }
            })
        }
        watch(ws, NSWorkspace.screensDidSleepNotification) { $0.asleep = true }
        watch(ws, NSWorkspace.screensDidWakeNotification) { $0.asleep = false }
        watch(ws, NSWorkspace.willSleepNotification) { $0.asleep = true }
        watch(ws, NSWorkspace.didWakeNotification) { $0.asleep = false; $0.onWake?() }
        watch(ws, NSWorkspace.activeSpaceDidChangeNotification) { _ in }
        watch(ws, NSWorkspace.didActivateApplicationNotification) { _ in }
        watch(dc, Notification.Name("com.apple.screenIsLocked")) { $0.locked = true }
        watch(dc, Notification.Name("com.apple.screenIsUnlocked")) { $0.locked = false }
        watch(.default, .NSProcessInfoPowerStateDidChange) { _ in }
        watch(.default, ProcessInfo.thermalStateDidChangeNotification) { _ in }
        // Plugging in or out should be noticed at once, not at the next 10-second tick.
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.evaluate() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }
        evaluate()
    }

    func setUserHidPet(_ hidden: Bool) {
        userHidPet = hidden
        evaluate()
    }

    /// Cheap enough to call from the 10-second clock as well as from system notifications.
    func evaluate() {
        var s = PowerSignals()
        let battery = Self.batteryState()
        s.onAC = battery.onAC
        s.isCharging = battery.charging
        s.batteryPercent = battery.percent
        s.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        s.thermal = switch ProcessInfo.processInfo.thermalState {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .nominal
        }
        s.screenAsleep = asleep
        s.screenLocked = locked
        s.userHidPet = userHidPet
        s.userIdleSeconds = Self.idleSeconds()
        if model.game.power.hideDuringFullscreen { s.fullscreenAppActive = Self.fullscreenAppIsActive() }

        var next = PowerPolicy.decide(s, settings: model.game.power)
        if let forcedTier { next.tier = forcedTier; next.reason = tr("บังคับด้วย HEY_DEV_TIER") }
        signals = s
        guard next != decision else { return }
        decision = next
        onChange?(next)
    }

    // MARK: system readings

    private static func batteryState() -> (onAC: Bool, percent: Int?, charging: Bool) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return (true, nil, false) }
        for source in list {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let current = d[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = d[kIOPSMaxCapacityKey] as? Int ?? 100
            let onAC = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let charging = d[kIOPSIsChargingKey] as? Bool ?? false
            return (onAC, max > 0 ? current * 100 / max : nil, charging)
        }
        return (true, nil, false)   // no battery: a desktop Mac
    }

    private static func idleSeconds() -> Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    /// A window from another app that covers a whole screen, menu bar included.
    private static func fullscreenAppIsActive() -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        guard let front = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              front != ProcessInfo.processInfo.processIdentifier else { return false }
        let screens = NSScreen.screens.map(\.frame.size)
        for w in windows {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? Int32) == front,
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.5,
                  let dict = w[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dict) else { continue }
            if screens.contains(where: { abs($0.width - rect.width) < 1 && abs($0.height - rect.height) < 1 }) { return true }
        }
        return false
    }
}
