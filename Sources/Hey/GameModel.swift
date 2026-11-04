import Foundation
import Observation
import HeyDomain

/// The single owner of `Game` in the app. The pet scene and the Hub both go through it,
/// so every change is saved and reported as events (bubbles) no matter where it started.
@MainActor
@Observable
final class GameModel {
    private(set) var game: Game
    @ObservationIgnored private var observers: [([GameEvent]) -> Void] = []
    /// Called after every change, whatever its events (used to keep floating windows in sync).
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let url: URL
    @ObservationIgnored private var saveWork: DispatchWorkItem?
    /// Folder holding the save file and the vault copies.
    @ObservationIgnored let directory: URL

    /// Where the save lives (`HEY_DATA_DIR` lets tests use a copy).
    static func dataDirectory() -> URL {
        let fm = FileManager.default
        let base: URL
        if let override = ProcessInfo.processInfo.environment["HEY_DATA_DIR"] {
            base = URL(fileURLWithPath: override)
        } else {
            base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Hey", isDirectory: true)
        }
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    init() {
        let base = Self.dataDirectory()
        directory = base
        url = base.appendingPathComponent("pet.json")   // same file as M2; SaveData.decode migrates it
        game = Game(save: Self.load(url) ?? SaveData(pet: PetState()))
    }

    func observe(_ handler: @escaping ([GameEvent]) -> Void) { observers.append(handler) }

    /// Run a change, save it, and announce the resulting events.
    @discardableResult
    func perform(_ body: (inout Game) -> [GameEvent]) -> [GameEvent] {
        var events = body(&game)
        events += game.checkAchievements(at: Date())
        save()
        announce(events)
        return events
    }

    /// For ticks that rarely change anything worth saving right away.
    func performQuietly(_ body: (inout Game) -> [GameEvent]) {
        var events = body(&game)
        events += game.checkAchievements(at: Date())
        if !events.isEmpty { save() }
        announce(events)
    }

    private func announce(_ events: [GameEvent]) {
        if !events.isEmpty { for o in observers { o(events) } }
        onChange?()
    }

    /// Saves shortly, so a burst of changes (typing in a note, dragging a slider) writes the file once.
    func save() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.flush() } }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Saves right now (used when quitting).
    func flush() {
        saveWork?.cancel()
        saveWork = nil
        do {
            try game.save.encoded().write(to: url, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("[Hey] save failed: \(error)\n".utf8))
        }
    }

    private static let backupGenerations = 3

    private static func backupURL(_ url: URL, _ n: Int) -> URL {
        url.deletingLastPathComponent().appendingPathComponent("pet.backup.\(n).json")
    }

    /// Loads the save, or the newest backup that can still be read. Keeps a few generations of backups.
    private static func load(_ url: URL) -> SaveData? {
        let fm = FileManager.default
        guard let data = try? Data(contentsOf: url) else { return restoreFromBackup(url) }
        do {
            let save = try SaveData.decode(data)
            for n in stride(from: backupGenerations, to: 1, by: -1) {
                try? fm.removeItem(at: backupURL(url, n))
                try? fm.moveItem(at: backupURL(url, n - 1), to: backupURL(url, n))
            }
            try? fm.removeItem(at: backupURL(url, 1))
            try? fm.copyItem(at: url, to: backupURL(url, 1))
            return save
        } catch {
            // Keep the unreadable file instead of silently overwriting it.
            let bad = url.deletingLastPathComponent()
                .appendingPathComponent("pet.corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? fm.moveItem(at: url, to: bad)
            FileHandle.standardError.write(Data("[Hey] save unreadable, moved to \(bad.lastPathComponent): \(error)\n".utf8))
            return restoreFromBackup(url)
        }
    }

    private static func restoreFromBackup(_ url: URL) -> SaveData? {
        for n in 1...backupGenerations {
            if let data = try? Data(contentsOf: backupURL(url, n)), let save = try? SaveData.decode(data) {
                FileHandle.standardError.write(Data("[Hey] restored from backup \(n)\n".utf8))
                return save
            }
        }
        return nil
    }
}
