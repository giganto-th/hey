import Foundation
import IOKit

/// Reads temperatures from the Mac's own sensors. macOS has no public call for this on Apple silicon, so it asks the HID event system
/// for the temperature sensors, the same way other system monitors do. It needs no permission. If a Mac does not answer (some Intel
/// Macs), `read()` returns nil and the page falls back to the system's coarse thermal level.
final class ThermalSensors {
    struct Reading: Equatable {
        var cpu: Double?        // °C, the hottest CPU die sensor
        var ssd: Double?
        var battery: Double?
    }

    @_silgen_name("IOHIDEventSystemClientCreate")
    private static func clientCreate(_ allocator: CFAllocator?) -> Unmanaged<AnyObject>?
    @_silgen_name("IOHIDEventSystemClientSetMatching")
    private static func clientSetMatching(_ client: AnyObject, _ matching: CFDictionary)
    @_silgen_name("IOHIDEventSystemClientCopyServices")
    private static func clientCopyServices(_ client: AnyObject) -> Unmanaged<CFArray>?
    @_silgen_name("IOHIDServiceClientCopyEvent")
    private static func serviceCopyEvent(_ service: AnyObject, _ type: Int64, _ options: Int32, _ timestamp: Int64) -> Unmanaged<AnyObject>?
    @_silgen_name("IOHIDServiceClientCopyProperty")
    private static func serviceCopyProperty(_ service: AnyObject, _ key: CFString) -> Unmanaged<AnyObject>?
    @_silgen_name("IOHIDEventGetFloatValue")
    private static func eventFloatValue(_ event: AnyObject, _ field: Int32) -> Double

    private static let temperatureEvent: Int64 = 15
    private let client: AnyObject?
    private var services: [(name: String, service: AnyObject)] = []

    init() {
        client = Self.clientCreate(kCFAllocatorDefault)?.takeRetainedValue()
        guard let client else { return }
        // usage page 0xff00 / usage 5 = Apple's temperature sensors
        Self.clientSetMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        let list = (Self.clientCopyServices(client)?.takeRetainedValue() as [AnyObject]?) ?? []
        services = list.map { service in
            ((Self.serviceCopyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String) ?? "", service)
        }
    }

    var isAvailable: Bool { !services.isEmpty }

    func read() -> Reading? {
        guard !services.isEmpty else { return nil }
        var reading = Reading()
        for (name, service) in services {
            guard let event = Self.serviceCopyEvent(service, Self.temperatureEvent, 0, 0)?.takeRetainedValue() else { continue }
            let value = Self.eventFloatValue(event, Int32(Self.temperatureEvent << 16))
            guard value > 0, value < 130 else { continue }          // some sensors report junk (a large negative number) when idle
            let lower = name.lowercased()
            if lower.contains("tdie") || lower.contains("cpu") {
                reading.cpu = max(reading.cpu ?? 0, value)
            } else if lower.contains("nand") {
                reading.ssd = max(reading.ssd ?? 0, value)
            } else if lower.contains("battery") {
                reading.battery = max(reading.battery ?? 0, value)
            }
        }
        return reading.cpu == nil && reading.ssd == nil && reading.battery == nil ? nil : reading
    }
}
