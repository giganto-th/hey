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
    /// Neglect has built up: 1 = the pet is in trouble, 2 = it will not last much longer.
    case neglect(level: Int)
    case died(PetNeed)
    case refusedDead
}

/// Owns the pet's numbers. Pure and clock-free: callers pass `now`.
public struct PetEngine: Sendable {
    public private(set) var state: PetState
    public let balance: Balance
    private var calendar: Calendar
    private var rng: any RandomSource
    /// Whether a neglected pet can die at all (a setting).
    public var mortal = true

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

        guard !state.isDead else { return [] }
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
        let before = (hunger: state.hunger, mood: state.mood, energy: state.energy)
        state.hunger -= balance.hungerDecayPerHour * hours
        state.mood -= (balance.moodDecayPerHour + (hungry ? balance.hungryExtraMoodDecay : 0)) * hours
        if sleeping || offline {
            state.energy += balance.energyRestPerHour * hours
        } else {
            state.energy -= balance.energyDecayPerHour * hours
        }
        // How long each need sat at zero within this stretch (it may have run out part of the way through).
        func hoursAtZero(_ was: Double, _ now: Double) -> Double {
            guard now <= 0, hours > 0 else { return 0 }
            guard was > 0 else { return hours }
            return max(hours - was / ((was - now) / hours), 0)
        }
        let zeroHours: [(PetNeed, Double)] = [
            (.hunger, hoursAtZero(before.hunger, state.hunger)),
            (.mood, hoursAtZero(before.mood, state.mood)),
            (.energy, hoursAtZero(before.energy, state.energy)),
        ]
        clampStats()
        events += updateNeglect(hours: hours, zero: zeroHours, now: now)
        return events
    }

    public mutating func dailyCheckIn(at now: Date) -> [PetEngineEvent] {
        guard !state.isDead else { return [] }
        rollDayIfNeeded(now)
        if let last = state.lastCheckIn, calendar.isDate(last, inSameDayAs: now) { return [] }
        state.lastCheckIn = now
        state.bond += 1
        return [.dailyCheckIn] + addXP(balance.dailyCheckInXP)
    }

    // MARK: interactions

    public mutating func pet(at now: Date) -> [PetEngineEvent] {
        guard !state.isDead else { return [.refusedDead] }
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

    /// Why this food can't be given right now, or nil if it can. Does not change anything.
    public func feedRefusal(_ food: Food, at now: Date) -> PetEngineEvent? {
        guard !state.isDead else { return .refusedDead }
        guard state.stage != .egg else { return .refusedEgg }
        guard state.hunger < 95 else { return .refusedFull }
        let remaining = cooldownRemaining(food, at: now)
        return remaining > 0 ? .refusedCooldown(remaining: remaining) : nil
    }

    public mutating func feed(_ food: Food, at now: Date) -> [PetEngineEvent] {
        guard !state.isDead else { return [.refusedDead] }
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
    public mutating func grantXP(_ amount: Double) -> [PetEngineEvent] { state.isDead ? [] : addXP(amount) }

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

    private mutating func updateNeglect(hours: Double, zero: [(PetNeed, Double)], now: Date) -> [PetEngineEvent] {
        let before = state.neglectSeconds ?? 0
        let worst = zero.max { $0.1 < $1.1 }
        let atZero = worst?.1 ?? 0
        var after = before
        if atZero > 0 {
            after += atZero * 3600
        } else if state.hunger > 0, state.mood > 0, state.energy > 0 {
            after = max(before - hours * 3600 * balance.neglectRecoveryFactor, 0)
        }
        state.neglectSeconds = after > 0 ? after : nil
        guard mortal else { return [] }
        let h = after / 3600, was = before / 3600
        if h >= balance.deathAfterNeglectHours, let cause = worst?.0 {
            state.diedAt = now
            state.deathCause = cause
            return [.died(cause)]
        }
        if h >= balance.dangerAfterNeglectHours, was < balance.dangerAfterNeglectHours { return [.neglect(level: 2)] }
        if h >= balance.warnAfterNeglectHours, was < balance.warnAfterNeglectHours { return [.neglect(level: 1)] }
        return []
    }

    /// Hours of neglect left before the pet dies at the current rate, or nil if nothing is at zero or dying is off.
    public var hoursUntilDeath: Double? {
        guard mortal, !state.isDead, state.stage != .egg, let n = state.neglectSeconds, n > 0 else { return nil }
        return max(balance.deathAfterNeglectHours - n / 3600, 0)
    }

    /// A fresh egg in place of a dead pet (or any pet): everything about the pet resets, the player's things stay.
    public mutating func startOver(at now: Date, name: String) {
        var fresh = PetState(now: now, calendar: calendar)
        fresh.name = name
        state = fresh
    }

    private mutating func clampStats() {
        state.hunger = min(max(state.hunger, 0), 100)
        state.mood = min(max(state.mood, 0), 100)
        state.energy = min(max(state.energy, 0), 100)
    }
}
