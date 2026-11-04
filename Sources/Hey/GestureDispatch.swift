import AppKit
import Observation
import HeyDomain

/// Remembers the last recognised gesture so the settings tab can show it (handy to check a trackpad).
@MainActor
@Observable
final class GestureLog {
    private(set) var last = tr("ยังไม่มี")
    private(set) var at: Date?
    func record(_ text: String) { last = text; at = Date() }
}
