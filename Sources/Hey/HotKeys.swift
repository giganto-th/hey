import AppKit
import Carbon.HIToolbox

nonisolated(unsafe) private var hotKeyActions: [UInt32: @MainActor () -> Void] = [:]

private func hotKeyHandler(_: EventHandlerCallRef?, _ event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    var id = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                      nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    MainActor.assumeIsolated { hotKeyActions[id.id]?() }
    return noErr
}

/// System-wide shortcuts (Carbon). They need no Accessibility permission.
@MainActor
enum HotKeys {
    private static var installed = false
    private static var refs: [EventHotKeyRef] = []
    private static var nextID: UInt32 = 1

    /// Registers ⌃⌥ + key. Returns false if another app already owns the combination.
    @discardableResult
    static func register(keyCode: Int, action: @escaping @MainActor () -> Void) -> Bool {
        if !installed {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &spec, nil, nil)
            installed = true
        }
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(controlKey | optionKey),
                                         EventHotKeyID(signature: OSType(0x48455921), id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs.append(ref)
        hotKeyActions[id] = action
        return true
    }
}
