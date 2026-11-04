import AppKit

/// Hei Hei's head, drawn in code so the menu-bar glyph stays crisp
/// at any size, and so there is always an icon even without the illustrated art in `Resources/Logo`.
enum LogoArt {
    private static let body = NSColor(calibratedRed: 0.91, green: 0.65, blue: 0.24, alpha: 1)
    private static let belly = NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.84, alpha: 1)
    private static let coral = NSColor(calibratedRed: 0.9, green: 0.25, blue: 0.13, alpha: 1)
    private static let navy = NSColor(calibratedRed: 0.32, green: 0.20, blue: 0.13, alpha: 1)

    // Unit square, origin bottom-left.
    private struct Geometry {
        let s: CGFloat, o: CGPoint
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
        func oval(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
            CGPath(ellipseIn: CGRect(x: o.x + (x - rx) * s, y: o.y + (y - ry) * s, width: 2 * rx * s, height: 2 * ry * s), transform: nil)
        }
        var bodyShape: CGPath { oval(0.47, 0.43, 0.28, 0.29) }
        var bellyShape: CGPath { oval(0.5, 0.31, 0.21, 0.17) }
        var leftEye: CGPath { oval(0.36, 0.50, 0.16, 0.18) }
        var rightEye: CGPath { oval(0.65, 0.56, 0.15, 0.17) }
        var leftCheek: CGPath { oval(0.29, 0.43, 0.048, 0.034) }
        var rightCheek: CGPath { oval(0.71, 0.43, 0.048, 0.034) }
        var beak: CGPath {
            let b = CGMutablePath()
            b.move(to: p(0.52, 0.35))
            b.addQuadCurve(to: p(0.92, 0.31), control: p(0.77, 0.55))
            b.addQuadCurve(to: p(0.52, 0.35), control: p(0.72, 0.26))
            b.closeSubpath()
            return b
        }
        /// Three irregular lobes of the rooster's comb.
        var curl: CGPath {
            let c = CGMutablePath()
            c.move(to: p(0.27, 0.63))
            c.addCurve(to: p(0.20, 0.94), control1: p(0.01, 0.81), control2: p(0.03, 1.01))
            c.addQuadCurve(to: p(0.43, 0.78), control: p(0.37, 0.94))
            c.addCurve(to: p(0.62, 0.98), control1: p(0.35, 1.12), control2: p(0.77, 1.12))
            c.addQuadCurve(to: p(0.64, 0.78), control: p(0.64, 0.85))
            c.addQuadCurve(to: p(0.85, 0.93), control: p(0.88, 1.11))
            c.addQuadCurve(to: p(0.70, 0.62), control: p(0.99, 0.72))
            c.closeSubpath()
            return c
        }
    }

    private static func fill(_ path: CGPath, _ color: NSColor, in ctx: CGContext) {
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
    }

    private static func stroke(_ path: CGPath, _ color: NSColor, width: CGFloat, in ctx: CGContext) {
        ctx.addPath(path)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }

    static func drawMascot(in ctx: CGContext, side: CGFloat, origin: CGPoint) {
        let g = Geometry(s: side, o: origin)
        fill(g.curl, coral, in: ctx)
        stroke(g.curl, navy, width: side * 0.016, in: ctx)
        fill(g.bodyShape, body, in: ctx)
        stroke(g.bodyShape, navy, width: side * 0.016, in: ctx)
        fill(g.oval(0.48, 0.17, 0.09, 0.14), coral, in: ctx)
        fill(g.oval(0.63, 0.15, 0.07, 0.12), coral, in: ctx)
        for eye in [g.leftEye, g.rightEye] {
            fill(eye, .white, in: ctx); stroke(eye, navy, width: side * 0.018, in: ctx)
        }
        fill(g.oval(0.42, 0.46, 0.035, 0.04), navy, in: ctx)
        fill(g.oval(0.61, 0.59, 0.035, 0.04), navy, in: ctx)
        fill(g.beak, body, in: ctx)
        stroke(g.beak, navy, width: side * 0.016, in: ctx)
    }

    // MARK: app icon

    /// A rounded square (the art fills 80% of the canvas, Apple's template) in a warm butter yellow.
    static func drawIcon(in ctx: CGContext, canvas: CGFloat) {
        let inset = canvas * 0.10
        let rect = CGRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
        let tile = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -canvas * 0.012), blur: canvas * 0.03,
                      color: NSColor.black.withAlphaComponent(0.28).cgColor)
        fill(tile, NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.40, alpha: 1), in: ctx)
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(tile)
        ctx.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.58, alpha: 1).cgColor,
            NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.36, alpha: 1).cgColor,
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), options: [])
        let side = rect.width * 0.92
        drawMascot(in: ctx, side: side, origin: CGPoint(x: rect.midX - side / 2, y: rect.midY - side * 0.52))
        ctx.restoreGState()
    }

    static func appIcon(pixels: Int) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let gc = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = gc
        drawIcon(in: gc.cgContext, canvas: CGFloat(pixels))
        NSGraphicsContext.current = previous
        return rep
    }

    /// For `NSApp.applicationIconImage` (alerts, dialogs). Uses the illustrated icon when it can be found.
    static func applicationImage() -> NSImage {
        let fm = FileManager.default
        let candidates: [String] = [
            Bundle.main.resourcePath.map { $0 + "/Logo/heihei_icon.png" },
            fm.currentDirectoryPath + "/Resources/Logo/heihei_icon.png",
        ].compactMap { $0 }
        if let path = candidates.first(where: { fm.fileExists(atPath: $0) }), let image = NSImage(contentsOfFile: path) {
            return image
        }
        return NSImage(size: NSSize(width: 512, height: 512), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            drawIcon(in: ctx, canvas: rect.width)
            return true
        }
    }

    // MARK: menu bar

    /// A template rooster head with a comb, beak and two readable eye cutouts.
    static func menuBarImage(height: CGFloat = 18) -> NSImage {
        let fm = FileManager.default
        let marks = [Bundle.main.resourcePath.map { $0 + "/Logo/heihei_mark.png" }, fm.currentDirectoryPath + "/Resources/Logo/heihei_mark.png"].compactMap { $0 }
        if let path = marks.first(where: { fm.fileExists(atPath: $0) }), let art = NSImage(contentsOfFile: path) {
            art.size = NSSize(width: height, height: height)
            art.isTemplate = true
            return art
        }
        let image = NSImage(size: NSSize(width: height, height: height), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let side = rect.height * 0.92
            let g = Geometry(s: side, o: CGPoint(x: rect.midX - side / 2, y: rect.minY))
            fill(g.curl, .black, in: ctx)
            fill(g.bodyShape, .black, in: ctx)
            fill(g.beak, .black, in: ctx)
            ctx.setBlendMode(.clear)
            for eye in [g.oval(0.36, 0.50, 0.11, 0.13), g.oval(0.65, 0.56, 0.10, 0.12)] { ctx.addPath(eye); ctx.fillPath() }
            ctx.setBlendMode(.normal)
            return true
        }
        image.isTemplate = true
        return image
    }
}
