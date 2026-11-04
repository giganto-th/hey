import Foundation

/// Decodes an element if it can; a bad one becomes nil instead of failing the whole list.
private struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

public struct SaveData: Codable, Equatable, Sendable {
    public var version = 2
    public var pet: PetState
    public var coins = 20
    public var inventory: [String: Int] = [:]
    public var quests: [Quest] = []
    public var questDay: Date?
    public var streak = StreakState()
    public var reminders: [Reminder] = []
    public var notes: [Note] = []
    public var vault: [VaultItem] = []
    public var vaultSettings = VaultSettings()
    public var playlists: [Playlist] = []
    public var music = MusicSettings()
    public var media: [MediaItem] = []
    public var capture = CaptureSettings()
    public var power = PowerSettings()
    public var gestures = GestureSettings()
    /// Which art set the pet uses (`Resources/Sprites/<species>/`).
    public var species = "heihei"
    public var reactions = ReactionSettings()
    public var motion = MotionSettings()
    public var radialMenu = RadialMenuSettings()
    public var shelf: [ShelfItem] = []
    public var files = FileSettings()
    public var stats = LifetimeStats()
    public var achievements: [String: Date] = [:]
    public var guide = GuideState()

    public init(pet: PetState) { self.pet = pet }

    // Hand-written so a file saved by an older build (missing newer keys) still loads.
    private enum CodingKeys: String, CodingKey {
        case version, pet, coins, inventory, quests, questDay, streak, reminders, notes, vault, vaultSettings, playlists, music, media, capture, power, gestures, species, reactions, motion, radialMenu, shelf, files, stats, achievements, guide
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Only the pet is essential. Every other section falls back on its own, and a damaged list item is
        // skipped, so one bad entry (or a save from another version) can't cost the player everything.
        pet = try c.decode(PetState.self, forKey: .pet)
        func value<T: Decodable>(_ type: T.Type, _ key: CodingKeys, default fallback: T) -> T {
            ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        func list<T: Decodable>(_ type: T.Type, _ key: CodingKeys) -> [T] {
            ((try? c.decodeIfPresent([Lossy<T>].self, forKey: key)) ?? nil)?.compactMap(\.value) ?? []
        }
        version = value(Int.self, .version, default: 1)
        coins = value(Int.self, .coins, default: 20)
        inventory = value([String: Int].self, .inventory, default: [:])
        quests = list(Quest.self, .quests)
        questDay = value(Date?.self, .questDay, default: nil)
        streak = value(StreakState.self, .streak, default: StreakState())
        reminders = list(Reminder.self, .reminders)
        notes = list(Note.self, .notes)
        vault = list(VaultItem.self, .vault)
        vaultSettings = value(VaultSettings.self, .vaultSettings, default: VaultSettings())
        playlists = list(Playlist.self, .playlists)
        music = value(MusicSettings.self, .music, default: MusicSettings())
        media = list(MediaItem.self, .media)
        capture = value(CaptureSettings.self, .capture, default: CaptureSettings())
        power = value(PowerSettings.self, .power, default: PowerSettings())
        gestures = value(GestureSettings.self, .gestures, default: GestureSettings())
        reactions = value(ReactionSettings.self, .reactions, default: ReactionSettings())
        motion = value(MotionSettings.self, .motion, default: MotionSettings())
        radialMenu = value(RadialMenuSettings.self, .radialMenu, default: RadialMenuSettings())
        shelf = list(ShelfItem.self, .shelf)
        files = value(FileSettings.self, .files, default: FileSettings())
        stats = value(LifetimeStats.self, .stats, default: LifetimeStats())
        achievements = value([String: Date].self, .achievements, default: [:])
        guide = value(GuideState.self, .guide, default: GuideState())
        let saved = (try? c.decodeIfPresent(String.self, forKey: .species)) ?? nil
        // v2 restores Hei Hei. Keep custom names and unknown species intact.
        let migrate = saved == nil || (version < 2 && saved == "tok")
        species = migrate ? "heihei" : (saved ?? "heihei")
        if version < 2, saved == nil || saved == "tok" || saved == "heihei",
           ["Hey", "ต๊อก", "Tok"].contains(pet.name) { pet.name = "Hei Hei" }
        // names this species had while it was being named
        if species == "fluff", ["Jiab", "ฟู"].contains(pet.name) { pet.name = "Foo" }
        version = max(version, 2)
    }

