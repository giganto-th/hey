import Testing
import Foundation
@testable import HeyDomain

private let gmt: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "GMT")!
    return c
}()
// 2027-01-15 08:00:00 GMT
private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func newGame() -> Game {
    var pet = PetState(now: t0, calendar: gmt)
    pet.stage = .hatchling
    return Game(save: SaveData(pet: pet), calendar: gmt, rng: FixedRandom(value: 0))
}

private func hm(_ d: Date) -> String {
    let c = gmt.dateComponents([.day, .hour, .minute], from: d)
    return "\(c.day!) \(c.hour!):\(String(format: "%02d", c.minute!))"
}

// MARK: parser

@Test func parsesRelativeTimes() {
    let a = ReminderParser.parse("ประชุม อีก 20 นาที", now: t0, calendar: gmt)
    #expect(a?.text == "ประชุม")
    #expect(a?.fireAt == t0.addingTimeInterval(1200))
    let b = ReminderParser.parse("stretch in 2 hours", now: t0, calendar: gmt)
    #expect(b?.text == "stretch")
    #expect(b?.fireAt == t0.addingTimeInterval(7200))
}

@Test func parsesThaiClockWords() {
    #expect(hm(ReminderParser.parse("พรุ่งนี้ 9 โมง ส่งงาน", now: t0, calendar: gmt)!.fireAt) == "16 9:00")
    #expect(hm(ReminderParser.parse("บ่าย 2 โมง กินยา", now: t0, calendar: gmt)!.fireAt) == "15 14:00")
    #expect(hm(ReminderParser.parse("เย็น 5 โมงครึ่ง", now: t0, calendar: gmt)!.fireAt) == "15 17:30")
    #expect(hm(ReminderParser.parse("2 ทุ่ม ดูหนัง", now: t0, calendar: gmt)!.fireAt) == "15 20:00")
}

@Test func parsesClockTimesAndRollsToTomorrowWhenPassed() {
    #expect(hm(ReminderParser.parse("call mom 18:30", now: t0, calendar: gmt)!.fireAt) == "15 18:30")
    #expect(hm(ReminderParser.parse("standup 7:15", now: t0, calendar: gmt)!.fireAt) == "16 7:15")   // 07:15 already passed
    #expect(hm(ReminderParser.parse("lunch 12pm", now: t0, calendar: gmt)!.fireAt) == "15 12:00")
}

@Test func parserRejectsTextWithoutATime() {
    #expect(ReminderParser.parse("ซื้อนม", now: t0, calendar: gmt) == nil)
    #expect(ReminderParser.parse("25:99 nonsense", now: t0, calendar: gmt) == nil)
}

@Test func parserKeepsDefaultTextWhenOnlyTimeGiven() {
    #expect(ReminderParser.parse("อีก 5 นาที", now: t0, calendar: gmt)?.text == "เตือน")
}

// MARK: reminders in the game

@Test func reminderRingsNagsThenWaitsForAnAnswer() {
    var g = newGame()
    g.addReminder("ยืด", at: t0.addingTimeInterval(60), now: t0)
    #expect(g.dueReminders(at: t0).isEmpty)
    #expect(g.dueReminders(at: t0.addingTimeInterval(60)).count == 1)
    #expect(g.dueReminders(at: t0.addingTimeInterval(61)).isEmpty)               // not due again yet
    #expect(g.dueReminders(at: t0.addingTimeInterval(60 + 300)).count == 1)      // nag 2
    #expect(g.dueReminders(at: t0.addingTimeInterval(60 + 600)).count == 1)      // nag 3
    #expect(g.dueReminders(at: t0.addingTimeInterval(86_400)).isEmpty)           // gave up, still ringing
    #expect(g.reminders[0].ringing && g.reminders[0].isActive)
}

@Test func acknowledgeEndsOneShotAndReschedulesRepeats() {
    var g = newGame()
    g.addReminder("once", at: t0, now: t0)
    g.addReminder("daily", at: t0, repeat: .daily, now: t0)
    g.addReminder("every 30", at: t0, repeat: .everyMinutes(30), now: t0)
    _ = g.dueReminders(at: t0)
    let later = t0.addingTimeInterval(3600 * 5)                    // 13:00
    for r in g.reminders { g.acknowledgeReminder(id: r.id, at: later) }

    #expect(g.reminders[0].doneAt == later)
    #expect(hm(g.reminders[1].nextFire) == "16 8:00")
    #expect(!g.reminders[1].ringing && g.reminders[1].isActive)
    #expect(hm(g.reminders[2].nextFire) == "15 13:30")
}

@Test func snoozeDelaysTheReminder() {
    var g = newGame()
    g.addReminder("x", at: t0, now: t0)
    _ = g.dueReminders(at: t0)
    g.snoozeReminder(id: g.reminders[0].id, minutes: 10, at: t0)
    #expect(!g.reminders[0].ringing)
    #expect(g.dueReminders(at: t0.addingTimeInterval(599)).isEmpty)
    #expect(g.dueReminders(at: t0.addingTimeInterval(600)).count == 1)
}

@Test func remindersDueWhileClosedRingOnStartup() {
    var g = newGame()
    g.addReminder("missed", at: t0.addingTimeInterval(3600), now: t0)
    var reopened = Game(save: g.save, calendar: gmt)
    #expect(reopened.dueReminders(at: t0.addingTimeInterval(86_400)).count == 1)
}

@Test func settingAReminderCountsForItsQuest() {
    var g = Game(save: SaveData(pet: { var p = PetState(now: t0, calendar: gmt); p.stage = .hatchling; return p }()),
                 calendar: gmt, rng: questRNG([.checkIn, .online, .reminder]))
    _ = g.startSession(at: t0)
    #expect(g.quests.map(\.kind) == [.checkIn, .online, .reminder])
    let events = g.addReminder("x", at: t0.addingTimeInterval(60), now: t0)
    #expect(events.contains { if case .questCompleted(let q) = $0 { q.kind == .reminder } else { false } })
}

