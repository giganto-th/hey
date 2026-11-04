import Foundation

/// Detects "petting": slow side-to-side hovering over the pet.
public struct StrokeDetector: Sendable {
    public var minStep = 3.0
    public var maxSpeed = 1500.0
    public var window = 1.2
    public var reversalsNeeded = 3

    private var lastX: Double?
    private var lastT = 0.0
    private var lastDir = 0
    private var reversals: [Double] = []

    public init() {}

    public mutating func reset() {
        lastX = nil
        lastDir = 0
        reversals.removeAll()
    }

    /// Feed pointer x positions; returns true when a stroke is recognised.
    public mutating func move(x: Double, at t: Double) -> Bool {
        defer { lastX = x; lastT = t }
        guard let prev = lastX else { return false }
        let dx = x - prev
        guard abs(dx) >= minStep else { return false }
        let dt = max(t - lastT, 0.001)
        if abs(dx) / dt > maxSpeed { reset(); return false }

        let dir = dx > 0 ? 1 : -1
        if lastDir != 0, dir != lastDir { reversals.append(t) }
        lastDir = dir
        reversals.removeAll { t - $0 > window }

        if reversals.count >= reversalsNeeded {
            reset()
            return true
        }
        return false
    }
}