    /// Reads the current format, or the old M2 file that held only a `PetState`.
    public static func decode(_ data: Data) throws -> SaveData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let save = try? decoder.decode(SaveData.self, from: data) { return save }
        return SaveData(pet: try decoder.decode(PetState.self, from: data))
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

/// Everything the player owns and has progressed in. Pure and clock-free.
public struct Game: Sendable {
    public static let dayStartsAtHour = 4
    public static let questsPerDay = 3
    public static let allDoneBonus = 20
    public static let streakBonusEvery = 7
    public static let streakBonus = 50

    public private(set) var pet: PetEngine
    public private(set) var coins: Int
    public private(set) var inventory: [String: Int]
    public private(set) var quests: [Quest]
    public private(set) var questDay: Date?
    public private(set) var streak: StreakState
    public private(set) var reminders: [Reminder]
    public private(set) var notes: [Note]
    public private(set) var vault: [VaultItem]
    public private(set) var vaultSettings: VaultSettings
    public private(set) var playlists: [Playlist]
    public private(set) var music: MusicSettings
    public private(set) var media: [MediaItem]
    public private(set) var capture: CaptureSettings
    public private(set) var power: PowerSettings
    public private(set) var gestures: GestureSettings
    public private(set) var species: String
    public private(set) var reactions: ReactionSettings
    public private(set) var motion: MotionSettings
    public private(set) var radialMenu: RadialMenuSettings
    public private(set) var shelf: [ShelfItem]
    public private(set) var files: FileSettings
    public private(set) var stats: LifetimeStats
    public private(set) var achievements: [String: Date]
    public private(set) var guide: GuideState

    private var calendar: Calendar
    private var rng: any RandomSource

    public init(
        save: SaveData,
        balance: Balance = .standard,
        calendar: Calendar = .current,
        rng: any RandomSource = SystemRandom()
    ) {
        pet = PetEngine(state: save.pet, balance: balance, calendar: calendar, rng: rng)
        coins = save.coins
        inventory = save.inventory
        quests = save.quests
        questDay = save.questDay
        streak = save.streak
        reminders = save.reminders
        notes = save.notes
        vault = save.vault
        vaultSettings = save.vaultSettings
        playlists = save.playlists
        music = save.music
        media = save.media
        capture = save.capture
        power = save.power
        gestures = save.gestures
        species = save.species
        reactions = save.reactions
        motion = save.motion
        radialMenu = save.radialMenu
        shelf = save.shelf
        files = save.files
        stats = save.stats
        achievements = save.achievements
        guide = save.guide
        self.calendar = calendar
        self.rng = rng
    }

    public var save: SaveData {
        var s = SaveData(pet: pet.state)
        s.coins = coins
        s.inventory = inventory
        s.quests = quests
        s.questDay = questDay
        s.streak = streak
        s.reminders = reminders
        s.notes = notes
        s.vault = vault
        s.vaultSettings = vaultSettings
        s.playlists = playlists
        s.music = music
        s.media = media
        s.capture = capture
        s.power = power
        s.gestures = gestures
        s.species = species
        s.reactions = reactions
        s.motion = motion
        s.radialMenu = radialMenu
        s.shelf = shelf
        s.files = files
        s.stats = stats
        s.achievements = achievements
        s.guide = guide
        return s
    }

    public func stock(of food: Food) -> Int { food.price == 0 ? .max : inventory[food.id, default: 0] }

    // MARK: session / time

    /// Call once at launch: applies time spent closed, rolls the day, checks in.
    public mutating func startSession(at now: Date) -> [GameEvent] {
        var events = advance(to: now, sleeping: true)
        events += pet.dailyCheckIn(at: now).map(GameEvent.pet)
        events += record(.checkedIn)
        return events
    }

