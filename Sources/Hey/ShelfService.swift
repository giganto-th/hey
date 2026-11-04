import AppKit
import HeyDomain

/// The shelf: a temporary tray. Holds *references* to what you give it, so you can drag it somewhere else.
@MainActor
final class ShelfService {
    private let model: GameModel
    var onAdded: (() -> Void)?

    init(model: GameModel) { self.model = model }

    func add(_ payload: DropPayload) {
        let now = Date()
        var items: [ShelfItem] = []
        switch payload {
        case .files(let urls):
            for url in urls {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                items.append(ShelfItem(kind: isDir ? .folder : .file, name: url.lastPathComponent, path: url.path, addedAt: now))
            }
        case .links(let urls):
            items = urls.map { url in
                var name = (url.host ?? "") + url.path
                if name.isEmpty { name = url.absoluteString }
                return ShelfItem(kind: .link, name: name, text: url.absoluteString, addedAt: now)
            }
        case .text(let text):
            let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
            items = [ShelfItem(kind: .text, name: String(firstLine.prefix(40)), text: text, addedAt: now)]
        }
        guard !items.isEmpty else { return }
        model.perform { game in items.flatMap { game.addToShelf($0) } }
        onAdded?()
    }

    /// What to hand to the drag session for an item, or nil if it is no longer there (file deleted or moved).
    func pasteboardWriter(for item: ShelfItem) -> NSPasteboardWriting? {
        switch item.kind {
        case .file, .folder:
            guard let path = item.path, FileManager.default.fileExists(atPath: path) else { return nil }
            return URL(fileURLWithPath: path) as NSURL
        case .link:
            return item.text.flatMap(URL.init(string:)).map { $0 as NSURL }
        case .text:
            return item.text.map { $0 as NSString }
        }
    }

    func exists(_ item: ShelfItem) -> Bool { pasteboardWriter(for: item) != nil }

    func icon(for item: ShelfItem) -> NSImage {
        switch item.kind {
        case .file, .folder:
            if let path = item.path, FileManager.default.fileExists(atPath: path) { return NSWorkspace.shared.icon(forFile: path) }
            return NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil) ?? NSImage()
        case .link: return NSImage(systemSymbolName: "link", accessibilityDescription: nil) ?? NSImage()
        case .text: return NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: nil) ?? NSImage()
        }
    }

    func open(_ item: ShelfItem) {
        switch item.kind {
        case .file, .folder: if let p = item.path { NSWorkspace.shared.open(URL(fileURLWithPath: p)) }
        case .link: if let t = item.text, let u = URL(string: t) { NSWorkspace.shared.open(u) }
        case .text:
            if let t = item.text { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(t, forType: .string) }
        }
    }

    /// A drag finished somewhere. If it landed, the item has done its job.
    func dragFinished(_ item: ShelfItem, operation: NSDragOperation) {
        guard operation != [], model.game.files.removeAfterDragOut else { return }
        model.perform { $0.removeFromShelf(id: item.id); return [] }
    }

    func remove(_ item: ShelfItem) { model.perform { $0.removeFromShelf(id: item.id); return [] } }
    func clear() { model.perform { $0.clearShelf(); return [] } }
}
