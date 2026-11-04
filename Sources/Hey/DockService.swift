import AppKit
import HeyDomain

/// Which apps are running, their icons, and launching. Reads names and bundle ids only.
@MainActor @Observable
final class DockService {
    private(set) var runningApps: [DockApp] = []
    private(set) var running: Set<String> = []
    @ObservationIgnored private var icons: [String: NSImage] = [:]
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
    }

    func refresh() {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
        running = Set(apps.compactMap(\.bundleIdentifier))
        runningApps = apps.compactMap { app in
            guard let id = app.bundleIdentifier, let url = app.bundleURL else { return nil }
            return DockApp(bundleID: id, name: app.localizedName ?? id, path: url.path)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func isRunning(_ app: DockApp) -> Bool { running.contains(app.bundleID) }

    func icon(_ app: DockApp) -> NSImage {
        if let cached = icons[app.path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: app.path)
        image.size = NSSize(width: 128, height: 128)
        icons[app.path] = image
        return image
    }

    /// Brings a running app forward, or launches it.
    func open(_ app: DockApp) {
        if let live = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).first {
            live.activate()
        } else {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: app.path), configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func info(forBundleID id: String) -> DockApp? { runningApps.first { $0.bundleID == id } }

    static func app(at url: URL) -> DockApp? {
        guard url.pathExtension == "app", let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return DockApp(bundleID: id, name: name, path: url.path)
    }
}
