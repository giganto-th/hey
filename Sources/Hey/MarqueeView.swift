import AppKit

/// The song title for the menu bar: a small icon and a text strip that keeps scrolling sideways while the song plays.
/// The scrolling is a Core Animation transform, so it runs on the compositor and costs the app almost nothing.
final class MarqueeView: NSView {
    static let iconWidth: CGFloat = 20
    private static let gap: CGFloat = 36
    private static let speed: CGFloat = 34          // points per second

    private let icon = NSImageView()
    private let clip = NSView()
    private let strip = NSView()
    private let first = NSTextField(labelWithString: "")
    private let second = NSTextField(labelWithString: "")
    private var text = ""
    private var playing = false
    private var scrolling = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        for label in [first, second] {
            label.font = .menuBarFont(ofSize: 0)
            label.lineBreakMode = .byClipping
            label.isBordered = false
            label.drawsBackground = false
            strip.addSubview(label)
        }
        clip.wantsLayer = true
        clip.layer?.masksToBounds = true
        strip.wantsLayer = true
        clip.addSubview(strip)
        icon.imageScaling = .scaleProportionallyDown
        icon.contentTintColor = .labelColor
        addSubview(icon)
        addSubview(clip)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Clicks go to the status item's button underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func set(text: String, playing: Bool, scrolling: Bool) {
        guard text != self.text || playing != self.playing || scrolling != self.scrolling else { return }
        self.text = text
        self.playing = playing
        self.scrolling = scrolling
        icon.image = NSImage(systemSymbolName: playing ? "music.note" : "pause.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        first.stringValue = text
        second.stringValue = text
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let h = bounds.height
        icon.frame = NSRect(x: 2, y: (h - 16) / 2, width: 16, height: 16)
        clip.frame = NSRect(x: Self.iconWidth, y: 0, width: max(bounds.width - Self.iconWidth, 0), height: h)

        first.sizeToFit()
        let textWidth = ceil(first.frame.width)
        let labelHeight = first.frame.height
        let y = (h - labelHeight) / 2
        // Always runs while a song plays; a title that fits just gets a longer pause before it comes round again.
        let loops = scrolling
        let gap = max(Self.gap, clip.bounds.width - textWidth + Self.gap)

        first.frame = NSRect(x: 0, y: y, width: textWidth, height: labelHeight)
        second.frame = NSRect(x: textWidth + gap, y: y, width: textWidth, height: labelHeight)
        second.isHidden = !loops
        strip.frame = NSRect(x: 0, y: 0, width: loops ? textWidth * 2 + gap : textWidth, height: h)

        strip.layer?.removeAnimation(forKey: "marquee")
        if loops {
            let distance = textWidth + gap
            let anim = CABasicAnimation(keyPath: "transform.translation.x")
            anim.fromValue = 0
            anim.toValue = -distance
            anim.duration = Double(distance / Self.speed)
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .linear)
            strip.layer?.add(anim, forKey: "marquee")
            clip.layer?.mask = Self.edgeFade(for: clip.bounds)
        } else {
            clip.layer?.mask = nil
        }
    }

    /// Soft edges so the text slides in and out instead of being cut off.
    private static func edgeFade(for rect: NSRect) -> CALayer {
        let fade = CAGradientLayer()
        fade.frame = rect
        fade.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
        fade.locations = [0, 0.08, 0.92, 1]
        fade.startPoint = CGPoint(x: 0, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 0.5)
        return fade
    }

    var isScrolling: Bool { strip.layer?.animation(forKey: "marquee") != nil }

    func snapshot() -> Data? {
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        cacheDisplay(in: bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }
}
