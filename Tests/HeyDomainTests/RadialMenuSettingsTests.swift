import Testing
import Foundation
@testable import HeyDomain

@Suite struct RadialMenuSettingsTests {
    @Test func defaultsAreValid() {
        let s = RadialMenuSettings()
        #expect(s.pinned.count >= RadialMenuSettings.minPinned)
        #expect(s.pinned.contains(.hub))
        #expect(Set(s.pinned).union(s.rest).count == RadialAction.allCases.count)
    }

    @Test func pinAndUnpinRespectLimits() {
        var s = RadialMenuSettings()
        let r867277 = s.setPinned(.note, true)
        #expect(r867277)
        #expect(s.pinned.count == 6)
        let r203367 = s.setPinned(.shot, true)
        #expect(!r203367)                       // full
        let r566247 = s.setPinned(.hub, false)
        #expect(!r566247)                       // hub stays
        let r117392 = s.setPinned(.note, false)
        #expect(r117392)
        let r531704 = s.setPinned(.feed, false)
        #expect(r531704)
        let r353582 = s.setPinned(.focus, false)
        #expect(!r353582)                     // minimum four
        #expect(s.pinned.count == 4)
    }

    @Test func moveSwapsNeighboursOnly() {
        var s = RadialMenuSettings()
        s.move(.music, by: -1)
        #expect(s.pinned.first == .music)
        s.move(.music, by: 1)
        #expect(s.pinned[1] == .music)
    }

    @Test func damagedSaveRepairsItself() throws {
        let bad = #"{"pinned":["nonsense","music","music","note","remind","shot","rec","shelf","hide"]}"#
        let s = try JSONDecoder().decode(RadialMenuSettings.self, from: Data(bad.utf8))
        #expect(s.pinned.count <= RadialMenuSettings.maxPinned)
        #expect(s.pinned.contains(.hub))
        #expect(Set(s.pinned).count == s.pinned.count)
        let empty = try JSONDecoder().decode(RadialMenuSettings.self, from: Data("{}".utf8))
        #expect(empty == RadialMenuSettings())
    }
}
