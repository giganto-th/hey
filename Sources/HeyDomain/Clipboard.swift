import Foundation

public struct ClipEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var createdAt: Date
    public var pinned: Bool

    public var isLink: Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.contains(where: \.isWhitespace), let url = URL(string: t), let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && url.host != nil
    }

    /// One short line for lists.
    public var preview: String {
        let flat = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let first = flat.first ?? ""
        let more = flat.count > 1 ? tr(" …(+{0} บรรทัด)", flat.count - 1) : ""
        return String(first.prefix(120)) + more
    }
}

/// Recent things copied as text, newest first. Memory only: nothing here is ever written to disk.
public struct ClipboardHistory: Sendable {
    public static let capacity = 30
    public static let maxLength = 20_000

    public private(set) var entries: [ClipEntry] = []

    public init() {}

    /// Returns false when the text was ignored (blank or huge).
    @discardableResult
    public mutating func add(_ text: String, at now: Date = Date()) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= Self.maxLength else { return false }
        var pinned = false
        if let i = entries.firstIndex(where: { $0.text == text }) {      // copying the same text again moves it to the top
            pinned = entries[i].pinned
            entries.remove(at: i)
        }
        let entry = ClipEntry(id: UUID(), text: text, createdAt: now, pinned: pinned)
        entries.insert(entry, at: pinned ? 0 : entries.firstIndex(where: { !$0.pinned }) ?? entries.count)
        trim()
        return true
    }

    public mutating func togglePin(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        var entry = entries.remove(at: i)
        entry.pinned.toggle()
        // pinned items stay together at the top; others keep time order
        if entry.pinned {
            entries.insert(entry, at: 0)
        } else {
            let at = entries.firstIndex(where: { !$0.pinned && $0.createdAt <= entry.createdAt }) ?? entries.count
            entries.insert(entry, at: at)
        }
    }

    public mutating func remove(_ id: UUID) { entries.removeAll { $0.id == id } }

    /// Forgets everything that isn't pinned.
    public mutating func clear() { entries.removeAll { !$0.pinned } }

    private mutating func trim() {
        while entries.count > Self.capacity, let last = entries.lastIndex(where: { !$0.pinned }) {
            entries.remove(at: last)
        }
    }
}
