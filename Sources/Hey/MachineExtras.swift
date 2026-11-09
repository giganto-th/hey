import AppKit
import Foundation
import IOKit

/// How the battery is ageing, from the system's own battery record. Nil on a Mac without a battery.
struct BatteryHealth: Equatable {
    var healthPercent: Int?
    var cycles: Int?
    var temperature: Double?        // °C
    var isCharging: Bool
    var minutesRemaining: Int?

    static func read() -> BatteryHealth? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var raw: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &raw, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = raw?.takeRetainedValue() as? [String: Any] else { return nil }
        func int(_ key: String) -> Int? { (dict[key] as? NSNumber)?.intValue }
        let design = int("DesignCapacity")
        let max = int("AppleRawMaxCapacity") ?? int("NominalChargeCapacity")
        var health: Int?
        if let design, design > 0, let max, max > 100 { health = Int((Double(max) / Double(design) * 100).rounded()) }
        else if let m = int("MaxCapacity"), m <= 100 { health = m }
        let remaining = int("TimeRemaining").flatMap { $0 > 0 && $0 < 65_535 ? $0 : nil }
        return BatteryHealth(healthPercent: health, cycles: int("CycleCount"), temperature: int("Temperature").map { Double($0) / 100 },
                             isCharging: (dict["IsCharging"] as? NSNumber)?.boolValue ?? false, minutesRemaining: remaining)
    }
}

/// The agents that start by themselves when you log in (the ones apps and tools install under LaunchAgents).
struct LoginAgent: Identifiable, Equatable {
    let label: String
    let url: URL
    let isSystemWide: Bool
    var id: URL { url }

    static func scan() -> [LoginAgent] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folders: [(URL, Bool)] = [(home.appending(path: "Library/LaunchAgents"), false), (URL(fileURLWithPath: "/Library/LaunchAgents"), true)]
        var out: [LoginAgent] = []
        for (folder, system) in folders {
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.pathExtension == "plist" {
                guard let data = try? Data(contentsOf: file),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { continue }
                guard (plist["RunAtLoad"] as? Bool) == true, (plist["Disabled"] as? Bool) != true else { continue }
                out.append(LoginAgent(label: plist["Label"] as? String ?? file.deletingPathExtension().lastPathComponent, url: file, isSystemWide: system))
            }
        }
        return out.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") { NSWorkspace.shared.open(url) }
    }
}
