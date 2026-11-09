import Foundation
@preconcurrency import UserNotifications

/// A macOS notification, for things that matter when Hey! is not in front (the pet is in danger, an update is out).
/// Asks permission the first time; does nothing when the app is not run from a bundle (a dev build), where the API is unavailable.
enum SystemNotice {
    static func post(_ text: String) {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Hey!"
            content.body = text
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}
