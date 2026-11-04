// Generates the Hey! app icon (.icns), a preview PNG and the logo lockup from the shared drawing code.
// Run:  scripts/make-icon.sh
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let fm = FileManager.default

func write(_ rep: NSBitmapImageRep, to url: URL) {
    try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("PNG failed for \(url.lastPathComponent)") }
    try! data.write(to: url)
}

// 1) the iconset macOS wants, then .icns
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
try? fm.removeItem(at: iconset)
let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
// Use the illustrated Hei Hei icon, or the matching code-drawn rooster head.
let artwork = NSImage(contentsOf: root.appendingPathComponent("Resources/Logo/heihei_icon.png"))
print(artwork == nil ? "using the code-drawn icon" : "using Resources/Logo/heihei_icon.png")

func icon(pixels: Int) -> NSBitmapImageRep {
    guard let artwork else { return LogoArt.appIcon(pixels: pixels)! }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gc
    gc.imageInterpolation = .high
    artwork.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.current = nil
    return rep
}

for s in sizes { write(icon(pixels: s.px), to: iconset.appendingPathComponent("\(s.name).png")) }

let icns = root.appendingPathComponent("Resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try! p.run(); p.waitUntilExit()
precondition(p.terminationStatus == 0, "iconutil failed")
try? fm.removeItem(at: iconset)

// 2) a big preview, for the README and quick looks
write(icon(pixels: 1024), to: root.appendingPathComponent("docs/icon-1024.png"))

// 3) logo lockup: icon + wordmark on a transparent canvas
let height = 520, width = 1500
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let gc = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gc
let ctx = gc.cgContext
let tile: CGFloat = 460, margin: CGFloat = 30
if let artwork {
    // the finished icon art has its own transparent margin (the tile fills ~77%), so draw it a little larger
    let side = tile / 0.77
    gc.imageInterpolation = .high
    artwork.draw(in: NSRect(x: margin - (side - tile) / 2, y: margin - (side - tile) / 2, width: side, height: side),
                 from: .zero, operation: .sourceOver, fraction: 1)
} else {
    ctx.saveGState()
    let canvas = tile / 0.80          // the code-drawn tile fills 80% of its canvas
    ctx.translateBy(x: margin - canvas * 0.10, y: margin - canvas * 0.10)
    LogoArt.drawIcon(in: ctx, canvas: canvas)
    ctx.restoreGState()
}

let rounded = NSFont.systemFont(ofSize: 330, weight: .heavy)
let font = NSFont(descriptor: rounded.fontDescriptor.withDesign(.rounded) ?? rounded.fontDescriptor, size: 330) ?? rounded
let brown = NSColor(calibratedRed: 0.36, green: 0.20, blue: 0.08, alpha: 1)
let word = NSAttributedString(string: "Hey!", attributes: [.font: font, .foregroundColor: brown, .kern: -4])
let size = word.size()
word.draw(at: NSPoint(x: margin + tile + 50, y: (CGFloat(height) - size.height) / 2 + 6))
NSGraphicsContext.current = nil
write(rep, to: root.appendingPathComponent("docs/logo.png"))
print("wrote \(icns.path), docs/icon-1024.png, docs/logo.png")
