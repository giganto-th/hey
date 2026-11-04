import CoreGraphics
import Foundation

/// Where the buttons of the pet's fan menu go. Pure geometry, so it can be tested against every screen position.
///
/// The buttons sit in a tight arc right around the pet (neighbouring buttons almost touch). The arc turns toward
/// whichever side has room: up when the pet stands at the bottom of the screen, sideways when it is at an edge,
/// down when it is at the top. If the free space is too narrow for all the buttons in one arc (a pet in a screen
/// corner), the rest go on a second arc just outside the first. Coordinates are screen coordinates (origin
/// bottom-left, like `NSScreen`).
public struct RadialLayout: Equatable, Sendable {
    public struct Arc: Equatable, Sendable {
        public var radius: Double
        /// Angle between neighbouring buttons, in radians.
        public var step: Double
        /// Direction of the middle of this arc, radians from the +x axis (π/2 = straight up).
        public var centerAngle: Double
        /// How many buttons fit on this arc.
        public var capacity: Int

        public init(radius: Double, step: Double, centerAngle: Double, capacity: Int) {
            self.radius = radius; self.step = step; self.centerAngle = centerAngle; self.capacity = capacity
        }
    }

    public var petCenter: CGPoint
    public var arcs: [Arc]
    public var buttonSize: Double
    public var header: CGRect
    /// The smallest rectangle holding every button and the header (the menu window).
    public var bounds: CGRect

    public init(petCenter: CGPoint, arcs: [Arc], buttonSize: Double, header: CGRect, bounds: CGRect) {
        self.petCenter = petCenter; self.arcs = arcs; self.buttonSize = buttonSize; self.header = header; self.bounds = bounds
    }

    /// The direction the menu mainly opens toward.
    public var centerAngle: Double { arcs.first?.centerAngle ?? .pi / 2 }
    public var radius: Double { arcs.first?.radius ?? 0 }

    /// Centres of `count` buttons in menu order: the first arc fills first (left to right), then the next.
    public func centers(count: Int) -> [CGPoint] {
        var result: [CGPoint] = []
        var remaining = count
        for (index, arc) in arcs.enumerated() where remaining > 0 {
            let isLast = index == arcs.count - 1
            let k = isLast ? remaining : min(remaining, max(arc.capacity, 1))
            for i in 0..<k {
                let angle = arc.centerAngle + (Double(k - 1) / 2 - Double(i)) * arc.step
                result.append(CGPoint(x: petCenter.x + cos(angle) * arc.radius, y: petCenter.y + sin(angle) * arc.radius))
            }
            remaining -= k
        }
        return result
    }
}

public enum RadialLayoutPlanner {
    public struct Input: Sendable {
        public var petCenter: CGPoint
        public var petRadius: Double
        public var screen: CGRect
        /// The largest number of buttons any page will show; the menu is sized for it.
        public var maxItems: Int
        public var buttonSize: Double = 54
        public var gap: Double = 6
        public var headerSize = CGSize(width: 280, height: 84)
        public var margin: Double = 8

        public init(petCenter: CGPoint, petRadius: Double, screen: CGRect, maxItems: Int) {
            self.petCenter = petCenter; self.petRadius = petRadius; self.screen = screen; self.maxItems = maxItems
        }
    }

    /// One arc never wraps more than this far around the pet.
    private static let maxSpanDegrees = 230.0

    public static func plan(_ input: Input) -> RadialLayout {
        let b = input.buttonSize
        let n = max(input.maxItems, 1)
        let base = input.petRadius + b / 2 + 10

        var arcs: [RadialLayout.Arc] = []

        // 1. one arc, as tight as the free space allows
        var radius = base
        while radius <= base + 64 {
            let arc = makeArc(input, radius: radius)
            if arc.capacity >= n { arcs = [arc]; break }
            radius += 4
        }

        // 2. otherwise several arcs, the first hugging the pet
        if arcs.isEmpty {
            var remaining = n
            radius = base
            while remaining > 0, arcs.count < 4, radius < base + 400 {
                let arc = makeArc(input, radius: radius)
                if arc.capacity > 0 { arcs.append(arc); remaining -= arc.capacity }
                radius += b + input.gap * 0.5
            }
        }
        // 3. a screen too small for anything: one arc, squeezed
        if arcs.isEmpty { arcs = [RadialLayout.Arc(radius: base, step: step(b + input.gap, base), centerAngle: .pi / 2, capacity: n)] }

        var layout = RadialLayout(petCenter: input.petCenter, arcs: arcs, buttonSize: b, header: .zero, bounds: .zero)
        place(&layout, input: input, count: n)
        return layout
    }

