import AppKit
import HeyDomain

/// Export the whole data folder (the save, the vault copies) to one .zip, and bring such a backup back.
@MainActor
enum BackupService {
    enum BackupError: Error { case notABackup, failed(String)
        var message: String {
            switch self {
            case .notABackup: tr("ไฟล์นี้ไม่ใช่ไฟล์สำรองของ Hey!")
            case .failed(let why): tr("ทำไม่สำเร็จ: {0}", why)
            }
        }
    }

    /// Write `Hey-backup-<date>.zip` to `url`.
    static func export(from directory: URL, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        let status = run("/usr/bin/ditto", ["-c", "-k", "--keepParent", directory.path, url.path])
        guard status == 0 else { throw BackupError.failed("ditto \(status)") }
    }

    /// Unpack a backup next to the data folder and check that its save can be read. Returns the unpacked folder.
    static func prepareImport(zip: URL, into directory: URL) throws -> URL {
        let staging = directory.deletingLastPathComponent().appendingPathComponent("Hey-import-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        guard run("/usr/bin/ditto", ["-x", "-k", zip.path, staging.path]) == 0 else {
            try? FileManager.default.removeItem(at: staging); throw BackupError.notABackup
        }
        // the archive holds one folder (the data folder's name); find the save inside it
        let found = (FileManager.default.enumerator(at: staging, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
            .first { $0.lastPathComponent == "pet.json" }
        guard let save = found, let data = try? Data(contentsOf: save), (try? SaveData.decode(data)) != nil else {
            try? FileManager.default.removeItem(at: staging); throw BackupError.notABackup
        }
        return save.deletingLastPathComponent()
    }

    /// Replace the current data with the unpacked backup. The old data is kept next to it as `Hey-before-restore`.
    static func applyImport(_ unpacked: URL, to directory: URL) throws {
        let fm = FileManager.default
        let parent = directory.deletingLastPathComponent()
        let old = parent.appendingPathComponent("Hey-before-restore")
        try? fm.removeItem(at: old)
        try fm.moveItem(at: directory, to: old)
        do { try fm.moveItem(at: unpacked, to: directory) }
        catch { try? fm.moveItem(at: old, to: directory); throw BackupError.failed(error.localizedDescription) }
        // the lock file belongs to this running copy
        try? fm.removeItem(at: directory.appendingPathComponent(".lock"))
        if let leftover = try? fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil).filter({ $0.lastPathComponent.hasPrefix("Hey-import-") }) {
            leftover.forEach { try? fm.removeItem(at: $0) }
        }
    }

    private static func run(_ path: String, _ args: [String]) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        task.standardOutput = Pipe(); task.standardError = Pipe()
        guard (try? task.run()) != nil else { return -1 }
        task.waitUntilExit()
        return task.terminationStatus
    }
}
