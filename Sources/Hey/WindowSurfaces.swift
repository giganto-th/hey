import AppKit
import HeyDomain

/// The tops of other apps' windows, in the same coordinates as the pet window.
@MainActor
enum WindowSurfaces {
    static func current() -> [Surface] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        let screens = NSScreen.screens
        guard let primaryHeight = screens.first?.frame.height else { return [] }
        let screenSizes = screens.map(\.frame.size)
        let highest = screens.map(\.visibleFrame.maxY).max() ?? primaryHeight

        var out: [Surface] = []
        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? Int32) != me,
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.5,
                  let number = w[kCGWindowNumber as String] as? Int,
                  let dict = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: dict),
                  r.width >= 220, r.height >= 100 else { continue }
            if screenSizes.contains(where: { abs($0.width - r.width) < 1 && abs($0.height - r.height) < 1 }) { continue }   // fullscreen
            let top = primaryHeight - r.minY          // CG puts the origin top-left, AppKit bottom-left
            guard top <= highest, top > 60 else { continue }
            out.append(Surface(id: number, minX: r.minX, maxX: r.maxX, top: top))
        }
        return out
    }
}
