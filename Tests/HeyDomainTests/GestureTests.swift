import Testing
import Foundation
@testable import HeyDomain

// MARK: swipe

@Test func trackpadSwipeFiresOnceWhenFingersLift() {
    var d = SwipeDetector()
    var fired: [GestureKind] = []
    for _ in 0..<10 { if let g = d.scroll(dx: -12, dyUp: 1, precise: true, ended: false, at: 1) { fired.append(g) } }
    #expect(fired.isEmpty)                                           // nothing while fingers are still down
    #expect(d.scroll(dx: 0, dyUp: 0, precise: true, ended: true, at: 1.1) == .swipeLeft)
}

@Test func allFourDirections() {
    func swipe(_ dx: Double, _ dy: Double) -> GestureKind? {
        var d = SwipeDetector()
        _ = d.scroll(dx: dx, dyUp: dy, precise: true, ended: false, at: 0)
        return d.scroll(dx: 0, dyUp: 0, precise: true, ended: true, at: 0.1)
    }
    #expect(swipe(120, 0) == .swipeRight)
    #expect(swipe(-120, 5) == .swipeLeft)
    #expect(swipe(5, 120) == .swipeUp)
    #expect(swipe(-5, -120) == .swipeDown)
}

@Test func shortOrDiagonalMovesAreIgnored() {
    var d = SwipeDetector()
    _ = d.scroll(dx: 30, dyUp: 0, precise: true, ended: false, at: 0)
    #expect(d.scroll(dx: 0, dyUp: 0, precise: true, ended: true, at: 0.1) == nil)       // too short

    _ = d.scroll(dx: 100, dyUp: 90, precise: true, ended: false, at: 1)
    #expect(d.scroll(dx: 0, dyUp: 0, precise: true, ended: true, at: 1.1) == nil)       // diagonal
}

@Test func nextSwipeStartsFreshAfterAnIgnoredOne() {
    var d = SwipeDetector()
    _ = d.scroll(dx: 40, dyUp: 0, precise: true, ended: false, at: 0)
    _ = d.scroll(dx: 0, dyUp: 0, precise: true, ended: true, at: 0.1)                   // ignored, must not leave residue
    _ = d.scroll(dx: 50, dyUp: 0, precise: true, ended: false, at: 1)
    #expect(d.scroll(dx: 0, dyUp: 0, precise: true, ended: true, at: 1.1) == nil)       // 50 alone is still too short
}

@Test func cooldownStopsRapidRepeats() {
    var d = SwipeDetector()
    func swipe(at t: Double) -> GestureKind? {
        _ = d.scroll(dx: 100, dyUp: 0, precise: true, ended: false, at: t)
        return d.scroll(dx: 0, dyUp: 0, precise: true, ended: true, at: t)
    }
    #expect(swipe(at: 0) == .swipeRight)
    #expect(swipe(at: 0.3) == nil)
    #expect(swipe(at: 0.7) == .swipeRight)
}

@Test func mouseWheelClicksFireImmediatelyWithCooldown() {
    var d = SwipeDetector()
    #expect(d.scroll(dx: 0, dyUp: 3, precise: false, ended: false, at: 0) == .swipeUp)
    #expect(d.scroll(dx: 0, dyUp: 3, precise: false, ended: false, at: 0.2) == nil)
    #expect(d.scroll(dx: 0, dyUp: -3, precise: false, ended: false, at: 1) == .swipeDown)
}

// MARK: rotation

@Test func rotationNeedsEnoughTurnAndReportsDirection() {
    var r = RotationDetector()
    for _ in 0..<5 { #expect(r.rotate(by: 6, ended: false) == nil) }
    #expect(r.rotate(by: 0, ended: true) == .rotateLeft)          // +30° = counter-clockwise
    _ = r.rotate(by: -40, ended: false)
    #expect(r.rotate(by: 0, ended: true) == .rotateRight)
    _ = r.rotate(by: 10, ended: false)
    #expect(r.rotate(by: 0, ended: true) == nil)                  // too small, and the total resets
}

// MARK: hot corners

private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

@Test func hotCornersAreDetectedOnlyInTheCornerPixels() {
    #expect(HotCorner.corner(at: CGPoint(x: 0, y: 899.5), in: [screen]) == .topLeft)
    #expect(HotCorner.corner(at: CGPoint(x: 1439.5, y: 899.5), in: [screen]) == .topRight)
    #expect(HotCorner.corner(at: CGPoint(x: 0, y: 0), in: [screen]) == .bottomLeft)
    #expect(HotCorner.corner(at: CGPoint(x: 1440, y: 0), in: [screen]) == .bottomRight)
    #expect(HotCorner.corner(at: CGPoint(x: 700, y: 899.5), in: [screen]) == nil)       // top edge, not a corner
    #expect(HotCorner.corner(at: CGPoint(x: 20, y: 880), in: [screen]) == nil)
}

@Test func hotCornersWorkOnASecondScreenWithOffsetOrigin() {
    let second = CGRect(x: 1440, y: -200, width: 1920, height: 1080)
    #expect(HotCorner.corner(at: CGPoint(x: 1440, y: 879.5), in: [screen, second]) == .topLeft)
    #expect(HotCorner.corner(at: CGPoint(x: 3359.5, y: -200), in: [screen, second]) == .bottomRight)
}

// MARK: settings

@Test func defaultsApplyUntilYouRebind() {
    var s = GestureSettings()
    #expect(s.action(for: .swipeLeft) == .musicNext && s.action(for: .swipeRight) == .musicPrevious)
    #expect(s.action(for: .rotateLeft) == .none)
    s.bind(.swipeLeft, to: .screenshotRegion)
    s.bind(.topRight, to: .recordToggle)
    #expect(s.action(for: .swipeLeft) == .screenshotRegion && s.action(for: .topRight) == .recordToggle)
    s.resetBindings()
    #expect(s.action(for: .swipeLeft) == .musicNext && s.action(for: .topRight) == .openHub)
}

@Test func everyGestureAndCornerHasADefaultAndLabel() {
    for g in GestureKind.allCases { #expect(!g.label.isEmpty); _ = GestureSettings.defaultAction(for: g) }
    for c in Corner.allCases { #expect(!c.label.isEmpty); _ = GestureSettings.defaultAction(for: c) }
    for a in PetAction.allCases { #expect(!a.label.isEmpty) }
}

@Test func scaleAndDwellAreClampedAndSettingsSurviveSaving() throws {
    var pet = PetState(); pet.stage = .hatchling
    var g = Game(save: SaveData(pet: pet))
    g.setGestures { $0.petScale = 5; $0.cornerDwell = 0; $0.hotCornersEnabled = true; $0.bind(.doubleClick, to: .petMenu) }
    #expect(g.gestures.petScale == 1.1 && g.gestures.cornerDwell == 0.2)
    let data = try g.save.encoded()
    #expect(try SaveData.decode(data).gestures == g.gestures)

    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let petJSON = try String(decoding: enc.encode(g.save.pet), as: UTF8.self)
    #expect(try SaveData.decode(Data(#"{"pet":\#(petJSON)}"#.utf8)).gestures == GestureSettings())
}
