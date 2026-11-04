// Lists the windows of one app: "<id> <layer> <width> <height>". Used by scripts/smoke.sh to find a window to capture.
import CoreGraphics
import Foundation

let owner = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Hey!"
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list where (w[kCGWindowOwnerName as String] as? String) == owner {
    let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    print(w[kCGWindowNumber as String] ?? 0, w[kCGWindowLayer as String] ?? 0, b["Width"] ?? 0, b["Height"] ?? 0)
}
