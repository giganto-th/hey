import Testing
import Foundation
@testable import HeyDomain

struct DockTests {
    func app(_ id: String) -> DockApp { DockApp(bundleID: id, name: id, path: "/Applications/\(id).app") }

    @Test func addDedupesAcrossGroups() {
        var d = DockLayout()
        let first = d.add(app("a")), again = d.add(app("a")), second = d.add(app("b"))
        d.drop("b", onto: "a")
        let grouped = d.add(app("b"))
        #expect(first && !again && second && !grouped)
    }

    @Test func droppingOnAnAppMakesAGroup() {
        var d = DockLayout()
        d.add(app("a")); d.add(app("b")); d.add(app("c"))
        d.drop("c", onto: "a")
        #expect(d.entries.count == 2)
        guard case .group(let g) = d.entries[0] else { Issue.record("expected a group"); return }
        #expect(g.apps.map(\.bundleID) == ["a", "c"])
        #expect(g.name == DockLayout.defaultGroupName)
    }

    @Test func droppingOnAGroupJoinsIt() {
        var d = DockLayout()
        d.add(app("a")); d.add(app("b")); d.add(app("c"))
        d.drop("b", onto: "a")
        guard case .group(let g) = d.entries[0] else { return }
        d.drop("c", onto: g.id.uuidString)
        guard case .group(let g2) = d.entries[0] else { return }
        #expect(g2.apps.map(\.bundleID) == ["a", "b", "c"])
        #expect(d.entries.count == 1)
    }

    @Test func ungroupPutsAppAfterTheGroupAndEmptyGroupsVanish() {
        var d = DockLayout()
        d.add(app("a")); d.add(app("b")); d.drop("b", onto: "a")
        d.ungroup("b")
        #expect(d.entries.map(\.id).contains("b"))
        d.remove("a")
        #expect(d.entries.count == 1)
    }

    @Test func dissolveRestoresLooseApps() {
        var d = DockLayout()
        d.add(app("a")); d.add(app("b")); d.drop("b", onto: "a")
        guard case .group(let g) = d.entries[0] else { return }
        d.dissolve(g.id)
        #expect(d.entries.map(\.id) == ["a", "b"])
    }

    @Test func renameTrimsAndRejectsBlank() {
        var d = DockLayout()
        d.add(app("a")); d.add(app("b")); d.drop("b", onto: "a")
        guard case .group(let g) = d.entries[0] else { return }
        d.rename(g.id, to: "  งาน  ")
        d.rename(g.id, to: "   ")
        guard case .group(let g2) = d.entries[0] else { return }
        #expect(g2.name == "งาน")
    }

    @Test func moveSwapsNeighboursAndStopsAtEnds() {
        var d = DockLayout()
        d.add(app("a")); d.add(app("b")); d.add(app("c"))
        d.move("a", by: 1)
        #expect(d.entries.map(\.id) == ["b", "a", "c"])
        d.move("c", by: 1)
        #expect(d.entries.map(\.id) == ["b", "a", "c"])
    }

    @Test func layoutSurvivesSaveRoundTripAndDamagedDuplicates() throws {
        var d = DockLayout()
        d.add(app("a")); d.add(app("b")); d.drop("b", onto: "a")
        let data = try JSONEncoder().encode(d)
        #expect(try JSONDecoder().decode(DockLayout.self, from: data) == d)
        let dup = #"{"entries":[{"app":{"_0":{"bundleID":"a","name":"a","path":"/a"}}},{"app":{"_0":{"bundleID":"a","name":"a","path":"/a"}}}]}"#
        #expect(try JSONDecoder().decode(DockLayout.self, from: Data(dup.utf8)).entries.count == 1)
    }
}
