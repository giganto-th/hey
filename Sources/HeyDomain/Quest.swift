import Foundation

public enum QuestKind: String, Codable, Sendable, CaseIterable {
    case checkIn, warm, online, feed, pet, variety, pomodoro, reminder, vault, music, capture
}

public struct Quest: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: QuestKind
    public var target: Double
    public var progress: Double = 0
    public var rewardCoins: Int
    public var rewardXP: Double
    public var done = false
    /// Distinct foods already counted (for `.variety`).
    public var seen: [String] = []

    public var title: String {
        let n = Int(target)
        switch kind {
        case .checkIn: return tr("ทักทายสัตว์เลี้ยงวันนี้")
        case .warm: return tr("อุ่นไข่ {0} ครั้ง", n)
        case .online: return tr("เปิดแอปไว้ {0} นาที", n)
        case .feed: return tr("ให้อาหาร {0} ครั้ง", n)
        case .pet: return tr("ลูบ/เล่นกับสัตว์เลี้ยง {0} ครั้ง", n)
        case .variety: return tr("ให้อาหารต่างชนิด {0} อย่าง", n)
        case .pomodoro: return tr("โฟกัสให้ครบ {0} รอบ", n)
        case .reminder: return tr("ตั้งเตือน {0} อย่าง", n)
        case .vault: return tr("ฝากของใน vault {0} ชิ้น", n)
        case .music: return tr("ฟังเพลง {0} นาที", n)
        case .capture: return tr("ถ่ายภาพหรืออัดวิดีโอ {0} ครั้ง", n)
        }
    }

    /// Quests that make sense for the pet's current stage.
    static func templates(for stage: PetStage) -> [Quest] {
        let egg = stage == .egg
        var list: [Quest] = [
            Quest(id: "", kind: .checkIn, target: 1, rewardCoins: 5, rewardXP: 0),
            Quest(id: "", kind: .online, target: 20, rewardCoins: 8, rewardXP: 2),
            Quest(id: "", kind: .pomodoro, target: 1, rewardCoins: 12, rewardXP: 4),
            Quest(id: "", kind: .reminder, target: 1, rewardCoins: 6, rewardXP: 1),
            Quest(id: "", kind: .vault, target: 1, rewardCoins: 6, rewardXP: 1),
            Quest(id: "", kind: .capture, target: 1, rewardCoins: 6, rewardXP: 1),
        ]
        if egg {
            list.append(Quest(id: "", kind: .warm, target: 5, rewardCoins: 8, rewardXP: 0))
        } else {
            list += [
                Quest(id: "", kind: .feed, target: 2, rewardCoins: 10, rewardXP: 5),
                Quest(id: "", kind: .pet, target: 5, rewardCoins: 8, rewardXP: 3),
                Quest(id: "", kind: .variety, target: 2, rewardCoins: 12, rewardXP: 6),
                Quest(id: "", kind: .music, target: 10, rewardCoins: 6, rewardXP: 1),
            ]
        }
        return list
    }
}

public struct StreakState: Codable, Equatable, Sendable {
    public var current = 0
    public var best = 0
    public var lastActiveDay: Date?
    public init() {}
}

public enum GameEvent: Equatable, Sendable {
    case pet(PetEngineEvent)
    case questCompleted(Quest)
    case allQuestsDone(bonus: Int)
    case streak(days: Int, bonus: Int)
    case bought(Food)
    case insufficientCoins(Food)
    case reminderDue(Reminder)
    case pomodoroCredited(session: Int)
    case vaultAdded(VaultItem)
    case vaultDuplicate(VaultItem)
    case vaultRemoved([VaultItem])
    case trackAdded(Track)
    case trackDuplicate(Track)
    case mediaAdded(MediaItem)
    case mediaRemoved(MediaItem)
    case achievementUnlocked(AchievementInfo)
    case miniGameFinished(score: Int, reward: Int)
    case shelfAdded(ShelfItem)
    case noStock(Food)
}