// MARK: pomodoro

@Test func pomodoroRunsFocusThenBreakThenWaits() {
    var p = PomodoroTimer()
    p.start(at: t0)
    #expect(p.tick(at: t0.addingTimeInterval(1499)) == nil)
    #expect(p.tick(at: t0.addingTimeInterval(1500)) == .focusFinished(session: 1))
    #expect(p.phase == .shortBreak && p.isRunning)
    #expect(p.remaining(at: t0.addingTimeInterval(1500)) == 300)
    #expect(p.tick(at: t0.addingTimeInterval(1800)) == .breakFinished)
    #expect(p.phase == .focus && !p.isRunning)
}

@Test func everyFourthFocusEarnsALongBreak() {
    var p = PomodoroTimer()
    var now = t0
    for round in 1...4 {
        p.start(at: now)
        now = now.addingTimeInterval(1500)
        #expect(p.tick(at: now) == .focusFinished(session: round))
        #expect(p.phase == (round == 4 ? .longBreak : .shortBreak))
        now = now.addingTimeInterval(p.duration(of: p.phase))
        #expect(p.tick(at: now) == .breakFinished)
    }
}

@Test func pausingKeepsRemainingTime() {
    var p = PomodoroTimer()
    p.start(at: t0)
    p.pause(at: t0.addingTimeInterval(600))
    #expect(p.remaining(at: t0.addingTimeInterval(9999)) == 900)
    p.start(at: t0.addingTimeInterval(10_000))
    #expect(p.remaining(at: t0.addingTimeInterval(10_100)) == 800)
}

@Test func skipAndResetDoNotCreditFocus() {
    var p = PomodoroTimer()
    p.start(at: t0)
    p.skip(at: t0.addingTimeInterval(10))
    #expect(p.phase == .shortBreak && p.completedFocus == 0 && p.isRunning)
    p.reset()
    #expect(p.phase == .focus && !p.isRunning && p.remaining(at: t0) == 1500)
}

@Test func lateTickStillFinishesPhase() {
    var p = PomodoroTimer()
    p.start(at: t0)
    #expect(p.tick(at: t0.addingTimeInterval(3 * 3600)) == .focusFinished(session: 1))   // Mac slept
}

@Test func finishedFocusCreditsXPAndQuest() {
    var g = Game(save: SaveData(pet: { var p = PetState(now: t0, calendar: gmt); p.stage = .hatchling; return p }()),
                 calendar: gmt, rng: questRNG([.checkIn, .online, .pomodoro]))
    _ = g.startSession(at: t0)
    let events = g.creditPomodoro(session: 1)
    #expect(g.pet.state.xp >= 5)
    #expect(events.contains { if case .questCompleted(let q) = $0 { q.kind == .pomodoro } else { false } })
}

// MARK: notes + persistence

@Test func notesCreateEditPinMoveDelete() {
    var g = newGame()
    let id = g.addNote(now: t0)
    g.updateNote(id: id, text: "ซื้อนม", now: t0.addingTimeInterval(5))
    g.setNote(id: id, pinned: true)
    g.moveNote(id: id, x: 100, y: 200)
    #expect(g.notes[0].text == "ซื้อนม" && g.notes[0].pinned && g.notes[0].x == 100)
    #expect(g.notes[0].updatedAt == t0.addingTimeInterval(5))
    g.deleteNote(id: id)
    #expect(g.notes.isEmpty)
}

@Test func saveFromBeforeRemindersAndNotesStillLoads() throws {
    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let petJSON = try String(decoding: enc.encode(PetState(now: t0, calendar: gmt)), as: UTF8.self)
    let json = #"{"version":1,"coins":77,"inventory":{"cookie":2},"streak":{"current":3,"best":5},"quests":[],"pet":\#(petJSON)}"#
    let save = try SaveData.decode(Data(json.utf8))
    #expect(save.coins == 77 && save.inventory["cookie"] == 2 && save.streak.current == 3)
    #expect(save.reminders.isEmpty && save.notes.isEmpty)
}

@Test func remindersAndNotesSurviveRoundTrip() throws {
    var g = newGame()
    g.addReminder("x", at: t0, repeat: .everyMinutes(15), now: t0)
    g.addNote(pinned: true, now: t0)
    let data = try g.save.encoded()
    #expect(try SaveData.decode(data) == g.save)
}

@Test func calmPetDoesNotWalk() {
    var fsm = BehaviorFSM(rng: FixedRandom(value: 0.1))     // would normally walk
    fsm.calm = true
    fsm.tick(dt: 3.1)
    #expect(fsm.pose != .walk)
}

@Suite struct EnglishReminderTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let cal = Calendar(identifier: .gregorian)

    @Test func parsesEnglishClockTimes() {
        var c = cal; c.timeZone = TimeZone(identifier: "UTC")!
        let r1 = ReminderParser.parse("call mom at 6:30pm", now: now, calendar: c)
        #expect(r1?.text == "call mom")
        #expect(c.component(.hour, from: r1!.fireAt) == 18)
        #expect(c.component(.minute, from: r1!.fireAt) == 30)
        let r2 = ReminderParser.parse("standup 9am tomorrow", now: now, calendar: c)
        #expect(r2?.text == "standup")
        #expect(c.component(.hour, from: r2!.fireAt) == 9)
        let r3 = ReminderParser.parse("take medicine in 2 hours", now: now, calendar: c)
        #expect(r3?.fireAt == now.addingTimeInterval(7200))
        #expect(r3?.text == "take medicine")
    }
}
