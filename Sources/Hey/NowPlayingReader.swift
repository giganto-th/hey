import AppKit
import HeyDomain

/// Asks macOS what is playing, the way Control Center does.
///
/// Since macOS 15.4 only Apple-signed programs may read this. So the work is done by `/usr/bin/perl` (Apple-signed),
/// which loads our tiny `libheynp.dylib` and runs one function that prints a line of JSON. It is a private API:
/// if Apple closes it, `read()` just returns nil and the other ways of finding songs keep working.
enum NowPlayingReader {
    static var libraryURL: URL? {
        let fm = FileManager.default
        let candidates = [
            Bundle.main.privateFrameworksURL?.appendingPathComponent("libheynp.dylib"),             // inside Hey.app
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("libheynp.dylib"),   // swift build
        ]
        return candidates.compactMap { $0 }.first { fm.fileExists(atPath: $0.path) }
    }

    private static let script = """
    use DynaLoader;
    my $lib = DynaLoader::dl_load_file($ARGV[0], 0) or exit 2;
    my $sym = DynaLoader::dl_find_symbol($lib, "heynp_dump") or exit 3;
    my $xs = DynaLoader::dl_install_xsub("main::heynp_dump", $sym);
    &$xs;
    """

    static func read() async -> NowPlayingInfo? {
        // HEY_DEV_FAKE_NP="Title|Artist|1" pretends the system is playing something (for trying the menu bar).
        if let fake = ProcessInfo.processInfo.environment["HEY_DEV_FAKE_NP"] {
            let p = fake.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            return NowPlayingInfo(title: p.first ?? "", artist: p.count > 1 ? p[1] : nil, rate: p.count > 2 ? Double(p[2]) ?? 1 : 1)
        }
        guard let lib = libraryURL else { return nil }
        return await Task.detached(priority: .utility) { () -> NowPlayingInfo? in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            process.arguments = ["-e", script, lib.path]
            let out = Pipe()
            process.standardOutput = out
            process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { return nil }
            // never let a stuck helper hang around
            let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 4, execute: killer)
            let data = out.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            killer.cancel()
            return NowPlayingInfo.parse(data)
        }.value
    }
}

/// Every tab of the running browsers we know. Needs the user's Automation permission, asked by macOS on first use.
@MainActor
enum BrowserTabs {
    enum Result { case tabs([BrowserTab]), denied(browser: String) }

    static func all() -> Result {
        var tabs: [BrowserTab] = []
        for (bundle, name) in YouTubeDetection.browsers {
            // Never ask AppleScript about a browser that isn't running: that would launch it.
            guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundle).isEmpty else { continue }
            let titleKey = name == "Safari" ? "name" : "title"
            let source = "with timeout of 2 seconds\ntell application \"\(name)\" to return {URL of tabs of windows, \(titleKey) of tabs of windows}\nend timeout"
            var error: NSDictionary?
            guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error) else {
                if (error?[NSAppleScript.errorNumber] as? Int) == -1743 { return .denied(browser: name) }
                continue
            }
            guard result.numberOfItems >= 2, let urls = result.atIndex(1), let titles = result.atIndex(2) else { continue }
            let u = strings(in: urls), t = strings(in: titles)
            for (url, title) in zip(u, t) { tabs.append(BrowserTab(url: url, title: title)) }
        }
        return .tabs(tabs)
    }

    /// AppleScript hands back a list per window; flatten them into one list of strings, keeping order.
    private static func strings(in d: NSAppleEventDescriptor) -> [String] {
        if d.numberOfItems == 0 { return d.stringValue.map { [$0] } ?? [] }
        return (1...d.numberOfItems).flatMap { i in d.atIndex(i).map(strings(in:)) ?? [] }
    }
}
