import AppKit
import CryptoKit
import Foundation
import Observation
import Security
import HeyDomain

/// Looks for a newer release on GitHub, tells the player, and (only when asked) downloads it, checks it and swaps it in.
///
/// Nothing is installed without a press of the button, and a download is refused unless all of these hold:
/// its SHA-256 matches the one GitHub publishes for the file (when GitHub publishes one), the app inside is signed by the same
/// Apple team as the running app, it is accepted by Gatekeeper (so it is notarized), and its version is really newer.
@MainActor @Observable
final class UpdateService: NSObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate(Date)
        case available(version: String)
        case downloading(Double)
        case verifying
        case installing
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var release: ReleaseInfo?

    static let repo = "giganto-th/hey"
    private static let lastCheckKey = "updateLastChecked"
    private static let notifiedKey = "updateNotifiedVersion"
    private static let autoKey = "updateAutoCheck"

    /// The running app's version; a dev run can pretend to be older to exercise the whole path.
    let currentVersion: AppVersion
    @ObservationIgnored var onAvailable: ((ReleaseInfo) -> Void)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var downloadTask: URLSessionDownloadTask?
    @ObservationIgnored private var session: URLSession!
    @ObservationIgnored private var downloadContinuation: CheckedContinuation<URL, Error>?

    override init() {
        let env = ProcessInfo.processInfo.environment
        let text = (env["HEY_DEV"] != nil ? env["HEY_DEV_UPDATE_VERSION"] : nil)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
        currentVersion = AppVersion(text) ?? AppVersion("0")!
        super.init()
        session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    }

    var autoCheck: Bool {
        get { UserDefaults.standard.object(forKey: Self.autoKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.autoKey) }
    }

    var lastChecked: Date? { UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date }
    var hasUpdate: Bool { if case .available = state { true } else if case .downloading = state { true } else { false } }

    /// Whether this copy can replace itself: it must be an app bundle in a folder the player can write to.
    var canInstallHere: Bool {
        let url = Bundle.main.bundleURL
        return url.pathExtension == "app" && FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path)
    }

    // MARK: checking

    /// Checks soon after launch and then daily, if the player has not turned it off.
    func startSchedule() {
        guard timer == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self, self.autoCheck, UpdateSchedule.isDue(lastChecked: self.lastChecked, now: Date()) else { return }
            Task { await self.check(userInitiated: false) }
        }
        let t = Timer(timeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.autoCheck, UpdateSchedule.isDue(lastChecked: self.lastChecked, now: Date()) else { return }
                Task { await self.check(userInitiated: false) }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func check(userInitiated: Bool = true) async {
        switch state { case .checking, .downloading, .verifying, .installing: return; default: break }
        state = .checking
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!, timeoutInterval: 20)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Hey-Updater/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)
            guard let info = try ReleaseFeed.parse(data), info.version > currentVersion else {
                release = nil
                state = .upToDate(Date())
                return
            }
            release = info
            state = .available(version: info.version.description)
            if UserDefaults.standard.string(forKey: Self.notifiedKey) != info.tag {       // tell the player once per version
                UserDefaults.standard.set(info.tag, forKey: Self.notifiedKey)
                onAvailable?(info)
            }
        } catch {
            state = userInitiated ? .failed(tr("ตรวจหาเวอร์ชันใหม่ไม่ได้ ตรวจอินเทอร์เน็ตนะ")) : .idle
        }
    }

    // MARK: installing

    func install() async {
        guard let info = release, case .available = state else { return }
        guard canInstallHere else { state = .failed(tr("แอปนี้อยู่ในที่ที่เขียนทับไม่ได้ ให้โหลด DMG มาติดตั้งเอง")); return }
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("hey-update-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            state = .downloading(0)
            let dmg = try await download(info.downloadURL, to: work.appendingPathComponent("Hey.dmg"))
            state = .verifying
            if let expected = info.sha256 {
                guard try Self.sha256(of: dmg) == expected else { throw UpdateError.checksum }
            }
            let mount = work.appendingPathComponent("mount")
            try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
            try Self.run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-noautoopen", "-readonly", "-mountpoint", mount.path, dmg.path])
            var mounted = true
            func unmount() { if mounted { _ = try? Self.run("/usr/bin/hdiutil", ["detach", "-force", mount.path]); mounted = false } }
            defer { unmount() }
            let source = mount.appendingPathComponent("Hey.app")
            guard FileManager.default.fileExists(atPath: source.path) else { throw UpdateError.noApp }
            // copy out of the disk image, then judge the copy (what we judge is what we install)
            let staged = work.appendingPathComponent("Hey.app")
            try Self.run("/usr/bin/ditto", [source.path, staged.path])
            unmount()                                  // the copy is all that is needed; terminate() may exit without returning
            try Self.verify(staged, newerThan: currentVersion, running: Bundle.main.bundleURL)
            state = .installing
            try launchSwapper(staged: staged, work: work)
            NSApp.terminate(nil)
        } catch {
            try? FileManager.default.removeItem(at: work)
            state = .failed((error as? UpdateError)?.message ?? tr("ติดตั้งอัปเดตไม่สำเร็จ ({0})", error.localizedDescription))
            release = info
        }
    }

    enum UpdateError: Error {
        case checksum, noApp, signature, notNotarized, notNewer, swap
        var message: String {
            switch self {
            case .checksum: tr("ไฟล์ที่โหลดมาไม่ตรงกับที่ GitHub ประกาศ จึงไม่ติดตั้ง")
            case .noApp: tr("ไม่พบ Hey.app ในไฟล์ที่โหลดมา")
            case .signature: tr("แอปใหม่ไม่ได้เซ็นโดยทีมเดียวกับแอปนี้ จึงไม่ติดตั้ง")
            case .notNotarized: tr("macOS ไม่ยอมรับแอปใหม่ (ยังไม่ผ่าน notarize) จึงไม่ติดตั้ง")
            case .notNewer: tr("แอปในไฟล์ไม่ใหม่กว่าที่ใช้อยู่ จึงไม่ติดตั้ง")
            case .swap: tr("เปลี่ยนแอปไม่สำเร็จ แอปเดิมยังอยู่ครบ")
            }
        }
    }

    // MARK: checks

    nonisolated static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Signed by our team, accepted by Gatekeeper, and a higher version than the running one.
    nonisolated static func verify(_ candidate: URL, newerThan current: AppVersion, running: URL) throws {
        guard let new = teamID(of: candidate), let old = teamID(of: running), new == old else { throw UpdateError.signature }
        do { try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", candidate.path]) } catch { throw UpdateError.signature }
        do { try run("/usr/sbin/spctl", ["--assess", "--type", "execute", candidate.path]) } catch { throw UpdateError.notNotarized }
        guard let plist = NSDictionary(contentsOf: candidate.appendingPathComponent("Contents/Info.plist")),
              let text = plist["CFBundleShortVersionString"] as? String, let version = AppVersion(text), version > current else { throw UpdateError.notNewer }
    }

    nonisolated static func teamID(of app: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }

    @discardableResult
    nonisolated static func run(_ tool: String, _ args: [String]) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: tool)
        task.arguments = args
        let out = Pipe()
        task.standardOutput = out; task.standardError = out
        try task.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw NSError(domain: "Hey.Update", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? tool]) }
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: swapping

    /// Once this app has quit, put the new one in its place (keeping the old one until the new one is in), then open it.
    /// A detached shell does it because a running app cannot replace itself.
    private func launchSwapper(staged: URL, work: URL) throws {
        let target = Bundle.main.bundleURL
        let backup = target.deletingLastPathComponent().appendingPathComponent(".Hey-previous.app")
        let script = """
        #!/bin/sh
        pid="$1"; staged="$2"; target="$3"; backup="$4"; work="$5"; log="$6"
        exec >>"$log" 2>&1
        echo "== $(date) swapping $target"
        n=0; while kill -0 "$pid" 2>/dev/null && [ $n -lt 100 ]; do sleep 0.2; n=$((n+1)); done
        rm -rf "$backup"
        if mv "$target" "$backup"; then
          if mv "$staged" "$target"; then
            xattr -dr com.apple.quarantine "$target" 2>/dev/null
            rm -rf "$backup"
            echo "swapped"
          else
            mv "$backup" "$target"
            echo "could not move the new app into place; the old one is back"
          fi
        else
          echo "could not move the old app aside; nothing changed"
        fi
        open "$target"
        rm -rf "$work"
        echo "done"
        """
        let scriptURL = work.appendingPathComponent("swap.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Logs")
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        task.arguments = [scriptURL.path, String(ProcessInfo.processInfo.processIdentifier), staged.path, target.path, backup.path, work.path,
                          logs.appendingPathComponent("Hey-update.log").path]
        task.standardOutput = FileHandle.nullDevice; task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { throw UpdateError.swap }
    }

    // MARK: download

    private func download(_ url: URL, to destination: URL) async throws -> URL {
        let file: URL = try await withCheckedThrowingContinuation { continuation in
            downloadContinuation = continuation
            let task = session.downloadTask(with: url)
            downloadTask = task
            task.resume()
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: file, to: destination)
        return destination
    }

    func cancelDownload() {
        downloadTask?.cancel()
    }

    /// The player wants nothing to do with this version.
    func dismiss() { if case .available = state { state = .idle } }
}

extension UpdateService: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in if case .downloading = self.state { self.state = .downloading(fraction) } }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // the system deletes `location` when this returns, so move it now
        let keep = FileManager.default.temporaryDirectory.appendingPathComponent("hey-dl-\(UUID().uuidString)")
        do {
            try FileManager.default.moveItem(at: location, to: keep)
            Task { @MainActor in self.downloadContinuation?.resume(returning: keep); self.downloadContinuation = nil }
        } catch {
            Task { @MainActor in self.downloadContinuation?.resume(throwing: error); self.downloadContinuation = nil }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        Task { @MainActor in self.downloadContinuation?.resume(throwing: error); self.downloadContinuation = nil }
    }
}
