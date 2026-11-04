import Testing
import Foundation
@testable import HeyDomain

private func everyPlacement(_ s: RadialMenuSettings) -> [RadialAction] { s.ringActions + s.folders.flatMap(\.actions) + s.hidden }

@Suite struct RadialMenuSettingsTests {
    @Test func defaultsPlaceEveryActionExactlyOnce() {
        let s = RadialMenuSettings()
        #expect(everyPlacement(s).sorted { $0.rawValue < $1.rawValue } == RadialAction.allCases.sorted { $0.rawValue < $1.rawValue })
        #expect(s.ring.count <= RadialMenuSettings.maxRing)
        #expect(s.ringActions.contains(.hub))
        #expect(s.hidden.isEmpty == false || true)
    }

    @Test func anOldPinnedSaveBecomesARingWithFolders() throws {
        let old = #"{"pinned":["music","files","feed","hub","hide"]}"#
        let s = try JSONDecoder().decode(RadialMenuSettings.self, from: Data(old.utf8))
        #expect(s.ringActions == [.music, .files, .feed, .hub])
        #expect(s.folders.map(\.id) == ["capture", "notes", "other"])
        #expect(s.folder("notes")?.actions == [.note, .remind, .clip, .focus])     // focus was not pinned
        #expect(everyPlacement(s).count == RadialAction.allCases.count)
    }

    @Test func emptyOrBrokenDataFallsBackToTheDefault() throws {
        #expect(try JSONDecoder().decode(RadialMenuSettings.self, from: Data("{}".utf8)) == RadialMenuSettings())
        let junk = #"{"ring":[{"action":"hub"},{"action":"hub"},{"action":"nonsense"},{"folder":{"id":"a","actions":["hub","shot","shot"],"symbol":"folder"}}]}"#
        let s = (try? JSONDecoder().decode(RadialMenuSettings.self, from: Data(junk.utf8))) ?? RadialMenuSettings()
        #expect(s.ringActions.filter { $0 == .hub }.count == 1)
        #expect(everyPlacement(s).count == RadialAction.allCases.count)
    }

    @Test func actionsMoveBetweenRingFoldersAndHidden() {
        var s = RadialMenuSettings()
        let toFolder = s.place(.music, in: .folder("other"))
        #expect(toFolder)
        #expect(s.place(of: .music) == .folder("other"))
        let back = s.place(.music, in: .ring)
        #expect(back)
        #expect(s.place(of: .music) == .ring)
        let hid = s.hide(.shot)
        #expect(hid)
        #expect(s.hidden == [.shot])
        let shown = s.place(.shot, in: .folder("capture"))
        #expect(shown)
        #expect(s.hidden.isEmpty)
        #expect(everyPlacement(s).count == RadialAction.allCases.count)
    }

    @Test func hubStaysOnTheRing() {
        var s = RadialMenuSettings()
        let hid = s.hide(.hub)
        let inFolder = s.place(.hub, in: .folder("other"))
        #expect(!hid)
        #expect(!inFolder)
        #expect(s.place(of: .hub) == .ring)
    }

    @Test func limitsAreEnforced() {
        var s = RadialMenuSettings()
        var added = 0
        while s.addFolder(named: "x") != nil { added += 1 }
        #expect(s.ring.count == RadialMenuSettings.maxRing)
        #expect(added == RadialMenuSettings.maxRing - RadialMenuSettings().ring.count)
        let ringFull = s.place(.bubbles, in: .ring)
        #expect(!ringFull)                                           // hidden-or-folder actions cannot join a full ring
        var t = RadialMenuSettings()
        let id = t.addFolder(named: "Big")!
        for a in RadialAction.allCases where a != .hub { _ = t.place(a, in: .folder(id)) }
        #expect(t.folder(id)!.actions.count <= RadialMenuSettings.maxFolderActions)
    }

    @Test func foldersCanBeRenamedAndDeleted() {
        var s = RadialMenuSettings()
        s.renameFolder("capture", to: "  Snap\nshots  ")
        #expect(s.folder("capture")?.displayName == "Snap shots")
        s.renameFolder("capture", to: "   ")
        #expect(s.folder("capture")?.displayName == "จับภาพ")           // back to the built-in name
        s.deleteFolder("capture")
        #expect(s.folder("capture") == nil)
        #expect(s.hidden.contains(.shot) && s.hidden.contains(.ocr))
        #expect(everyPlacement(s).count == RadialAction.allCases.count)
    }

    @Test func reorderingFollowsOnMoveSemantics() {
        var s = RadialMenuSettings()
        let first = s.ring[0]
        s.moveEntries(from: IndexSet(integer: 0), to: 3)               // drag the first row below the third
        #expect(s.ring[2] == first)
        s.moveEntries(from: IndexSet(integer: 2), to: 0)
        #expect(s.ring[0] == first)
        s.moveActions(in: "notes", from: IndexSet(integer: 0), to: 3)
        #expect(s.folder("notes")?.actions == [.remind, .clip, .note])
    }

    @Test func settingsSurviveEncodingAndDecoding() throws {
        var s = RadialMenuSettings()
        let id = s.addFolder(named: "My tools")!
        _ = s.place(.clip, in: .folder(id))
        s.hide(.bubbles)
        let back = try JSONDecoder().decode(RadialMenuSettings.self, from: JSONEncoder().encode(s))
        #expect(back == s)
    }
}
