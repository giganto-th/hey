import AppKit
import HeyDomain

/// What was dropped on the pet (or the Hub).
enum DropPayload {
    case files([URL])
    case links([URL])
    case text(String)

    init?(from pasteboard: NSPasteboard) {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            self = .files(urls)
        } else if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
                  !urls.isEmpty, urls.allSatisfy({ ["http", "https"].contains($0.scheme?.lowercased()) }) {
            self = .links(urls)
        } else if let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty {
            if let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased()), !text.contains(" ") {
                self = .links([url])
            } else {
                self = .text(text)
            }
        } else {
            return nil
        }
    }
}

/// Moves dropped things into the vault: copies files into our folder or remembers where they are.
@MainActor
final class VaultService {
    private let model: GameModel
    let root: URL
    var onMessage: ((String) -> Void)?

    init(model: GameModel) {
        self.model = model
        root = model.directory.appendingPathComponent("Vault", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func add(_ payload: DropPayload) {
        Task { await ingest(payload) }
    }

    private func ingest(_ payload: DropPayload) async {
        let now = Date()
        var items: [VaultItem] = []
        var failures: [String] = []

        switch payload {
        case .files(let urls):
            let policy = model.game.vaultSettings.policy
            for url in urls {
                if let item = await makeFileItem(url, policy: policy, now: now) { items.append(item) }
                else { failures.append(url.lastPathComponent) }
            }
        case .links(let urls):
            items = urls.map {
                var item = VaultItem(kind: .link, mode: .copy, name: ($0.host ?? "") + $0.path, text: $0.absoluteString, addedAt: now)
                if item.name.isEmpty { item.name = $0.absoluteString }
                return item
            }
        case .text(let text):
            let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
            items = [VaultItem(kind: .text, mode: .copy, name: String(firstLine.prefix(40)), text: text, addedAt: now)]
        }

        if !items.isEmpty {
            model.perform { game in items.flatMap { game.addVaultItem($0) } }
            // A rejected duplicate leaves a copy we just made with no owner; clean it up.
            for item in items where item.mode == .copy && model.game.vaultItem(id: item.id) == nil { deleteFiles(of: item) }
        }
        if !failures.isEmpty { onMessage?("เก็บไม่สำเร็จ: \(failures.joined(separator: ", ").prefix(24))") }
    }

    private func makeFileItem(_ url: URL, policy: VaultPolicy, now: Date) async -> VaultItem? {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        let isDir = values?.isDirectory ?? false
        let size = Int64(values?.fileSize ?? 0)
        let mode = policy.mode(isFolder: isDir, size: size)

        var item = VaultItem(kind: isDir ? .folder : .file, mode: mode, name: url.lastPathComponent,
                             sourcePath: url.path, size: isDir ? nil : size, addedAt: now)
        item.bookmark = try? url.bookmarkData()

        guard mode == .copy else { return item }
        let folder = root.appendingPathComponent(item.id.uuidString, isDirectory: true)
        let dest = folder.appendingPathComponent(url.lastPathComponent)
        do {
            try await Task.detached {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: url, to: dest)
            }.value
            item.storedName = url.lastPathComponent
            return item
        } catch {
            try? FileManager.default.removeItem(at: folder)
            return nil
        }
    }

    // MARK: lookup

    /// Where the file is now, or nil if it is gone (moved, deleted, drive unplugged).
    func resolve(_ item: VaultItem) -> URL? {
        let fm = FileManager.default
        switch item.mode {
        case .copy:
            guard let name = item.storedName else { return nil }
            let url = root.appendingPathComponent(item.id.uuidString).appendingPathComponent(name)
            return fm.fileExists(atPath: url.path) ? url : nil
        case .reference:
            if let path = item.sourcePath, fm.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
            guard let data = item.bookmark else { return nil }
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withoutUI], relativeTo: nil,
                                  bookmarkDataIsStale: &stale), fm.fileExists(atPath: url.path) {
                return url
            }
            return nil
        }
    }

    func deleteFiles(of item: VaultItem) {
        guard item.mode == .copy, item.storedName != nil else { return }
        try? FileManager.default.removeItem(at: root.appendingPathComponent(item.id.uuidString))
    }

    func open(_ item: VaultItem) {
        switch item.kind {
        case .file, .folder:
            if let url = resolve(item) { NSWorkspace.shared.open(url) }
        case .link:
            if let text = item.text, let url = URL(string: text) { NSWorkspace.shared.open(url) }
        case .text:
            copyToClipboard(item)
        }
    }

    func reveal(_ item: VaultItem) {
        if let url = resolve(item) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    func copyToClipboard(_ item: VaultItem) {
        guard let text = item.text else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
