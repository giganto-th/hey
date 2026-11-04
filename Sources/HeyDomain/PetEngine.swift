import Foundation

public enum PetEngineEvent: Equatable, Sendable {
    case hatched
    case evolved(PetStage)
    case fed(Food)
    case refusedEgg
    case refusedFull
    case refusedCooldown(remaining: TimeInterval)
    case dailyCheckIn
    case eggWarmed(progress: Double, needed: Double)
    case eggWarmEnoughToday
}

/// Owns the pet's numbers. Pure and clock-free: callers pass `now`.
public struct PetEngine: Sendable {
    public private(set) var state: PetState
    public let balance: Balance
    private var calendar: Calendar
    private var rng: any RandomSource

    public init(
        state: PetState,
        balance: Balance = .standard,
        calendar: Calendar = .current,
        rng: any RandomSource = SystemRandom()
    ) {
        self.state = state
        self.balance = balance
        self.calendar = calendar
        self.rng = rng
    }

    public var favoriteFood: Food? {
        balance.foods.first { $0.id == state.favoriteFood }
    }

    // MARK: time

    /// Applies elapsed time. `sleeping` only matters while the app is running;
    /// a long gap is treated as the app being closed and the pet as resting.
    @discardableResult
    public mutating func advance(to now: Date, sleeping: Bool) -> [PetEngineEvent] {
        rollDayIfNeeded(now)
        let raw = now.timeIntervalSince(state.lastTickAt)
        state.lastTickAt = now
        // Clock moved backwards (or nothing elapsed): never punish or reward.
        guard raw > 0 else { return [] }

        let offline = raw > balance.offlineGap
        let hours = min(raw / 3600, balance.offlineCapHours)
        var events: [PetEngineEvent] = []

        if state.stage == .egg {
            if !offline {
                let room = max(balance.warmDailyCap - state.warmedToday, 0)
                let gain = min(raw / 60 * balance.warmPerMinute, room)
                state.warmedToday += gain
                events += addHatchProgress(gain)
            }
            return events
        }

        let hungry = state.hunger < 20
        state.hunger -= balance.hungerDecayPerHour * hours
        state.mood -= (balance.moodDecayPerHour + (hungry ? balance.hungryExtraMoodDecay : 0)) * hours
        if sleeping || offline {
            state.energy += balance.energyRestPerHour * hours
        } else {
            state.energy -= balance.energyDecayPerHour * hours
        }
        clampStats()
        return events
    }

    public mutating func dailyCheckIn(at now: Date) -> [PetEngineEvent] {
        rollDayIfNeeded(now)
        if let last = state.lastCheckIn, calendar.isDate(last, inSameDayAs: now) { return [] }
        state.lastCheckIn = now
        state.bond += 1
        return [.dailyCheckIn] + addXP(balance.dailyCheckInXP)
    }

    // MARK: interactions

    public mutating func pet(at now: Date) -> [PetEngineEvent] {
        rollDayIfNeeded(now)
        if state.stage == .egg {
            let gain = min(balance.clickWarm, max(balance.clickWarmDailyCap - state.clickWarmedToday, 0))
            guard gain > 0 else { return [.eggWarmEnoughToday] }
            state.clickWarmedToday += gain
            let events = addHatchProgress(gain)
            return events.isEmpty ? [.eggWarmed(progress: state.hatchProgress, needed: balance.hatchNeeded)] : events
        }
        state.mood = min(state.mood + 3, 100)
        let bondGain = min(0.5, max(balance.petBondDailyCap - state.bondFromPettingToday, 0))
        state.bondFromPettingToday += bondGain
        state.bond += bondGain
        return addXP(0.5)
    }

    public mutating func feed(_ food: Food, at now: Date) -> [PetEngineEvent] {
        rollDayIfNeeded(now)
        guard state.stage != .egg else { return [.refusedEgg] }
        guard state.hunger < 95 else { return [.refusedFull] }
        if let last = state.lastFed[food.id] {
            let remaining = food.cooldown - now.timeIntervalSince(last)
            if remaining > 0 { return [.refusedCooldown(remaining: remaining)] }
        }
        let favorite = food.id == state.favoriteFood
        let boost = favorite ? 2.0 : 1.0
        let wasStarving = state.hunger < 20

        state.hunger += food.hunger
        state.mood += food.mood * boost
        state.bond += 1
        state.lastFed[food.id] = now
        clampStats()

        let xp = food.xp * boost * (wasStarving ? 0.5 : 1)
        return [.fed(food)] + addXP(xp)
    }

    /// Used by quests/dev tools; evolves the pet if the threshold is crossed.
    public mutating func rename(_ name: String) { state.name = name }
    public mutating func grantXP(_ amount: Double) -> [PetEngineEvent] { addXP(amount) }

    public mutating func grantWarmth(_ amount: Double) -> [PetEngineEvent] { addHatchProgress(amount) }

    /// How long until this food can be given again (0 = now).
    public func cooldownRemaining(_ food: Food, at now: Date) -> TimeInterval {
        guard let last = state.lastFed[food.id] else { return 0 }
        return max(food.cooldown - now.timeIntervalSince(last), 0)
    }

    // MARK: internals

    private mutating func addHatchProgress(_ amount: Double) -> [PetEngineEvent] {
        guard amount > 0, state.stage == .egg else { return [] }
        state.hatchProgress += amount
        guard state.hatchProgress >= balance.hatchNeeded else { return [] }
        state.stage = .hatchling
        state.bornAt = state.lastTickAt
        state.hunger = 70
        state.mood = 90
        state.energy = 100
        let foods = balance.foods
        if !foods.isEmpty {
            let i = min(Int(rng.next(in: 0...Double(foods.count))), foods.count - 1)
            state.favoriteFood = foods[i].id
        }
        return [.hatched]
    }

    private mutating func addXP(_ amount: Double) -> [PetEngineEvent] {
        guard amount > 0, state.stage != .egg else { return [] }
        state.xp += amount
        var events: [PetEngineEvent] = []
        while let needed = balance.xpToLeave(state.stage), state.xp >= needed, let next = state.stage.next {
            state.stage = next
            events.append(.evolved(next))
        }
        return events
    }

    private mutating func rollDayIfNeeded(_ now: Date) {
        let today = calendar.startOfDay(for: now)
        guard today > state.dayStart else { return }
        state.dayStart = today
        state.warmedToday = 0
        state.clickWarmedToday = 0
        state.bondFromPettingToday = 0
    }

    private mutating func clampStats() {
        state.hunger = min(max(state.hunger, 0), 100)
        state.mood = min(max(state.mood, 0), 100)
        state.energy = min(max(state.energy, 0), 100)
    }
}