    public mutating func advance(to now: Date, sleeping: Bool) -> [GameEvent] {
        var events = rollQuestsIfNeeded(now)
        events += expireVault(at: now)
        expireShelf(at: now)
        let before = pet.state.lastTickAt
        events += pet.advance(to: now, sleeping: sleeping).map(GameEvent.pet)
        let elapsed = now.timeIntervalSince(before)
        if elapsed > 0, elapsed <= pet.balance.offlineGap {
            events += record(.online(minutes: elapsed / 60))
        }
        return events
    }

    // MARK: actions

    public mutating func pet(at now: Date) -> [GameEvent] {
        let wasEgg = pet.state.stage == .egg
        var events = pet.pet(at: now).map(GameEvent.pet)
        if !wasEgg { stats.pets += 1 }
        events += record(wasEgg ? .warmed : .petted)
        return events
    }

    public mutating func feed(_ food: Food, at now: Date) -> [GameEvent] {
        if food.price > 0, inventory[food.id, default: 0] <= 0, pet.state.stage != .egg {
            return [.noStock(food)]
        }
        let result = pet.feed(food, at: now)
        var events = result.map(GameEvent.pet)
        if result.contains(.fed(food)) {
            if food.price > 0 { inventory[food.id, default: 0] -= 1 }
            stats.feeds += 1
            events += record(.fed(food.id))
        }
        return events
    }

    public mutating func buy(_ food: Food) -> [GameEvent] {
        guard food.price > 0 else { return [] }
        guard coins >= food.price else { return [.insufficientCoins(food)] }
        coins -= food.price
        inventory[food.id, default: 0] += 1
        return [.bought(food)]
    }

    public mutating func grantCoins(_ amount: Int) { coins += amount }

    public mutating func grantXP(_ amount: Double) -> [GameEvent] {
        pet.grantXP(amount).map(GameEvent.pet)
    }

    public mutating func grantWarmth(_ amount: Double) -> [GameEvent] {
        pet.grantWarmth(amount).map(GameEvent.pet)
    }

    // MARK: reminders

    public static let nagInterval: TimeInterval = 300
    public static let maxNags = 3

    @discardableResult
    public mutating func addReminder(
        _ text: String, at fire: Date, repeat rule: RepeatRule = .none, now: Date
    ) -> [GameEvent] {
        stats.remindersSet += 1
        reminders.append(Reminder(text: text, anchor: fire, nextFire: fire, repeatRule: rule, createdAt: now))
        return record(.reminderSet)
    }

    public mutating func removeReminder(id: UUID) {
        reminders.removeAll { $0.id == id }
    }

    /// Rings everything that is due. Unacknowledged reminders ring again every 5 minutes, up to 3 times.
    public mutating func dueReminders(at now: Date) -> [GameEvent] {
        var events: [GameEvent] = []
        for i in reminders.indices where reminders[i].isActive && reminders[i].nextFire <= now {
            reminders[i].ringing = true
            reminders[i].nags += 1
            reminders[i].nextFire = reminders[i].nags < Self.maxNags
                ? now.addingTimeInterval(Self.nagInterval) : .distantFuture
            events.append(.reminderDue(reminders[i]))
        }
        return events
    }

    public mutating func acknowledgeReminder(id: UUID, at now: Date) {
        guard let i = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[i].ringing = false
        reminders[i].nags = 0
        if reminders[i].repeatRule == .none {
            reminders[i].doneAt = now
        } else {
            let next = nextOccurrence(after: now, of: reminders[i])
            reminders[i].anchor = next
            reminders[i].nextFire = next
        }
    }

    public mutating func snoozeReminder(id: UUID, minutes: Int, at now: Date) {
        guard let i = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[i].ringing = false
        reminders[i].nags = 0
        reminders[i].nextFire = now.addingTimeInterval(Double(minutes) * 60)
    }

