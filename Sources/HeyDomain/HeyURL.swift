import Foundation

public enum HeyCommand: Equatable, Sendable {
    case focusStart, focusStop
    case note(String)
    case copyClip(Int)
    case openHub(String?)
    case bubbles
}

/// Parses `hey://…` links so Shortcuts ("Open URLs"), Terminal or Alfred can drive the app.
///   hey://focus/start   hey://focus/stop   hey://note?text=…   hey://clip?n=0   hey://hub?page=clipboard
public enum HeyURL {
    public static func parse(_ url: URL) -> HeyCommand? {
        guard url.scheme?.lowercased() == "hey", let host = url.host?.lowercased() else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        let sub = url.path.split(separator: "/").first.map { String($0).lowercased() }
        switch host {
        case "focus":
            switch sub { case "start": return .focusStart; case "stop": return .focusStop; default: return nil }
        case "note":
            guard let text = value("text")?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return .note(String(text.prefix(2000)))
        case "clip":
            let n = value("n").flatMap(Int.init) ?? 0
            return n >= 0 && n < 100 ? .copyClip(n) : nil
        case "hub": return .openHub(value("page"))
        case "bubbles": return .bubbles
        default: return nil
        }
    }
}
