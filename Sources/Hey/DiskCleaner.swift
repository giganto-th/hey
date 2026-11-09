import AppKit
import Foundation
import Observation
import HeyDomain

/// Finds the places on disk that usually hold things safe to clear, sizes them in the background, and clears the ones that rebuild
/// themselves. Nothing is deleted without the person pressing a button and confirming.
@MainActor @Observable
final class DiskCleaner {
    struct Place: Identifiable, Equatable {
        enum Kind { case caches, xcode, homebrew, logs, trash, downloads }
        let kind: Kind
        let url: URL
        var bytes: Double?              // nil while it is being measured
        var id: String { url.path }

        var title: String {
            switch kind {
            case .caches: tr("แคชของแอป")
            case .xcode: tr("ไฟล์ build ของ Xcode")
            case .homebrew: tr("แคช Homebrew")
            case .logs: tr("ไฟล์บันทึก (log)")
            case .trash: tr("ถังขยะ")
            case .downloads: tr("ดาวน์โหลด")
            }
        }
        var symbol: String {
            switch kind {
            case .caches: "internaldrive"
            case .xcode: "hammer"
            case .homebrew: "shippingbox"
            case .logs: "doc.text"
            case .trash: "trash"
            case .downloads: "arrow.down.circle"
            }
        }
        /// Rebuilds by itself, so it can be cleared here. The rest only open in Finder: they hold things the person chose to keep.
        var clearable: Bool { kind == .xcode || kind == .homebrew }
    }

    private(set) var places: [Place] = []
    struct LargeFile: Identifiable, Equatable {
        let url: URL
        let bytes: Double
        let modified: Date?
        var id: URL { url }
    }

    private(set) var largeFiles: [LargeFile] = []
    private(set) var scanning = false
    private(set) var lastScan: Date?
    var message: String?

    var reclaimable: Double {
        places.filter { $0.kind != .downloads }.compactMap(\.bytes).reduce(0, +)
    }

    func scan() {
        guard !scanning else { return }
        scanning = true
        message = nil
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [(Place.Kind, URL)] = [
            (.xcode, home.appending(path: "Library/Developer/Xcode/DerivedData")),
            (.homebrew, home.appending(path: "Library/Caches/Homebrew")),      // inside Caches: measured first, then taken off Caches
            (.caches, home.appending(path: "Library/Caches")),
            (.logs, home.appending(path: "Library/Logs")),
            (.trash, home.appending(path: ".Trash")),
            (.downloads, home.appending(path: "Downloads")),
        ].filter { FileManager.default.fileExists(atPath: $0.1.path) }
        places = candidates.map { Place(kind: $0.0, url: $0.1, bytes: nil) }
        let downloads = home.appending(path: "Downloads")
        Task.detached(priority: .utility) {
            var brew = 0.0
            for (kind, url) in candidates {
                var bytes = Self.size(of: url)
                if kind == .homebrew { brew = bytes }
                if kind == .caches { bytes = max(bytes - brew, 0) }      // Homebrew's share is shown on its own line
                let measured = bytes
                await MainActor.run {
                    if let i = self.places.firstIndex(where: { $0.url == url }) { self.places[i].bytes = measured }
                }
            }
            let large = Self.largestFiles(in: downloads)
            await MainActor.run {
                self.largeFiles = large
                self.places.sort { ($0.bytes ?? -1) > ($1.bytes ?? -1) }
                self.scanning = false
                self.lastScan = Date()
            }
        }
    }

    func reveal(_ file: LargeFile) { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }

    /// Asks first, then moves the file to the Trash (it can be put back from there).
    func trash(_ file: LargeFile) {
        let alert = NSAlert()
        alert.messageText = tr("ย้าย {0} ไปถังขยะ?", file.url.lastPathComponent)
        alert.informativeText = tr("ไฟล์ขนาด {0} ยังเอากลับจากถังขยะได้จนกว่าจะเทถัง", ByteText.size(file.bytes))
        alert.addButton(withTitle: tr("ย้ายไปถังขยะ"))
        alert.addButton(withTitle: tr("ยกเลิก"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { try FileManager.default.trashItem(at: file.url, resultingItemURL: nil); largeFiles.removeAll { $0 == file } }
        catch { message = tr("ย้ายไม่ได้ {0} รายการ", 1) }
    }

    nonisolated private static func largestFiles(in folder: URL, minimum: Double = 100_000_000, limit: Int = 10) -> [LargeFile] {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey, .contentModificationDateKey]
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles], errorHandler: { _, _ in true }) else { return [] }
        var found: [LargeFile] = []
        for case let file as URL in walker {
            guard let v = try? file.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            let bytes = Double(v.totalFileAllocatedSize ?? 0)
            if bytes >= minimum { found.append(LargeFile(url: file, bytes: bytes, modified: v.contentModificationDate)) }
        }
        return Array(found.sorted { $0.bytes > $1.bytes }.prefix(limit))
    }

    func reveal(_ place: Place) { NSWorkspace.shared.activateFileViewerSelecting([place.url]) }

    /// Asks first, then moves what is inside to the Trash (so a mistake can still be undone from there).
    func clear(_ place: Place) {
        guard place.clearable else { return }
        let alert = NSAlert()
        alert.messageText = tr("ล้าง {0}?", place.title)
        alert.informativeText = tr("ย้ายไฟล์ข้างใน ({0}) ไปที่ถังขยะ ไฟล์พวกนี้สร้างขึ้นใหม่เองเมื่อต้องใช้", ByteText.size(place.bytes ?? 0))
        alert.addButton(withTitle: tr("ล้าง"))
        alert.addButton(withTitle: tr("ยกเลิก"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let url = place.url
        Task.detached(priority: .utility) {
            var failed = 0
            let items = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            for item in items {
                do { try FileManager.default.trashItem(at: item, resultingItemURL: nil) } catch { failed += 1 }
            }
            let count = failed
            await MainActor.run {
                self.message = count == 0 ? nil : tr("ย้ายไม่ได้ {0} รายการ", count)
                self.scanning = false
                self.scan()
            }
        }
    }

    nonisolated private static func size(of url: URL) -> Double {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) else { return 0 }
        var total = 0.0
        for case let file as URL in walker {
            guard let v = try? file.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            total += Double(v.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