    private func nextOccurrence(after now: Date, of r: Reminder) -> Date {
        switch r.repeatRule {
        case .none:
            return r.anchor
        case .everyMinutes(let n):
            let step = Double(max(n, 1)) * 60
            let k = (now.timeIntervalSince(r.anchor) / step).rounded(.down) + 1
            return r.anchor.addingTimeInterval(max(k, 1) * step)
        case .daily, .weekly:
            let unit: Calendar.Component = r.repeatRule == .daily ? .day : .weekOfYear
            var next = r.anchor
            while next <= now { next = calendar.date(byAdding: unit, value: 1, to: next) ?? next.addingTimeInterval(86_400) }
            return next
        }
    }

    // MARK: pomodoro

    /// Credit a finished focus round: quest progress plus a little XP.
    public mutating func creditPomodoro(session: Int) -> [GameEvent] {
        stats.pomodoros += 1
        var events: [GameEvent] = [.pomodoroCredited(session: session)]
        events += pet.grantXP(5).map(GameEvent.pet)
        events += record(.pomodoro)
        return events
    }

    // MARK: notes

    @discardableResult
    public mutating func addNote(pinned: Bool = false, now: Date) -> UUID {
        let note = Note(colorIndex: notes.count % 4, pinned: pinned, createdAt: now, updatedAt: now)
        notes.insert(note, at: 0)
        return note.id
    }

    public mutating func updateNote(id: UUID, text: String, now: Date) {
        guard let i = notes.firstIndex(where: { $0.id == id }), notes[i].text != text else { return }
        notes[i].text = text
        notes[i].updatedAt = now
    }

    public mutating func setNote(id: UUID, pinned: Bool) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].pinned = pinned
    }

