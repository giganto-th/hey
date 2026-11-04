import Foundation
import Testing
@testable import HeyDomain

@Suite struct ClipboardTests {
    @Test func newestFirstAndDuplicatesMoveUp() {
        var h = ClipboardHistory()
        h.add("a"); h.add("b"); h.add("a")
        #expect(h.entries.map(\.text) == ["a", "b"])
    }

    @Test func blankAndHugeTextIsIgnored() {
        var h = ClipboardHistory()
        let blank = h.add("   \n ")
        let huge = h.add(String(repeating: "x", count: ClipboardHistory.maxLength + 1))
        #expect(!blank)
        #expect(!huge)
        #expect(h.entries.isEmpty)
    }

    @Test func capacityDropsTheOldestUnpinned() {
        var h = ClipboardHistory()
        h.add("keep"); h.togglePin(h.entries[0].id)
        for i in 0..<(ClipboardHistory.capacity + 5) { h.add("item \(i)") }
        #expect(h.entries.count == ClipboardHistory.capacity)
        #expect(h.entries.first?.text == "keep")
        #expect(h.entries.contains { $0.text == "item 0" } == false)
    }

    @Test func clearKeepsPinned() {
        var h = ClipboardHistory()
        h.add("x"); h.add("y")
        h.togglePin(h.entries.last!.id)
        h.clear()
        #expect(h.entries.map(\.text) == ["x"])
    }

    @Test func unpinReturnsToTimeOrder() {
        var h = ClipboardHistory()
        let t = Date()
        h.add("old", at: t); h.add("new", at: t.addingTimeInterval(10))
        let old = h.entries.first { $0.text == "old" }!
        h.togglePin(old.id)
        #expect(h.entries.first?.text == "old")
        h.togglePin(old.id)
        #expect(h.entries.map(\.text) == ["new", "old"])
    }

    @Test func recognisesLinksAndPreviews() {
        var h = ClipboardHistory()
        h.add("https://example.com/a?b=1"); h.add("not a link"); h.add("one\ntwo\nthree")
        #expect(h.entries.first { $0.text.hasPrefix("https") }!.isLink)
        #expect(!h.entries.first { $0.text == "not a link" }!.isLink)
        #expect(h.entries.first { $0.text.hasPrefix("one") }!.preview == "one …(+2 บรรทัด)")
    }
}
