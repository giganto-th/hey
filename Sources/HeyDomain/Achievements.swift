import Foundation

/// Totals over the pet's whole life; achievements read from these.
public struct LifetimeStats: Codable, Equatable, Sendable {
    public var feeds = 0
    public var pets = 0
    public var pomodoros = 0
    public var questsDone = 0
    public var remindersSet = 0
    public var vaultAdds = 0
    public var captures = 0
    public var musicMinutes = 0.0
    public var miniGameBest = 0
    /// Plays so far in the current quest-day (see `Game.miniGameDay`).
    public var miniGamePlaysToday = 0
    public var miniGameDay: Date?
    public init() {}
}

public struct AchievementInfo: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var reward: Int
}

public struct Achievement: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
    public let goal: Double
    public let reward: Int
    public let progress: @Sendable (Game) -> Double

    public var info: AchievementInfo { AchievementInfo(id: id, title: title, reward: reward) }

    private init(_ id: String, _ title: String, _ detail: String, goal: Double, reward: Int,
                 progress: @escaping @Sendable (Game) -> Double) {
        self.id = id; self.title = title; self.detail = detail
        self.goal = goal; self.reward = reward; self.progress = progress
    }

    public static let all: [Achievement] = [
        .init("hatch", "ฟักออกมาแล้ว!", "ฟักไข่สำเร็จ", goal: 1, reward: 10) { $0.pet.state.stage == .egg ? 0 : 1 },
        .init("adult", "โตเต็มวัย", "เลี้ยงจนโตเต็มวัย", goal: 1, reward: 60) { $0.pet.state.stage == .adult ? 1 : 0 },
        .init("feed10", "ใจดีมีอาหาร", "ให้อาหาร 10 ครั้ง", goal: 10, reward: 10) { Double($0.stats.feeds) },
        .init("feed100", "เชฟประจำบ้าน", "ให้อาหาร 100 ครั้ง", goal: 100, reward: 50) { Double($0.stats.feeds) },
        .init("pet50", "เพื่อนสนิท", "ลูบ/เล่นกับสัตว์เลี้ยง 50 ครั้ง", goal: 50, reward: 15) { Double($0.stats.pets) },
        .init("pet500", "รักกันมาก", "ลูบ/เล่นกับสัตว์เลี้ยง 500 ครั้ง", goal: 500, reward: 60) { Double($0.stats.pets) },
        .init("bond100", "ผูกพันลึกซึ้ง", "ค่าความผูกพันถึง 100", goal: 100, reward: 40) { $0.pet.state.bond },
        .init("streak3", "มาทุกวัน", "ทำภารกิจต่อเนื่อง 3 วัน", goal: 3, reward: 10) { Double($0.streak.best) },
        .init("streak7", "หนึ่งสัปดาห์เต็ม", "ทำภารกิจต่อเนื่อง 7 วัน", goal: 7, reward: 30) { Double($0.streak.best) },
        .init("streak30", "ไม่มีวันขาด", "ทำภารกิจต่อเนื่อง 30 วัน", goal: 30, reward: 150) { Double($0.streak.best) },
        .init("quests10", "ขยัน", "ทำภารกิจรายวันเสร็จ 10 ข้อ", goal: 10, reward: 20) { Double($0.stats.questsDone) },
        .init("quests50", "มืออาชีพ", "ทำภารกิจรายวันเสร็จ 50 ข้อ", goal: 50, reward: 80) { Double($0.stats.questsDone) },
        .init("pomo1", "เริ่มโฟกัส", "โฟกัสครบ 1 รอบ", goal: 1, reward: 10) { Double($0.stats.pomodoros) },
        .init("pomo10", "สมาธิแน่น", "โฟกัสครบ 10 รอบ", goal: 10, reward: 40) { Double($0.stats.pomodoros) },
        .init("remind10", "จัดระเบียบชีวิต", "ตั้งเตือน 10 ครั้ง", goal: 10, reward: 20) { Double($0.stats.remindersSet) },
        .init("vault10", "นักสะสม", "ฝากของใน vault 10 ชิ้น", goal: 10, reward: 20) { Double($0.stats.vaultAdds) },
        .init("music60", "คอเพลง", "ฟังเพลงรวม 60 นาที", goal: 60, reward: 20) { $0.stats.musicMinutes },
        .init("capture5", "ช่างภาพ", "ถ่ายภาพ/อัดวิดีโอ 5 ครั้ง", goal: 5, reward: 20) { Double($0.stats.captures) },
        .init("game15", "มือไว", "มินิเกมได้ 15 คะแนนขึ้นไป", goal: 15, reward: 25) { Double($0.stats.miniGameBest) },
    ]
}

public enum MiniGame {
    public static let seconds = 20.0
    public static let maxRewardedPlaysPerDay = 3
    public static let maxRewardPerPlay = 20

    /// Two points per coin, so a good run pays about what a quest does.
    public static func reward(score: Int) -> Int { min(max(score, 0) / 2, maxRewardPerPlay) }
}