    public mutating func moveNote(id: UUID, x: Double, y: Double) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].x = x
        notes[i].y = y
    }

    public mutating func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
    }

    // MARK: vault

    public func vaultItem(id: UUID) -> VaultItem? { vault.first { $0.id == id } }

    public var vaultTags: [String] {
        Array(Set(vault.flatMap(\.tags))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Every word must match the name, text, path or a tag. Pinned first, then newest.
    public func searchVault(_ query: String = "", tag: String? = nil) -> [VaultItem] {
        let tokens = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return vault
            .filter { item in
                (tag == nil || item.tags.contains { $0.caseInsensitiveCompare(tag!) == .orderedSame })
                    && item.matches(tokens)
            }
            .sorted { ($0.pinned ? 0 : 1, -$0.addedAt.timeIntervalSince1970) < ($1.pinned ? 0 : 1, -$1.addedAt.timeIntervalSince1970) }
    }

    /// Adds an item. The same file can't be referenced twice; copies are snapshots so they may repeat.
    public mutating func addVaultItem(_ item: VaultItem) -> [GameEvent] {
        var item = item
        if item.mode == .reference, let path = item.sourcePath,
           let existing = vault.first(where: { $0.mode == .reference && $0.sourcePath == path }) {
            return [.vaultDuplicate(existing)]
        }
        if item.expiresAt == nil, let days = vaultSettings.defaultExpiryDays {
            item.expiresAt = calendar.date(byAdding: .day, value: days, to: item.addedAt)
        }
        vault.insert(item, at: 0)
        stats.vaultAdds += 1
        return [.vaultAdded(item)] + record(.vaultAdded)
    }

    public mutating func removeVaultItem(id: UUID) -> [GameEvent] {
        guard let i = vault.firstIndex(where: { $0.id == id }) else { return [] }
        return [.vaultRemoved([vault.remove(at: i)])]
    }

    public mutating func setVaultPinned(id: UUID, _ pinned: Bool) {
        guard let i = vault.firstIndex(where: { $0.id == id }) else { return }
        vault[i].pinned = pinned
    }

    /// Trims, drops empties and duplicates (ignoring case), keeps the first spelling.
    public mutating func setVaultTags(id: UUID, _ tags: [String]) {
        guard let i = vault.firstIndex(where: { $0.id == id }) else { return }
        var seen = Set<String>()
        vault[i].tags = tags
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    public mutating func setVaultExpiry(id: UUID, days: Int?, now: Date) {
        guard let i = vault.firstIndex(where: { $0.id == id }) else { return }
        vault[i].expiresAt = days.flatMap { calendar.date(byAdding: .day, value: $0, to: now) }
    }

    public mutating func setVaultPolicy(_ policy: VaultPolicy) { vaultSettings.policy = policy }
    public mutating func setVaultDefaultExpiry(days: Int?) { vaultSettings.defaultExpiryDays = days }

    /// Removes expired items that aren't pinned.
    public mutating func expireVault(at now: Date) -> [GameEvent] {
        let gone = vault.filter { !$0.pinned && ($0.expiresAt.map { $0 <= now } ?? false) }
        guard !gone.isEmpty else { return [] }
        let ids = Set(gone.map(\.id))
        vault.removeAll { ids.contains($0.id) }
        return [.vaultRemoved(gone)]
    }

    // MARK: shelf (temporary tray)

    public static let shelfLimit = 30

    /// Puts something on the shelf. A file or folder already there just moves to the front.
    public mutating func addToShelf(_ item: ShelfItem) -> [GameEvent] {
        var item = item
        if let path = item.path, let i = shelf.firstIndex(where: { $0.path == path }) {
            item.id = shelf[i].id
            shelf.remove(at: i)
        }
        shelf.insert(item, at: 0)
        if shelf.count > Self.shelfLimit { shelf.removeLast(shelf.count - Self.shelfLimit) }
        return [.shelfAdded(item)]
    }

    public mutating func removeFromShelf(id: UUID) { shelf.removeAll { $0.id == id } }

    public mutating func clearShelf() { shelf.removeAll() }

    private mutating func expireShelf(at now: Date) {
        guard files.shelfExpireHours > 0 else { return }
        let limit = Double(files.shelfExpireHours) * 3600
        shelf.removeAll { now.timeIntervalSince($0.addedAt) > limit }
    }

    public mutating func setFiles(_ change: (inout FileSettings) -> Void) {
        change(&files)
        files.shelfExpireHours = min(max(files.shelfExpireHours, 0), 24 * 7)
    }

    // MARK: music

    public func playlist(id: UUID?) -> Playlist? {
        guard let id else { return nil }
        return playlists.first { $0.id == id }
    }

    /// The playlist the player is pointed at, falling back to the first one.
    public var currentPlaylist: Playlist? { playlist(id: music.playlistID) ?? playlists.first }

    @discardableResult
    public mutating func createPlaylist(_ name: String) -> UUID {
        let clean = name.trimmingCharacters(in: .whitespaces)
        let list = Playlist(name: clean.isEmpty ? "เพลย์ลิสต์ใหม่" : clean)
        playlists.append(list)
        music.playlistID = list.id
        return list.id
    }

    public mutating func renamePlaylist(id: UUID, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty, let i = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[i].name = clean
    }

    public mutating func deletePlaylist(id: UUID) {
        playlists.removeAll { $0.id == id }
        if music.playlistID == id { music.playlistID = playlists.first?.id }
    }

    /// The same YouTube video or local file can't be in one playlist twice.
    public mutating func addTrack(_ track: Track, to playlistID: UUID) -> [GameEvent] {
        guard let i = playlists.firstIndex(where: { $0.id == playlistID }) else { return [] }
        if let dup = playlists[i].tracks.first(where: { $0.source == track.source || (isSameFile($0, track)) }) {
            return [.trackDuplicate(dup)]
        }
        playlists[i].tracks.append(track)
        return [.trackAdded(track)]
    }

    private func isSameFile(_ a: Track, _ b: Track) -> Bool {
        if case .file(let p, _) = a.source, case .file(let q, _) = b.source { return p == q }
        return false
    }

    public mutating func removeTrack(id: UUID, from playlistID: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[i].tracks.removeAll { $0.id == id }
    }

    public mutating func moveTrack(in playlistID: UUID, from: Int, to: Int) {
        guard let i = playlists.firstIndex(where: { $0.id == playlistID }),
              playlists[i].tracks.indices.contains(from), playlists[i].tracks.indices.contains(to) else { return }
        let t = playlists[i].tracks.remove(at: from)
        playlists[i].tracks.insert(t, at: to)
    }

    /// Fills in details that arrive after a track was added (oEmbed title, file tags, duration).
    public mutating func updateTrack(id: UUID, title: String?, artist: String?, thumbnailURL: String?, duration: Double?) {
        for p in playlists.indices {
            guard let t = playlists[p].tracks.firstIndex(where: { $0.id == id }) else { continue }
            if let title, !title.isEmpty { playlists[p].tracks[t].title = title }
            if let artist, !artist.isEmpty { playlists[p].tracks[t].artist = artist }
            if let thumbnailURL { playlists[p].tracks[t].thumbnailURL = thumbnailURL }
            if let duration, duration > 0 { playlists[p].tracks[t].duration = duration }
        }
    }

    public mutating func setMusic(_ change: (inout MusicSettings) -> Void) {
        change(&music)
        music.volume = min(max(music.volume, 0), 1)
    }

    /// Called about once a minute while something is playing.
    public mutating func recordListening(minutes: Double) -> [GameEvent] {
        stats.musicMinutes += minutes
        return record(.music(minutes: minutes))
    }

    // MARK: media

    /// Newest first.
    public mutating func addMedia(_ item: MediaItem) -> [GameEvent] {
        media.insert(item, at: 0)
        stats.captures += 1
        media.sort { $0.createdAt > $1.createdAt }
        return [.mediaAdded(item)] + record(.captured)
    }

    public mutating func removeMedia(id: UUID) -> [GameEvent] {
        guard let i = media.firstIndex(where: { $0.id == id }) else { return [] }
        return [.mediaRemoved(media.remove(at: i))]
    }

    public mutating func setCapture(_ change: (inout CaptureSettings) -> Void) {
        change(&capture)
        capture.countdown = min(max(capture.countdown, 0), 10)
    }

    public mutating func setGestures(_ change: (inout GestureSettings) -> Void) {
        change(&gestures)
        gestures.clamp()
    }

    public mutating func setReactions(_ change: (inout ReactionSettings) -> Void) { change(&reactions) }
    public mutating func setRadialMenu(_ change: (inout RadialMenuSettings) -> Void) { change(&radialMenu) }
    public mutating func renamePet(_ name: String) { pet.rename(name) }

    /// Switches the art set. A name still at the old species' default follows along; a name the user chose stays.
    public mutating func setSpecies(_ id: String) {
        guard id != species, let next = PetSpecies.named(id) else { return }
        if pet.state.name == PetSpecies.named(species)?.defaultName { pet.rename(next.defaultName) }
        species = id
    }
    public mutating func setMotion(_ change: (inout MotionSettings) -> Void) { change(&motion) }

    public mutating func setPower(_ change: (inout PowerSettings) -> Void) {
        change(&power)
        power.dormantAfterIdleMinutes = min(max(power.dormantAfterIdleMinutes, 0), 120)
        power.saverBelowBatteryPercent = min(max(power.saverBelowBatteryPercent, 5), 80)
    }

    // MARK: first-run guide

    /// The next tip to show, if any. The tip counts as seen from here on.
    public mutating func nextGuideTip() -> GuideTip? {
        guard let tip = GuideTip.allCases.first(where: { !guide.seen.contains($0.rawValue) && $0.applies(to: pet.state.stage) }) else { return nil }
        guide.seen.insert(tip.rawValue)
        return tip
    }

    // MARK: achievements and the mini-game

    /// Unlocks anything newly earned and pays its coins. Safe to call after every change.
    public mutating func checkAchievements(at now: Date) -> [GameEvent] {
        var events: [GameEvent] = []
        for a in Achievement.all where achievements[a.id] == nil && a.progress(self) >= a.goal {
            achievements[a.id] = now
            coins += a.reward
            events.append(.achievementUnlocked(a.info))
        }
        return events
    }

    public func miniGamePlaysLeft(at now: Date) -> Int {
        guard let day = stats.miniGameDay, day == dayKey(now) else { return MiniGame.maxRewardedPlaysPerDay }
        return max(MiniGame.maxRewardedPlaysPerDay - stats.miniGamePlaysToday, 0)
    }

    /// Plays beyond the daily limit are still fun but earn nothing, so coins can't be farmed.
    public mutating func finishMiniGame(score: Int, at now: Date) -> [GameEvent] {
        let today = dayKey(now)
        if stats.miniGameDay != today { stats.miniGameDay = today; stats.miniGamePlaysToday = 0 }
        let paid = stats.miniGamePlaysToday < MiniGame.maxRewardedPlaysPerDay
        stats.miniGamePlaysToday += 1
        stats.miniGameBest = max(stats.miniGameBest, score)
        let reward = paid ? MiniGame.reward(score: score) : 0
        coins += reward
        return [.miniGameFinished(score: score, reward: reward)]
    }

    // MARK: quests

    private enum QuestEvent {
        case fed(String), petted, warmed, online(minutes: Double), checkedIn, pomodoro, reminderSet, vaultAdded
        case music(minutes: Double), captured
    }

    private func dayKey(_ date: Date) -> Date {
        calendar.startOfDay(for: date.addingTimeInterval(-Double(Self.dayStartsAtHour) * 3600))
    }

    private mutating func rollQuestsIfNeeded(_ now: Date) -> [GameEvent] {
        let today = dayKey(now)
        if let day = questDay, day >= today { return [] }   // same day, or clock went back
        questDay = today
        var pool = Quest.templates(for: pet.state.stage)
        var picked: [Quest] = []
        while picked.count < Self.questsPerDay, !pool.isEmpty {
            let i = min(Int(rng.next(in: 0...Double(pool.count))), pool.count - 1)
            var q = pool.remove(at: i)
            q.id = "\(q.kind.rawValue)-\(Int(today.timeIntervalSince1970))"
            picked.append(q)
        }
        quests = picked
        return []
    }

    private mutating func record(_ event: QuestEvent) -> [GameEvent] {
        var out: [GameEvent] = []
        var completedNow = false

        for i in quests.indices where !quests[i].done {
            switch (quests[i].kind, event) {
            case (.feed, .fed): quests[i].progress += 1
            case (.variety, .fed(let id)):
                if !quests[i].seen.contains(id) { quests[i].seen.append(id); quests[i].progress += 1 }
            case (.pet, .petted): quests[i].progress += 1
            case (.warm, .warmed): quests[i].progress += 1
            case (.online, .online(let m)): quests[i].progress += m
            case (.checkIn, .checkedIn): quests[i].progress = quests[i].target
            case (.pomodoro, .pomodoro): quests[i].progress += 1
            case (.reminder, .reminderSet): quests[i].progress += 1
            case (.vault, .vaultAdded): quests[i].progress += 1
            case (.music, .music(let m)): quests[i].progress += m
            case (.capture, .captured): quests[i].progress += 1
            default: continue
            }
            guard quests[i].progress >= quests[i].target else { continue }
            quests[i].progress = quests[i].target
            quests[i].done = true
            completedNow = true
            stats.questsDone += 1
            coins += quests[i].rewardCoins
            out.append(.questCompleted(quests[i]))
            if quests[i].rewardXP > 0 {
                out += pet.grantXP(quests[i].rewardXP).map(GameEvent.pet)
            }
        }

        if completedNow {
            out += markActiveToday()
            if !quests.isEmpty, quests.allSatisfy(\.done) {
                coins += Self.allDoneBonus
                out.append(.allQuestsDone(bonus: Self.allDoneBonus))
            }
        }
        return out
    }

    /// Streak counts days with at least one finished quest. Missing days halves it instead of zeroing.
    private mutating func markActiveToday() -> [GameEvent] {
        guard let today = questDay, streak.lastActiveDay != today else { return [] }
        if let last = streak.lastActiveDay,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: today), last == yesterday {
            streak.current += 1
        } else if streak.lastActiveDay == nil {
            streak.current = 1
        } else {
            streak.current = streak.current / 2 + 1
        }
        streak.lastActiveDay = today
        streak.best = max(streak.best, streak.current)

        var bonus = 0
        if streak.current % Self.streakBonusEvery == 0 {
            bonus = Self.streakBonus
            coins += bonus
        }
        return [.streak(days: streak.current, bonus: bonus)]
    }
}