    // MARK: arcs

    private static func step(_ spacing: Double, _ radius: Double) -> Double { 2 * asin(min(spacing / (2 * radius), 1)) }

    /// The widest stretch of the circle around the pet (at this radius) where a button stays on the screen.
    private static func makeArc(_ input: Input, radius: Double) -> RadialLayout.Arc {
        let b = input.buttonSize, half = b / 2
        let safe = input.screen.insetBy(dx: input.margin, dy: input.margin)
        let st = step(b + input.gap, radius)
        let stDeg = st * 180 / .pi

        func ok(_ deg: Int) -> Bool {
            let a = Double(deg) * .pi / 180
            let c = CGPoint(x: input.petCenter.x + cos(a) * radius, y: input.petCenter.y + sin(a) * radius)
            return safe.contains(CGRect(x: c.x - half, y: c.y - half, width: b, height: b))
        }
        let feasible = (0..<360).map(ok)

        // runs of feasible degrees on the doubled circle, so a run may cross 0°
        var best: (start: Double, end: Double)?
        var bestScore = (-1.0, -1.0)
        var d = 0
        while d < 360 {
            guard feasible[d % 360], !(d > 0 && feasible[(d - 1) % 360]) else { d += 1; continue }   // only start at the beginning of a run
            var e = d
            while e < d + 360, feasible[(e + 1) % 360] { e += 1 }
            let length = Double(e - d)
            let used = min(length, maxSpanDegrees)
            // aim for "up", but stay inside the run
            let wanted = 90.0 + 360 * ((Double(d) + length / 2 - 90) / 360).rounded()
            let center = min(max(wanted, Double(d) + used / 2), Double(e) - used / 2)
            let score = (used, -abs(center - 90))
            if score > bestScore { bestScore = score; best = (center - used / 2, center + used / 2) }
            d = e + 1
        }
        guard let run = best else { return .init(radius: radius, step: st, centerAngle: .pi / 2, capacity: 0) }
        let length = run.end - run.start
        let capacity = Int((length / stDeg).rounded(.down)) + 1
        let centre = (run.start + run.end) / 2 * .pi / 180
        return .init(radius: radius, step: st, centerAngle: atan2(sin(centre), cos(centre)), capacity: capacity)   // keep it in (-π, π]
    }

    // MARK: header and window

    private static func place(_ layout: inout RadialLayout, input: Input, count: Int) {
        let half = input.buttonSize / 2
        var area = CGRect(x: input.petCenter.x - input.petRadius, y: input.petCenter.y - input.petRadius,
                          width: 2 * input.petRadius, height: 2 * input.petRadius)
        for c in layout.centers(count: count) {
            area = area.union(CGRect(x: c.x - half, y: c.y - half, width: input.buttonSize, height: input.buttonSize))
        }
        let h = input.headerSize
        let safe = input.screen.insetBy(dx: input.margin, dy: input.margin)
        func rect(y: Double) -> CGRect {
            let x = min(max(input.petCenter.x - h.width / 2, safe.minX), max(safe.maxX - h.width, safe.minX))
            return CGRect(x: x, y: y, width: h.width, height: h.height)
        }
        let above = rect(y: area.maxY + 10)
        let below = rect(y: area.minY - 10 - h.height)
        var chosen = safe.contains(above) ? above : (safe.contains(below) ? below : above)
        if !safe.contains(chosen) {                                           // no room above or below: keep it on screen
            chosen = CGRect(x: min(max(chosen.minX, safe.minX), max(safe.maxX - h.width, safe.minX)),
                            y: min(max(chosen.minY, safe.minY), max(safe.maxY - h.height, safe.minY)),
                            width: h.width, height: h.height)
        }
        layout.header = chosen
        layout.bounds = area.union(chosen).insetBy(dx: -4, dy: -4)
    }
}
