import Foundation

/// Where one "paper" lands when the open windows are laid out as overlapping sheets.
public struct SpreadSlot: Equatable, Sendable {
    /// Top-left corner, relative to the block's top-left.
    public var x: Double
    public var y: Double
    /// A slight tilt so the stack reads as loose paper.
    public var angle: Double
}

/// Lays out `count` sheets so each overlaps the next but still shows its left strip (the app's icon and name).
/// Sheets are given back to front: the last one is drawn on top. When a single row would be too wide the sheets wrap into rows.
public enum SpreadLayout {
    public static let tilts: [Double] = [-1.6, 0.9, -0.6, 1.5, -1.0, 0.5]

    public struct Result: Equatable, Sendable {
        public var slots: [SpreadSlot]
        public var width: Double
        public var height: Double
    }

    public static func slots(count: Int, width: Double, cardWidth: Double, cardHeight: Double,
                             overlap: Double = 0.36, rowOverlap: Double = 0.2) -> Result {
        guard count > 0, width > 0 else { return Result(slots: [], width: 0, height: 0) }
        let step = cardWidth * (1 - overlap)
        let fitsInRow = max(1, Int(((width - cardWidth) / step).rounded(.down)) + 1)
        let rows = Int((Double(count) / Double(fitsInRow)).rounded(.up))
        let perRow = Int((Double(count) / Double(rows)).rounded(.up))          // balanced rows rather than one full and one stub
        let rowStep = cardHeight * (1 - rowOverlap)

        var out: [SpreadSlot] = []
        out.reserveCapacity(count)
        var widest = cardWidth
        for r in 0..<rows {
            let inThisRow = min(perRow, count - r * perRow)
            let rowWidth = Double(inThisRow - 1) * step + cardWidth
            widest = max(widest, rowWidth)
            let x0 = (width - rowWidth) / 2
            for c in 0..<inThisRow {
                let i = r * perRow + c
                out.append(SpreadSlot(x: x0 + Double(c) * step, y: Double(r) * rowStep, angle: tilts[i % tilts.count]))
            }
        }
        return Result(slots: out, width: widest, height: Double(rows - 1) * rowStep + cardHeight)
    }
}
