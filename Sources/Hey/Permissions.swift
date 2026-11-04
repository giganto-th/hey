import AppKit
import AVFoundation
import CoreGraphics

/// One place that knows how to ask for, and explain, the permissions capture needs.
@MainActor
enum Permissions {
    /// True when Screen Recording is allowed. Otherwise triggers the system prompt once and explains how to fix it.
    static func ensureScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        // The first time, macOS shows its own prompt; a second dialog on top would only confuse.
        let key = "askedScreenRecording"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            _ = CGRequestScreenCaptureAccess()
            return false
        }
        explain(
            title: "ต้องอนุญาตการบันทึกหน้าจอ",
            text: "เปิด การตั้งค่าระบบ › ความเป็นส่วนตัวและความปลอดภัย › การบันทึกหน้าจอ แล้วเปิดสวิตช์ให้ Hey! จากนั้นปิดและเปิดแอปใหม่หนึ่งครั้ง",
            pane: "Privacy_ScreenCapture")
        return false
    }

    static func ensureCamera() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) { return true }
        default: break
        }
        explain(title: "ต้องอนุญาตการใช้กล้อง",
                text: "เปิด การตั้งค่าระบบ › ความเป็นส่วนตัวและความปลอดภัย › กล้อง แล้วเปิดสวิตช์ให้ Hey!",
                pane: "Privacy_Camera")
        return false
    }

    /// Microphone is optional: returns false quietly if refused so the recording just goes without sound.
    static func microphoneAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    private static func explain(title: String, text: String, pane: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "เปิดการตั้งค่า")
        alert.addButton(withTitle: "ไว้ทีหลัง")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
