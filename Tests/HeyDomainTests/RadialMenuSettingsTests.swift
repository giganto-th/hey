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

@Test func everyActionLivesInExactlyOneGroup() {
    for action in RadialAction.allCases {
        let homes = RadialGroup.allCases.filter { $0.members.contains(action) }
        #expect(homes.count == 1, "\(action) is in \(homes.count) groups")
    }
    #expect(Set(RadialGroup.allCases.flatMap(\.members)) == Set(RadialAction.allCases))
}

@Test func pinnedActionsLeaveTheirGroupAndEmptyGroupsDisappear() {
    var s = RadialMenuSettings()
    #expect(s.groups == [.capture, .notes, .other])
    #expect(s.members(of: .notes) == [.note, .remind, .clip])        // focus is pinned by default
    for a in [RadialAction.shot, .rec, .ocr] { _ = s.setPinned(a, true) }
    #expect(s.pinned.count <= RadialMenuSettings.maxPinned)
    var t = RadialMenuSettings()
    _ = t.setPinned(.shot, true)
    #expect(t.members(of: .capture) == [.rec, .ocr])
}

@Test func theBusiestPageStaysSmall() {
    let s = RadialMenuSettings()
    let main = s.pinned.count + s.groups.count
    let biggestGroup = s.groups.map { s.members(of: $0).count + 1 }.max() ?? 0      // plus the back button
    #expect(main <= 8)
    #expect(biggestGroup <= 8)
}
