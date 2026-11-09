import Foundation

/// A drawn clip can only show as many frames per second as the screen is redrawn. Asking for more makes the player skip
/// frames unevenly (strobing, "jerky" wings); slowing the loop to what the redraw rate can carry keeps every frame in order.
public enum ClipRate {
    /// Every clip in the art sets has this many frames.
    public static let framesPerClip = 10

    /// The loop speed (cycles per second) to use at a given redraw rate.
    public static func limited(_ cyclesPerSecond: Double, frames: Int = framesPerClip, fps: Int) -> Double {
        guard fps > 0, frames > 0 else { return cyclesPerSecond }
        return min(cyclesPerSecond, Double(fps) / Double(frames))
    }
}
