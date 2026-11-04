import Testing
import Foundation
@testable import HeyDomain

struct HeyURLTests {
    func p(_ s: String) -> HeyCommand? { URL(string: s).flatMap(HeyURL.parse) }

    @Test func parsesFocus() {
        #expect(p("hey://focus/start") == .focusStart)
        #expect(p("hey://focus/stop") == .focusStop)
        #expect(p("hey://focus") == nil)
    }
    @Test func parsesNoteWithThaiText() {
        #expect(p("hey://note?text=%E0%B8%8B%E0%B8%B7%E0%B9%89%E0%B8%AD%E0%B8%99%E0%B9%89%E0%B8%B3") == .note("ซื้อน้ำ"))
        #expect(p("hey://note?text=%20") == nil)
        #expect(p("hey://note") == nil)
    }
    @Test func parsesClipAndHub() {
        #expect(p("hey://clip") == .copyClip(0))
        #expect(p("hey://clip?n=2") == .copyClip(2))
        #expect(p("hey://clip?n=-1") == nil)
        #expect(p("hey://hub?page=clipboard") == .openHub("clipboard"))
        #expect(p("hey://dock") == .toggleDock)
    }
    @Test func ignoresOtherSchemes() {
        #expect(p("https://example.com/focus/start") == nil)
        #expect(p("hey://unknown") == nil)
    }
}
