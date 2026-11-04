import AppKit
import Foundation

/// Who made Hey! and where to support them. Read from `Resources/About/about.json` so it can change without touching code:
/// `people` (handle, name) with a picture `<handle>.png` beside the file, and `donations` (label plus a link, a copyable text such as
/// a PromptPay number, or a QR image file).
struct AboutContent: Decodable {
    struct Person: Decodable, Identifiable {
        let handle: String
        let name: String?
        var id: String { handle }
        var displayName: String { name ?? handle }
        var profile: URL? { URL(string: "https://github.com/\(handle)") }
    }
    struct Donation: Decodable, Identifiable {
        let label: String
        let url: String?
        let text: String?
        let image: String?
        var id: String { label + (url ?? text ?? image ?? "") }
    }

    var people: [Person] = []
    var donations: [Donation] = []

    private static let roots: [URL] = {
        var paths: [String] = []
        if let res = Bundle.main.resourcePath { paths.append(res + "/About") }
        paths.append(FileManager.default.currentDirectoryPath + "/Resources/About")
        return paths.map { URL(fileURLWithPath: $0) }
    }()

    static let current: AboutContent = {
        for root in roots {
            if let data = try? Data(contentsOf: root.appendingPathComponent("about.json")),
               let content = try? JSONDecoder().decode(AboutContent.self, from: data) { return content }
        }
        return AboutContent()
    }()

    /// A picture that sits next to `about.json` (an avatar or a QR code).
    static func image(named file: String) -> NSImage? {
        roots.lazy.compactMap { NSImage(contentsOf: $0.appendingPathComponent(file)) }.first
    }
}
