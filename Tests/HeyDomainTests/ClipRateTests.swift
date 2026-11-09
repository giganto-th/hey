import Testing
@testable import HeyDomain

@Suite("ClipRate")
struct ClipRateTests {
    @Test func slowLoopsAreLeftAlone() {
        #expect(ClipRate.limited(0.4, fps: 6) == 0.4)
        #expect(ClipRate.limited(2, fps: 24) == 2)
    }

    @Test func fastLoopsAreSlowedToTheRedrawRate() {
        #expect(ClipRate.limited(4.5, fps: 24) == 2.4)         // flying on the full tier
        #expect(ClipRate.limited(3.5, fps: 12) == 1.2)         // wing flapping on the saver tier
        #expect(ClipRate.limited(1, fps: 6) == 0.6)            // a loop run at the "still" rate
    }

    @Test func everyFrameGetsAtLeastOneRedraw() {
        for fps in [3, 5, 6, 12, 18, 24] {
            for rate in [0.3, 1, 2, 3.5, 4.5] {
                #expect(ClipRate.limited(rate, fps: fps) * Double(ClipRate.framesPerClip) <= Double(fps) + 1e-9)
            }
        }
    }

    @Test func noRedrawRateMeansNoChange() {
        #expect(ClipRate.limited(3, fps: 0) == 3)
    }
}
