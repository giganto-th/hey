import ServiceManagement

/// "Open Hey! when I log in". Only works from a real .app bundle.
@MainActor
enum LoginItem {
    static var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error message to show, or nil on success.
    static func set(_ on: Bool) -> String? {
        guard isAvailable else { return "ใช้ได้เมื่อรันจาก Hey.app (scripts/make-app.sh)" }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            if on, SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
                return "ต้องอนุมัติใน การตั้งค่าระบบ › ทั่วไป › รายการเข้าสู่ระบบ"
            }
            return nil
        } catch {
            return "ตั้งค่าไม่สำเร็จ: \(error.localizedDescription)"
        }
    }
}
